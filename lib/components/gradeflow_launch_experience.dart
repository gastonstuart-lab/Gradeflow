import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/config/instructos_branding.dart';
import 'package:gradeflow/config/instructos_design.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/widgets/branding/instructos_boxes_background.dart';

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
  static const _minimumSplash = Duration(milliseconds: 350);
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
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 240),
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
    final dark = theme.brightness == Brightness.dark;
    final foreground = dark ? const Color(0xFFF1F7FC) : const Color(0xFF183C5A);
    final secondary = dark ? const Color(0xFFDCE5F4) : const Color(0xFF536F84);
    return Scaffold(
        backgroundColor: InstructOSDesign.background(context),
        body: InstructOSBoxesBackground(
            child: Center(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const InstructOSBrandMark(size: 64),
                      const SizedBox(height: 24),
                      Text(InstructOSBranding.productName,
                          style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800, letterSpacing: -1, color: foreground)),
                      const SizedBox(height: 8),
                      Text('Teaching, organised.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                              color: secondary))),
                      const SizedBox(height: 32),
                      const _LaunchPulseDot(),
                      const SizedBox(height: 14),
                      Semantics(
                          liveRegion: true,
                          child: Text('Opening your workspace',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: secondary)))),
                    ])))));
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

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
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.90),
          boxShadow: [
            BoxShadow(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.24),
              blurRadius: 16,
              spreadRadius: 3,
            ),
          ],
        ),
      ),
    );
  }
}
