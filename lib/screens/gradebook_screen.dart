import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/services/grading_category_service.dart';
import 'package:gradeflow/services/grade_item_service.dart';
import 'package:gradeflow/services/student_score_service.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/models/student_score.dart';
import 'package:gradeflow/theme.dart';
import 'package:uuid/uuid.dart';
import 'package:gradeflow/models/grade_item.dart';
import 'package:gradeflow/components/animated_glow_border.dart';

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
    final studentService = context.watch<StudentService>();
    final categoryService = context.watch<GradingCategoryService>();
    final gradeItemService = context.watch<GradeItemService>();
    final scoreService = context.watch<StudentScoreService>();

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
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gradebook'),
          actions: [
            if (selectedCategoryId != null)
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _showAddGradeItemDialog,
                tooltip: 'Add Grade Item',
              ),
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Undo last score change',
              onPressed: () async {
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
                    } catch (_) {
                      // Best-effort: still allow undo (it will enqueue behind pending writes).
                    }
                  }

                  final ok =
                      await scores.undoLastChange(userId, widget.classId);
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
            ),
            if (selectedGradeItemId != null)
              IconButton(
                icon: const Icon(Icons.done_all),
                tooltip: 'Apply score to all',
                onPressed: () async {
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
              ),
            if (selectedGradeItemId != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete selected item',
                onPressed: () async {
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
          ],
        ),
        body: Column(
          children: [
            if (categoryService.categories.isNotEmpty)
              Container(
                padding: AppSpacing.paddingMd,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Category', style: context.textStyles.labelLarge),
                    const SizedBox(height: AppSpacing.sm),
                    LayoutBuilder(
                      builder: (ctx, constraints) {
                        final isCompact = constraints.maxWidth < 520;
                        if (isCompact &&
                            categoryService.categories.length > 3) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('☞ Swipe to see all categories',
                                  style: context.textStyles.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
                              const SizedBox(height: 4),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Row(
                                  children: categoryService.categories
                                      .map((category) {
                                    final isSelected = category.categoryId ==
                                        selectedCategoryId;
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                          right: AppSpacing.sm),
                                      child: ChoiceChip(
                                        label: Text(category.name,
                                            overflow: TextOverflow.ellipsis),
                                        selected: isSelected,
                                        onSelected: (selected) async {
                                          setState(() {
                                            selectedCategoryId =
                                                category.categoryId;
                                            selectedGradeItemId = null;
                                          });
                                          await _ensureFirstItemForCategory(
                                              category.categoryId);
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          );
                        }
                        if (isCompact) {
                          return Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children:
                                categoryService.categories.map((category) {
                              final isSelected =
                                  category.categoryId == selectedCategoryId;
                              return ChoiceChip(
                                label: Text(category.name,
                                    overflow: TextOverflow.ellipsis),
                                selected: isSelected,
                                onSelected: (selected) async {
                                  setState(() {
                                    selectedCategoryId = category.categoryId;
                                    selectedGradeItemId = null;
                                  });
                                  await _ensureFirstItemForCategory(
                                      category.categoryId);
                                },
                              );
                            }).toList(),
                          );
                        }
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children:
                                categoryService.categories.map((category) {
                              final isSelected =
                                  category.categoryId == selectedCategoryId;
                              return Padding(
                                padding:
                                    const EdgeInsets.only(right: AppSpacing.sm),
                                child: ChoiceChip(
                                  label: Text(category.name,
                                      overflow: TextOverflow.ellipsis),
                                  selected: isSelected,
                                  onSelected: (selected) async {
                                    setState(() {
                                      selectedCategoryId = category.categoryId;
                                      selectedGradeItemId = null;
                                    });
                                    await _ensureFirstItemForCategory(
                                        category.categoryId);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                    if (categoryItems.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Text('Grade Item',
                              style: context.textStyles.labelLarge),
                          const Spacer(),
                          if (selectedCategoryId != null)
                            IconButton(
                              tooltip: 'Add next item',
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: _createNextItemForSelectedCategory,
                            ),
                          if (selectedGradeItemId != null)
                            IconButton(
                              tooltip: 'Edit selected item',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () {
                                final item = categoryItems.firstWhere((e) =>
                                    e.gradeItemId == selectedGradeItemId);
                                _showEditGradeItemDialog(item);
                              },
                            ),
                          if (selectedGradeItemId != null)
                            IconButton(
                              tooltip: 'Delete selected item',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                final item = categoryItems.firstWhere((e) =>
                                    e.gradeItemId == selectedGradeItemId);
                                await context
                                    .read<GradeItemService>()
                                    .deleteGradeItem(item.gradeItemId);
                                if (mounted) {
                                  setState(() => selectedGradeItemId = null);
                                }
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      LayoutBuilder(
                        builder: (ctx, constraints) {
                          final isCompact = constraints.maxWidth < 520;
                          final chips = categoryItems.map((item) {
                            final isSelected =
                                item.gradeItemId == selectedGradeItemId;
                            final chip = GestureDetector(
                              onLongPress: () => _showEditGradeItemDialog(item),
                              child: InputChip(
                                label: Text(item.name,
                                    overflow: TextOverflow.ellipsis),
                                selected: isSelected,
                                onSelected: (selected) => setState(() =>
                                    selectedGradeItemId = item.gradeItemId),
                                onDeleted: () async {
                                  await context
                                      .read<GradeItemService>()
                                      .deleteGradeItem(item.gradeItemId);
                                  if (mounted &&
                                      selectedGradeItemId == item.gradeItemId) {
                                    setState(() => selectedGradeItemId = null);
                                  }
                                },
                              ),
                            );
                            return isCompact
                                ? chip
                                : Padding(
                                    padding: const EdgeInsets.only(
                                        right: AppSpacing.sm),
                                    child: chip,
                                  );
                          }).toList();

                          // Add inline "Add next" chip
                          final category = categoryService.categories
                              .firstWhere(
                                  (c) => c.categoryId == selectedCategoryId);
                          final nextName = _suggestNameForCategory(
                              category.name,
                              _nextIndexForCategory(
                                  selectedCategoryId!, category.name));
                          final addChip = ActionChip(
                            avatar: const Icon(Icons.add, size: 18),
                            label: Text('Add $nextName',
                                overflow: TextOverflow.ellipsis),
                            onPressed: _createNextItemForSelectedCategory,
                          );
                          if (isCompact) {
                            chips.add(addChip);
                          } else {
                            chips.add(Padding(
                                padding:
                                    const EdgeInsets.only(right: AppSpacing.sm),
                                child: addChip));
                          }
                          if (isCompact) {
                            return Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.sm,
                                children: chips);
                          }
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(children: chips),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            Expanded(
              child: selectedGradeItemId == null
                  ? (selectedCategoryId != null && categoryItems.isEmpty
                      ? Center(
                          child: Padding(
                            padding: AppSpacing.paddingLg,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.playlist_add,
                                    size: 64,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                                const SizedBox(height: AppSpacing.md),
                                Text('Start grading this category',
                                    style: context.textStyles.titleLarge,
                                    textAlign: TextAlign.center),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                    'Create the first item (e.g., Homework 1, Quiz 1, Week 1).',
                                    style: context.textStyles.bodyMedium,
                                    textAlign: TextAlign.center),
                                const SizedBox(height: AppSpacing.md),
                                FilledButton.icon(
                                  icon: const Icon(Icons.add_chart),
                                  label: const Text('Add First Item (100)'),
                                  onPressed: () async {
                                    final now = DateTime.now();
                                    final category = context
                                        .read<GradingCategoryService>()
                                        .categories
                                        .firstWhere((c) =>
                                            c.categoryId == selectedCategoryId);
                                    final itemsInCategory = context
                                        .read<GradeItemService>()
                                        .getItemsByCategory(selectedCategoryId!)
                                        .where((g) => !_isHiddenItem(g))
                                        .toList();
                                    final nextIndex =
                                        itemsInCategory.length + 1;
                                    final suggestName = _suggestNameForCategory(
                                        category.name, nextIndex);
                                    final item = GradeItem(
                                      gradeItemId: const Uuid().v4(),
                                      classId: widget.classId,
                                      categoryId: selectedCategoryId!,
                                      name: suggestName,
                                      maxScore: 100.0,
                                      isActive: true,
                                      createdAt: now,
                                      updatedAt: now,
                                    );
                                    await context
                                        .read<GradeItemService>()
                                        .addGradeItem(item);

                                    final students = context
                                        .read<StudentService>()
                                        .students
                                        .map((s) => s.studentId)
                                        .toList();
                                    await context
                                        .read<StudentScoreService>()
                                        .ensureDefaultScoresForGradeItem(
                                          widget.classId,
                                          item.gradeItemId,
                                          students,
                                          item.maxScore,
                                        );
                                    if (mounted) {
                                      setState(() => selectedGradeItemId =
                                          item.gradeItemId);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.edit_note,
                                  size: 64,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                              const SizedBox(height: AppSpacing.md),
                              Text('No grade items yet',
                                  style: context.textStyles.titleLarge),
                              Text('Add a grade item to start entering scores',
                                  style: context.textStyles.bodyMedium),
                            ],
                          ),
                        ))
                  : ListView.builder(
                      padding: AppSpacing.paddingMd,
                      itemCount: studentService.students.length,
                      itemBuilder: (context, index) {
                        final student = studentService.students[index];
                        final item = gradeItemService.gradeItems.firstWhere(
                            (g) => g.gradeItemId == selectedGradeItemId);
                        final current = scoreService.getScore(
                            student.studentId, selectedGradeItemId!);
                        return _ScoreSliderRow(
                          key: ValueKey(
                              '${student.studentId}_${item.gradeItemId}'),
                          studentName:
                              '${student.chineseName} • ${student.englishFullName}',
                          studentId: student.studentId,
                          seatNo: student.seatNo,
                          photoBase64: student.photoBase64,
                          gradeItemId: item.gradeItemId,
                          maxScore: item.maxScore,
                          initialScore: current?.score,
                          onChanged: (val) => _updateScore(
                              student.studentId, item.gradeItemId, val),
                          onClear: () => _updateScore(
                              student.studentId, item.gradeItemId, null),
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
    return AnimatedGlowBorder(
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: InkWell(
          onTap: widget.onOpen,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: AppSpacing.paddingMd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StudentAvatar(
                        photoBase64: widget.photoBase64,
                        name: widget.studentName),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.studentName,
                              style: context.textStyles.titleMedium,
                              softWrap: true,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(
                              'ID: ${widget.studentId}${widget.seatNo != null ? '  •  Seat ${widget.seatNo}' : ''}',
                              style: context.textStyles.labelSmall,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Clear score',
                      icon: const Icon(Icons.backspace_outlined),
                      onPressed: () {
                        setState(() => _value = null);
                        widget.onClear();
                      },
                    ),
                    IconButton(
                      tooltip: 'Quick grade',
                      icon: const Icon(Icons.chevron_right),
                      onPressed: widget.onOpen,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
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
                    SizedBox(
                      width: 56,
                      child: Text(display,
                          textAlign: TextAlign.end,
                          style: context.textStyles.titleMedium),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
