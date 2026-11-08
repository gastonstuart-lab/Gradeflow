import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/models/seating_layout.dart';
import 'package:gradeflow/os/surfaces/classroom_surface.dart';
import 'package:gradeflow/components/home/approved_teacher_home.dart';
import 'package:gradeflow/screens/native_gradebook_screen.dart';
import 'package:gradeflow/repositories/repository_factory.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/services/seating_service.dart';
import 'package:gradeflow/theme.dart';

/// Standalone public preview. It does NOT boot the full GradeFlow application,
/// Firebase, sign-in, student imports or any production service.
const _classId = 'synthetic-public-classroom-preview';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  RepositoryFactory.useLocal();
  await SharedPreferences.getInstance();

  final classes = ClassService();
  final students = StudentService();
  final seating = SeatingService();
  final existing = await RepositoryFactory.instance.loadClasses();
  if (!existing.any((c) => c.classId == _classId)) {
    final now = DateTime(2026, 11, 8);
    await classes.addClass(Class(
      classId: _classId,
      className: 'Sample Science Classroom',
      subject: 'Synthetic demo — no real pupils',
      schoolYear: '2026',
      term: 'Demo',
      teacherId: 'synthetic-demo-only',
      createdAt: now,
      updatedAt: now,
    ));
  } else {
    await classes.loadClasses('synthetic-demo-only');
  }

  await students.loadStudents(_classId);
  if (students.students.isEmpty) {
    final names = [
      ('Alex', 'Review', '測試一'),
      ('Bella', 'Review', '測試二'),
      ('Chloe', 'Review', '測試三'),
      ('Daniel', 'Review', '測試四'),
      ('Emma', 'Review', '測試五'),
      ('Finn', 'Review', '測試六'),
      ('Grace', 'Review', '測試七'),
      ('Henry', 'Review', '測試八'),
    ];
    final now = DateTime(2026, 11, 8);
    await students.addStudents([
      for (var i = 0; i < names.length; i++)
        Student(
          studentId: 'preview-student-${i + 1}',
          chineseName: names[i].$3,
          englishFirstName: names[i].$1,
          englishLastName: names[i].$2,
          seatNo: '${i + 1}',
          classId: _classId,
          createdAt: now,
          updatedAt: now,
        ),
    ]);
  }

  await seating.loadRoomSetups();
  await seating.loadLayouts(_classId, studentCount: students.students.length);
  var layout = seating.activeLayout(_classId)!;
  if (layout.tables.isEmpty) {
    await seating.addTable(_classId, SeatingTableType.rectangular, seatCount: 4);
    await seating.addTable(_classId, SeatingTableType.round, seatCount: 4);
    layout = seating.activeLayout(_classId)!;
    for (var i = 0; i < layout.tables.length; i++) {
      final table = layout.tables[i];
      await seating.moveTable(_classId, table.tableId,
          (i == 0 ? 360.0 : 760.0) - table.x,
          (i == 0 ? 300.0 : 420.0) - table.y);
    }
    layout = seating.activeLayout(_classId)!;
    for (var i = 0; i < students.students.length && i < layout.seats.length; i++) {
      await seating.assignStudentToSeat(
          _classId, layout.seats[i].seatId, students.students[i].studentId);
    }
  }

  // All routes here are preview-only. Never invoke the application router or
  // production AppProviders; the repository is explicitly local-only.
  final themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);
  final previewClass = classes.getClassById(_classId)!;
  void unavailable(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$feature is not connected in this synthetic preview.'),
    ));
  }

  final presentationObserver = _PreviewPresentationObserver();
  final router = GoRouter(
    observers: [presentationObserver],
    initialLocation: '/preview/home',
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) => '/preview/home',
      ),
      GoRoute(
        path: '/preview/home',
        builder: (context, state) => Scaffold(
          body: ApprovedTeacherHome(
            teacherName: 'Demo Teacher',
            schoolName: 'Sample School · synthetic data only',
            primaryClass: previewClass,
            classes: [previewClass],
            studentCounts: {_classId: students.students.length},
            reminders: const [],
            loading: false,
            remindersAvailable: true,
            onSelectClass: (_) {},
            onOpenClassroom: () => context.go('/preview/classroom'),
            onOpenPlanner: () => context.go('/preview/planner'),
            onOpenGrades: () => context.go('/preview/gradebook'),
            onOpenStudents: () => context.go('/preview/students'),
            onOpenIedStudio: () => unavailable(context, 'IED Studio'),
            onOpenScience: () => unavailable(context, 'Science resources'),
            onMoreHomeTools: () => unavailable(context, 'Additional Home tools'),
            onToggleTheme: () => themeMode.value =
                themeMode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
            onAttention: () => unavailable(context, 'Attention centre'),
            onAssistant: () => unavailable(context, 'Assistant'),
          ),
        ),
      ),
      GoRoute(
        path: '/preview/classroom',
        builder: (context, state) => const ClassroomSurface(classId: _classId),
      ),
      GoRoute(
        path: '/preview/gradebook',
        builder: (context, state) => const NativeGradebookScreen(classId: _classId),
      ),
      GoRoute(
        path: '/preview/students',
        builder: (context, state) => Scaffold(
          appBar: AppBar(
            title: const Text('Sample students · local-only preview'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/preview/home'),
            ),
          ),
          body: ListView(
            children: [
              for (final student in students.students)
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(student.englishFullName),
                  subtitle: Text(student.chineseName),
                  trailing: Text(student.seatNo ?? ''),
                ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: '/preview/planner',
        builder: (context, state) => Scaffold(
          appBar: AppBar(
            title: const Text('Planner · preview'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/preview/home'),
            ),
          ),
          body: const Center(
            child: Text('The live Planner is not included in this local-only demo.'),
          ),
        ),
      ),
      // The recovered Classroom currently uses the production path for Back.
      // Redirect it here rather than presenting a blank page or login.
      GoRoute(
        path: '/os/classes',
        redirect: (context, state) => '/preview/home',
      ),
      GoRoute(
        path: '/os/planner',
        redirect: (context, state) => '/preview/planner',
      ),
      GoRoute(
        path: '/os/class/:classId/gradebook',
        redirect: (context, state) => '/preview/gradebook',
      ),
      GoRoute(
        path: '/os/class/:classId/students',
        redirect: (context, state) => '/preview/students',
      ),
    ],
  );

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
      ChangeNotifierProvider<ClassService>.value(value: classes),
      ChangeNotifierProvider<StudentService>.value(value: students),
      ChangeNotifierProvider<SeatingService>.value(value: seating),
    ],
    child: ValueListenableBuilder<ThemeMode>(
      valueListenable: themeMode,
      builder: (context, currentTheme, _) => MaterialApp.router(
        title: 'GradeFlow · SYNTHETIC TEACHER WORKSPACE',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: currentTheme,
        routerConfig: router,
        // A navigation bar for the *synthetic preview only*. Keep the
        // approved ClassroomSurface and its furniture geometry unchanged.
        builder: (context, navigator) => ValueListenableBuilder<bool>(
          valueListenable: presentationObserver.inPresentation,
          builder: (context, presenting, _) => AnimatedBuilder(
            animation: router.routeInformationProvider,
            builder: (context, _) {
              final path = router.routeInformationProvider.value.uri.path;
              final index = path.contains('gradebook')
                  ? 2
                  : path.contains('students')
                      ? 3
                      : path.contains('classroom')
                          ? 1
                          : 0;
              return Column(
                children: [
                  Expanded(child: navigator ?? const SizedBox.shrink()),
                  if (!presenting)
                    NavigationBar(
                      height: 65,
                      selectedIndex: index,
                      labelBehavior:
                          NavigationDestinationLabelBehavior.alwaysShow,
                      destinations: const [
                        NavigationDestination(
                            icon: Icon(Icons.home_outlined),
                            selectedIcon: Icon(Icons.home_rounded),
                            label: 'Home'),
                        NavigationDestination(
                            icon: Icon(Icons.meeting_room_outlined),
                            selectedIcon: Icon(Icons.meeting_room_rounded),
                            label: 'Classroom'),
                        NavigationDestination(
                            icon: Icon(Icons.grade_outlined),
                            selectedIcon: Icon(Icons.grade_rounded),
                            label: 'Grades'),
                        NavigationDestination(
                            icon: Icon(Icons.groups_outlined),
                            selectedIcon: Icon(Icons.groups_rounded),
                            label: 'Students'),
                      ],
                      onDestinationSelected: (next) {
                        router.go([
                          '/preview/home',
                          '/preview/classroom',
                          '/preview/gradebook',
                          '/preview/students',
                        ][next]);
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  ));
}

/// Hide preview navigation while the real Classroom presentation route
/// covers the screen; this does not modify the approved Classroom widget.
class _PreviewPresentationObserver extends NavigatorObserver {
  final ValueNotifier<bool> inPresentation = ValueNotifier<bool>(false);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute && route.settings is! Page) {
      inPresentation.value = true;
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute && route.settings is! Page) {
      inPresentation.value = false;
    }
  }
}
