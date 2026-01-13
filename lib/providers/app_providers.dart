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
        ChangeNotifierProvider(create: (_) => ThemeModeNotifier()),
      ],
      child: child,
    );
  }
}

class ThemeModeNotifier extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }
}
