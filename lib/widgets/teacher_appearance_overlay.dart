import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:provider/provider.dart';
import 'package:gradeflow/services/teacher_appearance_controller.dart';

/// A decorative, non-intercepting ambient layer for every OS page.
/// Faint over opaque pages and stronger in transparent regions.
/// Paints over a workspace while allowing all pointer input through.
/// The shell owns pointer tracking so the effect cannot intercept controls.
class TeacherAppearanceOverlay extends StatelessWidget {
  const TeacherAppearanceOverlay({super.key, required this.pointer});

  final ValueListenable<Offset?> pointer;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<TeacherAppearanceController>();
    if (!settings.enabled || settings.background == 'minimal' ||
        settings.intensity == 0) {
      return const SizedBox.expand();
    }
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final brightness = Theme.of(context).brightness;
    return IgnorePointer(
      child: RepaintBoundary(
        child: ValueListenableBuilder<Offset?>(
          valueListenable: pointer,
          builder: (_, position, __) => CustomPaint(
            painter: _AmbientPainter(
              background: settings.background,
              accent: settings.accentColor,
              strength: settings.intensity,
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
    // Foreground overlay intentionally restrained to protect grades/text.
    final opacity = strength * (light ? 0.10 : 0.13);
    switch (background) {
      case 'boxes':
        final step = size.width < 600 ? 44.0 : 58.0;
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = accent.withValues(alpha: opacity * 0.65);
        for (double x = 0; x < size.width; x += step) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        }
        for (double y = 0; y < size.height; y += step) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
        if (pointer != null) {
          final x = (pointer!.dx / step).floor() * step;
          final y = (pointer!.dy / step).floor() * step;
          final tile = Rect.fromLTWH(x, y, step, step);
          canvas.drawRect(tile, Paint()
            ..color = accent.withValues(alpha: math.min(0.23, opacity * 1.5)));
          canvas.drawRect(tile, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = accent.withValues(alpha: math.min(0.50, opacity * 3)));
        }
        break;
      case 'dots':
        final paint = Paint()..color = accent.withValues(alpha: opacity);
        for (double x = 24; x < size.width; x += 33) {
          for (double y = 24; y < size.height; y += 33) {
            final p = Offset(x, y);
            final proximity = pointer == null ? 0.0
                : (1.0 - ((p - pointer!).distance / 140)).clamp(0.0, 1.0);
            canvas.drawCircle(p, 0.8 + proximity * 2, paint);
          }
        }
        break;
      case 'aurora':
        final center = pointer ?? Offset(size.width * 0.52, size.height * 0.22);
        canvas.drawRect(Offset.zero & size, Paint()
          ..shader = RadialGradient(
            center: Alignment(
              (center.dx / size.width) * 2 - 1,
              (center.dy / size.height) * 2 - 1,
            ),
            radius: 1.5,
            colors: [
              accent.withValues(alpha: opacity * 1.8),
              accent.withValues(alpha: opacity * 0.50),
              Colors.transparent,
            ],
          ).createShader(Offset.zero & size));
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter other) =>
      other.background != background || other.accent != accent ||
      other.strength != strength || other.light != light ||
      other.pointer != pointer;
}
