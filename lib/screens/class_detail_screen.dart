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
import 'package:gradeflow/components/workspace_shell.dart';
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

  void _showFeedback(
    String message, {
    WorkspaceFeedbackTone tone = WorkspaceFeedbackTone.info,
    String? title,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!mounted) return;
    showWorkspaceSnackBar(
      context,
      message: message,
      tone: tone,
      title: title,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  void _showPersistentMessage(String message) {
    _showFeedback(
      message,
      title: 'Google Sign-In',
      actionLabel: 'Details',
      duration: const Duration(seconds: 12),
      onAction: () {
        showDialog<void>(
          context: context,
          builder: (ctx) => WorkspaceDialogScaffold(
            title: 'Google Sign-In',
            subtitle: 'Details from the latest sign-in attempt.',
            icon: Icons.login_outlined,
            body: SelectableText(
              message,
              style: context.textStyles.bodySmall?.copyWith(height: 1.4),
            ),
            actions: [
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: message));
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy'),
                style: WorkspaceButtonStyles.text(ctx),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: WorkspaceButtonStyles.filled(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
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
        builder: (ctx, setLocalState) => WorkspaceDialogScaffold(
          title: 'Add note or reminder',
          subtitle:
              'Keep a quick teaching note or date-based reminder with this class.',
          icon: Icons.sticky_note_2_outlined,
          body: SizedBox(
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
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  visualDensity: VisualDensity.compact,
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
                if (includeReminderDate) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        remindAt == null
                            ? 'Choose date'
                            : DateFormat('EEE, MMM d').format(remindAt!),
                      ),
                      onPressed: () async {
                        final picked = await showWorkspaceDatePicker(
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
                      style: WorkspaceButtonStyles.outlined(ctx, compact: true),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: WorkspaceButtonStyles.text(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              style: WorkspaceButtonStyles.filled(ctx),
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
      return const WorkspaceScaffold(
        eyebrow: 'Class workspace',
        title: 'Class workspace unavailable',
        subtitle: 'This class could not be opened in the shared workspace.',
        child: WorkspaceEmptyState(
          icon: Icons.class_outlined,
          title: 'Class not found',
          subtitle: 'Return to Classes and open another workspace to continue.',
        ),
      );
    }

    final studentCount = studentService.students.length;
    final categoryCount = categoryService.categories.length;
    final tools = [
      ClassWorkspaceToolData(
        icon: Icons.people_alt_outlined,
        title: 'Roster',
        subtitle: 'View, manage, and verify the students in this class.',
        onTap: () => context.push('/class/${widget.classId}/students'),
      ),
      ClassWorkspaceToolData(
        icon: Icons.event_seat_outlined,
        title: 'Seating',
        subtitle: 'Design room layouts and keep attendance flow fast.',
        onTap: () => context.push('/class/${widget.classId}/seating'),
      ),
      ClassWorkspaceToolData(
        icon: Icons.edit_note,
        title: 'Gradebook',
        subtitle: 'Enter marks and review the current assessment picture.',
        onTap: () => context.push('/class/${widget.classId}/gradebook'),
      ),
      ClassWorkspaceToolData(
        icon: Icons.category_outlined,
        title: 'Categories',
        subtitle: 'Adjust weights and keep grading structure aligned.',
        onTap: () => context.push('/class/${widget.classId}/categories'),
      ),
      ClassWorkspaceToolData(
        icon: Icons.description_outlined,
        title: 'Exams',
        subtitle: 'Capture final exam scores and keep the record complete.',
        onTap: () => context.push('/class/${widget.classId}/exams'),
      ),
      ClassWorkspaceToolData(
        icon: Icons.assessment_outlined,
        title: 'Results',
        subtitle: 'Review process, exam, and final outcomes together.',
        onTap: () => context.push('/class/${widget.classId}/results'),
      ),
      ClassWorkspaceToolData(
        icon: Icons.download_outlined,
        title: 'Export',
        subtitle: 'Download final results as a clean CSV for reporting.',
        onTap: () => context.push('/class/${widget.classId}/export'),
      ),
    ];

    return WorkspaceScaffold(
      eyebrow: 'Class Workspace',
      title: classItem.className,
      subtitle:
          '${classItem.subject} - ${classItem.schoolYear} - ${classItem.term}',
      compactHeader: true,
      contextBar: _buildCompactOverviewBar(
        context,
        studentCount: studentCount,
        categoryCount: categoryCount,
      ),
      child: studentService.isLoading || categoryService.isLoading
          ? const WorkspaceLoadingState(
              title: 'Loading class workspace',
              subtitle:
                  'Pulling roster, categories, and planning data into this class.',
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1180;
                final planningRail = _buildPlanningWorkspace(context);

                return SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: WorkspaceSurfaceCard(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const WorkspaceSectionHeader(
                                      title: 'Class tools',
                                      subtitle:
                                          'Open the next teaching task directly from the class workspace.',
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    ClassWorkspaceToolGrid(tools: tools),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(
                              flex: 2,
                              child: planningRail,
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            WorkspaceSurfaceCard(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const WorkspaceSectionHeader(
                                    title: 'Class tools',
                                    subtitle:
                                        'Open the next teaching task directly from the class workspace.',
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  ClassWorkspaceToolGrid(tools: tools),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            planningRail,
                          ],
                        ),
                );
              },
            ),
    );
  }

  Widget _buildCompactOverviewBar(
    BuildContext context, {
    required int studentCount,
    required int categoryCount,
  }) {
    return WorkspaceContextBar(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      radius: 16,
      leading: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _CompactWorkspaceMetricChip(
            label: 'Students',
            value: '$studentCount',
            icon: Icons.people_alt_outlined,
            accent: Theme.of(context).colorScheme.primary,
          ),
          _CompactWorkspaceMetricChip(
            label: 'Categories',
            value: '$categoryCount',
            icon: Icons.category_outlined,
            accent: Theme.of(context).colorScheme.secondary,
          ),
          _CompactWorkspaceMetricChip(
            label: 'Schedule',
            value: _scheduleItems.isEmpty ? 'None' : '${_scheduleItems.length}',
            icon: Icons.calendar_month_outlined,
            accent: Theme.of(context).colorScheme.tertiary,
          ),
        ],
      ),
      trailing: OutlinedButton.icon(
        onPressed: () => _showScheduleDialog(context),
        icon: const Icon(Icons.calendar_month_outlined),
        label: Text(_scheduleItems.isEmpty ? 'Add schedule' : 'Open schedule'),
        style: WorkspaceButtonStyles.outlined(context, compact: true),
      ),
    );
  }

  Widget _buildPlanningWorkspace(BuildContext context) {
    final now = DateTime.now();
    final thisWeekStart = _startOfWeek(now);
    final nextWeekStart = thisWeekStart.add(const Duration(days: 7));

    return WorkspaceSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkspaceSectionHeader(
            title: 'Planning',
            subtitle:
                'Weekly schedule and reminders stay visible as supporting context.',
          ),
          const SizedBox(height: AppSpacing.sm),
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
          const SizedBox(height: AppSpacing.sm),
          _buildClassNotesPanel(context),
        ],
      ),
    );
  }

  Widget _buildWeekSchedulePanel(
    BuildContext context, {
    required String title,
    required DateTime weekStart,
  }) {
    final theme = Theme.of(context);
    final items = _scheduleItemsForWeek(weekStart);
    final previewItems = items.take(3).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.24),
        ),
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
                style: context.textStyles.labelSmall?.withColor(
                  theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (previewItems.isEmpty)
            Text(
              'No scheduled items yet.',
              style: context.textStyles.labelMedium?.withColor(
                theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...previewItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: 4,
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item.details.isNotEmpty)
                            Text(
                              item.details.entries
                                  .take(1)
                                  .map((entry) => entry.value)
                                  .join(' - '),
                              style: context.textStyles.labelMedium?.withColor(
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
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '+${items.length - previewItems.length} more items',
                style: context.textStyles.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClassNotesPanel(BuildContext context) {
    final theme = Theme.of(context);
    final previewItems = _classNotes.take(3).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.24),
        ),
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
                style: WorkspaceButtonStyles.text(context, compact: true),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (previewItems.isEmpty)
            Text(
              'Keep track of things to revisit with this class.',
              style: context.textStyles.labelMedium?.withColor(
                theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...previewItems.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            note.remindAt != null
                                ? 'Reminder: ${DateFormat('EEE, MMM d').format(note.remindAt!)}'
                                : 'Note added ${DateFormat('MMM d').format(note.createdAt)}',
                            style: context.textStyles.labelMedium?.withColor(
                              theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteClassNote(note),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),
          if (_classNotes.length > previewItems.length)
            Text(
              '+${_classNotes.length - previewItems.length} more notes',
              style: context.textStyles.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }

  void _showScheduleDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => WorkspaceDialogScaffold(
        title: 'Class schedule',
        subtitle:
            'Upload, replace, or clear the class schedule without leaving this workspace.',
        icon: Icons.calendar_month_outlined,
        maxWidth: 860,
        maxHeight: 720,
        bodyCanExpand: true,
        headerAction: IconButton(
          onPressed: () => Navigator.pop(dialogCtx),
          icon: const Icon(Icons.close),
          style: WorkspaceButtonStyles.icon(dialogCtx),
          tooltip: 'Close',
        ),
        body: _scheduleItems.isEmpty
            ? _buildEmptySchedule(dialogCtx)
            : _buildScheduleList(dialogCtx),
        actions: [
          TextButton.icon(
            icon: _driveSigningIn
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login_outlined),
            label: Text(
              _driveAccessToken == null
                  ? 'Connect Google Drive'
                  : 'Drive connected',
            ),
            onPressed: _driveSigningIn ? null : () => _ensureDriveAccessToken(),
            style: WorkspaceButtonStyles.text(dialogCtx),
          ),
          TextButton.icon(
            icon: const Icon(Icons.cloud_download_outlined),
            label: const Text('Import from link'),
            onPressed: () => _importScheduleFromUrl(dialogCtx),
            style: WorkspaceButtonStyles.text(dialogCtx),
          ),
          if (_scheduleItems.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear schedule'),
              onPressed: () => _clearSchedule(dialogCtx),
              style: WorkspaceButtonStyles.text(dialogCtx),
            ),
          FilledButton.icon(
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(
              _scheduleItems.isEmpty ? 'Upload schedule' : 'Replace schedule',
            ),
            onPressed: () => _uploadSchedule(dialogCtx),
            style: WorkspaceButtonStyles.filled(dialogCtx),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySchedule(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: const WorkspaceInlineState(
          icon: Icons.calendar_month_outlined,
          title: 'No schedule uploaded',
          subtitle:
              'Upload an Excel, CSV, or Word file to make planning visible here.',
        ),
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
        _showFeedback(
          'Could not read the selected file.',
          tone: WorkspaceFeedbackTone.warning,
        );
        return;
      }

      final scheduleService = ClassScheduleService();
      final items = scheduleService.parseFromBytes(file.bytes!);

      if (items.isEmpty) {
        _showFeedback(
          'No schedule items were detected in that file.',
          tone: WorkspaceFeedbackTone.warning,
        );
        return;
      }

      await scheduleService.save(widget.classId, items);
      if (!mounted) return;

      setState(() {
        _scheduleItems = items;
      });

      Navigator.of(dialogCtx).pop();
      _showFeedback(
        'Uploaded ${items.length} schedule items.',
        tone: WorkspaceFeedbackTone.success,
      );
    } catch (e) {
      _showFeedback(
        'Schedule upload failed: $e',
        tone: WorkspaceFeedbackTone.error,
      );
    }
  }

  Future<void> _clearSchedule(BuildContext dialogCtx) async {
    final confirm = await showDialog<bool>(
      context: dialogCtx,
      builder: (ctx) => WorkspaceDialogScaffold(
        title: 'Clear schedule',
        subtitle: 'Remove all imported schedule items from this class.',
        icon: Icons.delete_outline,
        body: Text(
          'This removes the current schedule list for this class. You can upload a replacement at any time.',
          style: ctx.textStyles.bodySmall?.copyWith(
            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: WorkspaceButtonStyles.text(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: WorkspaceButtonStyles.filled(ctx),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final scheduleService = ClassScheduleService();
    await scheduleService.save(widget.classId, []);
    if (!mounted) return;

    setState(() {
      _scheduleItems = [];
    });

    Navigator.of(dialogCtx).pop();
    _showFeedback(
      'Schedule cleared.',
      tone: WorkspaceFeedbackTone.success,
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
        builder: (ctx, setState) => WorkspaceDialogScaffold(
          title: 'Import from link',
          subtitle:
              'Paste a Google Drive or direct file URL to import schedule data.',
          icon: Icons.cloud_download_outlined,
          body: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Link',
                    hintText: 'Paste a CSV, XLSX, or DOCX link',
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title:
                      const Text('Use Google Sign-In for private Drive links'),
                  value: useDriveAuth,
                  onChanged: (v) => setState(() => useDriveAuth = v ?? true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: WorkspaceButtonStyles.text(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: WorkspaceButtonStyles.filled(ctx),
              child: const Text('Import'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final rawUrl = controller.text.trim();
    if (rawUrl.isEmpty) {
      _showFeedback(
        'Paste a link before importing.',
        tone: WorkspaceFeedbackTone.warning,
      );
      return;
    }

    final directUrl = _driveDirectDownloadUrl(rawUrl) ?? rawUrl;
    final uri = Uri.tryParse(directUrl);
    if (uri == null) {
      _showFeedback(
        'That link is not a valid URL.',
        tone: WorkspaceFeedbackTone.warning,
      );
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
        _showFeedback(
          'Download failed (${resp.statusCode}).',
          tone: WorkspaceFeedbackTone.error,
        );
        return;
      }

      final scheduleService = ClassScheduleService();
      final items = scheduleService.parseFromBytes(resp.bodyBytes);

      if (items.isEmpty) {
        _showFeedback(
          'No schedule items were found in that file.',
          tone: WorkspaceFeedbackTone.warning,
        );
        return;
      }

      await scheduleService.save(widget.classId, items);
      setState(() {
        _scheduleItems = items;
      });

      if (mounted) {
        Navigator.pop(dialogCtx);
        _showFeedback(
          'Imported ${items.length} schedule items.',
          tone: WorkspaceFeedbackTone.success,
        );
      }
    } catch (e) {
      _showFeedback(
        'Schedule import failed: $e',
        tone: WorkspaceFeedbackTone.error,
      );
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

class ClassWorkspaceToolData {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const ClassWorkspaceToolData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

class _CompactWorkspaceMetricChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _CompactWorkspaceMetricChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.18),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: accent.withValues(alpha: 0.14),
              border: Border.all(
                color: accent.withValues(alpha: 0.2),
              ),
            ),
            child: Icon(icon, size: 15, color: accent),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: context.textStyles.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: context.textStyles.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ClassWorkspaceToolGrid extends StatelessWidget {
  final List<ClassWorkspaceToolData> tools;

  const ClassWorkspaceToolGrid({
    super.key,
    required this.tools,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final columnCount = constraints.maxWidth >= 1280
            ? 4
            : constraints.maxWidth >= 980
                ? 3
                : constraints.maxWidth >= 620
                    ? 2
                    : 1;
        final tileWidth = columnCount == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - (spacing * (columnCount - 1))) /
                columnCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tool in tools)
              SizedBox(
                width: tileWidth,
                child: _ClassWorkspaceToolCard(tool: tool),
              ),
          ],
        );
      },
    );
  }
}

class _ClassWorkspaceToolCard extends StatelessWidget {
  final ClassWorkspaceToolData tool;

  const _ClassWorkspaceToolCard({
    required this.tool,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return WorkspaceSurfaceCard(
      onTap: tool.onTap,
      radius: 20,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.18),
                  ),
                ),
                child: Icon(
                  tool.icon,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_outward_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            tool.title,
            style: context.textStyles.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            tool.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.textStyles.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
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
