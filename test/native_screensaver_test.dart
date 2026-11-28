import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/os/os_controller.dart';
import 'package:gradeflow/os/os_idle_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('screensaver preferences persist without school data', () async {
    SharedPreferences.setMockInitialValues({});
    const saved = ScreensaverPreferences(
      style: 'Ocean', clock: false, date: true, message: 'Welcome', speed: 1.5,
    );
    await saved.save();
    final loaded = await ScreensaverPreferences.load();
    expect(loaded.style, 'Ocean');
    expect(loaded.clock, false);
    expect(loaded.date, true);
    expect(loaded.message, 'Welcome');
    expect(loaded.speed, 1.5);
  });

  testWidgets('idle never starts in teaching, class or planner surfaces', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = GradeFlowOSController();
    await tester.pump();
    controller.setIdleTimeout(1);
    for (final surface in [OSSurface.teach, OSSurface.classWorkspace, OSSurface.planner]) {
      controller.setSurface(surface);
      controller.registerActivity();
      controller.triggerIdle();
      await tester.pump(const Duration(minutes: 2));
      expect(controller.idleActive, false);
    }
    controller.setSurface(OSSurface.home);
    await tester.pump(const Duration(minutes: 1));
    expect(controller.idleActive, true);
    controller.dismissIdle();
    expect(controller.idleActive, false);
    controller.dispose();
    await tester.pump();
  });

  testWidgets('projector preview displays only chosen content and dismisses', (tester) async {
    bool dismissed = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: OSIdleScreen(
      preferences: const ScreensaverPreferences(style: 'Grid', clock: false, date: false, message: 'Ready to learn'),
      onDismiss: () => dismissed = true,
    ))));
    expect(find.text('Ready to learn'), findsOneWidget);
    await tester.tap(find.byTooltip('Dismiss screensaver'));
    expect(dismissed, true);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
