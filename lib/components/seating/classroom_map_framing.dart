import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gradeflow/models/seating_layout.dart';

/// Frames the *saved* furniture rather than a fictional preview layout.
/// Read-only: never changes table coordinates, seat coordinates or identifiers.
class ClassroomMapFraming {
  /// Fit the *occupied furniture*, not the entire historical room extent.
  /// The saved room coordinates are unchanged: this is only a camera matrix.
  /// A caller in Arrange Mode can constrain positive camera translation so
  /// every on-screen point is reachable by the 0-based room geometry.
  static Matrix4 plannerRoom(SeatingLayout layout, Size viewport) {
    if (!viewport.width.isFinite ||
        !viewport.height.isFinite ||
        viewport.width <= 0 ||
        viewport.height <= 0) {
      return Matrix4.identity();
    }
    if (layout.tables.isEmpty) {
      final roomWidth = math.max(1.0, layout.canvasWidth);
      final roomHeight = math.max(1.0, layout.canvasHeight);
      final scale = math.min(2.6,
          math.min(viewport.width / roomWidth, viewport.height / roomHeight));
      return Matrix4.identity()
        ..setEntry(0, 0, scale)
        ..setEntry(1, 1, scale);
    }
    return fit(layout, viewport, compact: true);
  }

  /// Keep the logical point under the viewport centre stationary during
  /// button zoom, rather than resetting pan to (0,0) every time.
  static Matrix4 zoomKeepingCentre(
    Matrix4 current,
    Size viewport,
    double targetScale, {
    bool zeroBasedFloor = false,
  }) {
    final oldScale = current.getMaxScaleOnAxis();
    if (oldScale <= 0 || !oldScale.isFinite ||
        targetScale <= 0 || !targetScale.isFinite) {
      return Matrix4.copy(current);
    }
    final cx = viewport.width / 2;
    final cy = viewport.height / 2;
    final roomX = (cx - current.entry(0, 3)) / oldScale;
    final roomY = (cy - current.entry(1, 3)) / oldScale;
    var tx = cx - roomX * targetScale;
    var ty = cy - roomY * targetScale;
    if (zeroBasedFloor) {
      tx = math.min(0, tx);
      ty = math.min(0, ty);
    }
    return Matrix4.identity()
      ..setEntry(0, 0, targetScale)
      ..setEntry(1, 1, targetScale)
      ..setEntry(0, 3, tx)
      ..setEntry(1, 3, ty);
  }

  /// Derive world extents from the actual camera transform. The previous V2
  /// implementation divided screen dimensions by scale but ignored camera
  /// translation, incorrectly clipping free table and chair movement.
  static Size visibleWorkspace(
      SeatingLayout layout, Size viewport, Matrix4 transform) {
    final scale = transform.getMaxScaleOnAxis();
    if (scale <= 0 || !scale.isFinite) {
      return Size(layout.canvasWidth, layout.canvasHeight);
    }
    return Size(
      math.max(layout.canvasWidth,
          (viewport.width - transform.entry(0, 3)) / scale),
      math.max(layout.canvasHeight,
          (viewport.height - transform.entry(1, 3)) / scale),
    );
  }

  static Matrix4 fit(SeatingLayout layout, Size viewport, {bool compact = false}) {
    if (!viewport.width.isFinite ||
        !viewport.height.isFinite ||
        viewport.width <= 0 ||
        viewport.height <= 0) {
      return Matrix4.identity();
    }

    final bounds = roomBounds(layout, compact: compact);
    final left = bounds.left;
    final top = bounds.top;
    final right = bounds.right;
    final bottom = bounds.bottom;
    final contentWidth = math.max(1.0, right - left);
    final contentHeight = math.max(1.0, bottom - top);
    final width = math.max(1.0, viewport.width - (compact ? 16 : 32));
    final height = math.max(1.0, viewport.height - (compact ? 16 : 32));
    final scale = math.min(
        compact ? 2.6 : 2.0,
        math.max(
            0.001, math.min(width / contentWidth, height / contentHeight)));
    final dx = (viewport.width - contentWidth * scale) / 2 - left * scale;
    final dy = (viewport.height - contentHeight * scale) / 2 - top * scale;
    return Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(2, 2, scale)
      ..setEntry(0, 3, dx)
      ..setEntry(1, 3, dy);
  }

  /// Decorative room shell around actual furniture; no persisted geometry changes.
  static Rect roomBounds(SeatingLayout layout, {bool compact = false}) {
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
        for (final seat
            in layout.seats.where((s) => s.tableId == table.tableId)) {
          left = math.min(left, table.x + seat.x - 40);
          right = math.max(right, table.x + seat.x + 40);
          top = math.min(top, table.y + seat.y - 40);
          bottom = math.max(bottom, table.y + seat.y + 40);
        }
      }
      // An open floor needs breathing room around furniture, not an extra
      // decorative room border. Keep the default historic fit unchanged.
      left -= compact ? 55 : 105;
      right += compact ? 55 : 105;
      top -= compact ? 75 : 125;
      bottom += compact ? 55 : 105;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }
}
