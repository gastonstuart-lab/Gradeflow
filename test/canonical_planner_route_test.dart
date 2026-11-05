import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/providers/app_providers.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AuthenticatedLocal extends AuthService {
  @override
  bool get isAuthenticated => true;
  @override
  bool get isInitialized => true;
  @override
  bool get isLoading => false;
}

void main() {
  testWidgets('old dashboard bookmark opens current Planner with its date',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = _AuthenticatedLocal();
    await tester.pumpWidget(AppProviders(
        child: ChangeNotifierProvider<AuthService>.value(
      value: auth,
      child:
          MaterialApp.router(theme: lightTheme, routerConfig: AppRouter.router),
    )));
    AppRouter.router.go('/dashboard?date=2026-12-15');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(AppRouter.router.routeInformationProvider.value.uri.path,
        '/os/planner');
    expect(find.text('Selected: 2026-12-15'), findsOneWidget);
    expect(find.text('Planning Hub'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
