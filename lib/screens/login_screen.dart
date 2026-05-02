import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:gradeflow/components/animated_page_background.dart';
import 'package:gradeflow/components/gradeflow_entry_motion.dart';
import 'package:gradeflow/components/workspace_shell.dart';
import 'package:gradeflow/config/gradeflow_product_config.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/demo_data_service.dart';
import 'package:gradeflow/services/final_exam_service.dart';
import 'package:gradeflow/services/grade_item_service.dart';
import 'package:gradeflow/services/grading_category_service.dart';
import 'package:gradeflow/services/student_score_service.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/nav.dart';
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

  Widget _buildExperiencePanel(
    BuildContext context, {
    required bool compact,
  }) {
    final theme = Theme.of(context);
    final panelColor = theme.colorScheme.surface.withValues(alpha: 0.82);
    final secondaryPanel =
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.26);

    return Container(
      padding: EdgeInsets.all(compact ? 22 : 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 28 : 34),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            panelColor,
            secondaryPanel,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GradeFlowEntryMotion(
                size: compact ? 118 : 152,
                compact: compact,
              ),
              SizedBox(width: compact ? 14 : 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LoginSectionTag(
                      label: 'Teacher Operating System',
                    ),
                    const SizedBox(height: 14),
                    Text(
                      GradeFlowProductConfig.appName,
                      style: (compact
                              ? theme.textTheme.headlineSmall
                              : theme.textTheme.headlineMedium)
                          ?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A calm command center for today\'s teaching.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Classes, seating, grades, and live tools stay one motion away.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _LoginSignalChip(
                icon: Icons.verified_user_outlined,
                label: 'Secure workspace',
              ),
              _LoginSignalChip(
                icon: Icons.meeting_room_outlined,
                label: 'Classroom tools',
              ),
              _LoginSignalChip(
                icon: Icons.auto_graph_rounded,
                label: 'Live context',
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.white.withValues(alpha: 0.03),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _LoginSectionTag(
                  label: 'What opens next',
                ),
                SizedBox(height: 14),
                _LoginFeatureTile(
                  icon: Icons.bolt_outlined,
                  title: 'Start cleanly',
                  detail: 'Open into a focused workspace without visual noise.',
                ),
                SizedBox(height: 14),
                _LoginFeatureTile(
                  icon: Icons.meeting_room_outlined,
                  title: 'Teach live',
                  detail:
                      'Move from class context to seating and tools quickly.',
                ),
                SizedBox(height: 14),
                _LoginFeatureTile(
                  icon: Icons.insights_outlined,
                  title: 'Stay aware',
                  detail: 'Class signals and daily work remain close at hand.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessPanel(
    BuildContext context, {
    required bool compact,
  }) {
    final theme = Theme.of(context);
    final primaryButtonStyle = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    );
    final secondaryButtonStyle = OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      side: BorderSide(
        color: Colors.white.withValues(alpha: 0.10),
      ),
    );

    return Container(
      padding: EdgeInsets.all(compact ? 22 : 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 28 : 32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surface.withValues(alpha: 0.90),
            theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.82),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _LoginSectionTag(label: 'Secure sign in'),
              _LoginSectionTag(label: 'Demo-safe preview'),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Enter GradeFlow',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to open your teaching workspace.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.apartment_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    GradeFlowProductConfig.defaultSchoolName,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_shouldUseLocalhostForGoogleSignIn) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: theme.colorScheme.tertiaryContainer.withValues(
                  alpha: 0.34,
                ),
                border: Border.all(
                  color: theme.colorScheme.tertiary.withValues(alpha: 0.28),
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
          const SizedBox(height: 20),
          AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  enabled: !_isLoading,
                  onSubmitted: (_) => _handleLogin(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _isLoading ? null : _handleLogin,
            style: primaryButtonStyle,
            icon: _isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward_rounded),
            label: Text(_isLoading ? 'Entering workspace...' : 'Sign In'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'or continue with',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
            label: const Text('Try Demo Account'),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white.withValues(alpha: 0.03),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: Text(
              'Preview workspace opens a safe sample OS with class tools, seating, and live context.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
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
    final wideLayout = size.width >= 980;
    final shortViewport = size.height < 780;
    final edgePadding = shortViewport ? 18.0 : 24.0;
    final panelGap = wideLayout ? 24.0 : 18.0;

    return Scaffold(
      body: AnimatedPageBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(edgePadding),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1160),
                child: wideLayout
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildExperiencePanel(
                              context,
                              compact: false,
                            ),
                          ),
                          SizedBox(width: panelGap),
                          SizedBox(
                            width: 404,
                            child: _buildAccessPanel(
                              context,
                              compact: false,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildExperiencePanel(context, compact: true),
                          SizedBox(height: panelGap),
                          _buildAccessPanel(context, compact: true),
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

class _LoginSignalChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _LoginSignalChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginSectionTag extends StatelessWidget {
  final String label;

  const _LoginSectionTag({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _LoginFeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const _LoginFeatureTile({
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: theme.colorScheme.primary.withValues(alpha: 0.14),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.22),
            ),
          ),
          child: Icon(icon, size: 20, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
