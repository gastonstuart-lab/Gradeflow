import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/components/animated_page_background.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/widgets/branding/instructos_brand_widgets.dart';

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
            final edgePadding = compact ? 22.0 : 34.0;

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
                      children: [
                        InstructOSTextLockup(
                          centered: true,
                          markSize: compact ? 42 : 50,
                          wordmarkSize: compact ? 34 : 42,
                          spacing: compact ? 12 : 16,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'One system. Every classroom workflow.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 26),
                        _LaunchProgressLine(value: progress),
                        const SizedBox(height: 16),
                        Text(
                          'Preparing your classroom workspace...',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.92),
                            height: 1.45,
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

class _LaunchProgressLine extends StatelessWidget {
  const _LaunchProgressLine({
    required this.value,
  });

  final double value;

  @override
  Widget build(BuildContext context) {
    final clampedValue = value.clamp(0.0, 1.0);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackWidth = constraints.maxWidth;
          return Stack(
            children: [
              Container(
                height: 3,
                width: trackWidth,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                height: 3,
                width: trackWidth * clampedValue,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xFF2A6BFF), Color(0xFF22D3EE)],
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
