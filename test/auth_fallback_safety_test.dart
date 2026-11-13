import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/models/user.dart';

Map<String, dynamic> profile(String id, String email) {
  final now = DateTime(2026, 11, 13);
  return User(userId: id, email: email, fullName: 'Synthetic teacher',
    createdAt: now, updatedAt: now).toJson();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final teacher = profile('synthetic-teacher', 'teacher@example.invalid');

  setUp(() => SharedPreferences.setMockInitialValues({
    'users': jsonEncode([teacher]),
    'current_user': jsonEncode(teacher),
    'classes': 'preserve synthetic sentinel',
  }));

  test('a cached teacher cannot log in with any supplied local password', () async {
    final auth = AuthService();
    for (final password in ['', 'wrong', 'demo']) {
      expect(await auth.login('teacher@example.invalid', password), isFalse);
    }
    expect(auth.currentUser, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('users'), jsonEncode([teacher]));
    expect(prefs.getString('classes'), 'preserve synthetic sentinel');
    auth.dispose();
  });

  test('cached profile alone cannot restore authenticated access', () async {
    final auth = AuthService();
    await auth.initialize();
    expect(auth.isAuthenticated, isFalse);
    expect(auth.isInitialized, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('current_user'), jsonEncode(teacher));
    auth.dispose();
  });

  test('demo seeding preserves existing profiles and is idempotent', () async {
    final auth = AuthService();
    await auth.seedDemoUser();
    await auth.seedDemoUser();
    final prefs = await SharedPreferences.getInstance();
    final users = jsonDecode(prefs.getString('users')!) as List;
    expect(users.first, teacher);
    expect(users.length, AuthService.demoLoginAvailable ? 2 : 1);
    expect(prefs.getString('classes'), 'preserve synthetic sentinel');
    auth.dispose();
  });

  test('only explicitly enabled demo credentials authorize a local session', () async {
    final auth = AuthService();
    await auth.seedDemoUser();
    expect(await auth.login('teacher@demo.com', 'wrong'), isFalse);
    expect(await auth.login('teacher@demo.com', 'demo'), AuthService.demoLoginAvailable);
    if (AuthService.demoLoginAvailable) {
      expect(auth.currentUser!.userId, 'demo-teacher-1');
    }
    auth.dispose();
  });
}
