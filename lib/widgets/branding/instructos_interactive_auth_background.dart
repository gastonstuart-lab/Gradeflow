import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class InstructOSInteractiveAuthBackground extends StatefulWidget {
  final Widget child;

  const InstructOSInteractiveAuthBackground({
    super.key,
    required this.child,
  });

  @override
  State<InstructOSInteractiveAuthBackground> createState() =>
      _InstructOSInteractiveAuthBackgroundState();
}

class _InstructOSInteractiveAuthBackgroundState
    extends State<InstructOSInteractiveAuthBackground>
    with SingleTickerProviderStateMixin {
  static const Duration _animationDuration = Duration(seconds: 34);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _animationDuration,
  )..repeat();

  final ValueNotifier<Offset?> _pointer = ValueNotifier<Offset?>(null);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0.18;
    } else if (!disableAnimations && !_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pointer.dispose();
    super.dispose();
  }

  void _trackPointer(PointerEvent event, Size size) {
    if (size.isEmpty) return;
    _pointer.value = Offset(
      (event.localPosition.dx / size.width).clamp(0.0, 1.0),
      (event.localPosition.dy / size.height).clamp(0.0, 1.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final reducedEffects = disableAnimations || size.shortestSide < 560;

        return RepaintBoundary(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerHover: (event) => _trackPointer(event, size),
            onPointerMove: (event) => _trackPointer(event, size),
            onPointerDown: (event) => _trackPointer(event, size),
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
                          Color(0xFF050711),
                          Color(0xFF0A1023),
                          Color(0xFF090B16),
                        ],
                        stops: [0.0, 0.56, 1.0],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_controller, _pointer]),
                        builder: (context, _) {
                          return CustomPaint(
                            painter: _InstructOSAuthBackgroundPainter(
                              progress: _controller.value,
                              pointer: _pointer.value,
                              reducedEffects: reducedEffects,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              const Color(0xFF050711).withValues(alpha: 0.30),
                              const Color(0xFF050711).withValues(alpha: 0.04),
                              const Color(0xFF050711).withValues(alpha: 0.36),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(0, -0.05),
                            radius: 0.92,
                            colors: [
                              Colors.transparent,
                              const Color(0xFF050711).withValues(alpha: 0.18),
                              const Color(0xFF050711).withValues(alpha: 0.72),
                            ],
                            stops: const [0.0, 0.58, 1.0],
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
        );
      },
    );
  }
}

class _InstructOSAuthBackgroundPainter extends CustomPainter {
  final double progress;
  final Offset? pointer;
  final bool reducedEffects;

  static final List<_ParticleSeed> _particles = List.generate(56, (index) {
    final random = math.Random(index * 97 + 13);
    return _ParticleSeed(
      position: Offset(random.nextDouble(), random.nextDouble()),
      radius: 0.7 + random.nextDouble() * 1.9,
      phase: random.nextDouble() * math.pi * 2,
      drift: 0.35 + random.nextDouble() * 0.9,
    );
  });

  const _InstructOSAuthBackgroundPainter({
    required this.progress,
    required this.pointer,
    required this.reducedEffects,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final pulse = math.sin(progress * math.pi * 2);
    final pointerPoint = pointer == null
        ? Offset(
            size.width * (0.50 + math.sin(progress * math.pi * 2) * 0.06),
            size.height * (0.48 + math.cos(progress * math.pi * 1.7) * 0.05),
          )
        : Offset(pointer!.dx * size.width, pointer!.dy * size.height);
    final pointerPull = pointer == null ? 0.18 : 1.0;

    _paintSoftLight(canvas, size, pointerPoint, pointerPull);
    _paintRibbons(canvas, size, pointerPoint, pointerPull);
    if (!reducedEffects) {
      _paintParticles(canvas, size, pointerPoint, pointerPull);
    } else {
      _paintFallbackDust(canvas, size, pulse);
    }
    _paintFineTexture(canvas, rect);
  }

  void _paintSoftLight(
    Canvas canvas,
    Size size,
    Offset pointerPoint,
    double pointerPull,
  ) {
    final longestSide = math.max(size.width, size.height);
    final glowPaint = Paint()
      ..shader = ui.Gradient.radial(
        pointerPoint,
        longestSide * (pointer == null ? 0.38 : 0.28),
        [
          const Color(0xFF22D3EE).withValues(alpha: 0.16 * pointerPull),
          const Color(0xFFA855F7).withValues(alpha: 0.07 * pointerPull),
          Colors.transparent,
        ],
        const [0.0, 0.44, 1.0],
      );
    canvas.drawCircle(pointerPoint, longestSide * 0.42, glowPaint);

    final cornerPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.12, size.height * 0.12),
        longestSide * 0.44,
        [
          const Color(0xFF7C3AED).withValues(alpha: 0.22),
          Colors.transparent,
        ],
      );
    canvas.drawCircle(
      Offset(size.width * 0.12, size.height * 0.12),
      longestSide * 0.44,
      cornerPaint,
    );
  }

  void _paintRibbons(
    Canvas canvas,
    Size size,
    Offset pointerPoint,
    double pointerPull,
  ) {
    _paintRibbon(
      canvas,
      size,
      pointerPoint,
      pointerPull,
      phase: 0.00,
      yBase: 0.27,
      strokeScale: reducedEffects ? 0.070 : 0.088,
      blurSigma: reducedEffects ? 24 : 34,
      colors: [
        Colors.transparent,
        const Color(0xFFFF3EA5).withValues(alpha: 0.34),
        const Color(0xFFA855F7).withValues(alpha: 0.28),
        const Color(0xFF22D3EE).withValues(alpha: 0.22),
        Colors.transparent,
      ],
    );
    _paintRibbon(
      canvas,
      size,
      pointerPoint,
      pointerPull,
      phase: 0.37,
      yBase: 0.55,
      strokeScale: reducedEffects ? 0.052 : 0.066,
      blurSigma: reducedEffects ? 18 : 26,
      colors: [
        Colors.transparent,
        const Color(0xFF38BDF8).withValues(alpha: 0.18),
        const Color(0xFF8B5CF6).withValues(alpha: 0.24),
        const Color(0xFFFF3EA5).withValues(alpha: 0.16),
        Colors.transparent,
      ],
    );
    _paintRibbon(
      canvas,
      size,
      pointerPoint,
      pointerPull,
      phase: 0.72,
      yBase: 0.76,
      strokeScale: reducedEffects ? 0.044 : 0.054,
      blurSigma: reducedEffects ? 16 : 22,
      colors: [
        Colors.transparent,
        const Color(0xFF0EA5E9).withValues(alpha: 0.16),
        const Color(0xFF22D3EE).withValues(alpha: 0.20),
        const Color(0xFFA855F7).withValues(alpha: 0.16),
        Colors.transparent,
      ],
    );
  }

  void _paintRibbon(
    Canvas canvas,
    Size size,
    Offset pointerPoint,
    double pointerPull, {
    required double phase,
    required double yBase,
    required double strokeScale,
    required double blurSigma,
    required List<Color> colors,
  }) {
    final theta = (progress + phase) * math.pi * 2;
    final pointerX = (pointerPoint.dx / size.width).clamp(0.0, 1.0);
    final pointerY = (pointerPoint.dy / size.height).clamp(0.0, 1.0);
    final bend = (pointerY - yBase) * size.height * 0.18 * pointerPull;
    final horizontalBend = (pointerX - 0.5) * size.width * 0.08 * pointerPull;
    final idleA = math.sin(theta) * size.height * 0.045;
    final idleB = math.cos(theta * 0.82) * size.height * 0.055;

    final path = Path()
      ..moveTo(-size.width * 0.16, size.height * yBase + idleA * 0.42)
      ..cubicTo(
        size.width * 0.16 + horizontalBend,
        size.height * (yBase - 0.15) - idleB,
        size.width * 0.34 + horizontalBend,
        size.height * (yBase + 0.15) + bend,
        size.width * 0.52,
        size.height * yBase - idleA + bend,
      )
      ..cubicTo(
        size.width * 0.70 - horizontalBend,
        size.height * (yBase - 0.12) + idleB,
        size.width * 0.88 - horizontalBend,
        size.height * (yBase + 0.10) - bend * 0.45,
        size.width * 1.14,
        size.height * (yBase - 0.04) + idleA * 0.36,
      );

    final strokeWidth = size.shortestSide * strokeScale;
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..shader = ui.Gradient.linear(
        Offset(0, size.height * yBase),
        Offset(size.width, size.height * (yBase - 0.04)),
        colors,
        const [0.0, 0.18, 0.50, 0.82, 1.0],
      )
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blurSigma);

    final corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.2, strokeWidth * 0.12)
      ..shader = ui.Gradient.linear(
        Offset(0, size.height * yBase),
        Offset(size.width, size.height * yBase),
        [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.18),
          Colors.transparent,
        ],
        const [0.0, 0.5, 1.0],
      )
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 6);

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, corePaint);
  }

  void _paintParticles(
    Canvas canvas,
    Size size,
    Offset pointerPoint,
    double pointerPull,
  ) {
    final paint = Paint()..style = PaintingStyle.fill;
    final time = progress * math.pi * 2;

    for (final seed in _particles) {
      final base = Offset(
        seed.position.dx * size.width,
        seed.position.dy * size.height,
      );
      final drift = Offset(
        math.sin(time * seed.drift + seed.phase) * 10,
        math.cos(time * (seed.drift * 0.74) + seed.phase) * 7,
      );
      final delta = base - pointerPoint;
      final distance = delta.distance;
      final range = size.shortestSide * 0.32;
      final reaction = (1.0 - (distance / range)).clamp(0.0, 1.0);
      final pullOffset = distance == 0
          ? Offset.zero
          : delta / distance * reaction * 16 * pointerPull;
      final point = base + drift + pullOffset;
      final twinkle = 0.55 + math.sin(time * 1.4 + seed.phase) * 0.35;
      final alpha = (0.12 + reaction * 0.18 + twinkle * 0.08).clamp(0.06, 0.32);

      paint.color = Color.lerp(
        const Color(0xFFDBEAFE),
        const Color(0xFF67E8F9),
        reaction,
      )!
          .withValues(alpha: alpha);
      canvas.drawCircle(point, seed.radius + reaction * 1.6, paint);
    }
  }

  void _paintFallbackDust(Canvas canvas, Size size, double pulse) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFBAE6FD).withValues(alpha: 0.08 + pulse * 0.02);
    for (var i = 0; i < 18; i++) {
      final seed = _particles[i * 2];
      canvas.drawCircle(
        Offset(seed.position.dx * size.width, seed.position.dy * size.height),
        seed.radius,
        paint,
      );
    }
  }

  void _paintFineTexture(Canvas canvas, Rect rect) {
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.025);

    for (double y = rect.top + 24; y < rect.bottom; y += 38) {
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _InstructOSAuthBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.pointer != pointer ||
        oldDelegate.reducedEffects != reducedEffects;
  }
}

class _ParticleSeed {
  final Offset position;
  final double radius;
  final double phase;
  final double drift;

  const _ParticleSeed({
    required this.position,
    required this.radius,
    required this.phase,
    required this.drift,
  });
}
