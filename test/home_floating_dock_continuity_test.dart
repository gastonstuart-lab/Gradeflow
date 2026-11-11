import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/components/home/teacher_home_presentation.dart';
import 'package:gradeflow/os/gradeflow_os_shell.dart';
import 'package:gradeflow/os/os_controller.dart';
import 'package:gradeflow/os/os_dock.dart';
import 'package:gradeflow/os/os_palette.dart';
import 'package:gradeflow/providers/app_providers.dart';
import 'package:gradeflow/theme.dart';

void main() {
  testWidgets('only Home fills the space behind the floating OS dock',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = GradeFlowOSController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GradeFlowOSController>.value(value: controller),
          ChangeNotifierProvider<ThemeModeNotifier>(
            create: (_) => ThemeModeNotifier(),
          ),
        ],
        child: MaterialApp(
          theme: lightTheme,
          home: GradeFlowOSShell(
            child: const Scaffold(
              body: SizedBox.expand(key: ValueKey('full-page-probe')),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(OSDock), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('full-page-probe'))).height,
        closeTo(900, 1));

    // Other routed surfaces keep their established content reservation.
    controller.setSurface(OSSurface.planner);
    await tester.pump();
    expect(find.byType(OSDock), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('full-page-probe'))).height,
        closeTo(
          900 - OSSpacing.dockHeight - OSSpacing.dockBottomMargin,
          1,
        ));
  });

  testWidgets('approved Home scroll inset clears the floating OS dock',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: lightTheme,
      home: Scaffold(
        body: TeacherHomePresentation(
          teacherName: 'Test teacher',
          now: DateTime(2026, 11, 11),
          header: const Text('Header'),
          classCard: const SizedBox(height: 400, child: Text('Class')),
          shortcuts: const SizedBox(height: 400, child: Text('Tools')),
          calendar: const Text('Calendar'),
          reminders: const Text('Reminders'),
          footer: const Text('End of Home'),
        ),
      ),
    ));
    final scroll = tester.widget<SingleChildScrollView>(
      find.descendant(
        of: find.byType(TeacherHomePresentation),
        matching: find.byType(SingleChildScrollView),
      ),
    );
    final padding = scroll.padding!.resolve(TextDirection.ltr);
    expect(
      padding.bottom,
      greaterThanOrEqualTo(
        24 + OSSpacing.dockHeight + OSSpacing.dockBottomMargin,
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
