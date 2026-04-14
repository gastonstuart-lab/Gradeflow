/// GradeFlow OS — Class Surface
///
/// The focused single-class workspace.  When a teacher opens a class from
/// the OS, this surface becomes the active context with the class always
/// pinned at the top.
///
/// Structure:
///   - Class header (name, subject, student count, quick stats)
///   - Tab bar: Overview | Gradebook | Seating | Students | Export
///   - Each tab routes to the existing screen embedded in this surface

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/os/os_controller.dart';
import 'package:gradeflow/os/os_palette.dart';
import 'package:gradeflow/nav.dart';
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
    _TabDef(icon: Icons.menu_book_rounded, label: 'Gradebook'),
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

    // Tell the OS controller which class is active
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
      // Cold OS entry can arrive before class providers have been hydrated.
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

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final classService = context.watch<ClassService>();
    final classModel = classService.classes
        .where((c) => c.classId == widget.classId)
        .firstOrNull;
    if (classModel == null && _hydrating) {
      return Scaffold(
        backgroundColor: OSColors.bg(dark),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    final className = classModel?.className ?? 'Class';
    final subject = classModel?.subject ?? '';

    return Scaffold(
      backgroundColor: OSColors.bg(dark),
      body: Column(
        children: [
          // ── Class Header ────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: _ClassHeader(
              classId: widget.classId,
              className: className,
              subject: subject,
              onBack: () {
                context
                    .read<GradeFlowOSController>()
                    .setSurface(OSSurface.home);
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.osHome);
                }
              },
            ),
          ),

          // ── Tab Bar ─────────────────────────────────────────────────────
          _ClassTabBar(tabs: _tabDefs, controller: _tabs, dark: dark),

          // ── Tab Body ─────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                // Tab 0: Overview
                _ClassOverviewTab(
                  classId: widget.classId,
                  className: className,
                  onNavigate: (route) => context.push(route),
                ),
                // Tab 1: Gradebook
                _ClassToolTab(
                  icon: Icons.menu_book_rounded,
                  title: 'Gradebook',
                  description: 'Manage scores, grade items, and assessments.',
                  action: 'Open Gradebook',
                  onTap: () => context.go(
                    '${AppRoutes.classDetail}/${widget.classId}/gradebook',
                  ),
                ),
                // Tab 2: Seating
                _ClassToolTab(
                  icon: Icons.event_seat_rounded,
                  title: 'Seating',
                  description: 'Assign seats and configure room layout.',
                  action: 'Open Seating',
                  onTap: () => context.go(
                    '${AppRoutes.classDetail}/${widget.classId}/seating',
                  ),
                ),
                // Tab 3: Students
                _ClassToolTab(
                  icon: Icons.people_rounded,
                  title: 'Students',
                  description: 'View and manage student records.',
                  action: 'Open Students',
                  onTap: () => context.go(
                    '${AppRoutes.classDetail}/${widget.classId}/students',
                  ),
                ),
                // Tab 4: Export
                _ClassToolTab(
                  icon: Icons.picture_as_pdf_rounded,
                  title: 'Export',
                  description: 'Export grades as PDF or CSV.',
                  action: 'Open Export',
                  onTap: () => context.go(
                    '${AppRoutes.classDetail}/${widget.classId}/export',
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

// ─────────────────────────────────────────────────────────────────────────────
// CLASS HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _ClassHeader extends StatelessWidget {
  const _ClassHeader({
    required this.classId,
    required this.className,
    required this.subject,
    required this.onBack,
  });

  final String classId;
  final String className;
  final String subject;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final studentService = context.watch<StudentService>();
    final studentCount =
        studentService.students.where((s) => s.classId == classId).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
      decoration: BoxDecoration(
        color: OSColors.surface(dark),
        border: Border(
          bottom: BorderSide(color: OSColors.border(dark), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            iconSize: 18,
            color: OSColors.textSecondary(dark),
            style: IconButton.styleFrom(minimumSize: const Size(36, 36)),
          ),
          const SizedBox(width: 4),

          // Class avatar
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: OSColors.green.withValues(alpha: 0.14),
              borderRadius: OSRadius.mdBr,
            ),
            child: Icon(Icons.class_rounded, color: OSColors.green, size: 20),
          ),
          const SizedBox(width: 10),

          // Class name + info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  className,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: OSColors.text(dark),
                    letterSpacing: -0.3,
                  ),
                ),
                if (subject.isNotEmpty || studentCount > 0)
                  Text(
                    [
                      if (subject.isNotEmpty) subject,
                      if (studentCount > 0) '$studentCount students',
                    ].join(' · '),
                    style: TextStyle(
                      fontSize: 11,
                      color: OSColors.textSecondary(dark),
                    ),
                  ),
              ],
            ),
          ),

          // More actions
          IconButton(
            onPressed: () => context.go(
              '${AppRoutes.classDetail}/$classId',
            ),
            icon: const Icon(Icons.open_in_new_rounded),
            iconSize: 18,
            color: OSColors.textSecondary(dark),
            tooltip: 'Open full class view',
            style: IconButton.styleFrom(minimumSize: const Size(36, 36)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB BAR
// ─────────────────────────────────────────────────────────────────────────────

class _TabDef {
  const _TabDef({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _ClassTabBar extends StatelessWidget {
  const _ClassTabBar({
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
      height: 44,
      color: OSColors.surface(dark),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: OSColors.blue,
        unselectedLabelColor: OSColors.textSecondary(dark),
        indicatorColor: OSColors.blue,
        indicatorWeight: 2,
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        tabs: tabs
            .map(
              (t) => Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(t.icon, size: 15),
                    const SizedBox(width: 5),
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

// ─────────────────────────────────────────────────────────────────────────────
// TAB BODIES
// ─────────────────────────────────────────────────────────────────────────────

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
    final dark = context.isDark;
    final studentService = context.watch<StudentService>();
    final studentCount =
        studentService.students.where((s) => s.classId == classId).length;

    final tools = [
      _ClassToolLink(
        icon: Icons.menu_book_rounded,
        label: 'Gradebook',
        color: OSColors.coral,
        route: '${AppRoutes.classDetail}/$classId/gradebook',
      ),
      _ClassToolLink(
        icon: Icons.event_seat_rounded,
        label: 'Seating',
        color: OSColors.amber,
        route: '${AppRoutes.classDetail}/$classId/seating',
      ),
      _ClassToolLink(
        icon: Icons.people_rounded,
        label: 'Students',
        color: OSColors.green,
        route: '${AppRoutes.classDetail}/$classId/students',
      ),
      _ClassToolLink(
        icon: Icons.picture_as_pdf_rounded,
        label: 'Export',
        color: OSColors.cyan,
        route: '${AppRoutes.classDetail}/$classId/export',
      ),
      _ClassToolLink(
        icon: Icons.grade_rounded,
        label: 'Final Results',
        color: OSColors.indigo,
        route: '${AppRoutes.classDetail}/$classId/results',
      ),
      _ClassToolLink(
        icon: Icons.folder_open_rounded,
        label: 'Full View',
        color: OSColors.blue,
        route: '${AppRoutes.classDetail}/$classId',
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats row
          Row(
            children: [
              _StatChip(
                label: '$studentCount',
                sublabel: 'Students',
                icon: Icons.people_rounded,
                color: OSColors.green,
              ),
              const SizedBox(width: 10),
              _StatChip(
                label: 'Open',
                sublabel: 'Status',
                icon: Icons.check_circle_rounded,
                color: OSColors.blue,
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Tools grid
          Text(
            'Class Tools',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: OSColors.textSecondary(dark),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: tools
                .map(
                  (t) => GestureDetector(
                    onTap: () => context.go(t.route),
                    child: Container(
                      width: 88,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: OSColors.surface(dark),
                        borderRadius: OSRadius.lgBr,
                        border: Border.all(
                          color: OSColors.border(dark),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: t.color.withValues(alpha: 0.14),
                              borderRadius: OSRadius.mdBr,
                            ),
                            child: Icon(t.icon, color: t.color, size: 20),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            t.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: OSColors.textSecondary(dark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
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
    required this.color,
    required this.route,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String route;
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.color,
  });

  final String label;
  final String sublabel;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: OSRadius.lgBr,
        border: Border.all(color: color.withValues(alpha: 0.20), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: OSColors.text(dark),
                  height: 1,
                ),
              ),
              Text(
                sublabel,
                style: TextStyle(
                  fontSize: 10,
                  color: OSColors.textSecondary(dark),
                ),
              ),
            ],
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
    );
  }
}
