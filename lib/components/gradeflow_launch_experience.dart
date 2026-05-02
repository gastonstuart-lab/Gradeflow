import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/components/animated_page_background.dart';
import 'package:gradeflow/components/gradeflow_entry_motion.dart';
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

    return SizedBox.expand(
      child: AnimatedSwitcher(
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
      return 'Restoring session';
    }
    if (!auth.isInitialized) {
      return 'Preparing workspace';
    }
    if (auth.isAuthenticated) {
      return 'Workspace ready';
    }
    return 'Ready to enter';
  }

  String _statusDetail() {
    if (!auth.isInitialized && auth.isLoading) {
      return 'Checking your secure GradeFlow session.';
    }
    if (!auth.isInitialized) {
      return 'Bringing classroom tools online.';
    }
    if (auth.isAuthenticated) {
      return 'Your teaching OS is ready.';
    }
    return 'Secure access is ready.';
  }

  double _progressValue() {
    if (!auth.isInitialized) return auth.isLoading ? 0.42 : 0.28;
    return auth.isAuthenticated ? 1.0 : 0.86;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFF050912),
      body: AnimatedPageBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 640;
            final edgePadding = compact ? 18.0 : 28.0;
            final panelPadding = compact ? 24.0 : 34.0;

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
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(compact ? 28 : 34),
                        border: Border.all(
                          color: Colors.white
                              .withValues(alpha: isDark ? 0.11 : 0.20),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.colorScheme.surface.withValues(
                              alpha: isDark ? 0.78 : 0.94,
                            ),
                            theme.colorScheme.surfaceContainerHighest
                                .withValues(
                              alpha: isDark ? 0.60 : 0.80,
                            ),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.shadowColor.withValues(
                              alpha: isDark ? 0.42 : 0.13,
                            ),
                            blurRadius: 52,
                            offset: const Offset(0, 26),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(panelPadding),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const GradeFlowEntryMotion(size: 178),
                            const SizedBox(height: 18),
                            Text(
                              'Teacher Operating System'.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.primary,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              GradeFlowProductConfig.appName,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 430),
                              child: Text(
                                'Opening the workspace for today\'s classes.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.45,
                                ),
                              ),
                            ),
                            const SizedBox(height: 26),
                            Container(
                              padding: EdgeInsets.all(compact ? 16 : 18),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                color: Colors.white.withValues(
                                  alpha: isDark ? 0.045 : 0.56,
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(
                                    alpha: isDark ? 0.08 : 0.20,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _statusTitle(),
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0,
                                          ),
                                        ),
                                      ),
                                      _LaunchStageChip(
                                        label: auth.isInitialized
                                            ? 'Online'
                                            : 'Starting',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _statusDetail(),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: LinearProgressIndicator(
                                      value: _progressValue(),
                                      minHeight: 6,
                                      backgroundColor:
                                          Colors.white.withValues(alpha: 0.08),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        primary.withValues(alpha: 0.95),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      const _LaunchChecklistItem(
                                        label: 'Secure session',
                                        active: true,
                                      ),
                                      const _LaunchChecklistItem(
                                        label: 'Classroom tools',
                                        active: true,
                                      ),
                                      _LaunchChecklistItem(
                                        label: 'Workspace ready',
                                        active: auth.isInitialized,
                                      ),
                                    ],
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

class _LaunchChecklistItem extends StatelessWidget {
  const _LaunchChecklistItem({
    required this.label,
    required this.active,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = active
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.78);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: active ? 0.12 : 0.06),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.check_circle_outline : Icons.radio_button_unchecked,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}
