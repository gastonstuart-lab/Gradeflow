import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Cinematic aurora backdrop with soft motion and a designed pattern layer.
class AnimatedPageBackground extends StatefulWidget {
  final Widget child;

  const AnimatedPageBackground({
    super.key,
    required this.child,
  });

  @override
  State<AnimatedPageBackground> createState() => _AnimatedPageBackgroundState();
}

class _AnimatedPageBackgroundState extends State<AnimatedPageBackground>
    with SingleTickerProviderStateMixin {
  static const Duration _animationDuration = Duration(seconds: 32);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _animationDuration,
  );

  bool _animationsDisabled = false;

  @override
  void initState() {
    super.initState();
    _controller.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (disableAnimations == _animationsDisabled) {
      if (!disableAnimations && !_controller.isAnimating) {
        _controller.repeat();
      }
      return;
    }

    _animationsDisabled = disableAnimations;
    if (_animationsDisabled) {
      _controller
        ..stop()
        ..value = 0.22;
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final longestSide =
              math.max(size.width, size.height).clamp(720.0, 1800.0).toDouble();

          return ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _baseGradient(theme),
                      stops: const [0.0, 0.56, 1.0],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _AmbientPatternPainter(theme: theme),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final t =
                            _animationsDisabled ? 0.22 : _controller.value;
                        final theta = t * math.pi * 2;

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            CustomPaint(
                              painter: _AuroraRibbonPainter(
                                theme: theme,
                                progress: t,
                              ),
                            ),
                            _buildGlowCloud(
                              width: longestSide * 0.78,
                              height: longestSide * 0.48,
                              alignment: Alignment(
                                -0.98 + (0.16 * math.sin(theta * 0.90)),
                                -0.88 + (0.14 * math.cos(theta * 0.64)),
                              ),
                              angle: -0.28,
                              innerColor: _primaryGlow(theme),
                              middleColor: _primaryGlow(theme, middle: true),
                              blurSigma: 66,
                            ),
                            _buildGlowCloud(
                              width: longestSide * 0.66,
                              height: longestSide * 0.36,
                              alignment: Alignment(
                                0.92 + (0.12 * math.cos(theta * 0.82)),
                                -0.24 + (0.16 * math.sin(theta * 0.53)),
                              ),
                              angle: 0.36,
                              innerColor: _skyGlow(theme),
                              middleColor: _skyGlow(theme, middle: true),
                              blurSigma: 58,
                            ),
                            _buildGlowCloud(
                              width: longestSide * 0.92,
                              height: longestSide * 0.44,
                              alignment: Alignment(
                                0.12 + (0.16 * math.sin(theta * 0.47)),
                                1.02 + (0.08 * math.cos(theta * 0.78)),
                              ),
                              angle: -0.12,
                              innerColor: _cyanGlow(theme),
                              middleColor: _cyanGlow(theme, middle: true),
                              blurSigma: 72,
                            ),
                            _buildBeam(
                              width: longestSide * 1.20,
                              height: longestSide * 0.16,
                              alignment: Alignment(
                                -0.12 + (0.08 * math.cos(theta * 0.44)),
                                0.04 + (0.08 * math.sin(theta * 0.39)),
                              ),
                              angle: -0.36 + (0.07 * math.sin(theta * 0.27)),
                              color: _beamGlow(theme),
                            ),
                          ],
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
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.22, 0.65, 1.0],
                          colors: [
                            theme.colorScheme.surface.withValues(
                              alpha: theme.brightness == Brightness.dark
                                  ? 0.16
                                  : 0.24,
                            ),
                            Colors.transparent,
                            Colors.transparent,
                            theme.colorScheme.surface.withValues(
                              alpha: theme.brightness == Brightness.dark
                                  ? 0.22
                                  : 0.12,
                            ),
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
                          center: const Alignment(0, -0.1),
                          radius: 1.05,
                          colors: [
                            Colors.transparent,
                            theme.colorScheme.shadow.withValues(
                              alpha: theme.brightness == Brightness.dark
                                  ? 0.18
                                  : 0.05,
                            ),
                          ],
                          stops: const [0.68, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                widget.child,
              ],
            ),
          );
        },
      ),
    );
  }

  List<Color> _baseGradient(ThemeData theme) {
    final background = theme.scaffoldBackgroundColor;
    final surface = theme.colorScheme.surface;
    final lowSurface = theme.colorScheme.surfaceContainerLowest;

    if (theme.brightness == Brightness.dark) {
      return [
        Color.lerp(background, const Color(0xFF11203A), 0.42)!,
        Color.lerp(background, surface, 0.92)!,
        Color.lerp(background, lowSurface, 0.96)!,
      ];
    }

    return [
      Color.lerp(background, Colors.white, 0.42)!,
      Color.lerp(background, const Color(0xFFE9F4FF), 0.82)!,
      Color.lerp(background, const Color(0xFFF2FBFF), 0.88)!,
    ];
  }

  Color _primaryGlow(ThemeData theme, {bool middle = false}) {
    final alpha = theme.brightness == Brightness.dark
        ? (middle ? 0.12 : 0.24)
        : (middle ? 0.05 : 0.12);
    return theme.colorScheme.primary.withValues(alpha: alpha);
  }

  Color _skyGlow(ThemeData theme, {bool middle = false}) {
    const sky = Color(0xFF60A5FA);
    final alpha = theme.brightness == Brightness.dark
        ? (middle ? 0.10 : 0.18)
        : (middle ? 0.05 : 0.10);
    return sky.withValues(alpha: alpha);
  }

  Color _cyanGlow(ThemeData theme, {bool middle = false}) {
    const cyan = Color(0xFF06B6D4);
    final alpha = theme.brightness == Brightness.dark
        ? (middle ? 0.09 : 0.16)
        : (middle ? 0.04 : 0.08);
    return cyan.withValues(alpha: alpha);
  }

  Color _beamGlow(ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? const Color(0xFF93C5FD).withValues(alpha: 0.10)
        : const Color(0xFFE0F2FE).withValues(alpha: 0.40);
  }

  Widget _buildGlowCloud({
    required double width,
    required double height,
    required Alignment alignment,
    required double angle,
    required Color innerColor,
    required Color middleColor,
    required double blurSigma,
  }) {
    return Align(
      alignment: alignment,
      child: Transform.rotate(
        angle: angle,
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
            sigmaX: blurSigma,
            sigmaY: blurSigma,
          ),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height),
              gradient: RadialGradient(
                colors: [
                  innerColor,
                  middleColor,
                  Colors.transparent,
                ],
                stops: const [0.0, 0.52, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBeam({
    required double width,
    required double height,
    required Alignment alignment,
    required double angle,
    required Color color,
  }) {
    return Align(
      alignment: alignment,
      child: Transform.rotate(
        angle: angle,
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height),
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  color,
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AmbientPatternPainter extends CustomPainter {
  final ThemeData theme;

  const _AmbientPatternPainter({
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final isDark = theme.brightness == Brightness.dark;
    final rect = Offset.zero & size;

    final framePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = ui.Gradient.linear(
        rect.topLeft,
        rect.bottomRight,
        [
          theme.colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.11),
          Colors.transparent,
          const Color(0xFF06B6D4).withValues(alpha: isDark ? 0.14 : 0.09),
        ],
        const [0.0, 0.52, 1.0],
      );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(18), const Radius.circular(30)),
      framePaint,
    );

    final ringA = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color =
          theme.colorScheme.primary.withValues(alpha: isDark ? 0.12 : 0.07);
    final ringB = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = const Color(0xFF38BDF8).withValues(alpha: isDark ? 0.12 : 0.08);

    canvas.drawCircle(
      Offset(size.width * 1.04, -size.height * 0.04),
      size.width * 0.38,
      ringA,
    );
    canvas.drawCircle(
      Offset(size.width * 0.96, -size.height * 0.08),
      size.width * 0.31,
      ringB,
    );
    canvas.drawCircle(
      Offset(-size.width * 0.10, size.height * 1.02),
      size.width * 0.46,
      ringB,
    );

    final contourPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color =
          theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.10 : 0.045);

    for (var i = 0; i < 6; i++) {
      final y = size.height * (0.60 + (i * 0.055));
      final path = Path()
        ..moveTo(-size.width * 0.06, y)
        ..quadraticBezierTo(
          size.width * 0.26,
          y - (26 + i * 5),
          size.width * 0.58,
          y - (8 + i * 3),
        )
        ..quadraticBezierTo(
          size.width * 0.88,
          y + (18 - i * 2),
          size.width * 1.05,
          y - (20 - i * 2),
        );
      canvas.drawPath(path, contourPaint);
    }

    final baseDotColor =
        theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.055 : 0.028);
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = baseDotColor;
    final spacing = size.shortestSide < 720 ? 34.0 : 42.0;

    for (double y = 28; y < size.height * 0.86; y += spacing) {
      final rowFactor = 1.0 - ((y / size.height) * 0.85);
      final opacity = math.max(0.0, rowFactor) * (isDark ? 1.0 : 0.85);
      for (double x = 24; x < size.width; x += spacing) {
        final shift = ((x / spacing).floor().isEven ? 0.0 : spacing * 0.32);
        final point = Offset(x + shift, y);
        canvas.drawCircle(
          point,
          1.0,
          dotPaint
            ..color = baseDotColor.withValues(alpha: baseDotColor.a * opacity),
        );
      }
    }

    final accentPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.86, size.height * 0.20),
        size.width * 0.08,
        [
          theme.colorScheme.primary.withValues(alpha: isDark ? 0.16 : 0.11),
          Colors.transparent,
        ],
      );
    canvas.drawCircle(
      Offset(size.width * 0.86, size.height * 0.20),
      size.width * 0.08,
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _AmbientPatternPainter oldDelegate) {
    return oldDelegate.theme.brightness != theme.brightness ||
        oldDelegate.theme.colorScheme.primary != theme.colorScheme.primary ||
        oldDelegate.theme.colorScheme.onSurface != theme.colorScheme.onSurface;
  }
}

class _AuroraRibbonPainter extends CustomPainter {
  final ThemeData theme;
  final double progress;

  const _AuroraRibbonPainter({
    required this.theme,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintRibbon(
      canvas,
      size,
      phase: 0.0,
      anchorY: size.height * 0.16,
      endY: size.height * 0.08,
      strokeWidth: size.shortestSide * 0.09,
      blurSigma: 36,
      colors: [
        Colors.transparent,
        theme.colorScheme.primary.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.30 : 0.18,
        ),
        const Color(0xFF60A5FA).withValues(
          alpha: theme.brightness == Brightness.dark ? 0.22 : 0.16,
        ),
        const Color(0xFF22D3EE).withValues(
          alpha: theme.brightness == Brightness.dark ? 0.18 : 0.12,
        ),
        Colors.transparent,
      ],
    );

    _paintRibbon(
      canvas,
      size,
      phase: 0.42,
      anchorY: size.height * 0.74,
      endY: size.height * 0.64,
      strokeWidth: size.shortestSide * 0.07,
      blurSigma: 28,
      colors: [
        Colors.transparent,
        const Color(0xFF2DD4BF).withValues(
          alpha: theme.brightness == Brightness.dark ? 0.16 : 0.09,
        ),
        const Color(0xFF38BDF8).withValues(
          alpha: theme.brightness == Brightness.dark ? 0.18 : 0.10,
        ),
        theme.colorScheme.primary.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.16 : 0.08,
        ),
        Colors.transparent,
      ],
    );
  }

  void _paintRibbon(
    Canvas canvas,
    Size size, {
    required double phase,
    required double anchorY,
    required double endY,
    required double strokeWidth,
    required double blurSigma,
    required List<Color> colors,
  }) {
    final theta = (progress + phase) * math.pi * 2;
    final ySwingA = math.sin(theta) * size.height * 0.08;
    final ySwingB = math.cos(theta * 1.14) * size.height * 0.06;
    final ySwingC = math.sin(theta * 0.72) * size.height * 0.07;

    final path = Path()
      ..moveTo(-size.width * 0.16, anchorY + ySwingA * 0.18)
      ..cubicTo(
        size.width * 0.10,
        anchorY - ySwingA,
        size.width * 0.34,
        anchorY + ySwingB,
        size.width * 0.56,
        anchorY - ySwingC,
      )
      ..cubicTo(
        size.width * 0.78,
        endY + ySwingA * 0.30,
        size.width * 0.94,
        endY - ySwingB * 0.45,
        size.width * 1.12,
        endY + ySwingC * 0.18,
      );

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..shader = ui.Gradient.linear(
        Offset(0, anchorY),
        Offset(size.width, endY),
        colors,
        const [0.0, 0.22, 0.55, 0.82, 1.0],
      )
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blurSigma);

    final corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth * 0.22
      ..shader = ui.Gradient.linear(
        Offset(0, anchorY),
        Offset(size.width, endY),
        [
          Colors.transparent,
          Colors.white.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.08 : 0.18,
          ),
          Colors.transparent,
        ],
        const [0.0, 0.5, 1.0],
      )
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blurSigma * 0.28);

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, corePaint);
  }

  @override
  bool shouldRepaint(covariant _AuroraRibbonPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.theme.brightness != theme.brightness ||
        oldDelegate.theme.colorScheme.primary != theme.colorScheme.primary;
  }
}
