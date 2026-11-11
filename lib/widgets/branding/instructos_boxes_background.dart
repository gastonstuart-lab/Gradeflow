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

class _InstructOSBoxesBackgroundState extends State<InstructOSBoxesBackground> {
  // The reference effect responds to interaction. A continuously repeating
  // ticker wastes power during login, and prevents pumpAndSettle-based tests.
  final ValueNotifier<Offset?> _pointer = ValueNotifier<Offset?>(null);

  void _movePointer(PointerEvent event, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    _pointer.value = event.localPosition;
  }

  @override
  void dispose() {
    _pointer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
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
                  DecoratedBox(
                    key: const ValueKey('instructos-boxes-base'),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: dark
                            ? const [
                                Color(0xFF07101D),
                                Color(0xFF0C162A),
                                Color(0xFF070F1D),
                              ]
                            : const [
                                Color(0xFFF7FBFE),
                                Color(0xFFEAF4FA),
                                Color(0xFFF2F9F6),
                              ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ValueListenableBuilder<Offset?>(
                        valueListenable: _pointer,
                        builder: (context, pointer, _) => CustomPaint(
                          painter: _BoxesPainter(
                            pointer: pointer,
                            dark: dark,
                            reducedEffects: reduceMotion || size.width < 560,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Maintain legible type behind the same interactive grid
                  // without flattening the soft light-mode blue/mint palette.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 1.05,
                            colors: dark
                                ? [
                                    const Color(0xFF070F1D)
                                        .withValues(alpha: 0.58),
                                    const Color(0xFF070F1D)
                                        .withValues(alpha: 0.20),
                                    const Color(0xFF070F1D)
                                        .withValues(alpha: 0.47),
                                  ]
                                : [
                                    Colors.white.withValues(alpha: 0.53),
                                    Colors.white.withValues(alpha: 0.08),
                                    Colors.white.withValues(alpha: 0.32),
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
    required this.pointer,
    required this.dark,
    required this.reducedEffects,
  });

  final Offset? pointer;
  final bool dark;
  final bool reducedEffects;

  static const List<Color> _darkPalette = [
    Color(0xFF39D5BE),
    Color(0xFF60A5FA),
    Color(0xFFA78BFA),
    Color(0xFF7DD3FC),
  ];
  static const List<Color> _lightPalette = [
    Color(0xFF5AA6CF),
    Color(0xFF5BBEAD),
    Color(0xFF94B0DA),
    Color(0xFF76B4D0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final boxSize = reducedEffects ? 58.0 : 54.0;
    final cols = (size.width / boxSize).ceil() + 5;
    final rows = (size.height / boxSize).ceil() + 5;
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final ambientPoint = Offset(size.width * 0.54, size.height * 0.43);
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = dark
          ? const Color(0xFFBBD3E7).withValues(alpha: 0.095)
          : const Color(0xFF6E9AB2).withValues(alpha: 0.19);
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
          final palette = dark ? _darkPalette : _lightPalette;
          final color = palette[(row.abs() + col.abs() * 3) % palette.length];
          fill.color = color.withValues(
            alpha: intensity * (dark ? 0.22 : 0.15),
          );
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
      oldDelegate.pointer != pointer ||
      oldDelegate.dark != dark ||
      oldDelegate.reducedEffects != reducedEffects;
}
