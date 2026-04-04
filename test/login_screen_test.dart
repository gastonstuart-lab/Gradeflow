import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gradeflow/screens/login_screen.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:provider/provider.dart';

void main() {
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
    expect(find.text('Enter GradeFlow'), findsOneWidget);
    expect(find.text('Try Demo Account'), findsOneWidget);
  });
}
