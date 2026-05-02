import 'dart:math' as math;

import 'package:flutter/material.dart';

// Future motion slot: a professionally produced Lottie or Rive asset can
// replace this Flutter-native mark later without changing auth or routing.

class GradeFlowEntryMotion extends StatefulWidget {
  const GradeFlowEntryMotion({
    super.key,
    this.size = 184,
    this.compact = false,
  });

  final double size;
  final bool compact;

  @override
  State<GradeFlowEntryMotion> createState() => _GradeFlowEntryMotionState();
}

class _GradeFlowEntryMotionState extends State<GradeFlowEntryMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.compact ? widget.size * 0.82 : widget.size;

    return SizedBox.square(
      dimension: size,
      child: _NativeEntryMark(
        controller: _controller,
        compact: widget.compact,
      ),
    );
  }
}

class _NativeEntryMark extends StatelessWidget {
  const _NativeEntryMark({
    required this.controller,
    required this.compact,
  });

  final Animation<double> controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final cyan = isDark ? const Color(0xFF67E8F9) : const Color(0xFF0891B2);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = controller.value;
        final breathe = 1 + math.sin(t * math.pi * 2) * 0.018;
        final sweep = (t * math.pi * 2) - math.pi / 2;

        return Transform.scale(
          scale: breathe,
          child: CustomPaint(
            painter: _EntryOrbitPainter(
              progress: t,
              primary: primary,
              cyan: cyan,
              isDark: isDark,
            ),
            child: Center(
              child: Container(
                width: compact ? 82 : 104,
                height: compact ? 82 : 104,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(compact ? 26 : 32),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primary.withValues(alpha: 0.95),
                      cyan.withValues(alpha: 0.86),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: isDark ? 0.28 : 0.20),
                      blurRadius: compact ? 26 : 34,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.rotate(
                      angle: sweep * 0.18,
                      child: Container(
                        width: compact ? 52 : 66,
                        height: compact ? 52 : 66,
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(compact ? 18 : 22),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.32),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: compact ? 25 : 32,
                      height: compact ? 25 : 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
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
    );
  }
}

class _EntryOrbitPainter extends CustomPainter {
  const _EntryOrbitPainter({
    required this.progress,
    required this.primary,
    required this.cyan,
    required this.isDark,
  });

  final double progress;
  final Color primary;
  final Color cyan;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final shortest = math.min(size.width, size.height);
    final baseRadius = shortest * 0.36;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    paint
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: isDark ? 0.11 : 0.22);
    canvas.drawCircle(center, baseRadius, paint);
    canvas.drawCircle(center, baseRadius * 1.24, paint);

    final rect = Rect.fromCircle(center: center, radius: baseRadius * 1.24);
    paint
      ..strokeWidth = 3
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: [
          primary.withValues(alpha: 0),
          primary.withValues(alpha: 0.68),
          cyan.withValues(alpha: 0.86),
          primary.withValues(alpha: 0),
        ],
        stops: const [0, 0.45, 0.72, 1],
        transform: GradientRotation(progress * math.pi * 2),
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 1.35, false, paint);

    paint.shader = null;
    final dotAngle = progress * math.pi * 2 - math.pi / 2;
    final dot = Offset(
      center.dx + math.cos(dotAngle) * baseRadius * 1.24,
      center.dy + math.sin(dotAngle) * baseRadius * 1.24,
    );
    canvas.drawCircle(
      dot,
      4,
      Paint()
        ..color = cyan.withValues(alpha: 0.92)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  @override
  bool shouldRepaint(covariant _EntryOrbitPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primary != primary ||
        oldDelegate.cyan != cyan ||
        oldDelegate.isDark != isDark;
  }
}
