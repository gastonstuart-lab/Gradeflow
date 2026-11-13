import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/widgets/branding/instructos_boxes_background.dart';
import 'package:go_router/go_router.dart';
import 'package:gradeflow/screens/login_screen.dart';
import 'package:gradeflow/theme.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:provider/provider.dart';

void main() {

  for (final brightness in Brightness.values) {
    testWidgets('sign-in backdrop copy is readable in ${brightness.name}',
        (tester) async {
      final auth = AuthService();
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, __) => const LoginScreen()),
      ]);
      addTearDown(() {
        router.dispose();
        auth.dispose();
      });
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthService>.value(
          value: auth,
          child: MaterialApp.router(
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      for (final label in [
        'More time for\nteaching.',
        'Your classes, plans and grades.\nOne familiar workspace.',
        'Teach from your classroom',
        'InstructOS',
        'Teaching, organised.',
      ]) {
        final candidate = find.text(label);
        expect(candidate, findsOneWidget);
        final style = tester.widget<Text>(candidate).style;
        expect(style?.color, isNotNull, reason: 'Missing $label text colour');
        // Each backdrop palette must use a contrasting text colour.
        // Avoid preserving bright dark-mode text over the pale light grid.
        final luminance = style!.color!.computeLuminance();
        if (brightness == Brightness.dark) {
          expect(luminance, greaterThan(0.45), reason: label);
        } else {
          expect(luminance, lessThan(0.28), reason: label);
        }
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('login screen renders wide layout without layout exceptions',
      (tester) async {
    final auth = AuthService();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) {
            return ChangeNotifierProvider<AuthService>.value(
              value: auth,
              child: const LoginScreen(),
            );
          },
        ),
      ],
    );

    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      router.dispose();
      auth.dispose();
    });

    await tester.binding.setSurfaceSize(const Size(1280, 900));

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.byType(InstructOSBoxesBackground), findsOneWidget);
    expect(find.text('InstructOS'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Open demo workspace'), findsOneWidget);
    final demo = tester.widget<TextButton>(find.ancestor(of: find.text('Open demo workspace'), matching: find.byWidgetPredicate((widget) => widget is TextButton)).first);
    expect(demo.onPressed != null, AuthService.demoLoginAvailable);
    if (!AuthService.demoLoginAvailable) {
      expect(find.text('Demo workspace is available only in the isolated review preview.'), findsOneWidget);
    }
  });
}
