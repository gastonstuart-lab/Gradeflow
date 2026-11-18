import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradeflow/models/user.dart';
import 'package:gradeflow/providers/app_providers.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/teacher_appearance_controller.dart';

class _FakeTeacherAuth extends AuthService {
  User? teacher;

  @override
  bool get isAuthenticated => teacher != null;

  @override
  User? get currentUser => teacher;

  void signInAs(String id) {
    teacher = User(
      userId: id,
      email: '$id@example.test',
      fullName: id,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }

  void signOut() => teacher = null;
}

Future<void> _flushPreferences() async {
  // SharedPreferences is asynchronous even when its test storage is in memory.
  await Future<void>.delayed(const Duration(milliseconds: 20));
}

void main() {
  test('individual teachers retain different colour modes on one device',
      () async {
    SharedPreferences.setMockInitialValues({
      'theme_mode_v2_teacher_a': 'dark',
      'theme_mode_v2_teacher_b': 'light',
    });
    final auth = _FakeTeacherAuth();
    final theme = ThemeModeNotifier();

    auth.signInAs('teacher_a');
    theme.syncAuth(auth);
    await _flushPreferences();
    expect(theme.themeMode, ThemeMode.dark);

    auth.signInAs('teacher_b');
    theme.syncAuth(auth);
    await _flushPreferences();
    expect(theme.themeMode, ThemeMode.light);

    auth.signInAs('teacher_a');
    theme.syncAuth(auth);
    await _flushPreferences();
    expect(theme.themeMode, ThemeMode.dark);

    theme.dispose();
    auth.dispose();
  });

  test('custom colours are restored independently for signed-in teachers',
      () async {
    SharedPreferences.setMockInitialValues({
      'teacher_appearance_v1_teacher_a_accent': 'custom',
      'teacher_appearance_v1_teacher_a_custom_accent': '#FFB800',
      'teacher_appearance_v1_teacher_b_accent': 'teal',
    });
    final auth = _FakeTeacherAuth();
    final appearance = TeacherAppearanceController();
    auth.signInAs('teacher_a');
    appearance.syncAuth(auth);
    await _flushPreferences();
    expect(appearance.accent, 'custom');
    expect(TeacherAppearanceController.toHex(appearance.accentColor),
        '#FFB800');

    auth.signInAs('teacher_b');
    appearance.syncAuth(auth);
    await _flushPreferences();
    expect(appearance.accent, 'teal');

    auth.signInAs('teacher_a');
    appearance.syncAuth(auth);
    await _flushPreferences();
    expect(TeacherAppearanceController.toHex(appearance.accentColor),
        '#FFB800');
    appearance.dispose();
    auth.dispose();
  });

  test('background selections are isolated by authenticated teacher',
      () async {
    SharedPreferences.setMockInitialValues({
      'teacher_appearance_v1_teacher_a_background': 'boxes',
      'teacher_appearance_v1_teacher_b_background': 'dots',
      'teacher_appearance_v1_teacher_a_teach_mode': true,
    });
    final auth = _FakeTeacherAuth();
    final appearance = TeacherAppearanceController();

    auth.signInAs('teacher_a');
    appearance.syncAuth(auth);
    await _flushPreferences();
    expect(appearance.background, 'boxes');
    expect(appearance.showInTeachMode, true);

    auth.signInAs('teacher_b');
    appearance.syncAuth(auth);
    await _flushPreferences();
    expect(appearance.background, 'dots');
    expect(appearance.showInTeachMode, false);

    auth.signOut();
    appearance.syncAuth(auth);
    expect(appearance.background, 'minimal');
    expect(appearance.showInTeachMode, false);

    appearance.dispose();
    auth.dispose();
  });
}
