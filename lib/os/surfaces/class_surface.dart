/// GradeFlow OS - Class Surface
///
/// The focused single-class workspace. When a teacher opens a class from
/// the OS, this surface becomes the active context with the class pinned at
/// the top and an overview optimized for rapid teaching workflows.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/components/command_surface.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/os/os_controller.dart';
import 'package:gradeflow/os/os_palette.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/student_service.dart';

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
    _tabs = TabController(length: _tabDefs.length, vsync: this);
    _hydrating =
        context.read<ClassService>().getClassById(widget.classId) == null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<GradeFlowOSController>().setSurface(
            OSSurface.classWorkspace,
            classId: widget.classId,
          );
    });
    _scheduleHydration();
  }

  @override
  void didUpdateWidget(covariant ClassSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classId != widget.classId) {
      _tabs.index = 0;
      setState(() {
        _hydrating =
            context.read<ClassService>().getClassById(widget.classId) == null;
      });
      _scheduleHydration();
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
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
    final dark = context.isDark;
    final classService = context.watch<ClassService>();
    final classModel = classService.classes
        .where((c) => c.classId == widget.classId)
        .firstOrNull;

    if (classModel == null && _hydrating) {
      return _ClassWorkspaceStatusScaffold(
        title: 'Loading class workspace',
        subtitle: 'Restoring the active class, roster, and quick-launch tools.',
        loading: true,
        onBack: _goBackHome,
      );
    }

    if (classModel == null) {
      return _ClassWorkspaceStatusScaffold(
        title: 'Class not found',
        subtitle:
            'Return to the OS home surface and choose another class workspace.',
        onBack: _goBackHome,
      );
    }

    final className = classModel.className;
    final subject = classModel.subject;

    return Scaffold(
      backgroundColor: OSColors.appBackground(dark),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 980;
            final hPad = isCompact ? 12.0 : 16.0;
            final dockInset = MediaQuery.paddingOf(context).bottom;

            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 0),
                  child: _ClassWorkspaceHero(
                    classId: widget.classId,
                    className: className,
                    subject: subject,
                    onBack: _goBackHome,
                    onOpenFullView: () {
                      context.go('${AppRoutes.classDetail}/${widget.classId}');
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 8),
                  child: _ClassWorkspaceTabBar(
                    tabs: _tabDefs,
                    controller: _tabs,
                    dark: dark,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: dockInset),
                    child: TabBarView(
                      controller: _tabs,
                      children: [
                        _ClassOverviewTab(
                          classId: widget.classId,
                          className: className,
                          subject: subject,
                        ),
                        _ClassToolTab(
                          icon: Icons.event_note_outlined,
                          title: 'Schedule',
                          description:
                              'Manage class schedules, syllabus tables, and dated planning context.',
                          action: 'Open Schedule',
                          onTap: () => context.go(
                            AppRoutes.osClassSchedule(widget.classId),
                          ),
                        ),
                        _ClassToolTab(
                          icon: Icons.menu_book_rounded,
                          title: 'Gradebook',
                          description:
                              'Manage scores, grade items, and assessments.',
                          action: 'Open Gradebook',
                          onTap: () => context.go(
                            AppRoutes.osClassGradebook(widget.classId),
                          ),
                        ),
                        _ClassToolTab(
                          icon: Icons.description_outlined,
                          title: 'Exams',
                          description:
                              'Import, review, and correct exam scores for this class roster.',
                          action: 'Open Exams',
                          onTap: () => context.go(
                            AppRoutes.osClassExams(widget.classId),
                          ),
                        ),
                        _ClassToolTab(
                          icon: Icons.assessment_outlined,
                          title: 'Results',
                          description:
                              'Review process marks, exam scores, and final class outcomes.',
                          action: 'Open Results',
                          onTap: () => context.go(
                            AppRoutes.osClassResults(widget.classId),
                          ),
                        ),
                        _ClassToolTab(
                          icon: Icons.event_seat_rounded,
                          title: 'Seating',
                          description:
                              'Assign seats and configure room layout.',
                          action: 'Open Seating',
                          onTap: () => context.go(
                            AppRoutes.osClassSeating(widget.classId),
                          ),
                        ),
                        _ClassToolTab(
                          icon: Icons.people_rounded,
                          title: 'Students',
                          description: 'View and manage student records.',
                          action: 'Open Students',
                          onTap: () => context.go(
                            AppRoutes.osClassStudents(widget.classId),
                          ),
                        ),
                        _ClassToolTab(
                          icon: Icons.picture_as_pdf_rounded,
                          title: 'Export',
                          description: 'Export grades as PDF or CSV.',
                          action: 'Open Export',
                          onTap: () => context.go(
                            AppRoutes.osClassExport(widget.classId),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ClassWorkspaceStatusScaffold extends StatelessWidget {
  const _ClassWorkspaceStatusScaffold({
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.loading = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return Scaffold(
      backgroundColor: OSColors.appBackground(dark),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: GradeFlowPanel(
              variant: GradeFlowPanelVariant.stage,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading)
                    const SizedBox.square(
                      dimension: 34,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  else
                    Icon(
                      Icons.class_outlined,
                      size: 42,
                      color: OSColors.textSubtle(dark),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: OSColors.textPrimary(dark),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: OSColors.textSubtle(dark),
                    ),
                  ),
                  if (!loading) ...[
                    const SizedBox(height: 18),
                    GradeFlowActionChip(
                      label: 'Back to home',
                      icon: Icons.arrow_back_rounded,
                      onPressed: onBack,
                      emphasized: true,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClassWorkspaceHero extends StatelessWidget {
  const _ClassWorkspaceHero({
    required this.classId,
    required this.className,
    required this.subject,
    required this.onBack,
    required this.onOpenFullView,
  });

  final String classId;
  final String className;
  final String subject;
  final VoidCallback onBack;
  final VoidCallback onOpenFullView;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final studentCount = context
        .watch<StudentService>()
        .students
        .where((s) => s.classId == classId)
        .length;

    return GradeFlowPanel(
      variant: GradeFlowPanelVariant.stage,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Classes / $className',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: OSColors.textSubtle(dark),
                  ),
                ),
              ),
              GradeFlowActionChip(
                label: 'View full class',
                icon: Icons.open_in_new_rounded,
                onPressed: onOpenFullView,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                iconSize: 18,
                color: OSColors.textSubtle(dark),
                style: IconButton.styleFrom(
                  minimumSize: const Size(36, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          className,
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.2,
                            color: OSColors.textPrimary(dark),
                          ),
                        ),
                        Text(
                          subject,
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1.0,
                            color: OSColors.blueSoft,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      children: const [
                        _MetaItem(label: 'Term 2'),
                        _MetaItem(label: 'Live now', accent: OSColors.green),
                        _MetaItem(label: 'Class OS workspace'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              GradeFlowMetricPill(
                icon: Icons.people_alt_outlined,
                label: 'Students',
                value: '$studentCount',
                accent: OSColors.blue,
              ),
              const GradeFlowMetricPill(
                icon: Icons.check_circle_outline,
                label: 'Attendance',
                value: '92%',
                accent: OSColors.green,
              ),
              const GradeFlowMetricPill(
                icon: Icons.insights_outlined,
                label: 'Class average',
                value: '84.3',
                accent: OSColors.cyan,
              ),
              const GradeFlowMetricPill(
                icon: Icons.assignment_turned_in_outlined,
                label: 'Activities',
                value: '12',
                accent: OSColors.indigo,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.label, this.accent});

  final String label;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final color = accent ?? OSColors.textSubtle(dark);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 8, color: color.withValues(alpha: 0.9)),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: color,
          ),
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

double _classWorkspaceBottomPadding() {
  return 24;
}

class _ClassWorkspaceTabBar extends StatelessWidget {
  const _ClassWorkspaceTabBar({
    required this.tabs,
    required this.controller,
    required this.dark,
  });

  final List<_TabDef> tabs;
  final TabController controller;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color:
            OSColors.panelSurface(dark).withValues(alpha: dark ? 0.72 : 0.86),
        borderRadius: OSRadius.xlBr,
        border: Border.all(
          color: OSColors.panelBorder(dark).withValues(alpha: dark ? 0.7 : 0.8),
          width: 1,
        ),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        indicator: BoxDecoration(
          color: OSColors.blue.withValues(alpha: dark ? 0.26 : 0.18),
          borderRadius: OSRadius.lgBr,
          border: Border.all(
            color: OSColors.blue.withValues(alpha: dark ? 0.36 : 0.26),
            width: 1,
          ),
        ),
        labelColor: OSColors.textPrimary(dark),
        unselectedLabelColor: OSColors.textSubtle(dark),
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        tabs: tabs
            .map(
              (t) => Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(t.icon, size: 16),
                    const SizedBox(width: 7),
                    Text(t.label),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ClassOverviewTab extends StatelessWidget {
  const _ClassOverviewTab({
    required this.classId,
    required this.className,
    required this.subject,
  });

  final String classId;
  final String className;
  final String subject;

  String get _gradebookRoute => AppRoutes.osClassGradebook(classId);
  String get _seatingRoute => AppRoutes.osClassSeating(classId);
  String get _studentsRoute => AppRoutes.osClassStudents(classId);
  String get _exportRoute => AppRoutes.osClassExport(classId);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1220;
        final medium = constraints.maxWidth >= 900;
        final pad = constraints.maxWidth < 860 ? 12.0 : 16.0;

        final mainColumn = const _OverviewMainColumn();
        final rail = _OverviewInsightRail(
          className: className,
          onGradebook: () => context.go(_gradebookRoute),
          onSeating: () => context.go(_seatingRoute),
          onStudents: () => context.go(_studentsRoute),
          onExport: () => context.go(_exportRoute),
        );

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            pad,
            2,
            pad,
            _classWorkspaceBottomPadding(),
          ),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 8, child: mainColumn),
                    const SizedBox(width: 14),
                    Expanded(flex: 4, child: rail),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (medium)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: mainColumn),
                          const SizedBox(width: 14),
                          Expanded(flex: 5, child: rail),
                        ],
                      )
                    else ...[
                      mainColumn,
                      const SizedBox(height: 12),
                      rail,
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _OverviewMainColumn extends StatelessWidget {
  const _OverviewMainColumn();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _LessonFlowPanel(),
        SizedBox(height: 12),
        _UpcomingTasksPanel(),
        SizedBox(height: 12),
        _LiveActivityPanel(),
      ],
    );
  }
}

class _LessonFlowPanel extends StatelessWidget {
  const _LessonFlowPanel();

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    const rows = [
      _FlowRow('10:00 AM', 'Do now', 'Quick check-in and review of homework',
          '10 min', 'Now'),
      _FlowRow('10:10 AM', 'Lesson', 'Linear equations in two variables',
          '20 min', 'In progress'),
      _FlowRow('10:30 AM', 'Guided practice',
          'Work through examples as a class', '15 min', 'Upcoming'),
      _FlowRow('10:45 AM', 'Independent practice',
          'Problem set: apply and solve', '15 min', 'Upcoming'),
      _FlowRow('11:00 AM', 'Wrap up', 'Exit ticket and key takeaways', '10 min',
          'Upcoming'),
    ];

    return GradeFlowPanel(
      variant: GradeFlowPanelVariant.tool,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GradeFlowSectionHeader(
            title: 'Today\'s lesson flow',
            subtitle: '10:00 AM - 60 min lesson',
          ),
          const SizedBox(height: 10),
          for (final row in rows) ...[
            _TimelineRow(row: row),
            if (row != rows.last) const SizedBox(height: 8),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Classroom sequence is ready',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: OSColors.textSubtle(dark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowRow {
  const _FlowRow(
      this.time, this.title, this.detail, this.duration, this.status);

  final String time;
  final String title;
  final String detail;
  final String duration;
  final String status;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.row});

  final _FlowRow row;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final statusColor = switch (row.status) {
      'Now' => OSColors.amber,
      'In progress' => OSColors.blue,
      _ => OSColors.textFaint(dark),
    };

    return GradeFlowPanel(
      variant: GradeFlowPanelVariant.whisper,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.time,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: OSColors.textPrimary(dark),
                  ),
                ),
                Text(
                  row.duration,
                  style: TextStyle(
                    fontSize: 12,
                    color: OSColors.textSubtle(dark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: OSColors.textPrimary(dark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  row.detail,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: OSColors.textSubtle(dark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: dark ? 0.2 : 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: statusColor.withValues(alpha: dark ? 0.35 : 0.24),
                width: 1,
              ),
            ),
            child: Text(
              row.status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingTasksPanel extends StatelessWidget {
  const _UpcomingTasksPanel();

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    const rows = [
      _TaskRow('Quiz 6: Systems of Equations', 'Due May 2, 11:59 PM',
          '18 / 28 submitted', OSColors.indigo),
      _TaskRow('Problem Set 6.2', 'Due May 7, 11:59 PM', 'Not started',
          OSColors.green),
      _TaskRow(
          'Unit 6 Test', 'May 14, 10:00 AM', 'Not started', OSColors.coral),
    ];

    return GradeFlowPanel(
      variant: GradeFlowPanelVariant.tool,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GradeFlowSectionHeader(title: 'Upcoming tasks'),
          const SizedBox(height: 10),
          for (final row in rows) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: OSColors.panelSurface(dark)
                    .withValues(alpha: dark ? 0.52 : 0.82),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: OSColors.panelBorder(dark).withValues(alpha: 0.7),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: row.color.withValues(alpha: dark ? 0.25 : 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.assignment_outlined,
                        size: 16, color: row.color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: OSColors.textPrimary(dark),
                          ),
                        ),
                        Text(
                          row.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: OSColors.textSubtle(dark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    row.status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: OSColors.textSubtle(dark),
                    ),
                  ),
                ],
              ),
            ),
            if (row != rows.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _TaskRow {
  const _TaskRow(this.title, this.subtitle, this.status, this.color);

  final String title;
  final String subtitle;
  final String status;
  final Color color;
}

class _LiveActivityPanel extends StatelessWidget {
  const _LiveActivityPanel();

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    const rows = [
      'Jayden C. submitted Quiz 5',
      'Ava L. answered Q4 correctly',
      '5 students need help on Q3',
    ];

    return GradeFlowPanel(
      variant: GradeFlowPanelVariant.tool,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GradeFlowSectionHeader(title: 'Live class activity'),
          const SizedBox(height: 10),
          for (final row in rows) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: OSColors.panelSurface(dark)
                    .withValues(alpha: dark ? 0.52 : 0.82),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: OSColors.panelBorder(dark).withValues(alpha: 0.7),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 8, color: OSColors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      row,
                      style: TextStyle(
                        fontSize: 13,
                        color: OSColors.textPrimary(dark),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Now',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: OSColors.textSubtle(dark),
                    ),
                  ),
                ],
              ),
            ),
            if (row != rows.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _OverviewInsightRail extends StatelessWidget {
  const _OverviewInsightRail({
    required this.className,
    required this.onGradebook,
    required this.onSeating,
    required this.onStudents,
    required this.onExport,
  });

  final String className;
  final VoidCallback onGradebook;
  final VoidCallback onSeating;
  final VoidCallback onStudents;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return Column(
      children: [
        GradeFlowPanel(
          variant: GradeFlowPanelVariant.tool,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              GradeFlowSectionHeader(title: 'Class health'),
              SizedBox(height: 12),
              _HealthRow(label: 'Engagement', value: 0.78),
              SizedBox(height: 8),
              _HealthRow(label: 'Assignment completion', value: 0.82),
              SizedBox(height: 8),
              _HealthRow(label: 'On-track', value: 0.86),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GradeFlowPanel(
          variant: GradeFlowPanelVariant.tool,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              GradeFlowSectionHeader(title: 'Notices'),
              SizedBox(height: 10),
              _NoticeCard(
                icon: Icons.info_outline,
                iconColor: OSColors.blue,
                title: 'Midterm review sessions',
                detail: 'May 6 and May 7 after school in Room 204.',
              ),
              SizedBox(height: 8),
              _NoticeCard(
                icon: Icons.warning_amber_rounded,
                iconColor: OSColors.amber,
                title: 'Unit 6 Test',
                detail: 'May 14 at 10:00 AM. Calculator permitted.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GradeFlowPanel(
          variant: GradeFlowPanelVariant.tool,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GradeFlowSectionHeader(title: 'Quick launch'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  GradeFlowActionChip(
                    label: 'Gradebook',
                    icon: Icons.menu_book_rounded,
                    onPressed: onGradebook,
                    emphasized: true,
                  ),
                  GradeFlowActionChip(
                    label: 'Seating',
                    icon: Icons.event_seat_rounded,
                    onPressed: onSeating,
                  ),
                  GradeFlowActionChip(
                    label: 'Students',
                    icon: Icons.people_rounded,
                    onPressed: onStudents,
                  ),
                  GradeFlowActionChip(
                    label: 'Export',
                    icon: Icons.file_download_outlined,
                    onPressed: onExport,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$className workspace tools are one tap away.',
                style: TextStyle(
                  fontSize: 12,
                  color: OSColors.textSubtle(dark),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final pct = (value * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: OSColors.textPrimary(dark),
                ),
              ),
            ),
            Text(
              '$pct%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: OSColors.textSubtle(dark),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            minHeight: 6,
            value: value,
            backgroundColor:
                OSColors.panelBorder(dark).withValues(alpha: dark ? 0.35 : 0.5),
            valueColor: const AlwaysStoppedAnimation<Color>(OSColors.green),
          ),
        ),
      ],
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color:
            OSColors.panelSurface(dark).withValues(alpha: dark ? 0.52 : 0.82),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: OSColors.panelBorder(dark).withValues(alpha: 0.7),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: OSColors.textPrimary(dark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: OSColors.textSubtle(dark),
                  ),
                ),
              ],
            ),
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
    final dark = context.isDark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bottomPadding = _classWorkspaceBottomPadding();
        final minHeight = constraints.maxHeight > bottomPadding + 24
            ? constraints.maxHeight - bottomPadding - 24
            : 0.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: OSColors.blue.withValues(alpha: 0.12),
                      borderRadius: OSRadius.lgBr,
                    ),
                    child: Icon(icon, color: OSColors.blue, size: 30),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: OSColors.text(dark),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: OSColors.textSecondary(dark),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: onTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: OSColors.blue,
                        borderRadius: OSRadius.pillBr,
                      ),
                      child: Text(
                        action,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
