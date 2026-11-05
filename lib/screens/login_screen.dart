import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:gradeflow/components/workspace_shell.dart';
import 'package:gradeflow/config/instructos_branding.dart';
import 'package:gradeflow/config/instructos_design.dart';
import 'package:gradeflow/providers/app_providers.dart';
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
  bool _showPassword = false;

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
        message: 'Opening the local Google sign-in page.',
        title: 'Google sign-in',
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
      title: 'Check your sign-in details',
    );
  }

  Widget _buildAccessPanel(BuildContext context, {required bool compact}) {
    final theme = Theme.of(context);
    return InstructOSAuthCardShell(
        compact: compact,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(_isCreatingAccount ? 'Create your account' : 'Welcome back.',
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.7)),
          const SizedBox(height: 8),
          Text(
              _isCreatingAccount
                  ? 'Set up your teacher workspace.'
                  : 'Sign in to your teaching workspace.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 28),
          AutofillGroup(
              child: Column(children: [
            if (_isCreatingAccount) ...[
              TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.person_outline)),
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  enabled: !_isLoading),
              const SizedBox(height: 16)
            ],
            TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                    labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                enabled: !_isLoading),
            const SizedBox(height: 16),
            TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                        tooltip:
                            _showPassword ? 'Hide password' : 'Show password',
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                        icon: Icon(_showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined))),
                obscureText: !_showPassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                enabled: !_isLoading,
                onSubmitted: (_) =>
                    _isCreatingAccount ? _handleRegister() : _handleLogin()),
          ])),
          const SizedBox(height: 24),
          FilledButton.icon(
              onPressed: _isLoading
                  ? null
                  : (_isCreatingAccount ? _handleRegister : _handleLogin),
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.arrow_forward_rounded, size: 19),
              label: Text(_isLoading
                  ? 'Opening workspace...'
                  : _isCreatingAccount
                      ? 'Create account'
                      : 'Sign in'),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52))),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Divider(color: theme.colorScheme.outline)),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('or',
                    style:
                        TextStyle(color: theme.colorScheme.onSurfaceVariant))),
            Expanded(child: Divider(color: theme.colorScheme.outline))
          ]),
          const SizedBox(height: 16),
          OutlinedButton.icon(
              onPressed: _isLoading ? null : _handleGoogleLogin,
              icon: const Icon(Icons.login, size: 19),
              label: const Text('Continue with Google')),
          const SizedBox(height: 12),
          TextButton(
              onPressed: _isLoading
                  ? null
                  : () =>
                      setState(() => _isCreatingAccount = !_isCreatingAccount),
              child: Text(_isCreatingAccount
                  ? 'Already have an account? Sign in'
                  : 'Create account')),
          const SizedBox(height: 16),
          Divider(color: theme.colorScheme.outline),
          const SizedBox(height: 8),
          TextButton.icon(
              onPressed: _isLoading ? null : _handleDemoLogin,
              icon: const Icon(Icons.preview_outlined, size: 19),
              label: const Text('Open demo workspace')),
          Text('Explore with sample students and scores.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ]));
  }

  Widget _welcome(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('More time for\nteaching.',
          style: theme.textTheme.displaySmall?.copyWith(
              fontSize: 48,
              height: 1.08,
              letterSpacing: -1.6,
              fontWeight: FontWeight.w800)),
      const SizedBox(height: 20),
      Text('Your classes, plans and grades.\nOne familiar workspace.',
          style: theme.textTheme.titleLarge?.copyWith(
              height: 1.5,
              fontWeight: FontWeight.w400,
              color: theme.colorScheme.onSurfaceVariant)),
      const SizedBox(height: 40),
      for (final feature in [
        (
          Icons.meeting_room_outlined,
          'Teach from your classroom',
          'Your room map and student tools, together.'
        ),
        (
          Icons.menu_book_outlined,
          'Keep grades in reach',
          'Enter scores and prepare your gradebook.'
        ),
        (
          Icons.calendar_month_outlined,
          'Plan the day',
          'Your calendar, reminders and timetable.'
        )
      ])
        Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14)),
                  child: Icon(feature.$1,
                      color: theme.colorScheme.primary, size: 22)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(feature.$2,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(feature.$3,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.4))
                  ]))
            ])),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final router = GoRouter.of(context);
    if (auth.isAuthenticated)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) router.go(_postAuthDestination());
      });
    return Scaffold(body: InstructOSInteractiveAuthBackground(
        child: SafeArea(child: LayoutBuilder(builder: (context, size) {
      final wide = size.maxWidth >= 900;
      return SingleChildScrollView(
          padding:
              EdgeInsets.symmetric(horizontal: wide ? 48 : 20, vertical: 24),
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          const InstructOSBrandMark(),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(InstructOSBranding.productName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                            fontWeight: FontWeight.w800)),
                                Text('Teaching, organised.',
                                    style:
                                        Theme.of(context).textTheme.bodySmall)
                              ])),
                          IconButton(
                              tooltip: 'Change appearance',
                              onPressed: () => context
                                  .read<ThemeModeNotifier>()
                                  .toggleTheme(),
                              icon: Icon(InstructOSDesign.dark(context)
                                  ? Icons.light_mode_outlined
                                  : Icons.dark_mode_outlined))
                        ]),
                        SizedBox(height: wide ? 64 : 32),
                        if (wide)
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(child: _welcome(context)),
                                const SizedBox(width: 80),
                                SizedBox(
                                    width: 430,
                                    child: _buildAccessPanel(context,
                                        compact: false))
                              ])
                        else
                          Center(
                              child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 460),
                                  child: _buildAccessPanel(context,
                                      compact: true))),
                        const SizedBox(height: 32),
                      ]))));
    }))));
  }
}
