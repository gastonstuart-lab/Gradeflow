import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/services/grading_category_service.dart';
import 'package:gradeflow/services/grade_item_service.dart';
import 'package:gradeflow/services/student_score_service.dart';
import 'package:gradeflow/services/final_exam_service.dart';
import 'package:gradeflow/services/grading_template_service.dart';
import 'package:gradeflow/services/student_trash_service.dart';
import 'package:gradeflow/services/class_trash_service.dart';
import 'package:gradeflow/services/google_auth_service.dart';
import 'package:gradeflow/services/google_drive_service.dart';
import 'package:gradeflow/services/pilot_feedback_service.dart';
import 'package:gradeflow/services/seating_service.dart';
import 'package:gradeflow/services/communication_service.dart';
import 'package:gradeflow/services/global_system_shell_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradeflow/os/os_controller.dart';
import 'package:gradeflow/services/teacher_appearance_controller.dart';

class AppProviders extends StatelessWidget {
  final Widget child;

  const AppProviders({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => GoogleAuthService()),
        ChangeNotifierProxyProvider<GoogleAuthService, AuthService>(
          create: (_) => AuthService(),
          update: (_, googleAuth, auth) {
            auth ??= AuthService();
            auth.setGoogleAuthService(googleAuth);
            return auth;
          },
        ),
        ChangeNotifierProxyProvider<AuthService, CommunicationService>(
          create: (_) => CommunicationService(),
          update: (_, auth, service) {
            service ??= CommunicationService();
            service.syncAuth(auth);
            return service;
          },
        ),
        ChangeNotifierProxyProvider<AuthService, GlobalSystemShellController>(
          create: (_) => GlobalSystemShellController(),
          update: (_, auth, controller) {
            controller ??= GlobalSystemShellController();
            controller.syncAuth(auth);
            return controller;
          },
        ),
        ChangeNotifierProvider(create: (_) => GradeFlowOSController()),
        ProxyProvider<GoogleAuthService, GoogleDriveService>(
          update: (_, auth, __) => GoogleDriveService(authService: auth),
        ),
        ChangeNotifierProxyProvider<AuthService, ClassService>(
          create: (_) => ClassService(),
          update: (_, auth, service) {
            service ??= ClassService();
            service.syncAuth(auth);
            return service;
          },
        ),
        ChangeNotifierProvider(create: (_) => StudentService()),
        ChangeNotifierProvider(create: (_) => GradingCategoryService()),
        ChangeNotifierProvider(create: (_) => GradeItemService()),
        ChangeNotifierProvider(create: (_) => StudentScoreService()),
        ChangeNotifierProvider(create: (_) => FinalExamService()),
        ChangeNotifierProvider(create: (_) => GradingTemplateService()),
        ChangeNotifierProvider(create: (_) => StudentTrashService()),
        ChangeNotifierProvider(create: (_) => ClassTrashService()),
        ChangeNotifierProvider(create: (_) => SeatingService()),
        ChangeNotifierProvider(create: (_) => PilotFeedbackService()),
        ChangeNotifierProxyProvider<AuthService, ThemeModeNotifier>(
          create: (_) => ThemeModeNotifier(),
          update: (_, auth, mode) {
            mode ??= ThemeModeNotifier();
            mode.syncAuth(auth);
            return mode;
          },
        ),
        ChangeNotifierProxyProvider<AuthService, TeacherAppearanceController>(
          create: (_) => TeacherAppearanceController(),
          update: (_, auth, appearance) {
            appearance ??= TeacherAppearanceController();
            appearance.syncAuth(auth);
            return appearance;
          },
        ),
      ],
      child: child,
    );
  }
}

class ThemeModeNotifier extends ChangeNotifier {
  static const String _legacyKey = 'theme_mode_v1';
  static const String _scopedPrefix = 'theme_mode_v2_';

  ThemeMode _themeMode = ThemeMode.light;
  String? _teacherId;
  int _generation = 0;

  ThemeMode get themeMode => _themeMode;

  ThemeModeNotifier() {
    _loadLegacy();
  }

  /// Switch accounts without carrying one teacher's appearance to another.
  void syncAuth(AuthService auth) {
    final id = auth.isAuthenticated
        ? (auth.currentUser?.userId ?? 'local')
        : null;
    if (id == _teacherId) return;
    _teacherId = id;
    final generation = ++_generation;
    _themeMode = ThemeMode.light;
    notifyListeners();
    if (id != null) {
      _loadScoped(id, generation);
    } else {
      _loadLegacy(generation);
    }
  }

  static ThemeMode _parse(String? saved) {
    if (saved == 'dark') return ThemeMode.dark;
    if (saved == 'system') return ThemeMode.system;
    return ThemeMode.light;
  }

  Future<void> _loadLegacy([int? generation]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_legacyKey);
      if (_teacherId != null ||
          (generation != null && generation != _generation)) return;
      _themeMode = _parse(saved);
      notifyListeners();
    } catch (_) {
      // Light mode remains available if local storage is blocked.
    }
  }

  Future<void> _loadScoped(String id, int generation) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('$_scopedPrefix$id');
      if (_teacherId != id || generation != _generation) return;
      _themeMode = _parse(saved);
      notifyListeners();
    } catch (_) {
      // A new teacher always gets an independent, readable default.
    }
  }

  Future<void> _persist() async {
    final id = _teacherId;
    final mode = _themeMode == ThemeMode.light
        ? 'light'
        : _themeMode == ThemeMode.system ? 'system' : 'dark';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        id == null ? _legacyKey : '$_scopedPrefix$id',
        mode,
      );
    } catch (_) {
      // Keep the immediate selection even if persistence is blocked.
    }
  }

  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    _persist();
  }

  void setThemeMode(ThemeMode mode) {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    _persist();
  }
}
