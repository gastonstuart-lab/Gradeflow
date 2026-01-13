import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:gradeflow/theme.dart';

/// Animated glow border similar to Dreamflow's moving gradient outline.
/// Wraps any child and paints a rotating sweep gradient ring around it.
class AnimatedGlowBorder extends StatefulWidget {
  final Widget child;
  final double borderWidth;
  final double radius;
  final Duration duration;

  /// Globally toggle animations to improve performance when needed
  static bool animationsEnabled = false;

  const AnimatedGlowBorder({super.key, required this.child, this.borderWidth = 2.0, this.radius = AppRadius.lg, this.duration = const Duration(seconds: 6)});

  @override
  State<AnimatedGlowBorder> createState() => _AnimatedGlowBorderState();
}

class _AnimatedGlowBorderState extends State<AnimatedGlowBorder> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _controllerInitialized = false;

  @override
  void initState() {
    super.initState();
    if (AnimatedGlowBorder.animationsEnabled) {
      _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();
      _controllerInitialized = true;
    }
  }

  @override
  void dispose() {
    if (_controllerInitialized) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surfaceContainer;

    // Static (non-animated) border for performance safety
    if (!AnimatedGlowBorder.animationsEnabled) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: SweepGradient(
            colors: AppEffects.glowColors(context),
            stops: const [0.0, 0.33, 0.66, 1.0],
            // No rotation = static outline
          ),
        ),
        child: Container(
          margin: EdgeInsets.all(widget.borderWidth),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(widget.radius - 1),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.radius - 1),
            child: widget.child,
          ),
        ),
      );
    }

    // Animated version (optional)
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final angle = _controller.value * 2 * math.pi;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: SweepGradient(
              colors: AppEffects.glowColors(context),
              stops: const [0.0, 0.33, 0.66, 1.0],
              transform: GradientRotation(angle),
            ),
          ),
          child: Container(
            margin: EdgeInsets.all(widget.borderWidth),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(widget.radius - 1),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.radius - 1),
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
