import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:gradeflow/config/gradeflow_product_config.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/demo_data_service.dart';
import 'package:gradeflow/services/final_exam_service.dart';
import 'package:gradeflow/services/grade_item_service.dart';
import 'package:gradeflow/services/grading_category_service.dart';
import 'package:gradeflow/services/student_score_service.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/theme.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  bool get _shouldUseLocalhostForGoogleSignIn =>
      kIsWeb && Uri.base.host == '127.0.0.1';

  Uri get _localhostSignInUri => Uri.base.replace(host: 'localhost');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty) {
      _showError('Please enter your email');
      return;
    }

    setState(() => _isLoading = true);

    final authService = context.read<AuthService>();
    final success = await authService.login(
        _emailController.text, _passwordController.text);

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        context.go('/dashboard');
      } else {
        _showError('Login failed. Please check your credentials.');
      }
    }
  }

  Future<void> _handleDemoLogin() async {
    setState(() => _isLoading = true);

    final authService = context.read<AuthService>();
    await authService.seedDemoUser();
    final success = await authService.login('teacher@demo.com', 'demo');

    if (success && mounted) {
      final user = authService.currentUser;
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
    }

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        context.go('/dashboard');
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;

    if (_shouldUseLocalhostForGoogleSignIn) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Google sign-in on local web should use localhost. Opening ${_localhostSignInUri.toString()}',
          ),
        ),
      );
      await _openLocalhostSignIn();
      return;
    }

    setState(() => _isLoading = true);

    final authService = context.read<AuthService>();
    final success = await authService.signInWithGoogle();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      router.go('/dashboard');
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _shouldUseLocalhostForGoogleSignIn
                ? 'Google sign-in failed on 127.0.0.1. Open localhost and try again.'
                : 'Google sign-in failed.',
          ),
          backgroundColor: errorColor,
          action: _shouldUseLocalhostForGoogleSignIn
              ? SnackBarAction(
                  label: 'Open localhost',
                  onPressed: _openLocalhostSignIn,
                )
              : null,
        ),
      );
    }
  }

  Future<void> _openLocalhostSignIn() async {
    await launchUrl(_localhostSignInUri, webOnlyWindowName: '_self');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final router = GoRouter.of(context);
    debugPrint(
        'LoginScreen.build | isAuth=${auth.isAuthenticated} isLoading=${auth.isLoading} isInit=${auth.isInitialized}');
    if (auth.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        router.go('/dashboard');
      });
    }
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  'assets/images/school_logo2.png',
                  height: 120,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  GradeFlowProductConfig.appName,
                  style: context.textStyles.headlineLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  GradeFlowProductConfig.marketingTagline,
                  style: context.textStyles.bodyMedium?.withColor(
                      Theme.of(context).colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  GradeFlowProductConfig.defaultSchoolName,
                  style: context.textStyles.bodySmall?.withColor(
                    Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_shouldUseLocalhostForGoogleSignIn) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Google sign-in works better on localhost',
                            style: context.textStyles.titleSmall,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'This local run opened on 127.0.0.1, which Firebase web auth often rejects. Switch to localhost for Google sign-in.',
                            style: context.textStyles.bodySmall?.withColor(
                              Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          OutlinedButton.icon(
                            onPressed: _isLoading ? null : _openLocalhostSignIn,
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Open localhost sign-in'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  obscureText: true,
                  enabled: !_isLoading,
                  onSubmitted: (_) => _handleLogin(),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Sign In'),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleGoogleLogin,
                  icon: const Icon(Icons.login),
                  label: const Text('Continue with Google'),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: _isLoading ? null : _handleDemoLogin,
                  child: const Text('Try Demo Account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
