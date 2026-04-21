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
import 'package:gradeflow/screens/class_seating_screen.dart';
import 'package:gradeflow/screens/teacher_dashboard_screen.dart';
import 'package:gradeflow/screens/demo_dashboard_preview_screen.dart';
import 'package:gradeflow/screens/communication_hub_screen.dart';
import 'package:gradeflow/screens/admin_workspace_screen.dart';
import 'package:gradeflow/screens/teacher_whiteboard_screen.dart';
import 'package:gradeflow/components/teacher_whiteboard.dart';
import 'package:gradeflow/components/global_system_shell.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:gradeflow/screens/deleted_students_screen.dart';
import 'package:gradeflow/screens/deleted_classes_screen.dart';
import 'package:gradeflow/os/gradeflow_os_shell.dart';
import 'package:gradeflow/os/os_controller.dart';
import 'package:gradeflow/os/surfaces/home_surface.dart';
import 'package:gradeflow/os/surfaces/class_surface.dart';
import 'package:gradeflow/os/surfaces/teach_surface.dart';
import 'package:gradeflow/services/global_system_shell_service.dart';

class AppRouter {
  static String loginRedirectLocationFor(GoRouterState state) {
    return Uri(
      path: AppRoutes.home,
      queryParameters: {'from': state.uri.toString()},
    ).toString();
  }

  static String postAuthDestination(String? rawLocation) {
    return _validatedInternalAppLocation(rawLocation) ?? AppRoutes.osHome;
  }

  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.home,
    redirect: (context, state) {
      try {
        final auth = Provider.of<AuthService>(context, listen: false);
        final loggingIn = state.matchedLocation == AppRoutes.home;
        final previewing =
            kDebugMode && state.matchedLocation == AppRoutes.previewDashboard;
        debugPrint(
            'GoRouter.redirect from \'${state.matchedLocation}\' | isAuth=${auth.isAuthenticated} isInit=${auth.isInitialized} isLoading=${auth.isLoading}');
        if (!auth.isAuthenticated && !loggingIn && !previewing)
          return AppRouter.loginRedirectLocationFor(state);
        if (auth.isAuthenticated && loggingIn) {
          return AppRouter.postAuthDestination(
            state.uri.queryParameters['from'],
          );
        }
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
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: LoginScreen()),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        name: 'dashboard',
        pageBuilder: (context, state) =>
            _shellPage(state, const TeacherDashboardScreen()),
      ),
      GoRoute(
        path: AppRoutes.osHome,
        name: 'osHome',
        pageBuilder: (context, state) => _osPage(
          state,
          surface: OSSurface.home,
          child: const HomeSurface(),
        ),
      ),
      GoRoute(
        path: '${AppRoutes.osClass}/:classId',
        name: 'osClass',
        pageBuilder: (context, state) {
          final classId = state.pathParameters['classId']!;
          return _osPage(
            state,
            surface: OSSurface.classWorkspace,
            classId: classId,
            child: ClassSurface(classId: classId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.osTeach,
        name: 'osTeach',
        pageBuilder: (context, state) => _osPage(
          state,
          surface: OSSurface.teach,
          child: const TeachSurface(),
        ),
      ),
      GoRoute(
        path: AppRoutes.whiteboard,
        name: 'whiteboard',
        pageBuilder: (context, state) => _fadePage(
          TeacherWhiteboardScreen(
            controller: state.extra is TeacherWhiteboardController
                ? state.extra as TeacherWhiteboardController
                : null,
          ),
        ),
      ),
      if (kDebugMode)
        GoRoute(
          path: AppRoutes.previewDashboard,
          name: 'previewDashboard',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: DemoDashboardPreviewScreen()),
        ),
      GoRoute(
        path: AppRoutes.communication,
        name: 'communication',
        pageBuilder: (context, state) =>
            _shellPage(state, const CommunicationHubScreen()),
      ),
      GoRoute(
        path: AppRoutes.admin,
        name: 'admin',
        pageBuilder: (context, state) =>
            _shellPage(state, const AdminWorkspaceScreen()),
      ),
      GoRoute(
        path: AppRoutes.classes,
        name: 'classes',
        pageBuilder: (context, state) =>
            _shellPage(state, const ClassListScreen()),
      ),
      GoRoute(
        path: AppRoutes.classTrash,
        name: 'classTrash',
        pageBuilder: (context, state) =>
            _shellPage(state, const DeletedClassesScreen()),
      ),
      GoRoute(
        path: '${AppRoutes.classDetail}/:classId',
        name: 'classDetail',
        pageBuilder: (context, state) {
          final classId = state.pathParameters['classId']!;
          return _shellPage(
            state,
            ClassDetailScreen(classId: classId),
            classId: classId,
          );
        },
      ),
      GoRoute(
        path: '${AppRoutes.classDetail}/:classId/students',
        name: 'students',
        pageBuilder: (context, state) {
          final classId = state.pathParameters['classId']!;
          return _shellPage(
            state,
            StudentListScreen(classId: classId),
            classId: classId,
          );
        },
      ),
      GoRoute(
        path: '${AppRoutes.classDetail}/:classId/students/trash',
        name: 'studentsTrash',
        pageBuilder: (context, state) {
          final classId = state.pathParameters['classId']!;
          return _shellPage(
            state,
            DeletedStudentsScreen(classId: classId),
            classId: classId,
          );
        },
      ),
      GoRoute(
        path: '${AppRoutes.classDetail}/:classId/student/:studentId',
        name: 'studentDetail',
        pageBuilder: (context, state) {
          final classId = state.pathParameters['classId']!;
          final studentId = state.pathParameters['studentId']!;
          return _shellPage(
            state,
            StudentDetailScreen(classId: classId, studentId: studentId),
            classId: classId,
          );
        },
      ),
      GoRoute(
        path: '${AppRoutes.classDetail}/:classId/gradebook',
        name: 'gradebook',
        pageBuilder: (context, state) {
          final classId = state.pathParameters['classId']!;
          return _shellPage(
            state,
            GradebookScreen(classId: classId),
            classId: classId,
          );
        },
      ),
      GoRoute(
        path: '${AppRoutes.classDetail}/:classId/seating',
        name: 'classSeating',
        pageBuilder: (context, state) {
          final classId = state.pathParameters['classId']!;
          return _shellPage(
            state,
            ClassSeatingScreen(classId: classId),
            classId: classId,
          );
        },
      ),
      GoRoute(
        path: '${AppRoutes.classDetail}/:classId/categories',
        name: 'categories',
        pageBuilder: (context, state) {
          final classId = state.pathParameters['classId']!;
          return _shellPage(
            state,
            CategoryManagementScreen(classId: classId),
            classId: classId,
          );
        },
      ),
      GoRoute(
        path: '${AppRoutes.classDetail}/:classId/exams',
        name: 'exams',
        pageBuilder: (context, state) {
          final classId = state.pathParameters['classId']!;
          final highlightStudentId =
              state.uri.queryParameters['highlightStudentId'];
          return _shellPage(
            state,
            ExamInputScreen(
              classId: classId,
              highlightStudentId: highlightStudentId,
            ),
            classId: classId,
          );
        },
      ),
      GoRoute(
        path: '${AppRoutes.classDetail}/:classId/export',
        name: 'export',
        pageBuilder: (context, state) {
          final classId = state.pathParameters['classId']!;
          return _shellPage(
            state,
            ExportScreen(classId: classId),
            classId: classId,
          );
        },
      ),
      GoRoute(
        path: '${AppRoutes.classDetail}/:classId/results',
        name: 'results',
        pageBuilder: (context, state) {
          final classId = state.pathParameters['classId']!;
          return _shellPage(
            state,
            FinalResultsScreen(classId: classId),
            classId: classId,
          );
        },
      ),
    ],
  );
}

class AppRoutes {
  static const String home = '/';
  static const String dashboard = '/dashboard';
  static const String whiteboard = '/whiteboard';
  static const String previewDashboard = '/preview/dashboard';
  static const String communication = '/communication';
  static const String admin = '/admin';
  static const String classes = '/classes';
  static const String classTrash = '/classes/trash';
  static const String classDetail = '/class';
  // GradeFlow OS surfaces
  static const String osHome = '/os/home';
  static const String osClass = '/os/class';
  static const String osTeach = '/os/teach';
}

String? _validatedInternalAppLocation(String? rawLocation) {
  if (rawLocation == null) return null;
  final trimmed = rawLocation.trim();
  if (trimmed.isEmpty || !trimmed.startsWith('/')) {
    return null;
  }

  final parsed = Uri.tryParse(trimmed);
  // Only allow app-internal relative locations, never absolute URLs.
  if (parsed == null || parsed.hasScheme || parsed.hasAuthority) {
    return null;
  }

  final normalized = parsed.toString();
  if (!normalized.startsWith('/') || normalized.startsWith('//')) {
    return null;
  }
  return normalized;
}

CustomTransitionPage<void> _fadePage(Widget child) {
  return CustomTransitionPage<void>(
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.02, 0),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.988, end: 1.0).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

NoTransitionPage<void> _shellPage(GoRouterState state, Widget child,
    {String? classId}) {
  return NoTransitionPage<void>(
    child: _OSRouteFrame(
      location: state.uri.path,
      surface: OSSurface.other,
      classId: classId,
      child: GlobalSystemShellFrame(
        location: state.uri.path,
        showNavigationChrome: false,
        child: child,
      ),
    ),
  );
}

Page<void> _osPage(
  GoRouterState state, {
  required OSSurface surface,
  required Widget child,
  String? classId,
}) {
  return _fadePage(
    _OSRouteFrame(
      location: state.uri.path,
      surface: surface,
      classId: classId,
      child: child,
    ),
  );
}

class _OSRouteFrame extends StatefulWidget {
  const _OSRouteFrame({
    required this.location,
    required this.surface,
    required this.child,
    this.classId,
  });

  final String location;
  final OSSurface surface;
  final String? classId;
  final Widget child;

  @override
  State<_OSRouteFrame> createState() => _OSRouteFrameState();
}

class _OSRouteFrameState extends State<_OSRouteFrame> {
  @override
  void initState() {
    super.initState();
    _scheduleSync();
  }

  @override
  void didUpdateWidget(covariant _OSRouteFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surface != widget.surface ||
        oldWidget.classId != widget.classId) {
      _scheduleSync();
    }
  }

  void _scheduleSync() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context
          .read<GlobalSystemShellController>()
          .updateLocation(widget.location);
      context.read<GradeFlowOSController>().setSurface(
            widget.surface,
            classId: widget.classId,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    return GradeFlowOSShell(
      teachMode: widget.surface == OSSurface.teach,
      child: widget.child,
    );
  }
}
