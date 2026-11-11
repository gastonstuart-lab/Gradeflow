import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Native Flutter interpretation of Aceternity's Background Boxes effect.
///
/// The grid is deliberately low-contrast behind authentication controls.
/// Hover/touch highlights are painted underneath [child] and never intercept
/// the sign-in fields, buttons, keyboard navigation or accessibility tree.
class InstructOSBoxesBackground extends StatefulWidget {
  const InstructOSBoxesBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<InstructOSBoxesBackground> createState() =>
      _InstructOSBoxesBackgroundState();
}

class _InstructOSBoxesBackgroundState extends State<InstructOSBoxesBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 28),
  )..repeat();

  final ValueNotifier<Offset?> _pointer = ValueNotifier<Offset?>(null);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion && _ambient.isAnimating) {
      _ambient
        ..stop()
        ..value = 0.25;
    } else if (!reduceMotion && !_ambient.isAnimating) {
      _ambient.repeat();
    }
  }

  void _movePointer(PointerEvent event, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    _pointer.value = event.localPosition;
  }

  @override
  void dispose() {
    _ambient.dispose();
    _pointer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      return RepaintBoundary(
        child: MouseRegion(
          onHover: (event) => _movePointer(event, size),
          onExit: (_) => _pointer.value = null,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (event) => _movePointer(event, size),
            onPointerMove: (event) => _movePointer(event, size),
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF07101D),
                          Color(0xFF0C162A),
                          Color(0xFF070F1D),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_ambient, _pointer]),
                        builder: (context, _) => CustomPaint(
                          painter: _BoxesPainter(
                            progress: _ambient.value,
                            pointer: _pointer.value,
                            reducedEffects: reduceMotion || size.width < 560,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Keep sign-in controls readable against the grid, even
                  // when the hovered boxes become brighter.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 1.05,
                            colors: [
                              const Color(0xFF070F1D).withValues(alpha: 0.58),
                              const Color(0xFF070F1D).withValues(alpha: 0.20),
                              const Color(0xFF070F1D).withValues(alpha: 0.47),
                            ],
                            stops: const [0.0, 0.55, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  widget.child,
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _BoxesPainter extends CustomPainter {
  const _BoxesPainter({
    required this.progress,
    required this.pointer,
    required this.reducedEffects,
  });

  final double progress;
  final Offset? pointer;
  final bool reducedEffects;

  static const List<Color> _palette = [
    Color(0xFF39D5BE),
    Color(0xFF60A5FA),
    Color(0xFFA78BFA),
    Color(0xFF7DD3FC),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final boxSize = reducedEffects ? 58.0 : 54.0;
    final cols = (size.width / boxSize).ceil() + 5;
    final rows = (size.height / boxSize).ceil() + 5;
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final ambientPoint = Offset(
      size.width * (0.54 + (reducedEffects ? 0 : math.sin(progress * math.pi * 2) * 0.15)),
      size.height * (0.43 + (reducedEffects ? 0 : math.cos(progress * math.pi * 2) * 0.10)),
    );
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = const Color(0xFFBBD3E7).withValues(alpha: 0.095);
    final fill = Paint()..style = PaintingStyle.fill;

    canvas.save();
    // A slight tilt adds depth without the exaggerated perspective of the
    // original demo, keeping this suitable for a professional sign-in screen.
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.045);
    canvas.translate(-center.dx, -center.dy);

    for (var row = -2; row < rows; row++) {
      for (var col = -2; col < cols; col++) {
        final rect = Rect.fromLTWH(
          col * boxSize,
          row * boxSize,
          boxSize - 1,
          boxSize - 1,
        );
        final tileCenter = rect.center;

        final ambientDistance = (tileCenter - ambientPoint).distance;
        final ambientGlow = (1 - ambientDistance / (boxSize * 4.7))
            .clamp(0.0, 1.0);
        var hoverGlow = 0.0;
        if (pointer != null && !reducedEffects) {
          hoverGlow = (1 - (tileCenter - pointer!).distance / (boxSize * 3.0))
              .clamp(0.0, 1.0);
        }

        final intensity = math.max(ambientGlow * 0.24, hoverGlow * 0.75);
        if (intensity > 0.02) {
          final color = _palette[(row.abs() + col.abs() * 3) % _palette.length];
          fill.color = color.withValues(alpha: intensity * 0.22);
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect.deflate(2), const Radius.circular(2)),
            fill,
          );
        }
        canvas.drawRect(rect, outline);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BoxesPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.pointer != pointer ||
      oldDelegate.reducedEffects != reducedEffects;
}
