import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/components/time_slot_timetable.dart';
import 'package:gradeflow/components/planner/planner_teaching_workspace.dart';
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

// Eight fictional teaching groups for this local-only, public review entrypoint.
// The identifiers and students are synthetic, never real GradeFlow records.
const _previewGroups = <({String id, String label, String subject})>[
  (id: 'synthetic-preview-eep1', label: 'EEP 1 · Demo J1', subject: 'EEP'),
  (id: 'synthetic-preview-eep3', label: 'EEP 3 · Demo J3', subject: 'EEP'),
  (id: 'synthetic-preview-eep4', label: 'EEP 4 · Demo J2', subject: 'EEP'),
  (id: 'synthetic-preview-eep5', label: 'EEP 5 · Demo J3', subject: 'EEP'),
  (id: 'synthetic-preview-sci-j1', label: 'SCI 4 · Demo J1', subject: 'Science'),
  (id: _classId, label: 'SCI 4 · Sample Classroom', subject: 'Science'),
  (id: 'synthetic-preview-sci-j2', label: 'SCI 7 · Demo J2', subject: 'Science'),
  (id: 'synthetic-preview-pa', label: 'PA 6 · Demo J2', subject: 'Performance Arts'),
];

const _previewTimes = <({int start, int end})>[
  (start: 480, end: 530),  // P1 08:00–08:50
  (start: 540, end: 590),  // P2 09:00–09:50
  (start: 600, end: 650),  // P3 10:00–10:50
  (start: 660, end: 710),  // P4 11:00–11:50
  (start: 775, end: 825),  // P5 12:55–13:45
  (start: 835, end: 885),  // P6 13:55–14:45
  (start: 895, end: 945),  // P7 14:55–15:45
  (start: 950, end: 1000), // P8 15:50–16:40
];

// (Mon=0 ... Fri=4, period=0 ... 7, synthetic group index).
// Preserves 24 individually timed periods; doubles only group visually.
final _previewLessons = <TimeSlotClass>[
  for (final slot in const <(int, int, int)>[
    (0, 0, 3), (0, 1, 3), (0, 4, 1), (0, 5, 1),
    (1, 0, 2), (1, 1, 2), (1, 2, 0), (1, 3, 0),
    (1, 4, 5), (1, 5, 5), (1, 6, 3), (1, 7, 3),
    (2, 0, 4), (2, 1, 4), (2, 6, 6), (2, 7, 6),
    (3, 2, 0), (3, 3, 0), (3, 4, 2), (3, 5, 2),
    (3, 6, 1), (3, 7, 1),
    (4, 2, 7), (4, 3, 7),
  ])
    TimeSlotClass(
      dayOfWeek: slot.$1,
      startMinutes: _previewTimes[slot.$2].start,
      endMinutes: _previewTimes[slot.$2].end,
      title: _previewGroups[slot.$3].label,
      classId: _previewGroups[slot.$3].id,
    ),
];

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

  // Bring all eight fictional groups into the same isolated local workspace.
  // The original sample Classroom remains available and retains its own seats.
  await classes.loadClasses('synthetic-demo-only');
  for (final group in _previewGroups) {
    if (classes.getClassById(group.id) != null) continue;
    await classes.addClass(Class(
      classId: group.id,
      className: group.label,
      subject: group.subject,
      teacherId: 'synthetic-demo-only',
      schoolYear: '2026',
      term: 'Demo',
      createdAt: DateTime(2026, 11, 13),
      updatedAt: DateTime(2026, 11, 13),
    ));
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
        redirect: (context, state) => '/preview/classroom/$_classId',
      ),
      GoRoute(
        path: '/preview/classroom/:classId',
        builder: (context, state) => ClassroomSurface(
          classId: state.pathParameters['classId']!,
          cleanCanvas: true,
          plannerV2: true,
        ),
      ),
      GoRoute(
        path: '/preview/gradebook',
        redirect: (context, state) => '/preview/gradebook/$_classId',
      ),
      GoRoute(
        path: '/preview/gradebook/:classId',
        builder: (context, state) => NativeGradebookScreen(
          classId: state.pathParameters['classId']!,
        ),
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
        builder: (context, state) => _SyntheticPlannerPreview(
          classes: classes.activeClasses,
        ),
      ),
      GoRoute(
        path: '/preview/class/:classId',
        builder: (context, state) {
          final classId = state.pathParameters['classId']!;
          final course = classes.getClassById(classId);
          return Scaffold(
            appBar: AppBar(
              title: const Text('Class information · synthetic preview'),
              leading: BackButton(onPressed: () => context.go('/preview/planner')),
            ),
            body: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(course?.className ?? 'Unknown fictional class',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text('Local-only demonstration. No real roster or timetable data.'),
                const SizedBox(height: 16),
                Wrap(spacing: 12, children: [
                  FilledButton(
                    onPressed: course == null
                        ? null : () => context.go('/preview/classroom/$classId'),
                    child: const Text('Open Classroom'),
                  ),
                  OutlinedButton(
                    onPressed: course == null
                        ? null : () => context.go('/preview/gradebook/$classId'),
                    child: const Text('Open Gradebook'),
                  ),
                ]),
              ],
            ),
          );
        },
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
        path: '/os/home',
        redirect: (context, state) => '/preview/home',
      ),
      GoRoute(
        path: '/os/class/:classId/classroom',
        redirect: (context, state) =>
            '/preview/classroom/${state.pathParameters['classId']}',
      ),
      GoRoute(
        path: '/os/class/:classId/gradebook',
        redirect: (context, state) =>
            '/preview/gradebook/${state.pathParameters['classId']}',
      ),
      GoRoute(
        path: '/os/class/:classId/students',
        redirect: (context, state) => '/preview/students',
      ),
      GoRoute(
        path: '/os/class/:classId',
        redirect: (context, state) =>
            '/preview/class/${state.pathParameters['classId']}',
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
                  ? 3
                  : path.contains('students')
                      ? 4
                      : path.contains('classroom')
                          ? 2
                          : path.contains('planner')
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
                            icon: Icon(Icons.calendar_today_outlined),
                            selectedIcon: Icon(Icons.calendar_today_rounded),
                            label: 'Planner'),
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
                          '/preview/planner',
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


/// Interactive Planner review inside the existing synthetic-only GradeFlow shell.
/// It exercises the production PlannerTeachingWorkspace without Firebase or
/// connecting to any real teacher/student records.
class _SyntheticPlannerPreview extends StatefulWidget {
  const _SyntheticPlannerPreview({required this.classes});

  final List<Class> classes;

  @override
  State<_SyntheticPlannerPreview> createState() =>
      _SyntheticPlannerPreviewState();
}

class _SyntheticPlannerPreviewState extends State<_SyntheticPlannerPreview> {
  DateTime _selectedDate = DateTime.now();
  bool _todayView = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planner · GradeFlow V2 review'),
        leading: BackButton(onPressed: () => context.go('/preview/home')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 56),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    const Text(
                      'SYNTHETIC REVIEW ONLY · 8 fictional groups · 24 periods · no Firebase',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('Today')),
                        ButtonSegment(value: false, label: Text('Week')),
                      ],
                      selected: {_todayView},
                      onSelectionChanged: (value) =>
                          setState(() => _todayView = value.first),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => setState(() {
                        _selectedDate = DateTime.now();
                        _todayView = true;
                      }),
                      icon: const Icon(Icons.today_outlined),
                      label: const Text('Go to today'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            PlannerTeachingWorkspace(
              lessons: _previewLessons,
              classes: widget.classes,
              date: _selectedDate,
              todayView: _todayView,
              lunch: const PlannerLunch(710, 770),
              periods: _previewTimes,
              onSelectDate: (date) => setState(() {
                _selectedDate = date;
                _todayView = true;
              }),
              onUpload: () => _unavailable('Timetable import'),
              onManage: () => _unavailable('Saved timetable versions'),
            ),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'This is an interactive review of the real Planner Week/Today '
                  'widget inside the local-only demo shell. Calendar import, '
                  'cloud sync, and real class records are intentionally not '
                  'connected. The authenticated Planner remains in PR #130.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _unavailable(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$feature is not connected in the synthetic preview.'),
    ));
  }
}
