import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/demo_data_service.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/services/grading_category_service.dart';
import 'package:gradeflow/services/grade_item_service.dart';
import 'package:gradeflow/services/student_score_service.dart';
import 'package:gradeflow/services/final_exam_service.dart';
import 'package:gradeflow/services/class_schedule_service.dart';
import 'package:gradeflow/models/class_schedule_item.dart';
import 'package:gradeflow/models/class_note_item.dart';
import 'package:gradeflow/services/class_note_service.dart';
import 'package:gradeflow/services/google_auth_service.dart';
import 'package:gradeflow/theme.dart';
import 'package:gradeflow/components/animated_glow_border.dart';
import 'package:gradeflow/components/animated_page_background.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class ClassDetailScreen extends StatefulWidget {
  final String classId;

  const ClassDetailScreen({super.key, required this.classId});

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  List<ClassScheduleItem> _scheduleItems = [];
  List<ClassNoteItem> _classNotes = [];
  String? _driveAccessToken;
  bool _driveSigningIn = false;
  final ClassNoteService _classNoteService = ClassNoteService();

  void _showPersistentMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 12),
        content: Text(message),
        action: SnackBarAction(
          label: 'Details',
          onPressed: () {
            showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Google Sign-In'),
                content: SelectableText(message),
                actions: [
                  TextButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: message));
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Copy'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Schedule data loading after the first frame to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  String _classDataUserId() {
    final user = context.read<AuthService>().currentUser;
    return user?.userId ?? 'local';
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DateTime _startOfWeek(DateTime anchor) {
    final normalized = _dateOnly(anchor);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  List<ClassNoteItem> _sortClassNotes(Iterable<ClassNoteItem> items) {
    final sorted = items.toList();
    sorted.sort((a, b) {
      if (a.isDone != b.isDone) {
        return a.isDone ? 1 : -1;
      }

      final aReminder = a.remindAt;
      final bReminder = b.remindAt;
      if (aReminder != null && bReminder != null) {
        final byDate = aReminder.compareTo(bReminder);
        if (byDate != 0) return byDate;
      } else if (aReminder != null) {
        return -1;
      } else if (bReminder != null) {
        return 1;
      }

      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }

  Future<void> _saveClassNotes() async {
    await _classNoteService.save(
      classId: widget.classId,
      userId: _classDataUserId(),
      items: _classNotes,
    );
  }

  Future<void> _loadData() async {
    final authService = context.read<AuthService>();
    final classService = context.read<ClassService>();
    final studentService = context.read<StudentService>();
    final categoryService = context.read<GradingCategoryService>();
    final gradeItemService = context.read<GradeItemService>();
    final scoreService = context.read<StudentScoreService>();
    final examService = context.read<FinalExamService>();
    final scheduleService = ClassScheduleService();

    final user = authService.currentUser;
    if (user != null && classService.getClassById(widget.classId) == null) {
      if (DemoDataService.isDemoUser(user)) {
        await DemoDataService.ensureDemoWorkspace(
          teacherId: user.userId,
          classService: classService,
          studentService: studentService,
          categoryService: categoryService,
          gradeItemService: gradeItemService,
          scoreService: scoreService,
          examService: examService,
        );
      } else {
        await classService.loadClasses(user.userId);
      }
    }

    await studentService.loadStudents(widget.classId);
    await categoryService.loadCategories(widget.classId);
    await gradeItemService.loadGradeItems(widget.classId);

    // Load schedule + class notes/reminders
    final items = await scheduleService.load(widget.classId);
    final notes = await _classNoteService.load(
      classId: widget.classId,
      userId: user?.userId ?? 'local',
    );
    if (!mounted) return;
    setState(() {
      _scheduleItems = items;
      _classNotes = _sortClassNotes(notes);
    });

    if (studentService.students.isNotEmpty) {
      final studentIds =
          studentService.students.map((s) => s.studentId).toList();
      final gradeItemIds =
          gradeItemService.gradeItems.map((g) => g.gradeItemId).toList();

      await scoreService.loadScores(widget.classId, gradeItemIds);
      await examService.loadExams(widget.classId, studentIds);

      if (scoreService.scores.isEmpty && gradeItemIds.isNotEmpty) {
        await scoreService.seedDemoScores(
            widget.classId, studentIds, gradeItemIds);
        await examService.seedDemoExams(widget.classId, studentIds);
        await scoreService.loadScores(widget.classId, gradeItemIds);
        await examService.loadExams(widget.classId, studentIds);
      }
    }
  }

  List<ClassScheduleItem> _scheduleItemsForWeek(DateTime weekStart) {
    final start = _dateOnly(weekStart);
    final end = start.add(const Duration(days: 7));
    final items = _scheduleItems.where((item) {
      final date = item.date;
      if (date == null) return false;
      final normalized = _dateOnly(date);
      return !normalized.isBefore(start) && normalized.isBefore(end);
    }).toList();

    items.sort((a, b) {
      final aDate = a.date ?? DateTime(9999);
      final bDate = b.date ?? DateTime(9999);
      final byDate = aDate.compareTo(bDate);
      if (byDate != 0) return byDate;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return items;
  }

  String _weekRangeLabel(DateTime weekStart) {
    final end = weekStart.add(const Duration(days: 6));
    if (weekStart.month == end.month) {
      return '${DateFormat('MMM d').format(weekStart)}-${DateFormat('d').format(end)}';
    }
    return '${DateFormat('MMM d').format(weekStart)} - ${DateFormat('MMM d').format(end)}';
  }

  String _schedulePreviewTitle(ClassScheduleItem item) {
    final title = item.title.replaceAll(RegExp(r'\s+'), ' ').trim();
    final subjectMatch = RegExp(
      r'subject:\s*(.+?)(?=\s+aim:|\s+question:|$)',
      caseSensitive: false,
    ).firstMatch(title);
    if (subjectMatch != null) {
      final value = subjectMatch.group(1)?.trim();
      if (value != null && value.isNotEmpty) return value;
    }

    final aimMatch = RegExp(
      r'aim:\s*(.+?)(?=\s+question:|$)',
      caseSensitive: false,
    ).firstMatch(title);
    if (aimMatch != null) {
      final value = aimMatch.group(1)?.trim();
      if (value != null && value.isNotEmpty) return value;
    }

    final sentence = title.split(RegExp(r'(?<=[.!?])\s+')).first.trim();
    return sentence.isEmpty ? title : sentence;
  }

  Future<void> _showAddClassNoteDialog() async {
    final controller = TextEditingController();
    var includeReminderDate = false;
    DateTime? remindAt;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text('Add note or reminder'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Note',
                    hintText: 'Add a teaching note, reminder, or follow-up',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Set reminder date'),
                  value: includeReminderDate,
                  onChanged: (value) {
                    setLocalState(() {
                      includeReminderDate = value ?? false;
                      if (!includeReminderDate) {
                        remindAt = null;
                      }
                    });
                  },
                ),
                if (includeReminderDate)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event),
                      label: Text(
                        remindAt == null
                            ? 'Choose date'
                            : DateFormat('EEE, MMM d').format(remindAt!),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: remindAt ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked == null) return;
                        setLocalState(() {
                          remindAt = _dateOnly(picked);
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      controller.dispose();
      return;
    }

    final text = controller.text.trim();
    controller.dispose();
    if (text.isEmpty) return;

    final newItem = ClassNoteItem(
      id: const Uuid().v4(),
      text: text,
      createdAt: DateTime.now(),
      remindAt: includeReminderDate ? remindAt : null,
    );

    if (!mounted) return;
    setState(() {
      _classNotes = _sortClassNotes([..._classNotes, newItem]);
    });
    await _saveClassNotes();
  }

  Future<void> _toggleClassNoteDone(ClassNoteItem item, bool isDone) async {
    if (!mounted) return;
    setState(() {
      _classNotes = _sortClassNotes(_classNotes.map((note) {
        if (note.id != item.id) return note;
        return note.copyWith(isDone: isDone);
      }));
    });
    await _saveClassNotes();
  }

  Future<void> _deleteClassNote(ClassNoteItem item) async {
    if (!mounted) return;
    setState(() {
      _classNotes = _classNotes.where((note) => note.id != item.id).toList();
    });
    await _saveClassNotes();
  }

  @override
  Widget build(BuildContext context) {
    final classService = context.watch<ClassService>();
    final studentService = context.watch<StudentService>();
    final categoryService = context.watch<GradingCategoryService>();
    final classItem = classService.getClassById(widget.classId);

    if (classItem == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Class not found')),
      );
    }

    final studentCount = studentService.students.length;
    final categoryCount = categoryService.categories.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(classItem.className),
      ),
      body: AnimatedPageBackground(
        child: studentService.isLoading || categoryService.isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: AppSpacing.paddingLg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedGlowBorder(
                      child: Card(
                        child: Padding(
                          padding: AppSpacing.paddingLg,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(classItem.subject,
                                  style: context
                                      .textStyles.headlineSmall?.semiBold),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                  '${classItem.schoolYear} • ${classItem.term}',
                                  style: context.textStyles.bodyMedium),
                              const SizedBox(height: AppSpacing.lg),
                              Row(
                                children: [
                                  Expanded(
                                    child: _StatCard(
                                      icon: Icons.people,
                                      label: 'Students',
                                      value: '$studentCount',
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: _StatCard(
                                      icon: Icons.category,
                                      label: 'Categories',
                                      value: '$categoryCount',
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _showScheduleDialog(context),
                                      child: _StatCard(
                                        icon: Icons.calendar_today,
                                        label: 'Schedule',
                                        value: _scheduleItems.isEmpty
                                            ? '—'
                                            : '${_scheduleItems.length}',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              _buildOverviewPanels(context),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Quick Actions',
                        style: context.textStyles.titleLarge?.semiBold),
                    const SizedBox(height: AppSpacing.md),
                    AnimatedGlowBorder(
                      child: _ActionButton(
                        icon: Icons.people,
                        title: 'Student Roster',
                        subtitle: 'View and manage students',
                        onTap: () =>
                            context.push('/class/${widget.classId}/students'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AnimatedGlowBorder(
                      child: _ActionButton(
                        icon: Icons.event_seat_outlined,
                        title: 'Seating Plan',
                        subtitle:
                            'Design layouts and print substitute handouts',
                        onTap: () =>
                            context.push('/class/${widget.classId}/seating'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AnimatedGlowBorder(
                      child: _ActionButton(
                        icon: Icons.edit_note,
                        title: 'Gradebook',
                        subtitle: 'Enter and view grades',
                        onTap: () =>
                            context.push('/class/${widget.classId}/gradebook'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AnimatedGlowBorder(
                      child: _ActionButton(
                        icon: Icons.category,
                        title: 'Grading Categories',
                        subtitle: 'Manage weights and categories',
                        onTap: () =>
                            context.push('/class/${widget.classId}/categories'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AnimatedGlowBorder(
                      child: _ActionButton(
                        icon: Icons.description,
                        title: 'Final Exam Scores',
                        subtitle: 'Enter exam scores (60% weight)',
                        onTap: () =>
                            context.push('/class/${widget.classId}/exams'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AnimatedGlowBorder(
                      child: _ActionButton(
                        icon: Icons.assessment,
                        title: 'Final Results',
                        subtitle: 'Process, Exam, Final scores per student',
                        onTap: () =>
                            context.push('/class/${widget.classId}/results'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AnimatedGlowBorder(
                      child: _ActionButton(
                        icon: Icons.download,
                        title: 'Export Results',
                        subtitle: 'Download grades as CSV',
                        onTap: () =>
                            context.push('/class/${widget.classId}/export'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildOverviewPanels(BuildContext context) {
    final now = DateTime.now();
    final thisWeekStart = _startOfWeek(now);
    final nextWeekStart = thisWeekStart.add(const Duration(days: 7));

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 860;
            final weekCards = [
              Expanded(
                child: _buildWeekSchedulePanel(
                  context,
                  title: 'This Week',
                  weekStart: thisWeekStart,
                ),
              ),
              const SizedBox(width: AppSpacing.sm, height: AppSpacing.sm),
              Expanded(
                child: _buildWeekSchedulePanel(
                  context,
                  title: 'Next Week',
                  weekStart: nextWeekStart,
                ),
              ),
            ];

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: weekCards,
              );
            }

            return Column(
              children: [
                _buildWeekSchedulePanel(
                  context,
                  title: 'This Week',
                  weekStart: thisWeekStart,
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildWeekSchedulePanel(
                  context,
                  title: 'Next Week',
                  weekStart: nextWeekStart,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        _buildClassNotesPanel(context),
      ],
    );
  }

  Widget _buildWeekSchedulePanel(
    BuildContext context, {
    required String title,
    required DateTime weekStart,
  }) {
    final theme = Theme.of(context);
    final items = _scheduleItemsForWeek(weekStart);
    final previewItems = items.take(4).toList();

    return Container(
      width: double.infinity,
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_view_week,
                  size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.xs),
              Text(title, style: context.textStyles.titleSmall?.semiBold),
              const Spacer(),
              Text(
                _weekRangeLabel(weekStart),
                style: context.textStyles.bodySmall?.withColor(
                  theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (previewItems.isEmpty)
            Text(
              'No scheduled items yet.',
              style: context.textStyles.bodySmall?.withColor(
                theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...previewItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Column(
                        children: [
                          Text(
                            item.date == null
                                ? 'TBD'
                                : DateFormat('EEE').format(item.date!),
                            style: context.textStyles.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          if (item.date != null)
                            Text(
                              DateFormat('M/d').format(item.date!),
                              style: context.textStyles.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _schedulePreviewTitle(item),
                            style: context.textStyles.bodyMedium?.semiBold,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item.details.isNotEmpty)
                            Text(
                              item.details.entries
                                  .take(1)
                                  .map((entry) => entry.value)
                                  .join(' • '),
                              style: context.textStyles.bodySmall?.withColor(
                                theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (items.length > previewItems.length)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                '+${items.length - previewItems.length} more items',
                style: context.textStyles.bodySmall?.withColor(
                  theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClassNotesPanel(BuildContext context) {
    final theme = Theme.of(context);
    final previewItems = _classNotes.take(4).toList();

    return Container(
      width: double.infinity,
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sticky_note_2_outlined,
                  size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Class Notes & Reminders',
                  style: context.textStyles.titleSmall?.semiBold,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                onPressed: _showAddClassNoteDialog,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (previewItems.isEmpty)
            Text(
              'Keep track of things to revisit with this class.',
              style: context.textStyles.bodySmall?.withColor(
                theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...previewItems.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      note.remindAt != null
                          ? Icons.notifications_active_outlined
                          : Icons.note_alt_outlined,
                      size: 18,
                      color: note.isDone
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            note.text,
                            style: context.textStyles.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              decoration: note.isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: note.isDone
                                  ? theme.colorScheme.onSurfaceVariant
                                  : null,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            note.remindAt != null
                                ? 'Reminder: ${DateFormat('EEE, MMM d').format(note.remindAt!)}'
                                : 'Note added ${DateFormat('MMM d').format(note.createdAt)}',
                            style: context.textStyles.bodySmall?.withColor(
                              theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: note.isDone ? 'Mark unfinished' : 'Mark done',
                      icon: Icon(
                        note.isDone
                            ? Icons.check_circle
                            : Icons.check_circle_outline,
                        color: note.isDone
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      onPressed: () => _toggleClassNoteDone(note, !note.isDone),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteClassNote(note),
                    ),
                  ],
                ),
              ),
            ),
          if (_classNotes.length > previewItems.length)
            Text(
              '+${_classNotes.length - previewItems.length} more notes',
              style: context.textStyles.bodySmall?.withColor(
                theme.colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }

  void _showScheduleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
          child: Column(
            children: [
              // Header
              Container(
                padding: AppSpacing.paddingMd,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.lg)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today,
                        color:
                            Theme.of(context).colorScheme.onPrimaryContainer),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Class Schedule',
                      style: context.textStyles.titleLarge?.semiBold.withColor(
                        Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(dialogCtx),
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ],
                ),
              ),
              // Body
              Expanded(
                child: _scheduleItems.isEmpty
                    ? _buildEmptySchedule(context)
                    : _buildScheduleList(context),
              ),
              // Footer actions
              Container(
                padding: AppSpacing.paddingMd,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: Border(
                    top: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: _driveSigningIn
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            )
                          : const Icon(Icons.login),
                      label: Text(_driveAccessToken == null
                          ? 'Connect Google Drive'
                          : 'Drive connected'),
                      onPressed: _driveSigningIn
                          ? null
                          : () => _ensureDriveAccessToken(),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    TextButton.icon(
                      icon: const Icon(Icons.cloud_download),
                      label: const Text('Import from link'),
                      onPressed: () => _importScheduleFromUrl(dialogCtx),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (_scheduleItems.isNotEmpty)
                      TextButton.icon(
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Clear Schedule'),
                        onPressed: () => _clearSchedule(dialogCtx),
                      ),
                    if (_scheduleItems.isNotEmpty)
                      const SizedBox(width: AppSpacing.sm),
                    FilledButton.icon(
                      icon: const Icon(Icons.upload_file),
                      label: Text(_scheduleItems.isEmpty
                          ? 'Upload Schedule'
                          : 'Replace Schedule'),
                      onPressed: () => _uploadSchedule(dialogCtx),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySchedule(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_month_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No schedule uploaded',
            style: context.textStyles.titleMedium?.semiBold,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Upload an Excel, CSV, or Word file with your class schedule',
            style: context.textStyles.bodySmall?.withColor(
              Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleList(BuildContext context) {
    return ListView.separated(
      padding: AppSpacing.paddingMd,
      itemCount: _scheduleItems.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _scheduleItems[index];
        return _ScheduleItemTile(item: item);
      },
    );
  }

  Future<void> _uploadSchedule(BuildContext dialogCtx) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv', 'docx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read file')),
          );
        }
        return;
      }

      final scheduleService = ClassScheduleService();
      final items = scheduleService.parseFromBytes(file.bytes!);

      if (items.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No schedule items found in file')),
          );
        }
        return;
      }

      final dialogNavigator = Navigator.of(dialogCtx);
      final messenger = ScaffoldMessenger.of(context);

      await scheduleService.save(widget.classId, items);
      if (!mounted) return;

      setState(() {
        _scheduleItems = items;
      });

      dialogNavigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Uploaded ${items.length} schedule items')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading schedule: $e')),
        );
      }
    }
  }

  Future<void> _clearSchedule(BuildContext dialogCtx) async {
    final confirm = await showDialog<bool>(
      context: dialogCtx,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Schedule'),
        content:
            const Text('Are you sure you want to remove all schedule items?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final scheduleService = ClassScheduleService();
    final dialogNavigator = Navigator.of(dialogCtx);
    final messenger = ScaffoldMessenger.of(context);

    await scheduleService.save(widget.classId, []);
    if (!mounted) return;

    setState(() {
      _scheduleItems = [];
    });

    dialogNavigator.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Schedule cleared')),
    );
  }

  Future<String?> _ensureDriveAccessToken() async {
    setState(() {
      _driveSigningIn = true;
    });

    final result = await GoogleAuthService().ensureAccessTokenDetailed();
    final token = result.accessToken;

    if (!mounted) return token;

    setState(() {
      _driveSigningIn = false;
      _driveAccessToken = token;
    });

    _showPersistentMessage(result.userMessage());

    return token;
  }

  Future<void> _importScheduleFromUrl(BuildContext dialogCtx) async {
    final controller = TextEditingController();
    bool useDriveAuth = true;

    final confirmed = await showDialog<bool>(
      context: dialogCtx,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Import from link'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Link (Google Drive or direct URL)',
                  hintText: 'Paste a CSV/XLSX/DOCX link',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Use Google Sign-In for private Drive links'),
                value: useDriveAuth,
                onChanged: (v) => setState(() => useDriveAuth = v ?? true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Import'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final rawUrl = controller.text.trim();
    if (rawUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please paste a link')),
        );
      }
      return;
    }

    final directUrl = _driveDirectDownloadUrl(rawUrl) ?? rawUrl;
    final uri = Uri.tryParse(directUrl);
    if (uri == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid URL')),
        );
      }
      return;
    }

    try {
      Map<String, String>? headers;
      if (useDriveAuth) {
        final token = _driveAccessToken ?? await _ensureDriveAccessToken();
        if (token == null || token.isEmpty) return;
        headers = {'Authorization': 'Bearer $token'};
      }

      final resp = await http.get(uri, headers: headers);
      if (resp.statusCode >= 400) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Download failed (${resp.statusCode})')),
          );
        }
        return;
      }

      final scheduleService = ClassScheduleService();
      final items = scheduleService.parseFromBytes(resp.bodyBytes);

      if (items.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('No schedule items found in the file')),
          );
        }
        return;
      }

      await scheduleService.save(widget.classId, items);
      setState(() {
        _scheduleItems = items;
      });

      if (mounted) {
        Navigator.pop(dialogCtx);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported ${items.length} schedule items')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing: $e')),
        );
      }
    }
  }

  String? _driveDirectDownloadUrl(String url) {
    // Converts common Google Drive sharing URLs to direct-download links
    final fileIdMatch = RegExp(r'd/([^/]+)/').firstMatch(url);
    if (fileIdMatch != null && fileIdMatch.groupCount >= 1) {
      final id = fileIdMatch.group(1);
      return 'https://drive.google.com/uc?export=download&id=$id';
    }

    final queryId = Uri.tryParse(url)?.queryParameters['id'];
    if (queryId != null && queryId.isNotEmpty) {
      return 'https://drive.google.com/uc?export=download&id=$queryId';
    }

    return null;
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return AnimatedGlowBorder(
      radius: AppRadius.md,
      child: Container(
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: AppSpacing.xs),
            Text(value, style: context.textStyles.headlineMedium?.bold),
            Text(label, style: context.textStyles.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedGlowBorder(
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: AppSpacing.paddingMd,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(icon,
                      color: Theme.of(context).colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: context.textStyles.titleMedium?.semiBold),
                      Text(
                        subtitle,
                        style: context.textStyles.bodySmall?.withColor(
                          Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScheduleItemTile extends StatelessWidget {
  final ClassScheduleItem item;

  const _ScheduleItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final dateStr = item.date != null
        ? DateFormat('MMM d, yyyy').format(item.date!)
        : (item.week != null ? 'Week ${item.week}' : null);

    return ListTile(
      contentPadding: AppSpacing.paddingMd,
      leading: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(
          Icons.event_note,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
          size: 20,
        ),
      ),
      title: Text(
        item.title,
        style: context.textStyles.titleSmall?.semiBold,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dateStr != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  dateStr,
                  style: context.textStyles.bodySmall?.withColor(
                    Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
          if (item.details.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ...item.details.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          '${e.key}:',
                          style:
                              context.textStyles.bodySmall?.semiBold.withColor(
                            Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          e.value,
                          style: context.textStyles.bodySmall,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
