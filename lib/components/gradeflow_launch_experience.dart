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

  String _statusLine() {
    if (!auth.isInitialized && auth.isLoading) {
      return 'Restoring your secure classroom workspace...';
    }
    if (!auth.isInitialized) {
      return 'Preparing your classroom workspace...';
    }
    if (auth.isAuthenticated) {
      return 'Workspace ready. Opening ${GradeFlowProductConfig.appName}...';
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
    final progress = _progressValue();

    return Scaffold(
      backgroundColor: const Color(0xFF050912),
      body: AnimatedPageBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 640;
            final edgePadding = compact ? 20.0 : 32.0;

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
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _LaunchTextLockup(compact: compact),
                        const SizedBox(height: 16),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: Text(
                            GradeFlowProductConfig.marketingTagline,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        _LaunchProgressLine(value: progress),
                        const SizedBox(height: 14),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: Text(
                            _statusLine(),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.92),
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
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

class _LaunchTextLockup extends StatelessWidget {
  const _LaunchTextLockup({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final symbolSize = compact ? 34.0 : 42.0;
    final nameSize = compact ? 34.0 : 44.0;
    final symbolStyle = theme.textTheme.headlineMedium?.copyWith(
          fontSize: symbolSize,
          fontWeight: FontWeight.w700,
          height: 1.0,
          letterSpacing: -0.3,
          color: theme.colorScheme.onSurface,
        ) ??
        TextStyle(
          fontSize: symbolSize,
          fontWeight: FontWeight.w700,
          height: 1.0,
          letterSpacing: -0.3,
          color: theme.colorScheme.onSurface,
        );

    final nameStyle = theme.textTheme.displaySmall?.copyWith(
          fontSize: nameSize,
          fontWeight: FontWeight.w700,
          height: 1.0,
          letterSpacing: -0.4,
          color: theme.colorScheme.onSurface,
        ) ??
        TextStyle(
          fontSize: nameSize,
          fontWeight: FontWeight.w700,
          height: 1.0,
          letterSpacing: -0.4,
          color: theme.colorScheme.onSurface,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('I', style: symbolStyle),
            Text(
              '/',
              style: symbolStyle.copyWith(
                color: const Color(0xFF2A6BFF),
              ),
            ),
            Text(
              'OS',
              style: symbolStyle.copyWith(
                color: const Color(0xFF22D3EE),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          GradeFlowProductConfig.appName,
          style: nameStyle,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _LaunchProgressLine extends StatelessWidget {
  const _LaunchProgressLine({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final trackColor = Colors.white.withValues(alpha: 0.12);
    final clamped = value.clamp(0.0, 1.0);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Stack(
            children: [
              Container(
                height: 3,
                width: width,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: trackColor,
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                height: 3,
                width: width * clamped,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5C88FF), Color(0xFF22D3EE)],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
