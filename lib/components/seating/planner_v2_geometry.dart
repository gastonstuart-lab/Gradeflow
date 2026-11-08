import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gradeflow/models/seating_layout.dart';

/// Pointer-to-room geometry for the next Arrange Mode. This class is pure:
/// it cannot save, mutate a layout, alter seat assignments or move a camera.
///
/// All pointer values use the local viewport coordinate system. A snapshot of
/// the view transform is fixed for each gesture so resizing the browser does
/// not silently change the drag calculation midway through a gesture.
class PlannerV2Geometry {
  const PlannerV2Geometry._();

  static Offset roomPoint(Matrix4 viewTransform, Offset viewportPoint) {
    final determinant = viewTransform.determinant();
    if (!determinant.isFinite || determinant.abs() < 1e-10) {
      throw ArgumentError.value(
          viewTransform, 'viewTransform', 'Must be invertible');
    }
    return MatrixUtils.transformPoint(
      Matrix4.inverted(viewTransform),
      viewportPoint,
    );
  }

  static PlannerV2Gesture begin({
    required SeatingTable table,
    required Offset pointer,
    required Matrix4 viewTransform,
    required Size roomSize,
    required PlannerV2Action action,
    double minWidth = 40,
    double minHeight = 40,
  }) {
    if (roomSize.width <= 0 ||
        roomSize.height <= 0 ||
        !roomSize.width.isFinite ||
        !roomSize.height.isFinite) {
      throw ArgumentError.value(roomSize, 'roomSize', 'Must be positive');
    }
    if (minWidth <= 0 || minHeight <= 0) {
      throw ArgumentError('Minimum table size must be positive');
    }
    return PlannerV2Gesture._(
      table: table,
      startRoomPointer: roomPoint(viewTransform, pointer),
      viewTransform: Matrix4.copy(viewTransform),
      roomSize: roomSize,
      action: action,
      minWidth: minWidth,
      minHeight: minHeight,
    );
  }
}

enum PlannerV2Action { move, resizeBottomRight }

/// An immutable snapshot of the original geometry plus a gesture transform.
///
/// Update returns a new table *proposal*; the caller previews it while moving
/// and commits exactly once on pointer-up. Cancelling discards the proposal.
class PlannerV2Gesture {
  PlannerV2Gesture._({
    required this.table,
    required this.startRoomPointer,
    required this.viewTransform,
    required this.roomSize,
    required this.action,
    required this.minWidth,
    required this.minHeight,
  });

  final SeatingTable table;
  final Offset startRoomPointer;
  final Matrix4 viewTransform;
  final Size roomSize;
  final PlannerV2Action action;
  final double minWidth;
  final double minHeight;

  SeatingTable update(Offset viewportPointer) {
    final current =
        PlannerV2Geometry.roomPoint(viewTransform, viewportPointer);
    final delta = current - startRoomPointer;
    if (action == PlannerV2Action.move) {
      return table.copyWith(
        x: _clampCentre(table.x + delta.dx, table.width, roomSize.width),
        y: _clampCentre(table.y + delta.dy, table.height, roomSize.height),
      );
    }

    // Resize from the bottom-right, anchoring the top-left in room space.
    // The table's surrounding seats retain their own saved local positions;
    // future seat reflow must be an explicit, independently undoable action.
    final left = table.x - table.width / 2;
    final top = table.y - table.height / 2;
    final width = (table.width + delta.dx)
        .clamp(math.min(minWidth, roomSize.width - left), roomSize.width - left)
        .toDouble();
    final height = (table.height + delta.dy)
        .clamp(math.min(minHeight, roomSize.height - top), roomSize.height - top)
        .toDouble();
    return table.copyWith(
      x: left + width / 2,
      y: top + height / 2,
      width: width,
      height: height,
    );
  }

  static double _clampCentre(double position, double span, double roomSpan) {
    if (span >= roomSpan) return roomSpan / 2;
    return position.clamp(span / 2, roomSpan - span / 2).toDouble();
  }
}
