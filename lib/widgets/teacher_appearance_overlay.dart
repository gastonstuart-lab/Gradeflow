import 'dart:math' as math;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/services/teacher_appearance_controller.dart';

/// A decorative underlay painted behind the OS, never over controls.
///
/// All surfaces may use the teacher's chosen BACKGROUND effect. Dense pages attenuate
/// intensity automatically, and fullscreen teaching screens are opt-in.
class TeacherAppearanceOverlay extends StatelessWidget {
  const TeacherAppearanceOverlay({
    super.key,
    required this.pointer,
    this.attenuation = 1.0,
    this.teachMode = false,
  });

  final ValueListenable<Offset?> pointer;
  final double attenuation;
  final bool teachMode;

  @override
  Widget build(BuildContext context) {
    // OS shell is also rendered in isolated widget tests and design previews.
    // Missing preferences should behave exactly like the original no-effect UI.
    final settings = context.watch<TeacherAppearanceController?>();
    if (settings == null) return const SizedBox.expand();
    final amount = settings.intensity * attenuation.clamp(0.0, 1.0);
    if (!settings.enabled || settings.background == 'minimal' ||
        amount <= 0 || (teachMode && !settings.showInTeachMode)) {
      return const SizedBox.expand();
    }
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final brightness = Theme.of(context).brightness;
    return IgnorePointer(
      ignoring: true,
      child: RepaintBoundary(
        child: ValueListenableBuilder<Offset?>(
          valueListenable: pointer,
          builder: (_, position, __) => CustomPaint(
            painter: _AmbientPainter(
              background: settings.background,
              accent: settings.backgroundGlowColor,
              strength: amount,
              light: brightness == Brightness.light,
              pointer: reducedMotion ? null : position,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  const _AmbientPainter({
    required this.background,
    required this.accent,
    required this.strength,
    required this.light,
    required this.pointer,
  });

  final String background;
  final Color accent;
  final double strength;
  final bool light;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    switch (background) {
      case 'boxes':
        _paintBoxes(canvas, size);
        break;
      case 'dots':
        _paintDots(canvas, size);
        break;
      case 'aurora':
        _paintAurora(canvas, size);
        break;
    }
  }

  void _paintBoxes(Canvas canvas, Size size) {
    final step = size.width < 600 ? 44.0 : 56.0;
    final baseAlpha = strength * (light ? 0.11 : 0.16);
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .75
      ..color = accent.withValues(alpha: baseAlpha);
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final hover = pointer;
    if (hover == null) return;
    if (hover.dx < 0 || hover.dy < 0 ||
        hover.dx > size.width || hover.dy > size.height) return;

    final column = (hover.dx / step).floor();
    final row = (hover.dy / step).floor();
    // Small, 5x5 highlight radius like the accepted web preview.
    // Only hovered cells get blur; the rest of the grid is inexpensive.
    for (var dy = -2; dy <= 2; dy++) {
      for (var dx = -2; dx <= 2; dx++) {
        final distance = math.sqrt((dx * dx + dy * dy).toDouble());
        if (distance > 2.55) continue;
        final x = (column + dx) * step;
        final y = (row + dy) * step;
        if (x < -step || y < -step ||
            x > size.width || y > size.height) continue;
        final falloff = (1.0 - distance / 3.0);
        final activeAlpha = strength *
            (light ? .22 : .30) * falloff;
        final rect = Rect.fromLTWH(x + 1.2, y + 1.2, step - 2.4, step - 2.4);
        canvas.drawRect(
          rect,
          Paint()..color = accent.withValues(alpha: activeAlpha),
        );
        canvas.drawRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = distance < 1 ? 1.45 : .8
            ..color = accent.withValues(
              alpha: math.min(.78, activeAlpha * 2.2),
            )
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              distance < 1 ? 7.5 : 3.0,
            ),
        );
        canvas.drawRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = distance < 1 ? 1.35 : .8
            ..color = accent.withValues(
              alpha: math.min(.85, activeAlpha * 2.4),
            ),
        );
      }
    }
  }

  void _paintDots(Canvas canvas, Size size) {
    final alpha = strength * (light ? .12 : .20);
    for (double x = 22; x < size.width; x += 28) {
      for (double y = 22; y < size.height; y += 28) {
        final p = Offset(x, y);
        final proximity = pointer == null ? 0.0
            : (1.0 - (p - pointer!).distance / 135).clamp(0.0, 1.0);
        canvas.drawCircle(
          p,
          .8 + 1.6 * proximity,
          Paint()
            ..color = accent.withValues(
              alpha: math.min(.55, alpha + proximity * .26 * strength),
            ),
        );
      }
    }
  }

  void _paintAurora(Canvas canvas, Size size) {
    final center = pointer ?? Offset(size.width * .52, size.height * .24);
    final focal = Alignment(
      (center.dx / size.width) * 2 - 1,
      (center.dy / size.height) * 2 - 1,
    );
    final alpha = strength * (light ? .15 : .20);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = RadialGradient(
        center: focal,
        radius: 1.25,
        colors: [
          accent.withValues(alpha: alpha),
          const Color(0xFF22D3EE).withValues(alpha: alpha * .47),
          Colors.transparent,
        ],
        stops: const [0, .38, 1],
      ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter other) =>
      other.background != background || other.accent != accent ||
      other.strength != strength || other.light != light ||
      other.pointer != pointer;
}
