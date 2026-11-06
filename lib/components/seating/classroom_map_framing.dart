import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gradeflow/models/seating_layout.dart';

/// Frames the *saved* furniture rather than a fictional preview layout.
/// Read-only: never changes table coordinates, seat coordinates or identifiers.
class ClassroomMapFraming {
  static Matrix4 fit(SeatingLayout layout, Size viewport) {
    if (!viewport.width.isFinite ||
        !viewport.height.isFinite ||
        viewport.width <= 0 ||
        viewport.height <= 0) {
      return Matrix4.identity();
    }

    var left = 0.0;
    var top = 0.0;
    var right = math.max(1.0, layout.canvasWidth);
    var bottom = math.max(1.0, layout.canvasHeight);

    if (layout.tables.isNotEmpty) {
      left = double.infinity;
      top = double.infinity;
      right = double.negativeInfinity;
      bottom = double.negativeInfinity;
      for (final table in layout.tables) {
        left = math.min(left, table.x - table.width / 2);
        right = math.max(right, table.x + table.width / 2);
        top = math.min(top, table.y - table.height / 2);
        bottom = math.max(bottom, table.y + table.height / 2);
        for (final seat in layout.seats.where((s) => s.tableId == table.tableId)) {
          left = math.min(left, table.x + seat.x - 40);
          right = math.max(right, table.x + seat.x + 40);
          top = math.min(top, table.y + seat.y - 40);
          bottom = math.max(bottom, table.y + seat.y + 40);
        }
      }
      // Keep orientation visible and provide room around seats.
      left -= 105;
      right += 105;
      top -= 125;
      bottom += 105;
    }
    final contentWidth = math.max(1.0, right - left);
    final contentHeight = math.max(1.0, bottom - top);
    final width = math.max(1.0, viewport.width - 32);
    final height = math.max(1.0, viewport.height - 32);
    final scale = math.min(2.0, math.max(0.15,
        math.min(width / contentWidth, height / contentHeight)));
    final dx = (viewport.width - contentWidth * scale) / 2 - left * scale;
    final dy = (viewport.height - contentHeight * scale) / 2 - top * scale;
    return Matrix4.identity()
      ..translate(dx, dy)
      ..scale(scale);
  }
}
