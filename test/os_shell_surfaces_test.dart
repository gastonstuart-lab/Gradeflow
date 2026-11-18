import 'timetable_reliability_test.dart' show timetableGrid;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/os/os_dock.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/models/user.dart';
import 'package:gradeflow/os/gradeflow_os_shell.dart';
import 'package:gradeflow/os/os_controller.dart';
import 'package:gradeflow/os/surfaces/class_surface.dart';
import 'package:gradeflow/os/surfaces/home_surface.dart';
import 'package:gradeflow/os/surfaces/planner_surface.dart';
import 'package:gradeflow/providers/app_providers.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/communication_service.dart';
import 'package:gradeflow/services/global_system_shell_service.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('HomeSurface renders native OS home sections', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _harness(
        const HomeSurface(),
      ),
    );

    expect(find.text('TEACHER HOME'), findsOneWidget);
    expect(find.text('Where do you want to go?'), findsOneWidget);
    expect(find.text('Classroom'), findsOneWidget);
    expect(find.text('Whiteboard & PDF'), findsOneWidget);
    expect(find.text('Check Planner'), findsOneWidget);
    expect(find.text('Grades'), findsOneWidget);
    expect(find.text('Students'), findsOneWidget);
    expect(find.text('IED Studio'), findsOneWidget);
    expect(find.text('Science'), findsOneWidget);
    expect(find.text('More Home tools'), findsOneWidget);

    // Legacy Home utilities are deliberately demoted from the default view.
    expect(find.text('COMMAND CENTER'), findsNothing);
    expect(find.text('PINNED APPS'), findsNothing);
    expect(find.text('DAILY SIGNALS'), findsNothing);
    expect(find.text('Teacher launchpad'), findsNothing);
    expect(find.text('Create a class to begin staging teaching tools.'),
        findsNothing);
  });

  testWidgets('HomeSurface Ask InstructOS stays calm and scoped',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _harness(
        const HomeSurface(),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('More Home tools'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask InstructOS').first);
    await tester.pumpAndSettle();

    expect(find.text('Ask InstructOS'), findsWidgets);
    expect(find.text('What can I help you with today?'), findsOneWidget);
    expect(find.text('Prepare class'), findsOneWidget);
    expect(find.text('Make quiz'), findsOneWidget);
    expect(find.text('Draft note'), findsOneWidget);
    expect(find.text('Calm lesson'), findsOneWidget);
    expect(find.textContaining('Using Home context'), findsNothing);
    expect(find.textContaining('Context limits'), findsNothing);
    expect(find.textContaining('Suggestions are drafts'), findsNothing);
    expect(find.textContaining('Ready -'), findsNothing);
    expect(find.text('Help me prepare today\'s class'), findsNothing);
    expect(find.text('Summarise what needs attention'), findsNothing);
    expect(find.text('Draft a progress note'), findsNothing);
    expect(find.text('Turn this into a quick quiz'), findsNothing);
    expect(find.text('Suggest a seating adjustment'), findsNothing);
  });

  testWidgets('PlannerSurface exposes planning upload entry points',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      _harness(
        const PlannerSurface(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Weekly timetable'), findsOneWidget);
    expect(find.text('Import calendar'), findsOneWidget);
    expect(find.text('Import timetable'), findsOneWidget);
    expect(find.text('Class schedules and assessments'), findsNothing);
    expect(find.text('Where do uploads go?'), findsNothing);
  });

  testWidgets(
      'PlannerSurface waits for restored auth before loading scoped data',
      (tester) async {
    final user = User(
      userId: 'teacher-restored',
      email: 'teacher@example.com',
      fullName: 'Restored Teacher',
      schoolName: 'Pilot School',
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
    );
    final auth = _RestoredTestAuth(user);
    SharedPreferences.setMockInitialValues({
      'current_user': jsonEncode(user.toJson()),
      'dashboard_reminders_v1:local': jsonEncode([
        {
          'text': 'Local-only reminder should not hydrate first',
          'timestamp': DateTime(2026, 5, 2).toIso8601String(),
          'done': false,
        }
      ]),
      'dashboard_reminders_v1:teacher-restored': jsonEncode([
        {
          'text': 'Restored user reminder',
          // The new Agenda correctly excludes events months in the past.
          // Test authenticated scoping with a genuinely upcoming entry.
          'timestamp': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
          'done': false,
        }
      ]),
      'dashboard_timetables_v1:local': jsonEncode([
        {
          'id': 'local-table',
          'name': 'Local-only timetable',
          'base64': '',
          'grid': [
            ['Time', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
            ['08:00', 'Local-only class block'],
          ],
          'uploadedAt': DateTime(2026, 5, 2).toIso8601String(),
        }
      ]),
      'dashboard_timetables_v1:teacher-restored': jsonEncode([
        {
          'id': 'restored-table',
          'name': 'Restored timetable',
          'base64': '',
          'grid': [
            ['Time', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
            ['08:00-08:50', 'Restored timetable class block', '', '', '', ''],
          ],
          'uploadedAt': DateTime(2026, 5, 3).toIso8601String(),
        }
      ]),
      'dashboard_selected_timetable_v1:teacher-restored': 'restored-table',
    });
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      _harness(
        const PlannerSurface(),
        auth: auth,
      ),
    );
    await tester.pump();

    expect(find.text('Local-only reminder should not hydrate first'),
        findsNothing);
    expect(find.text('Restored user reminder'), findsNothing);
    expect(find.text('Local-only class block'), findsNothing);
    expect(find.text('Restored timetable class block'), findsNothing);

    await auth.initialize();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('Local-only reminder should not hydrate first'),
        findsNothing);
    // The same upcoming reminder appears in Agenda and Coming up, both scoped
    // to the restored teacher's account.
    expect(find.text('Restored user reminder'), findsWidgets);
    expect(find.text('Local-only class block'), findsNothing);
    expect(find.text('Restored timetable class block'), findsOneWidget);
  });

  testWidgets('ClassSurface keeps deep links loading while auth restores',
      (tester) async {
    final user = User(
      userId: 'teacher-restored',
      email: 'teacher@example.com',
      fullName: 'Restored Teacher',
      schoolName: 'Pilot School',
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
    );
    final auth = AuthService();
    SharedPreferences.setMockInitialValues({
      'current_user': jsonEncode(user.toJson()),
    });
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      _harness(
        const ClassSurface(classId: 'class-deep-link'),
        auth: auth,
      ),
    );
    await tester.pump();

    expect(find.text('Loading class workspace'), findsOneWidget);
    expect(find.text('Class not found'), findsNothing);

    await auth.initialize();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('Loading class workspace'), findsNothing);
    expect(find.text('Class not found'), findsOneWidget);
  });

  testWidgets('GradeFlowOSShell shows one overlay at a time', (tester) async {
    final controller = GradeFlowOSController();
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _harness(
        GradeFlowOSShell(
          child: const Scaffold(body: SizedBox.expand()),
        ),
        controller: controller,
      ),
    );

    controller.openLauncher();
    await tester.pump(const Duration(milliseconds: 420));
    expect(controller.launcherOpen, isTrue);
    expect(controller.shadeOpen, isFalse);
    expect(controller.assistantOpen, isFalse);

    controller.openAssistant();
    await tester.pump(const Duration(milliseconds: 420));
    expect(controller.launcherOpen, isFalse);
    expect(controller.shadeOpen, isFalse);
    expect(controller.assistantOpen, isTrue);
  });

  testWidgets('GradeFlowOSShell keeps desktop child taps interactive', (
    tester,
  ) async {
    final controller = GradeFlowOSController();
    var taps = 0;
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _harness(
        GradeFlowOSShell(
          child: Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => taps++,
                child: const Text('Open workspace'),
              ),
            ),
          ),
        ),
        controller: controller,
      ),
    );

    await tester.tap(find.text('Open workspace'));
    await tester.pump();

    expect(taps, 1);
  });
  testWidgets(
      'Home dock wins over Science shortcut underneath at desktop viewport',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var scienceHubTaps = 0;
    final controller = GradeFlowOSController();
    addTearDown(controller.dispose);
    final router = GoRouter(
      initialLocation: AppRoutes.osHome,
      routes: [
        GoRoute(
          path: AppRoutes.osHome,
          builder: (context, state) => GradeFlowOSShell(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: 160,
                  width: 900,
                  child: Material(
                    child: InkWell(
                      key: const Key('science-hub-below-dock'),
                      onTap: () => scienceHubTaps++,
                      child: const Center(child: Text('Science Hub')),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.osClasses,
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Classes destination'))),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
          ChangeNotifierProvider<ClassService>(create: (_) => ClassService()),
          ChangeNotifierProvider<StudentService>(
              create: (_) => StudentService()),
          ChangeNotifierProvider<CommunicationService>(
              create: (_) => CommunicationService()),
          ChangeNotifierProvider<GlobalSystemShellController>(
              create: (_) => GlobalSystemShellController()),
          ChangeNotifierProvider<GradeFlowOSController>.value(
              value: controller),
          ChangeNotifierProvider<ThemeModeNotifier>(
              create: (_) => ThemeModeNotifier()),
        ],
        child: MaterialApp.router(
          theme: darkTheme,
          routerConfig: router,
        ),
      ),
    );
    // The OS contains continuously animated surfaces. Pump a bounded frame
    // rather than using pumpAndSettle, which need not ever become idle.
    await tester.pump(const Duration(milliseconds: 250));

    final science = tester.getRect(
        find.byKey(const Key('science-hub-below-dock')));
    final dock = tester.getRect(find.byType(OSDock));
    // Home deliberately extends behind the floating dock to keep its full
    // background. This synthetic Science tile REALLY overlaps the pill;
    // hit testing, not clipping/shortening Home, must stop click-through.
    expect(science.bottom, closeTo(900, 1.0));
    expect(science.contains(dock.center), isTrue);

    // A tap on the visible pill's padding must not reach the Science card.
    await tester.tapAt(Offset(dock.left + 6, dock.center.dy));
    await tester.pump();
    expect(scienceHubTaps, 0);

    // Click near the TOP edge of the Classes dock tile, where its animated
    // icon card used to have unpainted vertical margins. That area must
    // belong to Classes too, not to Science Hub behind it.
    final classesIcon = tester.getRect(find.byTooltip('Classes'));
    await tester.tapAt(Offset(classesIcon.center.dx, classesIcon.top + 3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Classes destination'), findsOneWidget);
    expect(scienceHubTaps, 0);
  });

  testWidgets('Planner switches among Week Month Agenda and Tasks without leaving the page',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(
      PlannerSurface(initialDate: DateTime(2026, 12, 15)),
    ));
    await tester.pump();

    expect(find.byKey(const ValueKey('planner-view-picker')), findsOneWidget);
    expect(find.byKey(const ValueKey('planner-week-date-2026-12-15')), findsOneWidget);
    expect(find.text('Selected: 2026-12-15'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('planner-week-date-2026-12-16')));
    await tester.pump();
    expect(find.text('Selected: 2026-12-16'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('planner-view-month')));
    await tester.pump();
    expect(find.text('Dec 2026'), findsOneWidget);
    expect(find.text('Selected: 2026-12-16'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('planner-view-agenda')));
    await tester.pump();
    expect(find.text('Nothing scheduled in the next 30 days.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('planner-view-tasks')));
    await tester.pump();
    expect(find.text('No unfinished tasks. Select a day to add one.'),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('planner-view-week')));
    await tester.pump();
    expect(find.text('Selected: 2026-12-16'), findsOneWidget);
  });

  testWidgets('Planner week navigation crosses month and year boundaries',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(
      PlannerSurface(initialDate: DateTime(2026, 12, 31)),
    ));
    await tester.pump();
    expect(find.byKey(const ValueKey('planner-week-date-2027-01-01')),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('planner-next-week')));
    await tester.pump();
    expect(find.byKey(const ValueKey('planner-week-date-2027-01-07')),
        findsOneWidget);
    expect(find.text('Jan 2027'), findsOneWidget);
    expect(find.text('Selected: 2027-01-07'), findsOneWidget);
  });

  testWidgets('Planner accepts the date selected on Home', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
        _harness(PlannerSurface(initialDate: DateTime(2026, 12, 15))));
    await tester.pump();
    expect(find.text('Selected: 2026-12-15'), findsOneWidget);
    expect(find.text('Dec 2026'), findsOneWidget);
  });
  testWidgets('Today reuses selected-day tasks and school events', (tester) async {
    final user = User(userId: 'planner-today', email: 'synthetic@example.invalid',
      fullName: 'Synthetic teacher', createdAt: DateTime(2026), updatedAt: DateTime(2026));
    SharedPreferences.setMockInitialValues({
      'current_user': jsonEncode(user.toJson()),
      'dashboard_timetables_v1:planner-today': jsonEncode([{
        'id': 'weekly', 'name': 'Synthetic weekly timetable', 'selected': true,
        'base64': '', 'uploadedAt': '2026-11-13T00:00:00', 'grid': timetableGrid(),
      }]),
      'dashboard_reminders_v1:planner-today': jsonEncode([
        {'text': 'Prepare synthetic lesson', 'timestamp': '2026-12-15T09:00:00', 'kind': 'task', 'done': false},
        {'text': 'Synthetic school event', 'timestamp': '2026-12-15T10:00:00', 'kind': 'school_event', 'done': false},
        {'text': 'Other day event', 'timestamp': '2026-12-16T10:00:00', 'kind': 'school_event', 'done': false},
      ]),
    });
    final auth = _RestoredTestAuth(user);
    addTearDown(auth.dispose);
    await auth.initialize();
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_harness(PlannerSurface(initialDate: DateTime(2026, 12, 15)), auth: auth));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.textContaining('Lunch'), findsNWidgets(5));
    expect(find.text('15:45'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('planner-view-today')));
    await tester.pump();
    expect(find.text('Teaching today'), findsOneWidget);
    expect(find.text('Prepare synthetic lesson'), findsWidgets);
    expect(find.text('Synthetic school event'), findsWidgets);
    expect(find.text('Other day event'), findsNothing);
    expect(tester.takeException(), isNull);
  });

}

Widget _harness(
  Widget child, {
  GradeFlowOSController? controller,
  AuthService? auth,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthService>.value(value: auth ?? AuthService()),
      ChangeNotifierProvider<ClassService>(create: (_) => ClassService()),
      ChangeNotifierProvider<StudentService>(create: (_) => StudentService()),
      ChangeNotifierProvider<CommunicationService>(
        create: (_) => CommunicationService(),
      ),
      ChangeNotifierProvider<GlobalSystemShellController>(
        create: (_) => GlobalSystemShellController(),
      ),
      ChangeNotifierProvider<GradeFlowOSController>(
        create: (_) => controller ?? GradeFlowOSController(),
      ),
      ChangeNotifierProvider<ThemeModeNotifier>(
        create: (_) => ThemeModeNotifier(),
      ),
    ],
    child: MaterialApp(
      theme: darkTheme,
      home: child,
    ),
  );
}

// Scoped Planner tests model an already verified identity explicitly. A cached
// current_user profile is data, never proof of Firebase authentication (#128).
class _RestoredTestAuth extends AuthService {
  _RestoredTestAuth(this.user);
  final User user;
  bool _restored = false;

  @override
  bool get isInitialized => _restored;
  @override
  bool get isLoading => !_restored;
  @override
  bool get isAuthenticated => _restored;
  @override
  User? get currentUser => _restored ? user : null;

  @override
  Future<void> initialize() async {
    _restored = true;
    notifyListeners();
  }
}
