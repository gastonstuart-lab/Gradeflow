import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradeflow/models/user.dart';
import 'package:gradeflow/providers/app_providers.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/teacher_appearance_controller.dart';
import 'package:gradeflow/widgets/teacher_account_menu.dart';

class _SampleAuth extends AuthService {
  @override
  bool get isAuthenticated => true;

  @override
  User? get currentUser => User(
    userId: 'fictional-test',
    email: 'demo@example.test',
    fullName: 'Sample Teacher',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

void main() {
  testWidgets('top account menu offers appearance, sign out and identity',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = _SampleAuth();
    final appearance = TeacherAppearanceController();
    final theme = ThemeModeNotifier();

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: auth),
        ChangeNotifierProvider<TeacherAppearanceController>.value(
            value: appearance),
        ChangeNotifierProvider<ThemeModeNotifier>.value(value: theme),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Center(child: TeacherAccountMenu()),
        ),
      ),
    ));

    await tester.tap(find.byKey(const Key('teacher-account-settings-button')));
    await tester.pumpAndSettle();
    expect(find.text('Sample Teacher'), findsOneWidget);
    expect(find.text('Appearance & colours'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);

    await tester.tap(find.text('Appearance & colours'));
    await tester.pumpAndSettle();
    expect(find.text('Choose your colours'), findsOneWidget);
    expect(find.text('Neon boxes'), findsOneWidget);
    await tester.tap(find.text('Neon boxes'));
    await tester.pumpAndSettle();
    expect(appearance.background, 'boxes');
    await tester.ensureVisible(find.text('Advanced options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Advanced options'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Background intensity'), findsOneWidget);
    expect(find.text('Sign out'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
    appearance.dispose();
    theme.dispose();
  });

  testWidgets('signing out requires confirmation and allows cancellation',
      (tester) async {
    final auth = _SampleAuth();
    await tester.pumpWidget(ChangeNotifierProvider<AuthService>.value(
      value: auth,
      child: const MaterialApp(
        home: Scaffold(body: Center(child: TeacherAccountMenu())),
      ),
    ));

    await tester.tap(find.byKey(const Key('teacher-account-settings-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out of GradeFlow?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out of GradeFlow?'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
  });
}
