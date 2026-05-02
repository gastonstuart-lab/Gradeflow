import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/components/animated_page_background.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/services/grading_category_service.dart';
import 'package:gradeflow/services/grade_item_service.dart';
import 'package:gradeflow/services/student_score_service.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/models/student_score.dart';
import 'package:gradeflow/models/grading_category.dart';
import 'package:gradeflow/components/workspace_shell.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/theme.dart';
import 'package:uuid/uuid.dart';
import 'package:gradeflow/models/grade_item.dart';
import 'package:go_router/go_router.dart';

double _gradebookMaxScore(double maxScore) => maxScore <= 1 ? 100.0 : maxScore;

String _formatGradebookScore(double score) {
  if ((score - score.roundToDouble()).abs() < 0.001) {
    return score.toStringAsFixed(0);
  }
  return score
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String _scoreFieldText(double? score) =>
    score == null ? '' : _formatGradebookScore(score);

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
  final Map<String, FocusNode> _scoreFocusNodes = {};
  final Map<String, GlobalKey> _scoreRowKeys = {};
  final Set<String> _autoEnsuredCategories = <String>{};
  int? _activeRowIndex;

  Future<bool> _confirmLeaveIfSaving() async {
    final scores = context.read<StudentScoreService>();
    if (!scores.hasPendingWrites) return true;

    // Try a short flush first (common case).
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

      // User chose to wait, but do not let route changes lock up the app.
      try {
        await scores.flushPendingWrites().timeout(const Duration(seconds: 4));
      } catch (_) {}
      return true;
    }
  }

  bool _isHiddenItem(GradeItem item) =>
      item.name.trim().toLowerCase() == 'category total';

  void _goToClassWorkspace() {
    context.go('${AppRoutes.osClass}/${widget.classId}');
  }

  Future<void> _leaveToClassWorkspace() async {
    final ok = await _confirmLeaveIfSaving();
    if (ok && mounted) _goToClassWorkspace();
  }

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  Future<void> _loadData() async {
    final studentService = context.read<StudentService>();
    final categoryService = context.read<GradingCategoryService>();
    final gradeItemService = context.read<GradeItemService>();
    final scoreService = context.read<StudentScoreService>();

    await Future.wait([
      studentService.loadStudents(widget.classId),
      categoryService.loadCategories(widget.classId),
      gradeItemService.loadGradeItems(widget.classId),
    ]);
    if (!mounted) return;

    final gradeItemIds =
        gradeItemService.gradeItems.map((g) => g.gradeItemId).toList();
    await scoreService.loadScores(widget.classId, gradeItemIds);
    if (!mounted) return;

    final categories = categoryService.categories;
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
    for (final node in _scoreFocusNodes.values) {
      node.dispose();
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

  String _scoreControllerKey(String studentId, String gradeItemId) =>
      '$gradeItemId::$studentId';

  TextEditingController _scoreControllerFor({
    required String studentId,
    required String gradeItemId,
    required double? score,
  }) {
    final key = _scoreControllerKey(studentId, gradeItemId);
    return _controllers.putIfAbsent(
      key,
      () => TextEditingController(text: _scoreFieldText(score)),
    );
  }

  FocusNode _scoreFocusNodeFor({
    required String studentId,
    required String gradeItemId,
  }) {
    final key = _scoreControllerKey(studentId, gradeItemId);
    return _scoreFocusNodes.putIfAbsent(
      key,
      () => FocusNode(debugLabel: 'Gradebook score $key'),
    );
  }

  GlobalKey _scoreRowKeyFor({
    required String studentId,
    required String gradeItemId,
  }) {
    final key = _scoreControllerKey(studentId, gradeItemId);
    return _scoreRowKeys.putIfAbsent(key, GlobalKey.new);
  }

  void _setScoreControllerText(
    String studentId,
    GradeItem item,
    double? score,
  ) {
    final controller = _controllers[_scoreControllerKey(
      studentId,
      item.gradeItemId,
    )];
    if (controller == null) return;
    final next = _scoreFieldText(score);
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  Future<void> _commitScoreField(
    String studentId,
    GradeItem item, {
    bool showValidationMessage = false,
  }) async {
    final controller = _controllers[_scoreControllerKey(
      studentId,
      item.gradeItemId,
    )];
    final raw = controller?.text.trim() ?? '';
    if (raw.isEmpty) {
      await _updateScore(studentId, item.gradeItemId, null);
      return;
    }

    final max = _gradebookMaxScore(item.maxScore);
    final value = double.tryParse(raw);
    if (value == null || value < 0 || value > max) {
      final persisted = context
          .read<StudentScoreService>()
          .getScore(studentId, item.gradeItemId)
          ?.score;
      _setScoreControllerText(studentId, item, persisted);
      if (showValidationMessage) {
        _showError(
            'Score must be between 0 and ${_formatGradebookScore(max)}.');
      }
      return;
    }

    await _updateScore(studentId, item.gradeItemId, value);
    _setScoreControllerText(studentId, item, value);
  }

  Future<bool> _moveRapidScoreFocus({
    required List<Student> students,
    required int currentIndex,
    required GradeItem item,
    required int direction,
  }) async {
    if (students.isEmpty || direction == 0) return false;

    final nextIndex = (currentIndex + direction)
        .clamp(
          0,
          students.length - 1,
        )
        .toInt();
    if (nextIndex == currentIndex) return false;

    final nextStudent = students[nextIndex];
    final focusNode = _scoreFocusNodeFor(
      studentId: nextStudent.studentId,
      gradeItemId: item.gradeItemId,
    );
    final rowKey = _scoreRowKeyFor(
      studentId: nextStudent.studentId,
      gradeItemId: item.gradeItemId,
    );

    focusNode.requestFocus();
    await Future<void>.delayed(Duration.zero);

    final rowContext = rowKey.currentContext;
    if (rowContext != null && mounted) {
      await Scrollable.ensureVisible(
        rowContext,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        alignment: direction > 0 ? 0.72 : 0.28,
        alignmentPolicy: direction > 0
            ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
            : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    }
    return true;
  }

  void _openQuickGradeSheet(int startIndex) {
    final students = context.read<StudentService>().students;
    if (selectedGradeItemId == null || students.isEmpty) return;
    final items = context
        .read<GradeItemService>()
        .gradeItems
        .where((g) => g.categoryId == selectedCategoryId && !_isHiddenItem(g))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (items.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.88,
        child: _StudentScoreSheet(
          students: students,
          gradeItems: items,
          startIndex: startIndex,
          onUpdateScore: _updateScore,
        ),
      ),
    );
  }

  // ignore: unused_element
  void _openLegacyQuickGradeSheet(int startIndex) {
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
        await _leaveToClassWorkspace();
      },
      child: _GradebookNativeSurface(
        eyebrow: 'Class workspace',
        title: classItem?.className ?? 'Gradebook',
        toolLabel: 'Gradebook',
        subtitle: classItem != null
            ? '${classItem.subject} - ${classItem.schoolYear} - ${classItem.term}'
            : 'Enter scores for students',
        leading: IconButton(
          onPressed: _leaveToClassWorkspace,
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to class workspace',
        ),
        contextStrip: _CompactGradebookContextStrip(
          studentCount: studentService.students.length,
          categoryCount: categoryService.categories.length,
          syncStatus: scoreService.hasPendingWrites ? 'Saving...' : 'Synced',
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
            ? const _GradebookInlineEmptyState(
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
                  const SizedBox(height: WorkspaceSpacing.sm),
                  WorkspaceSectionHeader(
                    title: 'Student scores',
                    subtitle:
                        'Click a row or use Enter / Arrow keys to move through scores',
                    subtitleMaxLines: 1,
                    action: FilledButton.tonalIcon(
                      onPressed: studentService.students.isEmpty
                          ? null
                          : () => _openQuickGradeSheet(0),
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Student sheet'),
                      style:
                          WorkspaceButtonStyles.tonal(context, compact: true),
                    ),
                  ),
                  const SizedBox(height: WorkspaceSpacing.sm),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: studentService.students.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: WorkspaceSpacing.xs),
                      itemBuilder: (context, index) {
                        final student = studentService.students[index];
                        final current = scoreService.getScore(
                          student.studentId,
                          selectedGradeItem.gradeItemId,
                        );
                        final controller = _scoreControllerFor(
                          studentId: student.studentId,
                          gradeItemId: selectedGradeItem.gradeItemId,
                          score: current?.score,
                        );
                        final focusNode = _scoreFocusNodeFor(
                          studentId: student.studentId,
                          gradeItemId: selectedGradeItem.gradeItemId,
                        );
                        final rowKey = _scoreRowKeyFor(
                          studentId: student.studentId,
                          gradeItemId: selectedGradeItem.gradeItemId,
                        );
                        return _ScoreEntryRow(
                          key: rowKey,
                          studentName:
                              '${student.chineseName} • ${student.englishFullName}',
                          studentId: student.studentId,
                          seatNo: student.seatNo,
                          photoBase64: student.photoBase64,
                          controller: controller,
                          focusNode: focusNode,
                          gradeItemId: selectedGradeItem.gradeItemId,
                          maxScore: selectedGradeItem.maxScore,
                          initialScore: current?.score,
                          onCommit: ({bool showValidationMessage = false}) =>
                              _commitScoreField(
                            student.studentId,
                            selectedGradeItem,
                            showValidationMessage: showValidationMessage,
                          ),
                          onClear: () {
                            controller.clear();
                            return _updateScore(
                              student.studentId,
                              selectedGradeItem.gradeItemId,
                              null,
                            );
                          },
                          onOpen: () => _openQuickGradeSheet(index),
                          onMoveFocus: (direction) => _moveRapidScoreFocus(
                            students: studentService.students,
                            currentIndex: index,
                            item: selectedGradeItem,
                            direction: direction,
                          ),
                          isActive: index == _activeRowIndex,
                          onBecameActive: () {
                            if (_activeRowIndex != index) {
                              setState(() => _activeRowIndex = index);
                            }
                          },
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

InputDecoration _gradebookFieldDecoration(
  BuildContext context, {
  required String labelText,
  IconData? icon,
  String? suffixText,
}) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final borderRadius = BorderRadius.circular(8);
  final baseBorder = OutlineInputBorder(
    borderRadius: borderRadius,
    borderSide: BorderSide(
      color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.30 : 0.22),
    ),
  );

  return InputDecoration(
    labelText: labelText,
    suffixText: suffixText,
    prefixIcon: icon == null ? null : Icon(icon, size: 18),
    prefixIconConstraints: const BoxConstraints(minWidth: 36),
    isDense: true,
    filled: true,
    fillColor: theme.colorScheme.surface.withValues(
      alpha: isDark ? 0.22 : 0.54,
    ),
    border: baseBorder,
    enabledBorder: baseBorder,
    focusedBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(
        color: theme.colorScheme.primary.withValues(alpha: 0.62),
        width: 1.2,
      ),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
  );
}

class _GradebookNativeSurface extends StatelessWidget {
  const _GradebookNativeSurface({
    required this.eyebrow,
    required this.title,
    required this.toolLabel,
    required this.workspace,
    this.subtitle,
    this.leading,
    this.contextStrip,
    this.toolbar,
  });

  final String eyebrow;
  final String title;
  final String toolLabel;
  final String? subtitle;
  final Widget? leading;
  final Widget? contextStrip;
  final Widget? toolbar;
  final Widget workspace;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedPageBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1480),
              child: Padding(
                padding: WorkspaceSpacing.shellMargin,
                child: WorkspaceShellFrame(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  radius: WorkspaceRadius.shell,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _GradebookNativeHeader(
                        eyebrow: eyebrow,
                        title: title,
                        toolLabel: toolLabel,
                        subtitle: subtitle,
                        leading: leading,
                      ),
                      const SizedBox(height: WorkspaceSpacing.sm),
                      _GradebookCommandStrip(
                        contextStrip: contextStrip,
                        toolbar: toolbar,
                      ),
                      const SizedBox(height: WorkspaceSpacing.md),
                      Expanded(child: workspace),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GradebookNativeHeader extends StatelessWidget {
  const _GradebookNativeHeader({
    required this.eyebrow,
    required this.title,
    required this.toolLabel,
    this.subtitle,
    this.leading,
  });

  final String eyebrow;
  final String title;
  final String toolLabel;
  final String? subtitle;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toolBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: theme.colorScheme.primary.withValues(alpha: 0.11),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book_rounded,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            toolLabel,
            style: context.textStyles.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.primary,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );

    final iconTile = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.20),
        ),
      ),
      child: Icon(
        Icons.fact_check_outlined,
        color: theme.colorScheme.primary,
        size: 23,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 760;
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  eyebrow.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: WorkspaceTypography.eyebrow(context),
                ),
                toolBadge,
              ],
            ),
            const SizedBox(height: 7),
            Text(
              title,
              maxLines: narrow ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            if ((subtitle ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                subtitle!,
                maxLines: narrow ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.bodyMedium?.copyWith(
                  color: WorkspaceChrome.mutedText(context),
                  height: 1.35,
                ),
              ),
            ],
          ],
        );

        final leadingCluster = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: WorkspaceSpacing.sm),
            ],
            iconTile,
          ],
        );

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leadingCluster,
              const SizedBox(height: WorkspaceSpacing.sm),
              copy,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            leadingCluster,
            const SizedBox(width: WorkspaceSpacing.md),
            Expanded(child: copy),
          ],
        );
      },
    );
  }
}

class _GradebookCommandStrip extends StatelessWidget {
  const _GradebookCommandStrip({
    this.contextStrip,
    this.toolbar,
  });

  final Widget? contextStrip;
  final Widget? toolbar;

  @override
  Widget build(BuildContext context) {
    if (contextStrip == null && toolbar == null) {
      return const SizedBox.shrink();
    }

    return WorkspaceCommandBand(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 980;
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (contextStrip != null) contextStrip!,
                if (contextStrip != null && toolbar != null)
                  const SizedBox(height: WorkspaceSpacing.xs),
                if (toolbar != null) toolbar!,
              ],
            );
          }

          return Row(
            children: [
              if (contextStrip != null) Expanded(child: contextStrip!),
              if (contextStrip != null && toolbar != null)
                const SizedBox(width: WorkspaceSpacing.sm),
              if (toolbar != null) Flexible(flex: 2, child: toolbar!),
            ],
          );
        },
      ),
    );
  }
}

class _GradebookFlatSurface extends StatelessWidget {
  const _GradebookFlatSurface({
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.onTap,
    this.isActive = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final surface = WorkspaceFlatSurface(
      padding: padding,
      onTap: onTap,
      child: child,
    );
    if (!isActive) return surface;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Stack(
      children: [
        surface,
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(
                  alpha: isDark ? 0.08 : 0.07,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.75),
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(1.5),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GradebookInlineEmptyState extends StatelessWidget {
  const _GradebookInlineEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Icon(icon, size: 28, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: WorkspaceSpacing.md),
            Text(
              title,
              style: context.textStyles.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: WorkspaceTypography.metadata(context),
              textAlign: TextAlign.center,
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
  });

  final int studentCount;
  final int categoryCount;
  final String syncStatus;

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
                initialValue: selectedCategoryId,
                isExpanded: true,
                decoration: _gradebookFieldDecoration(
                  context,
                  labelText: 'Category',
                  icon: Icons.category_outlined,
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
                initialValue: selectedGradeItemId,
                isExpanded: true,
                decoration: _gradebookFieldDecoration(
                  context,
                  labelText: 'Assessment',
                  icon: Icons.assignment_turned_in_outlined,
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
    final syncPill = WorkspaceContextPill(
      icon: syncStatus == 'Synced' ? Icons.cloud_done_outlined : Icons.sync,
      label: 'Sync',
      value: syncStatus,
      accent: syncStatus == 'Synced'
          ? Theme.of(context).colorScheme.primary
          : const Color(0xFFDAA85E),
      emphasized: true,
    );

    return _GradebookFlatSurface(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 920;
          final contextPills = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              WorkspaceContextPill(
                icon: Icons.assignment_turned_in_outlined,
                label: 'Assessment',
                value: gradeItemName,
                emphasized: true,
              ),
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
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                contextPills,
                const SizedBox(height: WorkspaceSpacing.xs),
                syncPill,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: contextPills),
              const SizedBox(width: WorkspaceSpacing.sm),
              syncPill,
            ],
          );
        },
      ),
    );
  }
}

typedef _ScoreCommitCallback = Future<void> Function({
  bool showValidationMessage,
});

class _ScoreEntryRow extends StatefulWidget {
  final String studentName;
  final String studentId;
  final String? seatNo;
  final String? photoBase64;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String gradeItemId;
  final double maxScore;
  final double? initialScore;
  final _ScoreCommitCallback onCommit;
  final Future<void> Function() onClear;
  final VoidCallback onOpen;
  final Future<bool> Function(int direction) onMoveFocus;
  final bool isActive;
  final VoidCallback onBecameActive;

  const _ScoreEntryRow({
    super.key,
    required this.studentName,
    required this.studentId,
    this.seatNo,
    this.photoBase64,
    required this.controller,
    required this.focusNode,
    required this.gradeItemId,
    required this.maxScore,
    required this.initialScore,
    required this.onCommit,
    required this.onClear,
    required this.onOpen,
    required this.onMoveFocus,
    this.isActive = false,
    required this.onBecameActive,
  });

  @override
  State<_ScoreEntryRow> createState() => _ScoreEntryRowState();
}

class _ScoreEntryRowState extends State<_ScoreEntryRow> {
  bool _skipNextBlurCommit = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleScoreFocusChange);
    _syncController(force: true);
  }

  @override
  void didUpdateWidget(covariant _ScoreEntryRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_handleScoreFocusChange);
      widget.focusNode.addListener(_handleScoreFocusChange);
    }
    if (oldWidget.initialScore != widget.initialScore ||
        oldWidget.gradeItemId != widget.gradeItemId ||
        oldWidget.controller != widget.controller) {
      _syncController();
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleScoreFocusChange);
    super.dispose();
  }

  void _handleScoreFocusChange() {
    if (widget.focusNode.hasFocus) {
      widget.onBecameActive();
      return;
    }
    if (_skipNextBlurCommit) {
      _skipNextBlurCommit = false;
      return;
    }
    widget.onCommit(showValidationMessage: true);
  }

  void _syncController({bool force = false}) {
    if (!force && widget.focusNode.hasFocus) return;
    final next = _scoreFieldText(widget.initialScore);
    if (widget.controller.text == next) return;
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  Future<void> _commitAndMove(int direction) async {
    await widget.onCommit(showValidationMessage: true);
    if (!mounted) return;
    _skipNextBlurCommit = true;
    final moved = await widget.onMoveFocus(direction);
    if (!moved) _skipNextBlurCommit = false;
  }

  double _sliderValue(double max) {
    final parsed = double.tryParse(widget.controller.text.trim());
    return (parsed ?? widget.initialScore ?? 0).clamp(0.0, max).toDouble();
  }

  void _setControllerScore(double value) {
    final next = _formatGradebookScore(value);
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = _gradebookMaxScore(widget.maxScore);
    final scoreLabel = widget.initialScore == null
        ? 'blank'
        : '${_formatGradebookScore(widget.initialScore!)} of ${_formatGradebookScore(max)}';
    final seatLabel =
        widget.seatNo?.isNotEmpty == true ? 'Seat ${widget.seatNo}' : null;
    final rowLabel = [
      widget.studentName,
      'ID ${widget.studentId}',
      if (seatLabel != null) seatLabel,
      'score $scoreLabel',
    ].join(', ');

    return Semantics(
      container: true,
      label: rowLabel,
      child: _GradebookFlatSurface(
        isActive: widget.isActive,
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 720;
            final identity = Row(
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        seatLabel == null
                            ? 'ID: ${widget.studentId}'
                            : 'ID: ${widget.studentId} / $seatLabel',
                        style: WorkspaceTypography.utility(context)?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            );

            final activeFieldBorder = theme.colorScheme.primary.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.56 : 0.44,
            );

            final input = SizedBox(
              width: narrow ? double.infinity : 128,
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.enter): () =>
                      _commitAndMove(1),
                  const SingleActivator(LogicalKeyboardKey.numpadEnter): () =>
                      _commitAndMove(1),
                  const SingleActivator(
                    LogicalKeyboardKey.enter,
                    shift: true,
                  ): () => _commitAndMove(-1),
                  const SingleActivator(
                    LogicalKeyboardKey.numpadEnter,
                    shift: true,
                  ): () => _commitAndMove(-1),
                  const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                      _commitAndMove(1),
                  const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                      _commitAndMove(-1),
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOutCubic,
                  padding: widget.isActive
                      ? const EdgeInsets.symmetric(horizontal: 1, vertical: 1)
                      : EdgeInsets.zero,
                  decoration: widget.isActive
                      ? BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: activeFieldBorder),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(
                                alpha: theme.brightness == Brightness.dark
                                    ? 0.16
                                    : 0.10,
                              ),
                              blurRadius: 8,
                              spreadRadius: 0.5,
                            ),
                          ],
                        )
                      : null,
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    textAlign: TextAlign.end,
                    textInputAction: TextInputAction.next,
                    decoration: _gradebookFieldDecoration(
                      context,
                      labelText: 'Score',
                      suffixText: '/ ${_formatGradebookScore(max)}',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d*'),
                      ),
                    ],
                    onTap: () {
                      final text = widget.controller.text;
                      if (text.isEmpty) return;
                      widget.controller.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: text.length,
                      );
                    },
                    onSubmitted: (_) {
                      _commitAndMove(1);
                    },
                    onTapOutside: (_) => widget.onCommit(
                      showValidationMessage: true,
                    ),
                  ),
                ),
              ),
            );

            final actions = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Clear score',
                  icon: const Icon(Icons.backspace_outlined),
                  onPressed: widget.onClear,
                  style: WorkspaceButtonStyles.icon(context, compact: true),
                ),
                IconButton(
                  tooltip: 'Quick grade',
                  icon: const Icon(Icons.fact_check_outlined),
                  onPressed: widget.onOpen,
                  style: WorkspaceButtonStyles.icon(context, compact: true),
                ),
              ],
            );

            final sliderControl = Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _sliderValue(max),
                    min: 0,
                    max: max,
                    divisions: max > 0 ? max.round() : null,
                    label: _formatGradebookScore(_sliderValue(max)),
                    onChanged: (value) {
                      _setControllerScore(value);
                      setState(() {});
                    },
                    onChangeEnd: (_) => widget.onCommit(
                      showValidationMessage: true,
                    ),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    _formatGradebookScore(_sliderValue(max)),
                    textAlign: TextAlign.end,
                    style: context.textStyles.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            );

            final mainRow = narrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      identity,
                      const SizedBox(height: WorkspaceSpacing.sm),
                      Row(
                        children: [
                          Expanded(child: input),
                          const SizedBox(width: WorkspaceSpacing.xs),
                          actions,
                        ],
                      ),
                      const SizedBox(height: WorkspaceSpacing.xs),
                      sliderControl,
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: identity),
                      const SizedBox(width: WorkspaceSpacing.md),
                      SizedBox(
                        width: constraints.maxWidth >= 980 ? 280 : 220,
                        child: sliderControl,
                      ),
                      const SizedBox(width: WorkspaceSpacing.sm),
                      input,
                      const SizedBox(width: WorkspaceSpacing.xs),
                      actions,
                    ],
                  );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                mainRow,
              ],
            );
          },
        ),
      ),
    );
  }
}

// ignore: unused_element
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
      {required this.studentName,
      required this.studentId,
      required this.seatNo,
      required this.photoBase64,
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
    return _GradebookFlatSurface(
      onTap: widget.onOpen,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
    );
  }
}

class _StudentScoreSheet extends StatefulWidget {
  final List<Student> students;
  final List<GradeItem> gradeItems;
  final int startIndex;
  final Future<void> Function(
    String studentId,
    String gradeItemId,
    double? score,
  ) onUpdateScore;

  const _StudentScoreSheet({
    required this.students,
    required this.gradeItems,
    required this.startIndex,
    required this.onUpdateScore,
  });

  @override
  State<_StudentScoreSheet> createState() => _StudentScoreSheetState();
}

class _StudentScoreSheetState extends State<_StudentScoreSheet> {
  late int _index = widget.students.isEmpty
      ? 0
      : widget.startIndex.clamp(0, widget.students.length - 1).toInt();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _disposeFieldState() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _controllers.clear();
    _focusNodes.clear();
  }

  TextEditingController _controllerFor(GradeItem item, double? score) {
    final controller = _controllers.putIfAbsent(
      item.gradeItemId,
      () => TextEditingController(text: _scoreFieldText(score)),
    );
    final node = _focusNodes[item.gradeItemId];
    if (node?.hasFocus != true) {
      final next = _scoreFieldText(score);
      if (controller.text != next) {
        controller.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
      }
    }
    return controller;
  }

  FocusNode _focusNodeFor(GradeItem item) {
    return _focusNodes.putIfAbsent(
      item.gradeItemId,
      () {
        final node = FocusNode();
        node.addListener(() {
          if (!node.hasFocus) {
            _commit(item, showValidationMessage: true);
          }
        });
        return node;
      },
    );
  }

  void _showValidationError(double max) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Score must be between 0 and ${_formatGradebookScore(max)}.',
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _commit(
    GradeItem item, {
    bool showValidationMessage = false,
  }) async {
    if (!mounted || widget.students.isEmpty) return;
    final student = widget.students[_index];
    final controller = _controllers[item.gradeItemId];
    final raw = controller?.text.trim() ?? '';
    if (raw.isEmpty) {
      await widget.onUpdateScore(student.studentId, item.gradeItemId, null);
      return;
    }

    final max = _gradebookMaxScore(item.maxScore);
    final value = double.tryParse(raw);
    if (value == null || value < 0 || value > max) {
      final persisted = context
          .read<StudentScoreService>()
          .getScore(student.studentId, item.gradeItemId)
          ?.score;
      final next = _scoreFieldText(persisted);
      controller?.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
      if (showValidationMessage && mounted) _showValidationError(max);
      return;
    }

    await widget.onUpdateScore(student.studentId, item.gradeItemId, value);
    if (!mounted) return;
    final next = _scoreFieldText(value);
    controller?.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  Future<void> _clear(GradeItem item) async {
    if (!mounted || widget.students.isEmpty) return;
    final student = widget.students[_index];
    _controllers[item.gradeItemId]?.clear();
    await widget.onUpdateScore(student.studentId, item.gradeItemId, null);
  }

  void _loadStudent(int nextIndex) {
    if (nextIndex < 0 || nextIndex >= widget.students.length) return;
    FocusScope.of(context).unfocus();
    _disposeFieldState();
    setState(() => _index = nextIndex);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.students.isEmpty) {
      return const WorkspaceEmptyState(
        icon: Icons.people_outline,
        title: 'No students',
        subtitle: 'Add students before entering scores.',
      );
    }

    final scoreService = context.watch<StudentScoreService>();
    final student = widget.students[_index];
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final titleStyle = context.textStyles.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _StudentAvatar(
                photoBase64: student.photoBase64,
                name: '${student.chineseName} ${student.englishFullName}',
              ),
              const SizedBox(width: WorkspaceSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Student score sheet',
                      style: titleStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${student.chineseName} / ${student.englishFullName}',
                      style: WorkspaceTypography.metadata(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      student.seatNo?.isNotEmpty == true
                          ? 'ID: ${student.studentId} / Seat ${student.seatNo}'
                          : 'ID: ${student.studentId}',
                      style: WorkspaceTypography.utility(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                '${_index + 1}/${widget.students.length}',
                style: WorkspaceTypography.utility(context),
              ),
            ],
          ),
          const SizedBox(height: WorkspaceSpacing.md),
          Expanded(
            child: ListView.separated(
              itemCount: widget.gradeItems.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: WorkspaceSpacing.xs),
              itemBuilder: (context, index) {
                final item = widget.gradeItems[index];
                final current = scoreService
                    .getScore(student.studentId, item.gradeItemId)
                    ?.score;
                return _StudentScoreSheetRow(
                  item: item,
                  controller: _controllerFor(item, current),
                  focusNode: _focusNodeFor(item),
                  onCommit: () => _commit(
                    item,
                    showValidationMessage: true,
                  ),
                  onClear: () => _clear(item),
                );
              },
            ),
          ),
          const SizedBox(height: WorkspaceSpacing.md),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                label: const Text('Done'),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Previous student',
                onPressed: _index > 0 ? () => _loadStudent(_index - 1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                tooltip: 'Next student',
                onPressed: _index < widget.students.length - 1
                    ? () => _loadStudent(_index + 1)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudentScoreSheetRow extends StatelessWidget {
  final GradeItem item;
  final TextEditingController controller;
  final FocusNode focusNode;
  final Future<void> Function() onCommit;
  final Future<void> Function() onClear;

  const _StudentScoreSheetRow({
    required this.item,
    required this.controller,
    required this.focusNode,
    required this.onCommit,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final max = _gradebookMaxScore(item.maxScore);
    return _GradebookFlatSurface(
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 620;
          final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: context.textStyles.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Max ${_formatGradebookScore(max)}',
                style: WorkspaceTypography.metadata(context),
              ),
            ],
          );
          final input = SizedBox(
            width: narrow ? double.infinity : 138,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textAlign: TextAlign.end,
              decoration: _gradebookFieldDecoration(
                context,
                labelText: 'Score',
                suffixText: '/ ${_formatGradebookScore(max)}',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              onSubmitted: (_) => onCommit(),
              onTapOutside: (_) => onCommit(),
            ),
          );
          final clear = IconButton(
            tooltip: 'Clear score',
            onPressed: onClear,
            icon: const Icon(Icons.backspace_outlined),
            style: WorkspaceButtonStyles.icon(context, compact: true),
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                const SizedBox(height: WorkspaceSpacing.sm),
                Row(
                  children: [
                    Expanded(child: input),
                    const SizedBox(width: WorkspaceSpacing.xs),
                    clear,
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: WorkspaceSpacing.md),
              input,
              const SizedBox(width: WorkspaceSpacing.xs),
              clear,
            ],
          );
        },
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
