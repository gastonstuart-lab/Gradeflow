import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

    expect(find.text('COMMAND CENTER'), findsOneWidget);
    expect(find.text('PINNED APPS'), findsOneWidget);
    expect(find.text('Today'), findsWidgets);
    expect(find.text('Classes'), findsWidgets);
    expect(find.text('Tasks'), findsWidgets);
    expect(find.text('Messages'), findsWidgets);
    expect(find.text('Data Inbox'), findsWidgets);
    expect(find.text('Import data'), findsOneWidget);
    expect(find.text('Insights'), findsWidgets);
    expect(find.text('Create a class to begin staging teaching tools.'),
        findsNothing);
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
    expect(find.text('Weekly Timetable'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
    expect(find.text('Upload'), findsOneWidget);
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
    final auth = AuthService();
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
          'timestamp': DateTime(2026, 5, 3).toIso8601String(),
          'done': false,
        }
      ]),
      'dashboard_timetables_v1:local': jsonEncode([
        {
          'id': 'local-table',
          'name': 'Local-only timetable',
          'base64': '',
          'grid': [
            ['Time', 'Monday'],
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
            ['Time', 'Monday'],
            ['08:00', 'Restored timetable class block'],
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
    expect(find.text('Restored user reminder'), findsOneWidget);
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
