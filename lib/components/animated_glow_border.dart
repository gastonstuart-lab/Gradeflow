import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:gradeflow/theme.dart';

/// Animated glow border for GradeFlow's moving gradient outline.
/// Wraps any child and paints a rotating sweep gradient ring around it.
class AnimatedGlowBorder extends StatefulWidget {
  final Widget child;
  final double borderWidth;
  final double radius;
  final Duration duration;

  /// Globally toggle animations to improve performance when needed
  static bool animationsEnabled = false;

  const AnimatedGlowBorder(
      {super.key,
      required this.child,
      this.borderWidth = 2.0,
      this.radius = AppRadius.lg,
      this.duration = const Duration(seconds: 6)});

  @override
  State<AnimatedGlowBorder> createState() => _AnimatedGlowBorderState();
}

class _AnimatedGlowBorderState extends State<AnimatedGlowBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _controllerInitialized = false;

  @override
  void initState() {
    super.initState();
    if (AnimatedGlowBorder.animationsEnabled) {
      _controller = AnimationController(vsync: this, duration: widget.duration)
        ..repeat();
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;
    final surfaceAccent = theme.colorScheme.surfaceContainerHighest;
    final panelGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        surface.withValues(alpha: isDark ? 0.88 : 0.86),
        surfaceAccent.withValues(alpha: isDark ? 0.82 : 0.72),
      ],
    );
    final panelShadow = [
      BoxShadow(
        color:
            theme.colorScheme.primary.withValues(alpha: isDark ? 0.10 : 0.06),
        blurRadius: 28,
        spreadRadius: -12,
        offset: const Offset(0, 14),
      ),
      BoxShadow(
        color: theme.shadowColor.withValues(alpha: isDark ? 0.28 : 0.10),
        blurRadius: 32,
        offset: const Offset(0, 16),
      ),
    ];

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
          boxShadow: panelShadow,
        ),
        child: Container(
          margin: EdgeInsets.all(widget.borderWidth),
          decoration: BoxDecoration(
            gradient: panelGradient,
            borderRadius: BorderRadius.circular(widget.radius - 1),
            border: Border.all(
              color: theme.colorScheme.outline
                  .withValues(alpha: isDark ? 0.28 : 0.18),
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
            boxShadow: panelShadow,
          ),
          child: Container(
            margin: EdgeInsets.all(widget.borderWidth),
            decoration: BoxDecoration(
              gradient: panelGradient,
              borderRadius: BorderRadius.circular(widget.radius - 1),
              border: Border.all(
                color: theme.colorScheme.outline
                    .withValues(alpha: isDark ? 0.28 : 0.18),
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
