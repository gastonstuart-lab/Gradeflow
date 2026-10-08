import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Materials shared by the teaching room and its presentation view.
/// Furniture dimensions, hit targets and seat assignments live in the room.
class TeachingPreviewSurfaces {
  static Color boundary(bool dark) =>
      dark ? const Color(0xff3c555c) : const Color(0xffaabbb5);

  static BoxDecoration floor(bool dark) => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xff21343c), Color(0xff14252d), Color(0xff112129)]
              : const [Color(0xfff0f0e7), Color(0xffe3e8df), Color(0xffd4ded7)],
          stops: const [0, .5, 1],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: boundary(dark)),
        boxShadow: [
          BoxShadow(
            color: dark ? const Color(0x6604090e) : const Color(0x242c4742),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      );

  static BoxDecoration tabletop(bool dark, bool spotlight) => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: spotlight
              ? (dark
                  ? const [Color(0xffb89a63), Color(0xff8e6f43)]
                  : const [Color(0xffefd2a1), Color(0xffcda05c)])
              : (dark
                  ? const [
                      Color(0xffb9a27e),
                      Color(0xffa38d68),
                      Color(0xff927b58)
                    ]
                  : const [
                      Color(0xffe1cfac),
                      Color(0xffd1ba94),
                      Color(0xffc2a67d)
                    ]),
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: spotlight
              ? const Color(0xffe5b85f)
              : dark
                  ? const Color(0xffc2a67c)
                  : const Color(0xffb69b73),
          width: spotlight ? 2 : 1.2,
        ),
        boxShadow: [
          // The close edge and darker frame give thickness without growing
          // the furniture footprint or introducing legs among the seats.
          BoxShadow(
            color: dark ? const Color(0xff654d32) : const Color(0xffab8e63),
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: dark ? const Color(0xff101e24) : const Color(0xff64766f),
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: dark ? const Color(0x66070d11) : const Color(0x3d3a4a42),
            blurRadius: 14,
            offset: const Offset(0, 11),
          ),
        ],
      );
}

/// Quiet directional light, wall skirting and floor joints; no new fixtures.
class TeachingPreviewFloorPainter extends CustomPainter {
  final bool dark;
  const TeachingPreviewFloorPainter(this.dark);

  @override
  void paint(Canvas canvas, Size size) {
    final bounds =
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18));
    canvas.save();
    canvas.clipRRect(bounds);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-1, -.55),
          radius: 1.3,
          colors: [
            dark ? const Color(0x123eb2ab) : const Color(0x70fffdf0),
            Colors.transparent,
          ],
        ).createShader(Offset.zero & size),
    );
    final joint = Paint()
      ..color = dark ? const Color(0x0df1f6ec) : const Color(0x146c8378)
      ..strokeWidth = .7;
    // Spacious, low-contrast joints follow the room rather than its tables.
    for (var x = 180.0; x < size.width; x += 240) {
      canvas.drawLine(Offset(x, 12), Offset(x, size.height - 12), joint);
    }
    final skirt = Paint()
      ..color = dark ? const Color(0x332e494f) : const Color(0x2490a59b)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7;
    canvas.drawRRect(bounds.deflate(5), skirt);
    canvas.drawLine(
      const Offset(18, 9),
      Offset(size.width - 18, 9),
      Paint()
        ..color = dark ? const Color(0x405c7978) : const Color(0xaafffdf1)
        ..strokeWidth = 1,
    );
    // These are the existing boundary fixtures, expressed as inset materials
    // instead of floating captions. They never participate in seating layout.
    final frame = Paint()
      ..color = dark ? const Color(0xff486065) : const Color(0xff9eb2a8);
    final glass = Paint()
      ..color = dark ? const Color(0xff294b54) : const Color(0xffa9c8c4);
    final highlight = Paint()
      ..color = dark ? const Color(0xff607e80) : const Color(0xffe1eee6);
    final gap = math.max(0.0, (size.height - 44 - 162) / 4);
    for (var i = 0; i < 3; i++) {
      final y = 22 + gap + i * (54 + gap);
      final window = RRect.fromRectAndRadius(
          Rect.fromLTWH(4, y, 12, 54), const Radius.circular(2));
      canvas.drawRRect(window, frame);
      canvas.drawRect(Rect.fromLTWH(6, y + 2, 8, 50), glass);
      canvas.drawLine(
          Offset(6, y + 27), Offset(14, y + 27), highlight..strokeWidth = 1.2);
      canvas.drawLine(
          Offset(6, y + 2), Offset(6, y + 51), highlight..strokeWidth = .7);
    }
    final door = Rect.fromLTWH(size.width - 16, 24, 12, 68);
    canvas.drawRRect(
        RRect.fromRectAndRadius(door, const Radius.circular(2)), frame);
    canvas.drawRect(
        door.deflate(2),
        Paint()
          ..color = dark ? const Color(0xff33494e) : const Color(0xffbccbbf));
    canvas.drawCircle(Offset(size.width - 7, 60), 1.4,
        Paint()..color = const Color(0xffb1986d));
    final storage = Rect.fromLTWH(size.width - 138, size.height - 26, 116, 17);
    canvas.drawRRect(
        RRect.fromRectAndRadius(storage, const Radius.circular(2)), frame);
    canvas.drawRect(
        storage.deflate(1.5),
        Paint()
          ..color = dark ? const Color(0xff30444a) : const Color(0xffbac9bd));
    canvas.drawLine(
        Offset(storage.center.dx, storage.top + 2),
        Offset(storage.center.dx, storage.bottom - 2),
        Paint()
          ..color = dark ? const Color(0xff1a2b33) : const Color(0xff91a59a));
    for (final x in [storage.center.dx - 5, storage.center.dx + 5]) {
      canvas.drawLine(
          Offset(x, storage.top + 7),
          Offset(x, storage.top + 11),
          Paint()
            ..color = dark ? const Color(0xff809592) : const Color(0xff657b70)
            ..strokeWidth = 1.2);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(TeachingPreviewFloorPainter oldDelegate) =>
      dark != oldDelegate.dark;
}

/// Low-contrast oak grain is painted inside the existing tabletop bounds.
class TeachingPreviewOakPainter extends CustomPainter {
  final int table;
  const TeachingPreviewOakPainter(this.table);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14)));
    final grain = Paint()
      ..color = const Color(0x0d6a4b2b)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .65;
    for (var line = 0; line < 10; line++) {
      final path = Path();
      for (var x = 0.0; x <= size.width + 4; x += 4) {
        final y = size.height * (line + .5) / 10 +
            math.sin(x / 58 + table * .6 + line) * 2.2;
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, grain);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(TeachingPreviewOakPainter oldDelegate) =>
      table != oldDelegate.table;
}
