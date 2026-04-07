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
        ChangeNotifierProvider(create: (_) => ClassService()),
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
        ChangeNotifierProvider(create: (_) => ThemeModeNotifier()),
      ],
      child: child,
    );
  }
}

class ThemeModeNotifier extends ChangeNotifier {
  static const String _prefsKey = 'theme_mode_v1';

  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;

  ThemeModeNotifier() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved == 'light') {
        _themeMode = ThemeMode.light;
      } else if (saved == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.dark;
      }
      notifyListeners();
    } catch (_) {
      // Fall back to dark mode if preferences are unavailable.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        _themeMode == ThemeMode.light ? 'light' : 'dark',
      );
    } catch (_) {
      // Ignore persistence failures and keep the in-memory selection.
    }
  }

  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    _persist();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
    _persist();
  }
}
