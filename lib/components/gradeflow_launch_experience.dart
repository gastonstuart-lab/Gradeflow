import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/components/animated_page_background.dart';
import 'package:gradeflow/config/gradeflow_product_config.dart';
import 'package:gradeflow/services/auth_service.dart';

class GradeFlowLaunchGate extends StatefulWidget {
  final Widget child;

  const GradeFlowLaunchGate({
    super.key,
    required this.child,
  });

  @override
  State<GradeFlowLaunchGate> createState() => _GradeFlowLaunchGateState();
}

class _GradeFlowLaunchGateState extends State<GradeFlowLaunchGate> {
  static const _minimumSplash = Duration(milliseconds: 1100);
  bool _minimumElapsed = false;
  bool _completed = false;
  Timer? _minimumTimer;

  @override
  void initState() {
    super.initState();
    _minimumTimer = Timer(_minimumSplash, () {
      if (!mounted) return;
      setState(() => _minimumElapsed = true);
      _maybeComplete();
    });
  }

  @override
  void dispose() {
    _minimumTimer?.cancel();
    super.dispose();
  }

  void _maybeComplete() {
    if (_completed || !_minimumElapsed) return;
    final auth = context.read<AuthService>();
    if (!auth.isInitialized) return;
    setState(() => _completed = true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!_completed && _minimumElapsed && auth.isInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _maybeComplete();
        }
      });
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 620),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _completed
          ? KeyedSubtree(
              key: const ValueKey<String>('app-ready'),
              child: widget.child,
            )
          : KeyedSubtree(
              key: const ValueKey<String>('launch-experience'),
              child: _GradeFlowLaunchExperience(auth: auth),
            ),
    );
  }
}

class _GradeFlowLaunchExperience extends StatelessWidget {
  final AuthService auth;

  const _GradeFlowLaunchExperience({
    required this.auth,
  });

  String _statusTitle() {
    if (!auth.isInitialized && auth.isLoading) {
      return 'Restoring your teaching workspace';
    }
    if (!auth.isInitialized) {
      return 'Starting GradeFlow';
    }
    if (auth.isAuthenticated) {
      return 'Opening your dashboard';
    }
    return 'Preparing secure sign in';
  }

  String _statusDetail() {
    if (!auth.isInitialized && auth.isLoading) {
      return 'Checking your session and restoring workspace state.';
    }
    if (!auth.isInitialized) {
      return 'Loading the dashboard shell and classroom tools.';
    }
    if (auth.isAuthenticated) {
      return 'Classes, live rail, and teaching tools are ready.';
    }
    return 'Secure sign-in is ready.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final secondary =
        isDark ? const Color(0xFF7DD3FC) : const Color(0xFF1D4ED8);

    return Scaffold(
      body: AnimatedPageBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final edgePadding = constraints.maxWidth < 640 ? 16.0 : 24.0;
            final panelPadding = constraints.maxWidth < 640 ? 22.0 : 28.0;

            return SingleChildScrollView(
              padding: EdgeInsets.all(edgePadding),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - (edgePadding * 2)).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: Colors.white
                              .withValues(alpha: isDark ? 0.12 : 0.24),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.colorScheme.surface.withValues(
                              alpha: isDark ? 0.86 : 0.92,
                            ),
                            theme.colorScheme.surfaceContainerHighest
                                .withValues(
                              alpha: isDark ? 0.82 : 0.88,
                            ),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.shadowColor.withValues(
                              alpha: isDark ? 0.36 : 0.12,
                            ),
                            blurRadius: 40,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(panelPadding),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 82,
                                  height: 82,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(26),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        primary.withValues(alpha: 0.95),
                                        secondary.withValues(alpha: 0.86),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: primary.withValues(alpha: 0.34),
                                        blurRadius: 28,
                                        offset: const Offset(0, 16),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Image.asset(
                                      'assets/images/school_logo2.png',
                                      fit: BoxFit.contain,
                                      filterQuality: FilterQuality.high,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Teacher Operating System',
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                          letterSpacing: 0.9,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        GradeFlowProductConfig.appName,
                                        style: theme.textTheme.headlineMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.8,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        GradeFlowProductConfig.marketingTagline,
                                        style:
                                            theme.textTheme.bodyLarge?.copyWith(
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                          height: 1.45,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: const [
                                _LaunchSignalChip(
                                  icon: Icons.dvr_rounded,
                                  label: 'Dashboard shell',
                                ),
                                _LaunchSignalChip(
                                  icon: Icons.auto_awesome_rounded,
                                  label: 'Class tools',
                                ),
                                _LaunchSignalChip(
                                  icon: Icons.cloud_done_outlined,
                                  label: 'Live context',
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                color: Colors.white.withValues(
                                  alpha: isDark ? 0.05 : 0.54,
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(
                                    alpha: isDark ? 0.08 : 0.22,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 7,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          color: primary.withValues(
                                            alpha: isDark ? 0.16 : 0.12,
                                          ),
                                          border: Border.all(
                                            color: primary.withValues(
                                              alpha: isDark ? 0.24 : 0.18,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'Launch sequence',
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                            color: primary,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.35,
                                          ),
                                        ),
                                      ),
                                      _LaunchStageChip(
                                        label: auth.isAuthenticated
                                            ? 'Session restored'
                                            : auth.isInitialized
                                                ? 'Ready for sign in'
                                                : 'Bringing systems online',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    _statusTitle(),
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 520),
                                    child: Text(
                                      _statusDetail(),
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                        height: 1.55,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: const [
                                      _LaunchSequencePill(
                                        label: 'Auth',
                                        icon: Icons.verified_user_outlined,
                                      ),
                                      _LaunchSequencePill(
                                        label: 'Dashboard',
                                        icon:
                                            Icons.dashboard_customize_outlined,
                                      ),
                                      _LaunchSequencePill(
                                        label: 'Tools',
                                        icon: Icons.draw_outlined,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: LinearProgressIndicator(
                                      minHeight: 6,
                                      backgroundColor:
                                          Colors.white.withValues(alpha: 0.08),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        primary.withValues(alpha: 0.95),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LaunchSignalChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _LaunchSignalChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
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

class _LaunchStageChip extends StatelessWidget {
  final String label;

  const _LaunchStageChip({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _LaunchSequencePill extends StatelessWidget {
  final String label;
  final IconData icon;

  const _LaunchSequencePill({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
