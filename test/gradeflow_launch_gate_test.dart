import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/components/gradeflow_launch_experience.dart';
import 'package:gradeflow/os/gradeflow_os_shell.dart';
import 'package:gradeflow/providers/app_providers.dart';
import 'package:gradeflow/screens/teacher_dashboard_screen.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('launch gate gives routed app content tight screen constraints',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthService();
    await auth.initialize();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: auth,
        child: MaterialApp(
          builder: (context, child) => GradeFlowLaunchGate(child: child!),
          home: Scaffold(
            body: Column(
              children: const [
                Expanded(
                  child: Center(child: Text('Ready child')),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(find.text('Ready child'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('planning hub dashboard can mount inside the OS shell',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      AppProviders(
        child: MaterialApp(
          theme: darkTheme,
          home: const GradeFlowOSShell(
            child: TeacherDashboardScreen(),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Planning Hub'), findsWidgets);
    expect(find.byType(DashboardUtilityDock), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
