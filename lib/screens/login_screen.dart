import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:gradeflow/components/workspace_shell.dart';
import 'package:gradeflow/config/instructos_branding.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/demo_data_service.dart';
import 'package:gradeflow/services/final_exam_service.dart';
import 'package:gradeflow/services/grade_item_service.dart';
import 'package:gradeflow/services/grading_category_service.dart';
import 'package:gradeflow/services/student_score_service.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/widgets/branding/instructos_auth_card_shell.dart';
import 'package:gradeflow/widgets/branding/instructos_interactive_auth_background.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isCreatingAccount = false;

  bool get _shouldUseLocalhostForGoogleSignIn =>
      kIsWeb && Uri.base.host == '127.0.0.1';

  Uri get _localhostSignInUri => Uri.base.replace(host: 'localhost');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String _postAuthDestination() {
    final state = GoRouterState.of(context);
    return AppRouter.postAuthDestination(state.uri.queryParameters['from']);
  }

  void _completeAuthNavigation() {
    context.go(_postAuthDestination());
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
        _completeAuthNavigation();
      } else {
        _showError('Login failed. Please check your credentials.');
      }
    }
  }

  Future<void> _handleRegister() async {
    if (_emailController.text.trim().isEmpty) {
      _showError('Please enter your email');
      return;
    }

    final displayName = _nameController.text.trim().isEmpty
        ? _emailController.text.trim()
        : _nameController.text.trim();

    setState(() => _isLoading = true);

    final authService = context.read<AuthService>();
    final success = await authService.register(
      _emailController.text.trim(),
      displayName,
      null,
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        _completeAuthNavigation();
      } else {
        _showError('Account creation failed. Please try another email.');
      }
    }
  }

  Future<void> _handleDemoLogin() async {
    setState(() => _isLoading = true);

    final authService = context.read<AuthService>();
    bool success = false;
    try {
      await authService.seedDemoUser();
      success = await authService.login('teacher@demo.com', 'demo');

      if (success && mounted) {
        final user = authService.currentUser;
        if (DemoDataService.isDemoUser(user) && user != null) {
          await DemoDataService.ensureDemoWorkspace(
            teacherId: user.userId,
            classService: context.read<ClassService>(),
            studentService: context.read<StudentService>(),
            categoryService: context.read<GradingCategoryService>(),
            gradeItemService: context.read<GradeItemService>(),
            scoreService: context.read<StudentScoreService>(),
            examService: context.read<FinalExamService>(),
          );
        }
      }
    } catch (_) {
      success = false;
    }

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        _completeAuthNavigation();
      } else {
        _showError('Demo login failed. Please try again.');
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    final router = GoRouter.of(context);

    if (_shouldUseLocalhostForGoogleSignIn) {
      showWorkspaceSnackBar(
        context,
        message:
            'Google sign-in on local web should use localhost. Opening ${_localhostSignInUri.toString()}',
        title: 'Opening localhost',
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
      router.go(_postAuthDestination());
    } else {
      showWorkspaceSnackBar(
        context,
        message: _shouldUseLocalhostForGoogleSignIn
            ? 'Google sign-in failed on 127.0.0.1. Open localhost and try again.'
            : 'Google sign-in failed.',
        tone: WorkspaceFeedbackTone.error,
        actionLabel:
            _shouldUseLocalhostForGoogleSignIn ? 'Open localhost' : null,
        onAction: _shouldUseLocalhostForGoogleSignIn
            ? () {
                _openLocalhostSignIn();
              }
            : null,
      );
    }
  }

  Future<void> _openLocalhostSignIn() async {
    await launchUrl(_localhostSignInUri, webOnlyWindowName: '_self');
  }

  void _showError(String message) {
    showWorkspaceSnackBar(
      context,
      message: message,
      tone: WorkspaceFeedbackTone.error,
    );
  }

  Widget _buildAccessPanel(
    BuildContext context, {
    required bool compact,
  }) {
    final theme = Theme.of(context);
    final primaryButtonStyle = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(54),
      backgroundColor: const Color(0xFF8B5CF6),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
      ),
      textStyle: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
    final secondaryButtonStyle = OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(50),
      foregroundColor: const Color(0xFFB8C3FF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      side: BorderSide(
        color: Colors.white.withValues(alpha: 0.13),
      ),
      textStyle: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );

    return InstructOSAuthCardShell(
      compact: compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            InstructOSBranding.productName,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Teaching, organised.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFD7DDF1).withValues(alpha: 0.72),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: compact ? 30 : 36),
          Text(
            _isCreatingAccount ? 'Create account' : 'Sign in',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.94),
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          if (_shouldUseLocalhostForGoogleSignIn) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: const Color(0xFF142036).withValues(alpha: 0.62),
                border: Border.all(
                  color: theme.colorScheme.tertiary.withValues(alpha: 0.30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Google sign-in works better on localhost',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'This local run opened on 127.0.0.1, which Firebase web auth often rejects. Switch to localhost for Google sign-in.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _openLocalhostSignIn,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open localhost sign-in'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isCreatingAccount) ...[
                  TextField(
                    controller: _nameController,
                    decoration: _portalInputDecoration(
                      theme,
                      labelText: 'Name',
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _emailController,
                  decoration: _portalInputDecoration(
                    theme,
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  decoration: _portalInputDecoration(
                    theme,
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  enabled: !_isLoading,
                  onSubmitted: (_) =>
                      _isCreatingAccount ? _handleRegister() : _handleLogin(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isLoading
                ? null
                : (_isCreatingAccount ? _handleRegister : _handleLogin),
            style: primaryButtonStyle,
            icon: _isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward_rounded),
            label: Text(_isLoading ? 'Opening...' : 'Enter'),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _handleGoogleLogin,
            style: secondaryButtonStyle,
            icon: const Icon(Icons.login),
            label: const Text('Continue with Google'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _handleDemoLogin,
            style: secondaryButtonStyle,
            icon: const Icon(Icons.preview_outlined),
            label: const Text('Open demo'),
          ),
          const SizedBox(height: 18),
          TextButton(
            onPressed: _isLoading
                ? null
                : () {
                    setState(() => _isCreatingAccount = !_isCreatingAccount);
                  },
            child: Text(
              _isCreatingAccount ? 'Sign in' : 'Create account',
              style: theme.textTheme.labelLarge?.copyWith(
                color: const Color(0xFFB8C3FF),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _portalInputDecoration(
    ThemeData theme, {
    required String labelText,
    required Widget prefixIcon,
  }) {
    final borderRadius = BorderRadius.circular(18);
    return InputDecoration(
      labelText: labelText,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: const Color(0xFF070B14).withValues(alpha: 0.46),
      labelStyle: TextStyle(
        color: const Color(0xFFD7DDF1).withValues(alpha: 0.78),
        fontWeight: FontWeight.w600,
      ),
      prefixIconColor: const Color(0xFFD7DDF1).withValues(alpha: 0.86),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.13),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(
          color: Color(0xFF8B5CF6),
          width: 1.4,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.07),
        ),
      ),
      border: OutlineInputBorder(borderRadius: borderRadius),
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
        router.go(_postAuthDestination());
      });
    }

    final size = MediaQuery.sizeOf(context);
    final shortViewport = size.height < 780;
    final edgePadding = shortViewport ? 18.0 : 24.0;

    return Scaffold(
      body: InstructOSInteractiveAuthBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(edgePadding),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: _buildAccessPanel(
                  context,
                  compact: size.width < 560 || shortViewport,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
