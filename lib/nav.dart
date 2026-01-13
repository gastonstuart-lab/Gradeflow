import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/screens/login_screen.dart';
import 'package:gradeflow/screens/class_list_screen.dart';
import 'package:gradeflow/screens/class_detail_screen.dart';
import 'package:gradeflow/screens/student_list_screen.dart';
import 'package:gradeflow/screens/student_detail_screen.dart';
import 'package:gradeflow/screens/gradebook_screen.dart';
import 'package:gradeflow/screens/category_management_screen.dart';
import 'package:gradeflow/screens/exam_input_screen.dart';
import 'package:gradeflow/screens/export_screen.dart';
import 'package:gradeflow/screens/final_results_screen.dart';
import 'package:gradeflow/screens/teacher_dashboard_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:gradeflow/screens/deleted_students_screen.dart';
import 'package:gradeflow/screens/deleted_classes_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.home,
    redirect: (context, state) {
      try {
        final auth = Provider.of<AuthService>(context, listen: false);
        final loggingIn = state.matchedLocation == AppRoutes.home;
        debugPrint('GoRouter.redirect from \'${state.matchedLocation}\' | isAuth=${auth.isAuthenticated} isInit=${auth.isInitialized} isLoading=${auth.isLoading}');
        if (!auth.isAuthenticated && !loggingIn) return AppRoutes.home;
        if (auth.isAuthenticated && loggingIn) return AppRoutes.dashboard;
      } catch (e) {
        debugPrint('GoRouter.redirect error: $e');
        return null; // fail open to avoid blank screen
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        pageBuilder: (context, state) => const NoTransitionPage(child: LoginScreen()),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        name: 'dashboard',
        pageBuilder: (context, state) => const NoTransitionPage(child: TeacherDashboardScreen()),
      ),
      GoRoute(
        path: AppRoutes.classes,
        name: 'classes',
        pageBuilder: (context, state) => const NoTransitionPage(child: ClassListScreen()),
      ),
      GoRoute(
        path: AppRoutes.classTrash,
        name: 'classTrash',
        pageBuilder: (context, state) => const NoTransitionPage(child: DeletedClassesScreen()),
      ),
      GoRoute(
        path: '${AppRoutes.classDetail}/:classId',
        name: 'classDetail',
        pageBuilder: (context, state) {
          final classId = state.pathParameters['classId']!;
          return NoTransitionPage(child: ClassDetailScreen(classId: classId));
        },
      ),
      GoRoute(
        path: '${AppRoutes.classDetail}/:classId/students',
        name: 'students',
        pageBuilder: (context, state) {
          final classId = state.pathParameters['classId']!;
          return NoTransitionPage(child: StudentListScreen(classId: classId));
        },
      ),
      GoRoute(
        path: '${AppRoutes.classDetail}/:classId/students/trash',
        name: 'studentsTrash',
        pageBuilder: (context, state) {
          final classId = state.pathParameters['classId']!;
          return NoTransitionPage(child: DeletedStudentsScreen(classId: classId));
        },
      ),
      GoRoute(
        path: '${AppRoutes.classDetail}/:classId/student/:studentId',
        name: 'studentDetail',
        pageBuilder: (context, state) {
          final classId = state.pathParameters['classId']!;
          final studentId = state.pathParameters['studentId']!;
          return NoTransitionPage(child: StudentDetailScreen(classId: classId, studentId: studentId));
        },
      ),
      GoRoute(
        path: '${AppRoutes.classDetail}/:classId/gradebook',
        name: 'gradebook',
        pageBuilder: (context, state) {
          final classId = state.pathParameters['classId']!;
          return NoTransitionPage(child: GradebookScreen(classId: classId));
        },
      ),
      GoRoute(
        path: '${AppRoutes.classDetail}/:classId/categories',
        name: 'categories',
        pageBuilder: (context, state) {
          final classId = state.pathParameters['classId']!;
          return NoTransitionPage(child: CategoryManagementScreen(classId: classId));
        },
      ),
      GoRoute(
        path: '${AppRoutes.classDetail}/:classId/exams',
        name: 'exams',
        pageBuilder: (context, state) {
          final classId = state.pathParameters['classId']!;
          final highlightStudentId = state.uri.queryParameters['highlightStudentId'];
          return NoTransitionPage(child: ExamInputScreen(classId: classId, highlightStudentId: highlightStudentId));
        },
      ),
      GoRoute(
        path: '${AppRoutes.classDetail}/:classId/export',
        name: 'export',
        pageBuilder: (context, state) {
          final classId = state.pathParameters['classId']!;
          return NoTransitionPage(child: ExportScreen(classId: classId));
        },
      ),
      GoRoute(
        path: '${AppRoutes.classDetail}/:classId/results',
        name: 'results',
        pageBuilder: (context, state) {
          final classId = state.pathParameters['classId']!;
          return NoTransitionPage(child: FinalResultsScreen(classId: classId));
        },
      ),
    ],
  );
}

class AppRoutes {
  static const String home = '/';
  static const String dashboard = '/dashboard';
  static const String classes = '/classes';
  static const String classTrash = '/classes/trash';
  static const String classDetail = '/class';
}
