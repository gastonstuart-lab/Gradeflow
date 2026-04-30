/// GradeFlow OS - Class Surface
///
/// The focused single-class workspace. When a teacher opens a class from
/// the OS, this surface becomes the active context with the class always
/// pinned at the top.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gradeflow/components/command_surface.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/components/animated_page_background.dart';
import 'package:gradeflow/components/workspace_shell.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/os/os_controller.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/theme.dart';

class ClassSurface extends StatefulWidget {
  const ClassSurface({super.key, required this.classId});

  final String classId;

  @override
  State<ClassSurface> createState() => _ClassSurfaceState();
}

class _ClassSurfaceState extends State<ClassSurface>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _hydrating = false;
  int _activeTabIndex = 0;

  static const _tabDefs = [
    _TabDef(icon: Icons.dashboard_outlined, label: 'Overview'),
    _TabDef(icon: Icons.event_note_outlined, label: 'Schedule'),
    _TabDef(icon: Icons.menu_book_rounded, label: 'Gradebook'),
    _TabDef(icon: Icons.description_outlined, label: 'Exams'),
    _TabDef(icon: Icons.assessment_outlined, label: 'Results'),
    _TabDef(icon: Icons.event_seat_rounded, label: 'Seating'),
    _TabDef(icon: Icons.people_rounded, label: 'Students'),
    _TabDef(icon: Icons.picture_as_pdf_rounded, label: 'Export'),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabDefs.length, vsync: this)
      ..addListener(_handleTabChange);
    _hydrating =
        context.read<ClassService>().getClassById(widget.classId) == null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<GradeFlowOSController>().setSurface(
              OSSurface.classWorkspace,
              classId: widget.classId,
            );
      }
    });
    _scheduleHydration();
  }

  @override
  void didUpdateWidget(covariant ClassSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classId != widget.classId) {
      setState(() {
        _activeTabIndex = 0;
        _tabs.index = 0;
        _hydrating =
            context.read<ClassService>().getClassById(widget.classId) == null;
      });
      _scheduleHydration();
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_handleTabChange);
    _tabs.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_activeTabIndex != _tabs.index && mounted) {
      setState(() => _activeTabIndex = _tabs.index);
    }
  }

  void _scheduleHydration() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_hydrateClassContext());
    });
  }

  Future<void> _hydrateClassContext() async {
    final requestedClassId = widget.classId;
    final auth = context.read<AuthService>();
    final classService = context.read<ClassService>();
    final studentService = context.read<StudentService>();

    try {
      final user = auth.currentUser;
      if (user != null && classService.getClassById(requestedClassId) == null) {
        await classService.loadClasses(user.userId);
      }
      await studentService.loadStudents(requestedClassId);
    } catch (e) {
      debugPrint('Failed to hydrate OS class surface: $e');
    } finally {
      final sameClass = widget.classId == requestedClassId;
      if (mounted && sameClass && _hydrating) {
        setState(() => _hydrating = false);
      }
    }
  }

  void _goBackHome() {
    context.read<GradeFlowOSController>().setSurface(OSSurface.home);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.osHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classService = context.watch<ClassService>();
    final classModel = classService.classes
        .where((c) => c.classId == widget.classId)
        .firstOrNull;

    if (classModel == null && _hydrating) {
      return const WorkspaceScaffold(
        eyebrow: 'Class workspace',
        title: 'Loading class workspace',
        subtitle: 'Preparing the class context, roster, and available tools.',
        child: WorkspaceLoadingState(
          title: 'Loading class workspace',
          subtitle:
              'Restoring the active class, roster, and quick-launch tools.',
        ),
      );
    }

    if (classModel == null) {
      return WorkspaceScaffold(
        eyebrow: 'Class workspace',
        title: 'Class unavailable',
        subtitle: 'We could not restore this class context right now.',
        child: WorkspaceEmptyState(
          icon: Icons.class_outlined,
          title: 'Class not found',
          subtitle:
              'Return to the OS home surface and choose another class workspace.',
          actions: [
            FilledButton.icon(
              onPressed: _goBackHome,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back to home'),
              style: WorkspaceButtonStyles.filled(context),
            ),
          ],
        ),
      );
    }

    final activeTabLabel = _tabDefs[_activeTabIndex].label;

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
                  padding: WorkspaceSpacing.shellPadding,
                  radius: WorkspaceRadius.shell,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ClassHeader(
                        classId: widget.classId,
                        className: classModel.className,
                        subject: classModel.subject,
                        schoolYear: classModel.schoolYear,
                        term: classModel.term,
                        isArchived: classModel.isArchived,
                        hasPlanning:
                            classModel.syllabus?.entries.isNotEmpty ?? false,
                        activeTabLabel: activeTabLabel,
                        onBack: _goBackHome,
                      ),
                      const SizedBox(height: WorkspaceSpacing.sm),
                      _ClassTabBar(
                        tabs: _tabDefs,
                        controller: _tabs,
                      ),
                      const SizedBox(height: WorkspaceSpacing.lg),
                      Expanded(
                        child: TabBarView(
                          controller: _tabs,
                          children: [
                            _ClassOverviewTab(
                              classId: widget.classId,
                              className: classModel.className,
                              onNavigate: (route) => context.go(route),
                            ),
                            _ClassToolTab(
                              icon: Icons.event_note_outlined,
                              title: 'Schedule',
                              description:
                                  'Upload class schedules, syllabus tables, and dated planning context for this class.',
                              action: 'Manage schedule',
                              onTap: () => context.go(
                                AppRoutes.osClassSchedule(widget.classId),
                              ),
                            ),
                            _ClassToolTab(
                              icon: Icons.menu_book_rounded,
                              title: 'Gradebook',
                              description:
                                  'Manage assessments, scoring, and classroom grading context.',
                              action: 'Open gradebook',
                              onTap: () => context.go(
                                AppRoutes.osClassGradebook(widget.classId),
                              ),
                            ),
                            _ClassToolTab(
                              icon: Icons.description_outlined,
                              title: 'Exam Scores',
                              description:
                                  'Import, review, and correct final exam scores for this class roster.',
                              action: 'Import exam scores',
                              onTap: () => context.go(
                                AppRoutes.osClassExams(widget.classId),
                              ),
                            ),
                            _ClassToolTab(
                              icon: Icons.assessment_outlined,
                              title: 'Final Results',
                              description:
                                  'Review process marks, exam scores, and final outcomes in one place.',
                              action: 'Open results',
                              onTap: () => context.go(
                                AppRoutes.osClassResults(widget.classId),
                              ),
                            ),
                            _ClassToolTab(
                              icon: Icons.event_seat_rounded,
                              title: 'Seating',
                              description:
                                  'Adjust layouts, room setups, and student placement for this class.',
                              action: 'Open seating',
                              onTap: () => context.go(
                                AppRoutes.osClassSeating(widget.classId),
                              ),
                            ),
                            _ClassToolTab(
                              icon: Icons.people_rounded,
                              title: 'Students',
                              description:
                                  'Review roster details, notes, and class-specific student records.',
                              action: 'Open students',
                              onTap: () => context.go(
                                AppRoutes.osClassStudents(widget.classId),
                              ),
                            ),
                            _ClassToolTab(
                              icon: Icons.picture_as_pdf_rounded,
                              title: 'Export',
                              description:
                                  'Prepare printable or shareable class outputs without leaving this context.',
                              action: 'Open export',
                              onTap: () => context.go(
                                AppRoutes.osClassExport(widget.classId),
                              ),
                            ),
                          ],
                        ),
                      ),
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

class _ClassHeader extends StatelessWidget {
  const _ClassHeader({
    required this.classId,
    required this.className,
    required this.subject,
    required this.schoolYear,
    required this.term,
    required this.isArchived,
    required this.hasPlanning,
    required this.activeTabLabel,
    required this.onBack,
  });

  final String classId;
  final String className;
  final String subject;
  final String schoolYear;
  final String term;
  final bool isArchived;
  final bool hasPlanning;
  final String activeTabLabel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final studentCount = context
        .watch<StudentService>()
        .students
        .where((s) => s.classId == classId)
        .length;

    final pulseTone = isArchived || !hasPlanning
        ? CommandPulseTone.attention
        : CommandPulseTone.calm;
    final pulseLabel = isArchived
        ? 'Archived class context'
        : hasPlanning
            ? 'Class context pinned and ready'
            : 'Planning setup still needed';

    final actionButton = FilledButton.icon(
      onPressed: () => context.go(AppRoutes.osClassSchedule(classId)),
      icon: const Icon(Icons.open_in_new_rounded),
      label: const Text('Schedule & details'),
      style: WorkspaceButtonStyles.filled(context),
    );

    return CommandHeader(
      eyebrow: 'Class workspace',
      title: className,
      subtitle:
          'A focused class command surface with the live context pinned while you move between overview, grading, seating, students, and export.',
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back to home',
            style: WorkspaceButtonStyles.icon(context),
          ),
          const SizedBox(width: WorkspaceSpacing.sm),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(WorkspaceRadius.context),
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.24),
              ),
            ),
            child: Icon(
              Icons.class_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 26,
            ),
          ),
        ],
      ),
      primaryAction: actionButton,
      pulseTone: pulseTone,
      pulseLabel: pulseLabel,
      contextPills: [
        WorkspaceContextPill(
          icon: Icons.auto_stories_outlined,
          label: 'Subject',
          value: subject.trim().isEmpty ? 'Class workspace' : subject,
        ),
        WorkspaceContextPill(
          icon: Icons.people_alt_outlined,
          label: 'Students',
          value: '$studentCount',
        ),
        WorkspaceContextPill(
          icon: Icons.event_note_outlined,
          label: 'Term',
          value: '$schoolYear / $term',
        ),
        WorkspaceContextPill(
          icon: hasPlanning
              ? Icons.check_circle_outline
              : Icons.edit_calendar_outlined,
          label: 'Planning',
          value: hasPlanning ? 'Ready' : 'Add later',
          accent:
              hasPlanning ? const Color(0xFF4C9B7A) : const Color(0xFFDAA85E),
          emphasized: true,
        ),
        WorkspaceContextPill(
          icon: isArchived ? Icons.archive_outlined : Icons.grid_view_outlined,
          label: 'Active tab',
          value: activeTabLabel,
          accent: isArchived
              ? Theme.of(context).colorScheme.secondary
              : Theme.of(context).colorScheme.primary,
          emphasized: true,
        ),
      ],
    );
  }
}

class _TabDef {
  const _TabDef({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _ClassTabBar extends StatelessWidget {
  const _ClassTabBar({
    required this.tabs,
    required this.controller,
  });

  final List<_TabDef> tabs;
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(WorkspaceRadius.band),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.14),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(WorkspaceRadius.context),
        child: SizedBox(
          height: 52,
          child: TabBar(
            controller: controller,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: Colors.transparent,
            labelColor: theme.colorScheme.onSurface,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            labelStyle: context.textStyles.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            unselectedLabelStyle: context.textStyles.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            overlayColor: WidgetStatePropertyAll(
              theme.colorScheme.primary.withValues(alpha: 0.06),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(WorkspaceRadius.context),
              color: theme.colorScheme.primary.withValues(alpha: 0.14),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.18),
              ),
            ),
            tabs: tabs
                .map(
                  (tab) => Tab(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(tab.icon, size: 16),
                          const SizedBox(width: 6),
                          Text(tab.label),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _ClassOverviewTab extends StatelessWidget {
  const _ClassOverviewTab({
    required this.classId,
    required this.className,
    required this.onNavigate,
  });

  final String classId;
  final String className;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final tools = [
      _ClassToolLink(
        icon: Icons.event_note_outlined,
        label: 'Schedule',
        subtitle: 'Upload class schedule files and dated planning context.',
        color: Color(0xFF58C78B),
        route: AppRoutes.osClassSchedule(classId),
      ),
      _ClassToolLink(
        icon: Icons.menu_book_rounded,
        label: 'Gradebook',
        subtitle: 'Assessments, categories, and daily scoring.',
        color: Color(0xFFE38B5B),
        route: AppRoutes.osClassGradebook(classId),
      ),
      _ClassToolLink(
        icon: Icons.description_outlined,
        label: 'Exam Scores',
        subtitle: 'Import final exam scores for this roster.',
        color: Color(0xFF9A7AE8),
        route: AppRoutes.osClassExams(classId),
      ),
      _ClassToolLink(
        icon: Icons.assessment_outlined,
        label: 'Final Results',
        subtitle: 'Review process, exam, and final outcomes together.',
        color: Color(0xFF6F86E8),
        route: AppRoutes.osClassResults(classId),
      ),
      _ClassToolLink(
        icon: Icons.event_seat_rounded,
        label: 'Seating',
        subtitle: 'Layouts, room setups, and seat placement.',
        color: Color(0xFFDAA85E),
        route: AppRoutes.osClassSeating(classId),
      ),
      _ClassToolLink(
        icon: Icons.people_rounded,
        label: 'Students',
        subtitle: 'Roster details, notes, and class records.',
        color: Color(0xFF4C9B7A),
        route: AppRoutes.osClassStudents(classId),
      ),
      _ClassToolLink(
        icon: Icons.picture_as_pdf_rounded,
        label: 'Export',
        subtitle: 'Shareable packets, printouts, and outputs.',
        color: Color(0xFF5EC7E6),
        route: AppRoutes.osClassExport(classId),
      ),
      _ClassToolLink(
        icon: Icons.folder_open_rounded,
        label: 'Schedule & Details',
        subtitle: 'Open class notes, schedule, and setup for this class.',
        color: Color(0xFF3E7EDB),
        route: AppRoutes.osClassSchedule(classId),
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkspaceSectionHeader(
            title: 'Tools',
            subtitle: 'Open the workflow you need for this class.',
          ),
          const SizedBox(height: WorkspaceSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 12.0;
              final columns = constraints.maxWidth >= 1180
                  ? 3
                  : constraints.maxWidth >= 760
                      ? 2
                      : 1;
              final tileWidth =
                  (constraints.maxWidth - (spacing * (columns - 1))) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final tool in tools)
                    SizedBox(
                      width: tileWidth,
                      child: _ClassOverviewToolCard(
                        tool: tool,
                        onTap: () => onNavigate(tool.route),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ClassToolLink {
  const _ClassToolLink({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final String route;
}

class _ClassOverviewToolCard extends StatelessWidget {
  const _ClassOverviewToolCard({
    required this.tool,
    required this.onTap,
  });

  final _ClassToolLink tool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return WorkspaceFlatSurface(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: tool.color.withValues(alpha: 0.14),
            ),
            child: Icon(tool.icon, color: tool.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tool.label,
                  style: context.textStyles.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tool.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: WorkspaceTypography.metadata(context),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            Icons.arrow_outward_rounded,
            size: 18,
            color: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class _ClassToolTab extends StatelessWidget {
  const _ClassToolTab({
    required this.icon,
    required this.title,
    required this.description,
    required this.action,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WorkspaceFlatSurface(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 620;
                final iconBox = Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: theme.colorScheme.primary.withValues(alpha: 0.13),
                  ),
                  child: Icon(
                    icon,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                );
                final copy = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.textStyles.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: WorkspaceTypography.metadata(context),
                    ),
                  ],
                );
                final button = FilledButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.arrow_outward_rounded),
                  label: Text(action),
                  style: WorkspaceButtonStyles.filled(context),
                );

                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          iconBox,
                          const SizedBox(width: 14),
                          Expanded(child: copy),
                        ],
                      ),
                      const SizedBox(height: WorkspaceSpacing.md),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: button,
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    iconBox,
                    const SizedBox(width: 16),
                    Expanded(child: copy),
                    const SizedBox(width: 16),
                    button,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: WorkspaceSpacing.lg),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _ClassToolAffordance(
                icon: Icons.push_pin_outlined,
                label: 'Class context stays pinned',
              ),
              _ClassToolAffordance(
                icon: Icons.flash_on_outlined,
                label: 'Opens immediately',
              ),
              _ClassToolAffordance(
                icon: Icons.keyboard_return_rounded,
                label: 'Back returns here',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClassToolAffordance extends StatelessWidget {
  const _ClassToolAffordance({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(WorkspaceRadius.pill),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: theme.colorScheme.primary),
          const SizedBox(width: 7),
          Text(
            label,
            style: WorkspaceTypography.metadata(context)?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
