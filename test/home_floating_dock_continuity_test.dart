import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/components/home/teacher_home_presentation.dart';
import 'package:gradeflow/os/gradeflow_os_shell.dart';
import 'package:gradeflow/os/os_controller.dart';
import 'package:gradeflow/os/os_dock.dart';
import 'package:gradeflow/os/os_palette.dart';
import 'package:gradeflow/widgets/teacher_appearance_overlay.dart';
import 'package:gradeflow/providers/app_providers.dart';
import 'package:gradeflow/theme.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/services/communication_service.dart';
import 'package:gradeflow/services/global_system_shell_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Home backdrop fills viewport; other surfaces clear floating dock',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = GradeFlowOSController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
          ChangeNotifierProvider<ClassService>(create: (_) => ClassService()),
          ChangeNotifierProvider<StudentService>(create: (_) => StudentService()),
          ChangeNotifierProvider<CommunicationService>(
              create: (_) => CommunicationService()),
          ChangeNotifierProvider<GlobalSystemShellController>(
              create: (_) => GlobalSystemShellController()),
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
    // Home's SCROLLABLE PAINTED background continues all the way to the
    // bottom. An independent opaque hit shield protects the dock zone.
    // This removes the 84px empty footer while allowing the Home scroll
    // inset to expose its final buttons above the dock.
    expect(tester.getSize(find.byKey(const ValueKey('full-page-probe'))).height,
        closeTo(900, 1));
    expect(tester.getSize(find.byType(TeacherAppearanceOverlay)).height,
        closeTo(900, 1));
    final dock = tester.getRect(find.byType(OSDock));
    expect(dock.height, closeTo(OSSpacing.dockHeight, 1));
    expect(dock.bottom, closeTo(900 - OSSpacing.dockBottomMargin, 1));
    expect(OSSpacing.dockHeight + OSSpacing.dockBottomMargin,
        lessThanOrEqualTo(64));

    // Other routed surfaces retain the same protected content reservation.
    controller.setSurface(OSSurface.planner);
    await tester.pump();
    expect(find.byType(OSDock), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('full-page-probe'))).height,
        closeTo(
          900 - OSSpacing.dockHeight - OSSpacing.dockBottomMargin,
          1,
        ));

    // The account menu now lives only in the approved Home header, so
    // Classroom and detail pages no longer reserve its old 64px top band.
    // All non-Home surfaces still reserve space for the floating dock.
    for (final surface in [OSSurface.classWorkspace, OSSurface.other]) {
      controller.setSurface(surface);
      await tester.pump();
      expect(find.byType(OSDock), findsOneWidget);
      expect(tester.getSize(find.byKey(const ValueKey('full-page-probe'))).height,
          closeTo(
            900 - OSSpacing.dockHeight - OSSpacing.dockBottomMargin,
            1,
          ));
    }
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
