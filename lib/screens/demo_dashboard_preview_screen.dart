import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/screens/teacher_dashboard_screen.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/demo_data_service.dart';
import 'package:gradeflow/services/final_exam_service.dart';
import 'package:gradeflow/services/grade_item_service.dart';
import 'package:gradeflow/services/grading_category_service.dart';
import 'package:gradeflow/services/student_score_service.dart';
import 'package:gradeflow/services/student_service.dart';

class DemoDashboardPreviewScreen extends StatefulWidget {
  const DemoDashboardPreviewScreen({super.key});

  @override
  State<DemoDashboardPreviewScreen> createState() =>
      _DemoDashboardPreviewScreenState();
}

class _DemoDashboardPreviewScreenState
    extends State<DemoDashboardPreviewScreen> {
  bool _isBootstrapping = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapPreview();
    });
  }

  Future<void> _bootstrapPreview() async {
    final auth = context.read<AuthService>();
    try {
      if (!auth.isAuthenticated) {
        await auth.seedDemoUser();
        final success = await auth.login('teacher@demo.com', 'demo');
        if (!success) {
          throw StateError('Demo login failed.');
        }
      }

      final user = auth.currentUser;
      if (DemoDataService.isDemoUser(user)) {
        await DemoDataService.ensureDemoWorkspace(
          teacherId: user!.userId,
          classService: context.read<ClassService>(),
          studentService: context.read<StudentService>(),
          categoryService: context.read<GradingCategoryService>(),
          gradeItemService: context.read<GradeItemService>(),
          scoreService: context.read<StudentScoreService>(),
          examService: context.read<FinalExamService>(),
        );
      }

      if (!mounted) return;
      setState(() {
        _isBootstrapping = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isBootstrapping = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isBootstrapping && _error == null) {
      return const TeacherDashboardScreen();
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.surface,
              scheme.surfaceContainerHighest.withValues(alpha: 0.86),
            ],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(color: scheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Launching dashboard preview',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _error ??
                          'Seeding the demo workspace and opening the teacher dashboard.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_error == null)
                      const LinearProgressIndicator(minHeight: 6)
                    else
                      FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _isBootstrapping = true;
                            _error = null;
                          });
                          _bootstrapPreview();
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry preview'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
