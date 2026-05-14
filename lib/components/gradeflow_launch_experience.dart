import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/config/instructos_branding.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/widgets/branding/instructos_interactive_auth_background.dart';

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
                child: const _GradeFlowLaunchExperience(),
              ),
      ),
    );
  }
}

class _GradeFlowLaunchExperience extends StatelessWidget {
  const _GradeFlowLaunchExperience();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF050912),
      body: InstructOSInteractiveAuthBackground(
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
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
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
                            color:
                                const Color(0xFFD7DDF1).withValues(alpha: 0.72),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const _LaunchPulseDot(),
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

class _LaunchPulseDot extends StatefulWidget {
  const _LaunchPulseDot();

  @override
  State<_LaunchPulseDot> createState() => _LaunchPulseDotState();
}

class _LaunchPulseDotState extends State<_LaunchPulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.36, end: 0.88).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFB8C3FF).withValues(alpha: 0.90),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.34),
              blurRadius: 16,
              spreadRadius: 3,
            ),
          ],
        ),
      ),
    );
  }
}
