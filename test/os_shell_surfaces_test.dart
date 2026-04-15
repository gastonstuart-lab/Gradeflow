import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/os/gradeflow_os_shell.dart';
import 'package:gradeflow/os/os_controller.dart';
import 'package:gradeflow/os/surfaces/home_surface.dart';
import 'package:gradeflow/providers/app_providers.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/communication_service.dart';
import 'package:gradeflow/services/global_system_shell_service.dart';
import 'package:gradeflow/theme.dart';

void main() {
  testWidgets('HomeSurface renders native OS home sections', (tester) async {
    await tester.pumpWidget(
      _harness(
        const HomeSurface(),
      ),
    );

    expect(find.text('HOME STAGE'), findsOneWidget);
    expect(find.text('PINNED APPS'), findsOneWidget);
    expect(find.text('OTHER WORKSPACES'), findsOneWidget);
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
