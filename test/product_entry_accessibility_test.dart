import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/screens/login_screen.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
        'entry stays usable at phone width with enlarged text in ${brightness.name}',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, __) => const LoginScreen())
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ChangeNotifierProvider(
          create: (_) => AuthService(),
          child: MaterialApp.router(
              theme: brightness == Brightness.light ? lightTheme : darkTheme,
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(1.4)),
                  child: child!))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Sign in'));
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Please enter your email'), findsWidgets);
      final password = find.widgetWithText(TextField, 'Password');
      expect(tester.widget<TextField>(password).obscureText, isTrue);
      await tester.ensureVisible(find.byTooltip('Show password'));
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(tester.widget<TextField>(password).obscureText, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
  test('shared primary and body colours meet readable contrast in both themes',
      () {
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
    }

    for (final theme in [lightTheme, darkTheme]) {
      expect(contrast(theme.colorScheme.primary, theme.colorScheme.onPrimary),
          greaterThanOrEqualTo(4.5));
      expect(contrast(theme.colorScheme.onSurface, theme.colorScheme.surface),
          greaterThanOrEqualTo(7));
    }
  });
}
