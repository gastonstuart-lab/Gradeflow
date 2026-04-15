import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/services/grading_category_service.dart';
import 'package:gradeflow/services/grade_item_service.dart';
import 'package:gradeflow/services/student_score_service.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/models/student_score.dart';
import 'package:gradeflow/models/grading_category.dart';
import 'package:gradeflow/components/tool_first_app_surface.dart';
import 'package:gradeflow/components/workspace_shell.dart';
import 'package:gradeflow/theme.dart';
import 'package:uuid/uuid.dart';
import 'package:gradeflow/models/grade_item.dart';
import 'package:go_router/go_router.dart';

class GradebookScreen extends StatefulWidget {
  final String classId;

  const GradebookScreen({super.key, required this.classId});

  @override
  State<GradebookScreen> createState() => _GradebookScreenState();
}

class _GradebookScreenState extends State<GradebookScreen> {
  String? selectedCategoryId;
  String? selectedGradeItemId;
  final Map<String, TextEditingController> _controllers = {};
  final Set<String> _autoEnsuredCategories = <String>{};

  Future<bool> _confirmLeaveIfSaving() async {
    final scores = context.read<StudentScoreService>();
    if (!scores.hasPendingWrites) return true;

    // Try a short flush first (common case)
    try {
      await scores
          .flushPendingWrites()
          .timeout(const Duration(milliseconds: 1200));
      return true;
    } catch (_) {
      if (!mounted) return true;
      final leaveNow = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Saving changes…'),
          content: const Text(
              'Some scores are still being saved. Want to wait, or leave anyway?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Wait')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Leave anyway')),
          ],
        ),
      );
      if (leaveNow == true) return true;

      // User chose to wait: block until flush completes.
      try {
        await scores.flushPendingWrites();
      } catch (_) {}
      return true;
    }
  }

  bool _isHiddenItem(GradeItem item) =>
      item.name.trim().toLowerCase() == 'category total';

  String _canonicalBaseForCategory(String categoryName) {
    final lower = categoryName.toLowerCase();
    if (lower.contains('homework')) return 'Homework';
    if (lower.contains('quiz')) return 'Quiz';
    if (lower.contains('participation')) return 'Week';
    if (lower.contains('classwork')) return 'Classwork';
    return categoryName.trim();
  }

  String _suggestNameForCategory(String categoryName, int index) {
    final lower = categoryName.toLowerCase();
    if (lower.contains('homework')) return 'Homework $index';
    if (lower.contains('quiz')) return 'Quiz $index';
    if (lower.contains('participation')) return 'Week $index';
    if (lower.contains('classwork')) return 'Classwork $index';
    return '$categoryName $index';
  }

  int _nextIndexForCategory(String categoryId, String categoryName) {
    final base = _canonicalBaseForCategory(categoryName);
    final items = context
        .read<GradeItemService>()
        .getItemsByCategory(categoryId)
        .where((g) => !_isHiddenItem(g))
        .toList();
    int maxIdx = 0;
    for (final it in items) {
      final name = it.name.trim();
      if (name.toLowerCase().startsWith(base.toLowerCase())) {
        final parts = name.split(' ');
        if (parts.isNotEmpty) {
          final maybe = int.tryParse(parts.last);
          if (maybe != null && maybe > maxIdx) maxIdx = maybe;
        }
      }
    }
    return maxIdx + 1;
  }

  Future<void> _ensureFirstItemForCategory(String categoryId,
      {bool setSelection = true}) async {
    final gradeItemService = context.read<GradeItemService>();
    final items = gradeItemService
        .getItemsByCategory(categoryId)
        .where((g) => !_isHiddenItem(g))
        .toList();
    if (items.isEmpty) {
      final category = context
          .read<GradingCategoryService>()
          .categories
          .firstWhere((c) => c.categoryId == categoryId);
      final now = DateTime.now();
      final item = GradeItem(
        gradeItemId: const Uuid().v4(),
        classId: widget.classId,
        categoryId: categoryId,
        name: _suggestNameForCategory(category.name, 1),
        maxScore: 100.0,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );
      await gradeItemService.addGradeItem(item);

      final students = context.read<StudentService>().students;
      await context.read<StudentScoreService>().ensureDefaultScoresForGradeItem(
            widget.classId,
            item.gradeItemId,
            students.map((s) => s.studentId).toList(),
            item.maxScore,
          );
      if (mounted && setSelection) {
        setState(() => selectedGradeItemId = item.gradeItemId);
      }
    }
  }

  // ignore: unused_element
  Future<void> _createNextItemForSelectedCategory() async {
    if (selectedCategoryId == null) return;
    final category = context
        .read<GradingCategoryService>()
        .categories
        .firstWhere((c) => c.categoryId == selectedCategoryId);
    final nextIndex = _nextIndexForCategory(selectedCategoryId!, category.name);
    final now = DateTime.now();
    final newItem = GradeItem(
      gradeItemId: const Uuid().v4(),
      classId: widget.classId,
      categoryId: selectedCategoryId!,
      name: _suggestNameForCategory(category.name, nextIndex),
      maxScore: 100.0,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
    await context.read<GradeItemService>().addGradeItem(newItem);

    final students = context.read<StudentService>().students;
    await context.read<StudentScoreService>().ensureDefaultScoresForGradeItem(
          widget.classId,
          newItem.gradeItemId,
          students.map((s) => s.studentId).toList(),
          newItem.maxScore,
        );
    if (mounted) setState(() => selectedGradeItemId = newItem.gradeItemId);
  }

  // ignore: unused_element
  Future<void> _showEditGradeItemDialog(GradeItem item) async {
    final nameController = TextEditingController(text: item.name);
    final maxScoreController =
        TextEditingController(text: item.maxScore.toStringAsFixed(0));
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Grade Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: AppSpacing.md),
            TextField(
                controller: maxScoreController,
                decoration: const InputDecoration(labelText: 'Max Score'),
                keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'delete'),
              child: const Text('Delete')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: const Text('Save')),
        ],
      ),
    );
    if (!mounted) return;
    if (result == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Delete Grade Item'),
          content: Text(
              'Delete "${item.name}"? Scores for this item will be hidden.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Delete')),
          ],
        ),
      );
      if (confirmed == true) {
        await context
            .read<GradeItemService>()
            .deleteGradeItem(item.gradeItemId);
        if (selectedGradeItemId == item.gradeItemId) {
          setState(() => selectedGradeItemId = null);
        }
      }
      return;
    }
    if (result == 'save') {
      final maxScore =
          double.tryParse(maxScoreController.text) ?? item.maxScore;
      final updated = item.copyWith(
          name: nameController.text.trim().isEmpty
              ? item.name
              : nameController.text.trim(),
          maxScore: maxScore,
          updatedAt: DateTime.now());
      await context.read<GradeItemService>().updateGradeItem(updated);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final studentService = context.read<StudentService>();
    final categoryService = context.read<GradingCategoryService>();
    final gradeItemService = context.read<GradeItemService>();
    final scoreService = context.read<StudentScoreService>();

    await studentService.loadStudents(widget.classId);
    if (!mounted) return;
    await categoryService.loadCategories(widget.classId);
    if (!mounted) return;
    await gradeItemService.loadGradeItems(widget.classId);
    if (!mounted) return;

    final gradeItemIds =
        gradeItemService.gradeItems.map((g) => g.gradeItemId).toList();
    await scoreService.loadScores(widget.classId, gradeItemIds);
    if (!mounted) return;

    // Initialize default selections safely after data is loaded (not during build)
    final categories = categoryService.categories;
    // Ensure every category has at least one item, but don't change current selection during bulk ensure
    for (final c in categories) {
      await _ensureFirstItemForCategory(c.categoryId, setSelection: false);
      if (!mounted) return;
    }
    // Choose first category and ensure at least one visible item exists
    if (categories.isNotEmpty) {
      selectedCategoryId ??= categories.first.categoryId;
      if (selectedCategoryId != null) {
        final refreshed = gradeItemService.gradeItems
            .where(
                (g) => g.categoryId == selectedCategoryId && !_isHiddenItem(g))
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        if (refreshed.isEmpty) {
          await _ensureFirstItemForCategory(selectedCategoryId!);
          if (!mounted) return;
        }
      }
    }
    if (mounted) {
      setState(() {
        if (selectedCategoryId != null) {
          final firstItems = gradeItemService.gradeItems
              .where((g) =>
                  g.categoryId == selectedCategoryId && !_isHiddenItem(g))
              .toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
          selectedGradeItemId ??=
              firstItems.isNotEmpty ? firstItems.first.gradeItemId : null;
        }
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _showAddGradeItemDialog() async {
    if (selectedCategoryId == null) {
      _showError('Please select a category first');
      return;
    }

    final nameController = TextEditingController();
    final maxScoreController = TextEditingController(text: '100');

    // Suggest a default name like Homework 1, Quiz 1, Week 1, etc.
    final category = context
        .read<GradingCategoryService>()
        .categories
        .firstWhere((c) => c.categoryId == selectedCategoryId);
    final nextIndex = _nextIndexForCategory(selectedCategoryId!, category.name);
    final suggestName = _suggestNameForCategory(category.name, nextIndex);
    nameController.text = suggestName;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Grade Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: maxScoreController,
              decoration: const InputDecoration(labelText: 'Max Score'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add')),
        ],
      ),
    );

    if (result == true && mounted) {
      final now = DateTime.now();
      final gradeItem = GradeItem(
        gradeItemId: const Uuid().v4(),
        classId: widget.classId,
        categoryId: selectedCategoryId!,
        name: nameController.text,
        maxScore: double.tryParse(maxScoreController.text) ?? 100.0,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      await context.read<GradeItemService>().addGradeItem(gradeItem);

      final students = context.read<StudentService>().students;
      await context.read<StudentScoreService>().ensureDefaultScoresForGradeItem(
            widget.classId,
            gradeItem.gradeItemId,
            students.map((s) => s.studentId).toList(),
            gradeItem.maxScore,
          );
      _showSuccess('Grade item added');
    }
  }

  Future<void> _updateScore(
      String studentId, String gradeItemId, double? score) async {
    final now = DateTime.now();
    final studentScore = StudentScore(
      studentId: studentId,
      gradeItemId: gradeItemId,
      score: score,
      createdAt: now,
      updatedAt: now,
    );

    final authService = context.read<AuthService>();
    await context.read<StudentScoreService>().updateScore(
          studentScore,
          authService.currentUser!.userId,
          widget.classId,
        );
  }

  void _openQuickGradeSheet(int startIndex) {
    final students = context.read<StudentService>().students;
    if (selectedGradeItemId == null || students.isEmpty) return;
    final item = context
        .read<GradeItemService>()
        .gradeItems
        .firstWhere((g) => g.gradeItemId == selectedGradeItemId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) {
        int idx = startIndex;
        double? localValue = context
                .read<StudentScoreService>()
                .getScore(students[idx].studentId, item.gradeItemId)
                ?.score ??
            item.maxScore;
        return StatefulBuilder(builder: (ctx, setSheetState) {
          void loadIndex(int newIdx) {
            idx = newIdx;
            final current = context
                .read<StudentScoreService>()
                .getScore(students[idx].studentId, item.gradeItemId)
                ?.score;
            localValue =
                current ?? (item.maxScore <= 1 ? 100.0 : item.maxScore);
            setSheetState(() {});
          }

          final max = item.maxScore <= 1 ? 100.0 : item.maxScore;
          final min = 0.0;
          final divisions = max > min ? (max - min).round() : null;
          final s = students[idx];
          return Padding(
            padding: AppSpacing.paddingMd,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StudentAvatar(
                        photoBase64: s.photoBase64,
                        name: '${s.chineseName} ${s.englishFullName}'),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${s.chineseName} • ${s.englishFullName}',
                                style: context.textStyles.titleLarge,
                                overflow: TextOverflow.ellipsis),
                            Text(
                                'ID: ${s.studentId}${s.seatNo != null ? '  •  Seat ${s.seatNo}' : ''}',
                                style: context.textStyles.labelSmall,
                                overflow: TextOverflow.ellipsis),
                          ]),
                    ),
                    Text('${idx + 1}/${students.length}',
                        style: context.textStyles.labelMedium),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(children: [
                  Expanded(
                    child: Slider(
                      value: (localValue ?? max).clamp(min, max),
                      min: min,
                      max: max,
                      divisions: divisions,
                      label: (localValue ?? max).toStringAsFixed(0),
                      onChanged: (v) => setSheetState(() => localValue = v),
                      onChangeEnd: (v) =>
                          _updateScore(s.studentId, item.gradeItemId, v),
                    ),
                  ),
                  SizedBox(
                      width: 64,
                      child: Text((localValue ?? max).toStringAsFixed(0),
                          textAlign: TextAlign.end,
                          style: context.textStyles.titleMedium)),
                ]),
                const SizedBox(height: AppSpacing.sm),
                Row(children: [
                  TextButton.icon(
                    onPressed: () {
                      setSheetState(() => localValue = null);
                      _updateScore(s.studentId, item.gradeItemId, null);
                    },
                    icon: const Icon(Icons.backspace_outlined),
                    label: const Text('Clear'),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Previous',
                    onPressed: idx > 0 ? () => loadIndex(idx - 1) : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    tooltip: 'Next',
                    onPressed: idx < students.length - 1
                        ? () => loadIndex(idx + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.check),
                    label: const Text('Done'),
                  ),
                ]),
              ],
            ),
          );
        });
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final classService = context.watch<ClassService>();
    final studentService = context.watch<StudentService>();
    final categoryService = context.watch<GradingCategoryService>();
    final gradeItemService = context.watch<GradeItemService>();
    final scoreService = context.watch<StudentScoreService>();
    final classItem = classService.getClassById(widget.classId);
    final availableClasses = classService.classes;
    final selectedCategory = categoryService.categories
        .where((c) => c.categoryId == selectedCategoryId)
        .firstOrNull;
    final selectedGradeItem = gradeItemService.gradeItems
        .where((g) => g.gradeItemId == selectedGradeItemId)
        .firstOrNull;

    final categoryItems = selectedCategoryId != null
        ? (gradeItemService.gradeItems
            .where(
                (g) => g.categoryId == selectedCategoryId && !_isHiddenItem(g))
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt)))
        : <GradeItem>[];

    // Safety net: if a category is selected but still has no items, auto-create the first once
    if (selectedCategoryId != null &&
        categoryItems.isEmpty &&
        !_autoEnsuredCategories.contains(selectedCategoryId)) {
      _autoEnsuredCategories.add(selectedCategoryId!);
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _ensureFirstItemForCategory(selectedCategoryId!));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final ok = await _confirmLeaveIfSaving();
        if (ok && mounted) Navigator.of(context).pop(result);
      },
      child: ToolFirstAppSurface(
        eyebrow: 'Class gradebook',
        title: classItem?.className ?? 'Gradebook',
        subtitle: classItem != null
            ? '${classItem.subject} - ${classItem.schoolYear} - ${classItem.term}'
            : 'Enter scores for students',
        leading: IconButton(
          onPressed: () => context.go('/classes'),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to classes',
        ),
        trailing: [
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String>(
              value: widget.classId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Class',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              items: [
                for (final item in availableClasses)
                  DropdownMenuItem(
                    value: item.classId,
                    child:
                        Text(item.className, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) {
                if (value != null && value != widget.classId) {
                  context.go('/class/$value/gradebook');
                }
              },
            ),
          ),
        ],
        contextStrip: _CompactGradebookContextStrip(
          studentCount: studentService.students.length,
          categoryCount: categoryService.categories.length,
          syncStatus: scoreService.hasPendingWrites ? 'Saving...' : 'Synced',
          selectedCategory: selectedCategory?.name,
          selectedGradeItem: selectedGradeItem?.name,
        ),
        toolbar: _CompactGradebookToolbar(
          categories: categoryService.categories,
          categoryItems: categoryItems,
          selectedCategoryId: selectedCategoryId,
          selectedGradeItemId: selectedGradeItemId,
          onCategoryChanged: (catId) {
            setState(() {
              selectedCategoryId = catId;
              selectedGradeItemId = null;
            });
            _ensureFirstItemForCategory(catId);
          },
          onGradeItemChanged: (itemId) {
            setState(() => selectedGradeItemId = itemId);
          },
          onAddGradeItem: _showAddGradeItemDialog,
          onUndoLastChange: () async {
            try {
              final authService = context.read<AuthService>();
              final userId = authService.currentUser?.userId;
              if (userId == null) {
                _showError('Please log in to undo changes.');
                return;
              }

              final scores = context.read<StudentScoreService>();
              if (scores.hasPendingWrites) {
                try {
                  await scores
                      .flushPendingWrites()
                      .timeout(const Duration(milliseconds: 1200));
                } catch (_) {}
              }

              final ok = await scores.undoLastChange(userId, widget.classId);
              if (!mounted) return;
              if (ok) {
                _showSuccess('Undid last score change');
              } else {
                _showError('Nothing to undo');
              }
            } catch (e) {
              debugPrint('Undo failed: $e');
              if (mounted) _showError('Undo failed');
            }
          },
          onApplyToAll: selectedGradeItemId == null
              ? null
              : () async {
                  final item = context
                      .read<GradeItemService>()
                      .gradeItems
                      .firstWhere((g) => g.gradeItemId == selectedGradeItemId);
                  double temp = item.maxScore <= 1 ? 100.0 : item.maxScore;
                  await showModalBottomSheet(
                    context: context,
                    showDragHandle: true,
                    builder: (ctx) {
                      return Padding(
                        padding: AppSpacing.paddingMd,
                        child: StatefulBuilder(
                          builder: (ctx, setSheetState) {
                            final max =
                                item.maxScore <= 1 ? 100.0 : item.maxScore;
                            const min = 0.0;
                            final divisions =
                                max > min ? (max - min).round() : null;
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Set score for entire class',
                                    style: context.textStyles.titleLarge),
                                const SizedBox(height: AppSpacing.sm),
                                Row(children: [
                                  Expanded(
                                    child: Slider(
                                      value: temp.clamp(min, max),
                                      min: min,
                                      max: max,
                                      divisions: divisions,
                                      label: temp.toStringAsFixed(0),
                                      onChanged: (v) =>
                                          setSheetState(() => temp = v),
                                    ),
                                  ),
                                  SizedBox(
                                      width: 56,
                                      child: Text(temp.toStringAsFixed(0),
                                          textAlign: TextAlign.end,
                                          style:
                                              context.textStyles.titleMedium)),
                                ]),
                                const SizedBox(height: AppSpacing.sm),
                                Row(
                                  children: [
                                    TextButton.icon(
                                        onPressed: () => Navigator.pop(ctx),
                                        icon: const Icon(Icons.close),
                                        label: const Text('Cancel')),
                                    const Spacer(),
                                    FilledButton.icon(
                                      icon: const Icon(Icons.done_all),
                                      label: const Text('Apply to all'),
                                      onPressed: () async {
                                        try {
                                          final authService =
                                              context.read<AuthService>();
                                          final students = context
                                              .read<StudentService>()
                                              .students
                                              .map((s) => s.studentId)
                                              .toList();
                                          await context
                                              .read<StudentScoreService>()
                                              .setAllScoresForGradeItem(
                                                widget.classId,
                                                item.gradeItemId,
                                                students,
                                                temp,
                                                authService.currentUser!.userId,
                                              );
                                          if (!mounted) return;
                                          setState(
                                              () {}); // ensure rebuild so rows pick up new initialScore
                                          _showSuccess(
                                              'Applied ${temp.toStringAsFixed(0)} to entire class');
                                          Navigator.pop(ctx);
                                        } catch (e) {
                                          debugPrint('Apply-to-all failed: $e');
                                          if (mounted) {
                                            _showError(
                                                'Failed to apply to all. Please try again.');
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      );
                    },
                  );
                },
          onDeleteGradeItem: selectedGradeItemId == null
              ? null
              : () async {
                  final item = context
                      .read<GradeItemService>()
                      .gradeItems
                      .firstWhere((g) => g.gradeItemId == selectedGradeItemId);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Grade Item'),
                      content: Text(
                          'Delete "${item.name}"? Scores for this item will be hidden.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel')),
                        FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete')),
                      ],
                    ),
                  );
                  if (confirm == true && mounted) {
                    await context
                        .read<GradeItemService>()
                        .deleteGradeItem(item.gradeItemId);
                    setState(() => selectedGradeItemId = null);
                  }
                },
        ),
        workspace: selectedGradeItem == null
            ? const WorkspaceEmptyState(
                icon: Icons.edit_note_outlined,
                title: 'Select a grade item',
                subtitle:
                    'Choose a category and an assessment to open the active grading workspace.',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _GradebookActiveContextCard(
                    categoryName: selectedCategory?.name,
                    gradeItemName: selectedGradeItem.name,
                    maxScore: selectedGradeItem.maxScore,
                    studentCount: studentService.students.length,
                    syncStatus:
                        scoreService.hasPendingWrites ? 'Saving...' : 'Synced',
                  ),
                  const SizedBox(height: WorkspaceSpacing.lg),
                  const WorkspaceSectionHeader(
                    title: 'Student roster',
                    subtitle:
                        'Adjust scores in place, keep class context visible, and jump into a student quick-grade sheet when you need more detail.',
                  ),
                  const SizedBox(height: WorkspaceSpacing.md),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: studentService.students.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final student = studentService.students[index];
                        final current = scoreService.getScore(
                          student.studentId,
                          selectedGradeItem.gradeItemId,
                        );
                        return _ScoreSliderRow(
                          key: ValueKey(
                            '${student.studentId}_${selectedGradeItem.gradeItemId}',
                          ),
                          studentName:
                              '${student.chineseName} • ${student.englishFullName}',
                          studentId: student.studentId,
                          seatNo: student.seatNo,
                          photoBase64: student.photoBase64,
                          gradeItemId: selectedGradeItem.gradeItemId,
                          maxScore: selectedGradeItem.maxScore,
                          initialScore: current?.score,
                          onChanged: (val) => _updateScore(
                            student.studentId,
                            selectedGradeItem.gradeItemId,
                            val,
                          ),
                          onClear: () => _updateScore(
                            student.studentId,
                            selectedGradeItem.gradeItemId,
                            null,
                          ),
                          onOpen: () => _openQuickGradeSheet(index),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CompactGradebookContextStrip extends StatelessWidget {
  const _CompactGradebookContextStrip({
    required this.studentCount,
    required this.categoryCount,
    required this.syncStatus,
    this.selectedCategory,
    this.selectedGradeItem,
  });

  final int studentCount;
  final int categoryCount;
  final String syncStatus;
  final String? selectedCategory;
  final String? selectedGradeItem;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          WorkspaceContextPill(
            icon: Icons.people_alt_outlined,
            label: 'Students',
            value: '$studentCount',
          ),
          const SizedBox(width: 8),
          WorkspaceContextPill(
            icon: Icons.category_outlined,
            label: 'Categories',
            value: '$categoryCount',
          ),
          const SizedBox(width: 8),
          WorkspaceContextPill(
            icon:
                syncStatus == 'Synced' ? Icons.cloud_done_outlined : Icons.sync,
            label: 'Sync',
            value: syncStatus,
            accent: syncStatus == 'Synced'
                ? Theme.of(context).colorScheme.primary
                : const Color(0xFFDAA85E),
            emphasized: true,
          ),
          if (selectedCategory != null) ...[
            const SizedBox(width: 8),
            WorkspaceContextPill(
              icon: Icons.bookmark_outline,
              label: 'Category',
              value: selectedCategory!,
            ),
          ],
          if (selectedGradeItem != null) ...[
            const SizedBox(width: 8),
            WorkspaceContextPill(
              icon: Icons.assignment_turned_in_outlined,
              label: 'Assessment',
              value: selectedGradeItem!,
            ),
          ],
        ],
      ),
    );
  }
}

class _CompactGradebookToolbar extends StatelessWidget {
  final List<GradingCategory> categories;
  final List<GradeItem> categoryItems;
  final String? selectedCategoryId;
  final String? selectedGradeItemId;
  final Function(String) onCategoryChanged;
  final Function(String) onGradeItemChanged;
  final VoidCallback onAddGradeItem;
  final VoidCallback onUndoLastChange;
  final VoidCallback? onApplyToAll;
  final VoidCallback? onDeleteGradeItem;

  const _CompactGradebookToolbar({
    required this.categories,
    required this.categoryItems,
    required this.selectedCategoryId,
    required this.selectedGradeItemId,
    required this.onCategoryChanged,
    required this.onGradeItemChanged,
    required this.onAddGradeItem,
    required this.onUndoLastChange,
    required this.onApplyToAll,
    required this.onDeleteGradeItem,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (categories.isNotEmpty)
            SizedBox(
              width: 176,
              child: DropdownButtonFormField<String>(
                value: selectedCategoryId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                items: [
                  for (final cat in categories)
                    DropdownMenuItem(
                      value: cat.categoryId,
                      child: Text(cat.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    onCategoryChanged(value);
                  }
                },
              ),
            ),
          const SizedBox(width: 8),
          if (selectedCategoryId != null && categoryItems.isNotEmpty)
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<String>(
                value: selectedGradeItemId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Assessment',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                items: [
                  for (final item in categoryItems)
                    DropdownMenuItem(
                      value: item.gradeItemId,
                      child: Text(item.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    onGradeItemChanged(value);
                  }
                },
              ),
            ),
          const SizedBox(width: 10),
          if (selectedCategoryId != null)
            FilledButton.icon(
              onPressed: onAddGradeItem,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add item'),
              style: WorkspaceButtonStyles.filled(context, compact: true),
            ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onUndoLastChange,
            icon: const Icon(Icons.undo_rounded),
            label: const Text('Undo'),
            style: WorkspaceButtonStyles.outlined(context, compact: true),
          ),
          if (onApplyToAll != null) ...[
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: onApplyToAll,
              icon: const Icon(Icons.done_all_rounded),
              label: const Text('Apply to all'),
              style: WorkspaceButtonStyles.tonal(context, compact: true),
            ),
          ],
          if (onDeleteGradeItem != null) ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: onDeleteGradeItem,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Delete'),
              style: WorkspaceButtonStyles.outlined(context, compact: true),
            ),
          ],
        ],
      ),
    );
  }
}

class _GradebookActiveContextCard extends StatelessWidget {
  const _GradebookActiveContextCard({
    required this.gradeItemName,
    required this.maxScore,
    required this.studentCount,
    required this.syncStatus,
    this.categoryName,
  });

  final String gradeItemName;
  final double maxScore;
  final int studentCount;
  final String syncStatus;
  final String? categoryName;

  @override
  Widget build(BuildContext context) {
    return WorkspaceContextBar(
      title: gradeItemName,
      subtitle: categoryName == null
          ? 'Active grading context'
          : 'Active grading context for $categoryName',
      leading: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (categoryName != null)
            WorkspaceContextPill(
              icon: Icons.bookmark_outline,
              label: 'Category',
              value: categoryName!,
            ),
          WorkspaceContextPill(
            icon: Icons.rule_folder_outlined,
            label: 'Max score',
            value: maxScore <= 1 ? '100' : maxScore.toStringAsFixed(0),
          ),
          WorkspaceContextPill(
            icon: Icons.people_alt_outlined,
            label: 'Roster',
            value: '$studentCount students',
          ),
        ],
      ),
      trailing: WorkspaceContextPill(
        icon: syncStatus == 'Synced' ? Icons.cloud_done_outlined : Icons.sync,
        label: 'Sync',
        value: syncStatus,
        accent: syncStatus == 'Synced'
            ? Theme.of(context).colorScheme.primary
            : const Color(0xFFDAA85E),
        emphasized: true,
      ),
    );
  }
}

class _ScoreSliderRow extends StatefulWidget {
  final String studentName;
  final String studentId;
  final String? seatNo;
  final String? photoBase64;
  final String gradeItemId;
  final double maxScore;
  final double? initialScore;
  final ValueChanged<double?> onChanged;
  final VoidCallback onClear;
  final VoidCallback onOpen;

  const _ScoreSliderRow(
      {super.key,
      required this.studentName,
      required this.studentId,
      this.seatNo,
      this.photoBase64,
      required this.gradeItemId,
      required this.maxScore,
      required this.initialScore,
      required this.onChanged,
      required this.onClear,
      required this.onOpen});

  @override
  State<_ScoreSliderRow> createState() => _ScoreSliderRowState();
}

class _ScoreSliderRowState extends State<_ScoreSliderRow> {
  double? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialScore;
  }

  @override
  void didUpdateWidget(covariant _ScoreSliderRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialScore != widget.initialScore ||
        oldWidget.gradeItemId != widget.gradeItemId) {
      _value = widget.initialScore;
    }
  }

  @override
  Widget build(BuildContext context) {
    final max = widget.maxScore <= 1 ? 100.0 : widget.maxScore;
    final min = 0.0;
    final display = (_value ?? max).toStringAsFixed(0);
    final divisions = max > min ? (max - min).round() : null;
    return WorkspaceSurfaceCard(
      radius: WorkspaceRadius.cardCompact,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: InkWell(
        onTap: widget.onOpen,
        borderRadius: BorderRadius.circular(WorkspaceRadius.context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StudentAvatar(
                  photoBase64: widget.photoBase64,
                  name: widget.studentName,
                ),
                const SizedBox(width: WorkspaceSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.studentName,
                        style: context.textStyles.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'ID: ${widget.studentId}${widget.seatNo != null ? ' • Seat ${widget.seatNo}' : ''}',
                        style: WorkspaceTypography.utility(context)?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: WorkspaceSpacing.sm),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(WorkspaceRadius.button),
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.10),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.18),
                    ),
                  ),
                  child: Text(
                    '$display / ${max.toStringAsFixed(0)}',
                    style: WorkspaceTypography.pillValue(
                      context,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: WorkspaceSpacing.xs),
                IconButton(
                  tooltip: 'Clear score',
                  icon: const Icon(Icons.backspace_outlined),
                  onPressed: () {
                    setState(() => _value = null);
                    widget.onClear();
                  },
                  style: WorkspaceButtonStyles.icon(context, compact: true),
                ),
                IconButton(
                  tooltip: 'Quick grade',
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: widget.onOpen,
                  style: WorkspaceButtonStyles.icon(context, compact: true),
                ),
              ],
            ),
            const SizedBox(height: WorkspaceSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: (_value ?? max).clamp(min, max),
                    min: min,
                    max: max,
                    divisions: divisions,
                    label: display,
                    onChanged: (v) => setState(() => _value = v),
                    onChangeEnd: (v) => widget.onChanged(v),
                  ),
                ),
                const SizedBox(width: WorkspaceSpacing.md),
                SizedBox(
                  width: 52,
                  child: Text(
                    display,
                    textAlign: TextAlign.end,
                    style: context.textStyles.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentAvatar extends StatelessWidget {
  final String? photoBase64;
  final String name;
  const _StudentAvatar({required this.photoBase64, required this.name});

  @override
  Widget build(BuildContext context) {
    ImageProvider? img;
    if (photoBase64 != null && photoBase64!.isNotEmpty) {
      try {
        img = MemoryImage(base64Decode(photoBase64!));
      } catch (_) {}
    }
    return CircleAvatar(
        radius: 20,
        backgroundImage: img,
        child: img == null
            ? Text(name.isNotEmpty ? name.characters.first : '?')
            : null);
  }
}
