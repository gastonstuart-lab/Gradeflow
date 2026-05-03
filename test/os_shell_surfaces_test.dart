import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/os/gradeflow_os_shell.dart';
import 'package:gradeflow/os/os_controller.dart';
import 'package:gradeflow/os/surfaces/home_surface.dart';
import 'package:gradeflow/os/surfaces/planner_surface.dart';
import 'package:gradeflow/providers/app_providers.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/communication_service.dart';
import 'package:gradeflow/services/global_system_shell_service.dart';
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

Widget _harness(Widget child, {GradeFlowOSController? controller}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
      ChangeNotifierProvider<ClassService>(create: (_) => ClassService()),
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
