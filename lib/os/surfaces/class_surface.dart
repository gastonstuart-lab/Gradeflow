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
import 'package:gradeflow/config/instructos_design.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/os/os_controller.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/student_service.dart';

class ClassSurface extends StatefulWidget {
  const ClassSurface({super.key, required this.classId});

  final String classId;

  @override
  State<ClassSurface> createState() => _ClassSurfaceState();
}

class _ClassSurfaceState extends State<ClassSurface> {
  bool _hydrating = false;
  String? _lastHydrationUserId;

  @override
  void initState() {
    super.initState();
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
      _lastHydrationUserId = null;
      setState(() {
        _hydrating =
            context.read<ClassService>().getClassById(widget.classId) == null;
      });
      _scheduleHydration();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthService>(context);
    if (!auth.isInitialized || auth.isLoading) {
      if (!_hydrating &&
          context.read<ClassService>().getClassById(widget.classId) == null) {
        _hydrating = true;
      }
      return;
    }

    final userId = auth.currentUser?.userId ?? 'local';
    if (_lastHydrationUserId == userId) return;
    _lastHydrationUserId = userId;
    _scheduleHydration();
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

    if (!auth.isInitialized || auth.isLoading) {
      if (mounted && !_hydrating) {
        setState(() => _hydrating = true);
      }
      return;
    }

    try {
      _lastHydrationUserId = auth.currentUser?.userId ?? 'local';
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

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ClassService>();
    final item = service.getClassById(widget.classId);
    if (item == null)
      return Scaffold(
          body: SafeArea(
              child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_hydrating) const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(_hydrating ? 'Loading class workspace' : 'Class not found'),
        const SizedBox(height: 16),
        TextButton(
            onPressed: () => context.go(AppRoutes.osClasses),
            child: const Text('Back to classes'))
      ]))));
    final count = context
        .watch<StudentService>()
        .students
        .where((s) => s.classId == widget.classId)
        .length;
    final tools =
        <({IconData icon, String label, String detail, String route})>[
      (
        icon: Icons.meeting_room_outlined,
        label: 'Classroom',
        detail: 'Room map, student picking and quick scores',
        route: AppRoutes.osClassroom(widget.classId)
      ),
      (
        icon: Icons.menu_book_outlined,
        label: 'Gradebook',
        detail: 'Assessments, scores and Excel export',
        route: AppRoutes.osClassGradebook(widget.classId)
      ),
      (
        icon: Icons.people_outline,
        label: 'Students',
        detail: 'Roster and student records',
        route: AppRoutes.osClassStudents(widget.classId)
      ),
      (
        icon: Icons.event_note_outlined,
        label: 'Class plan',
        detail: 'Schedule and syllabus',
        route: AppRoutes.osClassSchedule(widget.classId)
      ),
      (
        icon: Icons.description_outlined,
        label: 'Exams',
        detail: 'Review and enter exam scores',
        route: AppRoutes.osClassExams(widget.classId)
      ),
      (
        icon: Icons.assessment_outlined,
        label: 'Results',
        detail: 'Review calculated class outcomes',
        route: AppRoutes.osClassResults(widget.classId)
      ),
      (
        icon: Icons.download_outlined,
        label: 'Reports & export',
        detail: 'Prepare files and printable reports',
        route: AppRoutes.osClassExport(widget.classId)
      ),
      (
        icon: Icons.tune_outlined,
        label: 'Grading settings',
        detail: 'Review categories and weights',
        route: AppRoutes.osClassCategories(widget.classId)
      ),
    ];
    return Scaffold(
        backgroundColor: InstructOSDesign.background(context),
        body: SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                      gradient: InstructOSDesign.header,
                                      borderRadius: BorderRadius.circular(24)),
                                  child: Row(children: [
                                    IconButton(
                                        tooltip: 'Back to classes',
                                        onPressed: () =>
                                            context.go(AppRoutes.osClasses),
                                        icon: const Icon(Icons.arrow_back,
                                            color: Colors.white)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Text(item.className,
                                              style: const TextStyle(
                                                  fontSize: 28,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white)),
                                          const SizedBox(height: 4),
                                          Text(
                                              '${item.subject} · ${item.schoolYear} ${item.term} · $count students',
                                              style: const TextStyle(
                                                  color: Colors.white70))
                                        ]))
                                  ])),
                              const SizedBox(height: 24),
                              Text('What do you need for this class?',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 16),
                              LayoutBuilder(builder: (context, size) {
                                final columns = size.maxWidth < 650
                                    ? 1
                                    : size.maxWidth < 1000
                                        ? 2
                                        : 3;
                                return Wrap(
                                    spacing: 16,
                                    runSpacing: 16,
                                    children: [
                                      for (final tool in tools)
                                        SizedBox(
                                            width: (size.maxWidth -
                                                    16 * (columns - 1)) /
                                                columns,
                                            child: Card(
                                                child: InkWell(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                    onTap: () =>
                                                        context.go(tool.route),
                                                    child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(22),
                                                        child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Icon(tool.icon,
                                                                  color: Theme.of(
                                                                          context)
                                                                      .colorScheme
                                                                      .primary,
                                                                  size: 27),
                                                              const SizedBox(
                                                                  height: 18),
                                                              Text(tool.label,
                                                                  style: Theme.of(
                                                                          context)
                                                                      .textTheme
                                                                      .titleMedium
                                                                      ?.copyWith(
                                                                          fontWeight:
                                                                              FontWeight.w700)),
                                                              const SizedBox(
                                                                  height: 6),
                                                              Text(tool.detail,
                                                                  style: TextStyle(
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurfaceVariant,
                                                                      height:
                                                                          1.4)),
                                                              const SizedBox(
                                                                  height: 8)
                                                            ])))))
                                    ]);
                              }),
                            ]))))));
  }
}
