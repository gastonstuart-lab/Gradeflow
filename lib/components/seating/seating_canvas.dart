import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gradeflow/models/seating_layout.dart';
import 'package:gradeflow/models/student.dart';

const double _editorSeatAreaPadding = 180;
const double _presentationSeatAreaPadding = 120;
const double _editorSeatSize = 56;
const double _presentationSeatSize = 70;

class SeatingCanvas extends StatelessWidget {
  final SeatingLayout layout;
  final Map<String, Student> studentsById;
  final bool designMode;
  final bool interactive;
  final bool presentationMode;
  final bool showFrontMarker;
  final void Function(String tableId, Offset delta)? onMoveTable;
  final void Function(String tableId)? onRemoveTable;
  final void Function(String tableId, SeatingTableType type, int seatCount)?
      onUpdateTable;
  final void Function(String tableId)? onEditTable;
  final void Function(String tableId)? onDuplicateTable;
  final void Function(String tableId)? onRotateTable;
  final void Function(String tableId, Offset delta)? onResizeTable;
  final void Function(String seatId, Offset delta)? onMoveSeat;
  final void Function(String tableId, StudentDragData data)? onTableDrop;
  final void Function(String seatId, StudentDragData data)? onSeatDrop;
  final void Function(String seatId)? onSeatTap;

  const SeatingCanvas({
    super.key,
    required this.layout,
    required this.studentsById,
    required this.designMode,
    required this.interactive,
    required this.presentationMode,
    this.showFrontMarker = true,
    this.onMoveTable,
    this.onRemoveTable,
    this.onUpdateTable,
    this.onEditTable,
    this.onDuplicateTable,
    this.onRotateTable,
    this.onResizeTable,
    this.onMoveSeat,
    this.onTableDrop,
    this.onSeatDrop,
    this.onSeatTap,
  });

  @override
  Widget build(BuildContext context) {
    final boundary = Size(layout.canvasWidth, layout.canvasHeight);
    return RepaintBoundary(
      child: InteractiveViewer(
        maxScale: 2.6,
        minScale: 0.6,
        boundaryMargin: const EdgeInsets.all(200),
        constrained: false,
        child: SizedBox(
          width: boundary.width,
          height: boundary.height,
          child: Stack(
            children: [
              if (showFrontMarker) _FrontMarker(width: boundary.width),
              if (layout.tables.isEmpty) const _BlankCanvasHint(),
              for (final table in layout.tables)
                _SeatingTableDraggable(
                  table: table,
                  onMove: (delta) => onMoveTable?.call(table.tableId, delta),
                  onResize: (delta) =>
                      onResizeTable?.call(table.tableId, delta),
                  padding: _seatAreaPadding(presentationMode),
                  enabled: designMode,
                  child: TableWidget(
                    table: table,
                    seats: layout.seats
                        .where((seat) => seat.tableId == table.tableId)
                        .toList(),
                    studentsById: studentsById,
                    designMode: designMode,
                    interactive: interactive,
                    presentationMode: presentationMode,
                    onRemove: () => onRemoveTable?.call(table.tableId),
                    onUpdateTable: (type, count) =>
                        onUpdateTable?.call(table.tableId, type, count),
                    onEditTable: () => onEditTable?.call(table.tableId),
                    onDuplicateTable: () =>
                        onDuplicateTable?.call(table.tableId),
                    onRotateTable: () => onRotateTable?.call(table.tableId),
                    onMoveSeat: (seatId, delta) =>
                        onMoveSeat?.call(seatId, delta),
                    onTableDrop: (data) =>
                        onTableDrop?.call(table.tableId, data),
                    onSeatDrop: (seatId, data) =>
                        onSeatDrop?.call(seatId, data),
                    onSeatTap: (seatId) => onSeatTap?.call(seatId),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  double _seatAreaPadding(bool presentationMode) {
    return presentationMode
        ? _presentationSeatAreaPadding
        : _editorSeatAreaPadding;
  }
}

class TableWidget extends StatelessWidget {
  final SeatingTable table;
  final List<SeatingSeat> seats;
  final Map<String, Student> studentsById;
  final bool designMode;
  final bool interactive;
  final bool presentationMode;
  final VoidCallback? onRemove;
  final void Function(SeatingTableType type, int seatCount)? onUpdateTable;
  final VoidCallback? onEditTable;
  final VoidCallback? onDuplicateTable;
  final VoidCallback? onRotateTable;
  final void Function(String seatId, Offset delta)? onMoveSeat;
  final ValueChanged<StudentDragData>? onTableDrop;
  final void Function(String seatId, StudentDragData data)? onSeatDrop;
  final void Function(String seatId)? onSeatTap;

  const TableWidget({
    super.key,
    required this.table,
    required this.seats,
    required this.studentsById,
    required this.designMode,
    required this.interactive,
    required this.presentationMode,
    this.onRemove,
    this.onUpdateTable,
    this.onEditTable,
    this.onDuplicateTable,
    this.onRotateTable,
    this.onMoveSeat,
    this.onTableDrop,
    this.onSeatDrop,
    this.onSeatTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surface;
    final border = Theme.of(context).colorScheme.outlineVariant;
    final seatAreaPadding = presentationMode
        ? _presentationSeatAreaPadding
        : _editorSeatAreaPadding;
    final areaWidth = table.width + seatAreaPadding * 2;
    final areaHeight = table.height + seatAreaPadding * 2;
    final center = Offset(areaWidth / 2, areaHeight / 2);
    final seatSize = _seatSize(presentationMode);
    final tableLeft = center.dx - table.width / 2;
    final tableTop = center.dy - table.height / 2;

    final tableLabel =
        table.label.isEmpty ? _defaultLabel(table.type) : table.label;
    final hasOpenSeat =
        seats.any((seat) => seat.studentId == null || seat.studentId!.isEmpty);
    final canDropOnTable = interactive && onTableDrop != null && hasOpenSeat;

    Widget buildTableBody(bool isDropActive) {
      final scheme = Theme.of(context).colorScheme;
      final tableDecoration = BoxDecoration(
        color: isDropActive
            ? scheme.primaryContainer
            : table.type == SeatingTableType.teacherDesk
                ? scheme.primaryContainer
                : bg,
        borderRadius: BorderRadius.circular(
          table.type == SeatingTableType.round ? 60 : 16,
        ),
        border: Border.all(
          color: isDropActive ? scheme.primary : border,
          width: isDropActive ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDropActive ? 0.1 : 0.06),
            blurRadius: isDropActive ? 14 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      );

      return AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: table.width,
        height: table.height,
        decoration: tableDecoration,
        padding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: Text(
                tableLabel,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: table.type == SeatingTableType.teacherDesk
                          ? scheme.onPrimaryContainer
                          : scheme.onSurface,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            if (isDropActive)
              Align(
                alignment: Alignment.bottomCenter,
                child: Text(
                  'Drop for empty seat',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
          ],
        ),
      );
    }

    final tableBody = canDropOnTable
        ? DragTarget<StudentDragData>(
            onWillAcceptWithDetails: (_) => hasOpenSeat,
            onAcceptWithDetails: (details) => onTableDrop?.call(details.data),
            builder: (context, candidateData, _) =>
                buildTableBody(candidateData.isNotEmpty),
          )
        : buildTableBody(false);

    return SizedBox(
      width: areaWidth,
      height: areaHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: center.dx - table.width / 2,
            top: center.dy - table.height / 2,
            child: tableBody,
          ),
          if (designMode && interactive)
            Positioned(
              left: tableLeft + table.width - 10,
              top: tableTop - 12,
              child: _TableMenu(
                table: table,
                onRemove: onRemove,
                onUpdateTable: onUpdateTable,
                onEditTable: onEditTable,
                onDuplicateTable: onDuplicateTable,
                onRotateTable: onRotateTable,
              ),
            ),
          for (final seat in seats)
            Positioned(
              left: center.dx + seat.x - seatSize / 2,
              top: center.dy + seat.y - seatSize / 2,
              child: _buildSeat(
                seat: seat,
                studentsById: studentsById,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSeat({
    required SeatingSeat seat,
    required Map<String, Student> studentsById,
  }) {
    Widget child = SeatWidget(
      seat: seat,
      student: seat.studentId == null ? null : studentsById[seat.studentId],
      acceptDrops: interactive,
      allowStudentDrag: interactive && !designMode,
      presentationMode: presentationMode,
      onSeatDrop: (data) => onSeatDrop?.call(seat.seatId, data),
      onTap: interactive ? () => onSeatTap?.call(seat.seatId) : null,
    );

    if (designMode && interactive) {
      child = _SeatPositionDraggable(
        onMove: (delta) => onMoveSeat?.call(seat.seatId, delta),
        child: child,
      );
    }

    return child;
  }

  String _defaultLabel(SeatingTableType type) {
    switch (type) {
      case SeatingTableType.round:
        return 'Round table';
      case SeatingTableType.square:
        return 'Square table';
      case SeatingTableType.singleDesk:
        return 'Desk';
      case SeatingTableType.teacherDesk:
        return 'Teacher desk';
      case SeatingTableType.rectangular:
        return 'Table';
      case SeatingTableType.pairedRect:
        return 'Paired tables';
      case SeatingTableType.longDouble:
        return 'Long tables';
    }
  }

  double _seatSize(bool presentationMode) =>
      presentationMode ? _presentationSeatSize : _editorSeatSize;
}

class SeatWidget extends StatelessWidget {
  final SeatingSeat seat;
  final Student? student;
  final bool acceptDrops;
  final bool allowStudentDrag;
  final bool presentationMode;
  final ValueChanged<StudentDragData>? onSeatDrop;
  final VoidCallback? onTap;

  const SeatWidget({
    super.key,
    required this.seat,
    required this.student,
    required this.acceptDrops,
    required this.allowStudentDrag,
    required this.presentationMode,
    this.onSeatDrop,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = presentationMode ? _presentationSeatSize : _editorSeatSize;
    final statusColor = _statusColor(context, seat.statusColor);
    final label = student == null
        ? ''
        : presentationMode
            ? '${student!.englishFirstName} ${student!.englishLastName}'
            : student!.englishFirstName;
    final noteIcon = seat.reminder
        ? Icons.notifications_active_outlined
        : seat.note.trim().isNotEmpty
            ? Icons.sticky_note_2_outlined
            : null;
    final iconSize = presentationMode ? 20.0 : 18.0;
    final verticalPadding = presentationMode ? 8.0 : 6.0;

    Widget buildSeatVisual({bool isDropTarget = false}) {
      final scheme = Theme.of(context).colorScheme;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isDropTarget
              ? scheme.primaryContainer
              : statusColor.withValues(
                  alpha: seat.statusColor == SeatStatusColor.none ? 0.06 : 0.22,
                ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDropTarget
                ? scheme.primary
                : statusColor.withValues(alpha: 0.65),
            width: isDropTarget ? 2.2 : 1.5,
          ),
          boxShadow: isDropTarget
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: presentationMode ? 6 : 5,
          vertical: verticalPadding,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    student == null ? Icons.event_seat_outlined : Icons.person,
                    size: iconSize,
                    color: isDropTarget ? scheme.primary : statusColor,
                  ),
                  if (label.isNotEmpty)
                    SizedBox(height: presentationMode ? 4 : 2),
                  if (label.isNotEmpty)
                    Text(
                      label,
                      maxLines: presentationMode ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontSize: presentationMode ? 10 : 9,
                            height: 1.0,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                    ),
                ],
              ),
            ),
            if (seat.locked)
              Positioned(
                top: -1,
                right: -1,
                child: Icon(
                  Icons.push_pin,
                  size: presentationMode ? 14 : 12,
                  color:
                      isDropTarget ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            if (noteIcon != null)
              Positioned(
                top: -1,
                left: -1,
                child: Icon(
                  noteIcon,
                  size: presentationMode ? 14 : 12,
                  color: seat.reminder
                      ? Colors.deepOrange.shade600
                      : scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      );
    }

    Widget content = buildSeatVisual();

    if (acceptDrops) {
      content = DragTarget<StudentDragData>(
        onWillAcceptWithDetails: (_) => onSeatDrop != null,
        onAcceptWithDetails: (details) => onSeatDrop?.call(details.data),
        builder: (context, candidateData, _) => _SeatTapTarget(
          onTap: onTap,
          child: buildSeatVisual(isDropTarget: candidateData.isNotEmpty),
        ),
      );
    } else if (onTap != null) {
      content = _SeatTapTarget(onTap: onTap, child: content);
    }

    if (student != null && allowStudentDrag) {
      final draggableContent = content;
      content = _buildStudentDraggable(
        data: StudentDragData(
          studentId: student!.studentId,
          fromSeatId: seat.seatId,
        ),
        feedback: _DragChip(label: label),
        child: draggableContent,
        childWhenDragging: Opacity(opacity: 0.4, child: draggableContent),
      );
    }

    return content;
  }

  Widget _buildStudentDraggable({
    required StudentDragData data,
    required Widget feedback,
    required Widget child,
    required Widget childWhenDragging,
  }) {
    if (_usesImmediateMouseDrag) {
      return Draggable<StudentDragData>(
        data: StudentDragData(
          studentId: data.studentId,
          fromSeatId: data.fromSeatId,
        ),
        feedback: Material(
          color: Colors.transparent,
          child: feedback,
        ),
        childWhenDragging: childWhenDragging,
        child: child,
      );
    }

    return LongPressDraggable<StudentDragData>(
      data: StudentDragData(
        studentId: data.studentId,
        fromSeatId: data.fromSeatId,
      ),
      feedback: Material(
        color: Colors.transparent,
        child: feedback,
      ),
      childWhenDragging: childWhenDragging,
      child: child,
    );
  }

  Color _statusColor(BuildContext context, SeatStatusColor status) {
    switch (status) {
      case SeatStatusColor.green:
        return Colors.green.shade600;
      case SeatStatusColor.yellow:
        return Colors.amber.shade700;
      case SeatStatusColor.red:
        return Colors.red.shade600;
      case SeatStatusColor.blue:
        return Colors.blue.shade600;
      case SeatStatusColor.none:
        return Theme.of(context).colorScheme.outlineVariant;
    }
  }
}

class _SeatTapTarget extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;

  const _SeatTapTarget({
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: child,
    );
  }
}

class StudentDragData {
  final String studentId;
  final String? fromSeatId;
  const StudentDragData({required this.studentId, this.fromSeatId});
}

class _DragChip extends StatelessWidget {
  final String label;
  const _DragChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.primaryContainer;
    final fg = Theme.of(context).colorScheme.onPrimaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.person, size: 14, color: fg),
        const SizedBox(width: 4),
        Text(label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg)),
      ]),
    );
  }
}

class _TableMenu extends StatelessWidget {
  final SeatingTable table;
  final VoidCallback? onRemove;
  final void Function(SeatingTableType type, int seatCount)? onUpdateTable;
  final VoidCallback? onEditTable;
  final VoidCallback? onDuplicateTable;
  final VoidCallback? onRotateTable;

  const _TableMenu({
    required this.table,
    required this.onRemove,
    required this.onUpdateTable,
    required this.onEditTable,
    required this.onDuplicateTable,
    required this.onRotateTable,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_TableAction>(
      tooltip: 'Edit table',
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _TableAction.edit,
          child: Text('Edit details'),
        ),
        const PopupMenuItem(
          value: _TableAction.duplicate,
          child: Text('Duplicate'),
        ),
        if (_canRotate(table))
          const PopupMenuItem(
            value: _TableAction.rotate,
            child: Text('Rotate 90 deg'),
          ),
        const PopupMenuItem(
          value: _TableAction.remove,
          child: Text('Remove'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _TableAction.rect2,
          child: Text('Rect table (2 seats)'),
        ),
        const PopupMenuItem(
          value: _TableAction.rect4,
          child: Text('Rect table (4 seats)'),
        ),
        const PopupMenuItem(
          value: _TableAction.square4,
          child: Text('Square table (4 seats)'),
        ),
        const PopupMenuItem(
          value: _TableAction.rect6,
          child: Text('Rect table (6 seats)'),
        ),
        const PopupMenuItem(
          value: _TableAction.paired6,
          child: Text('Paired tables (6 seats)'),
        ),
        const PopupMenuItem(
          value: _TableAction.long8,
          child: Text('Long table (8 seats)'),
        ),
        const PopupMenuItem(
          value: _TableAction.desk1,
          child: Text('Single desk'),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case _TableAction.edit:
            onEditTable?.call();
            break;
          case _TableAction.duplicate:
            onDuplicateTable?.call();
            break;
          case _TableAction.rotate:
            onRotateTable?.call();
            break;
          case _TableAction.remove:
            onRemove?.call();
            break;
          case _TableAction.rect2:
            onUpdateTable?.call(SeatingTableType.rectangular, 2);
            break;
          case _TableAction.rect4:
            onUpdateTable?.call(SeatingTableType.rectangular, 4);
            break;
          case _TableAction.square4:
            onUpdateTable?.call(SeatingTableType.square, 4);
            break;
          case _TableAction.rect6:
            onUpdateTable?.call(SeatingTableType.rectangular, 6);
            break;
          case _TableAction.paired6:
            onUpdateTable?.call(SeatingTableType.pairedRect, 6);
            break;
          case _TableAction.long8:
            onUpdateTable?.call(SeatingTableType.longDouble, 8);
            break;
          case _TableAction.desk1:
            onUpdateTable?.call(SeatingTableType.singleDesk, 1);
            break;
        }
      },
      child: const Icon(Icons.more_horiz, size: 18),
    );
  }

  bool _canRotate(SeatingTable table) {
    switch (table.type) {
      case SeatingTableType.round:
      case SeatingTableType.square:
        return false;
      case SeatingTableType.rectangular:
      case SeatingTableType.singleDesk:
      case SeatingTableType.teacherDesk:
      case SeatingTableType.pairedRect:
      case SeatingTableType.longDouble:
        return true;
    }
  }
}

enum _TableAction {
  edit,
  duplicate,
  rotate,
  remove,
  rect2,
  rect4,
  square4,
  rect6,
  paired6,
  long8,
  desk1,
}

class _SeatingTableDraggable extends StatefulWidget {
  final SeatingTable table;
  final Widget child;
  final bool enabled;
  final double padding;
  final void Function(Offset delta)? onMove;
  final void Function(Offset delta)? onResize;

  const _SeatingTableDraggable({
    required this.table,
    required this.child,
    required this.enabled,
    required this.padding,
    this.onMove,
    this.onResize,
  });

  @override
  State<_SeatingTableDraggable> createState() => _SeatingTableDraggableState();
}

class _SeatingTableDraggableState extends State<_SeatingTableDraggable> {
  Offset _localOffset = Offset.zero;
  Offset _resizeOffset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final left = widget.table.x - widget.table.width / 2 - widget.padding;
    final top = widget.table.y - widget.table.height / 2 - widget.padding;
    final handleInset = widget.padding - 14;
    return Positioned(
      left: left + _localOffset.dx,
      top: top + _localOffset.dy,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          if (widget.enabled)
            Positioned(
              left: handleInset,
              top: handleInset,
              child: _EditorHandle(
                icon: Icons.open_with,
                tooltip: 'Move table',
                cursor: SystemMouseCursors.grab,
                onPanUpdate: (delta) => setState(() => _localOffset += delta),
                onPanEnd: () {
                  final delta = _localOffset;
                  if (delta != Offset.zero) {
                    widget.onMove?.call(delta);
                  }
                  setState(() => _localOffset = Offset.zero);
                },
              ),
            ),
          if (widget.enabled)
            Positioned(
              left: widget.padding + widget.table.width - 14,
              top: widget.padding + widget.table.height - 14,
              child: Transform.translate(
                offset: _resizeOffset,
                child: _EditorHandle(
                  icon: Icons.drag_handle,
                  tooltip: 'Resize table',
                  cursor: SystemMouseCursors.resizeUpLeftDownRight,
                  onPanUpdate: (delta) =>
                      setState(() => _resizeOffset += delta),
                  onPanEnd: () {
                    final delta = _resizeOffset;
                    if (delta != Offset.zero) {
                      widget.onResize?.call(delta);
                    }
                    setState(() => _resizeOffset = Offset.zero);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SeatPositionDraggable extends StatefulWidget {
  final Widget child;
  final void Function(Offset delta)? onMove;

  const _SeatPositionDraggable({
    required this.child,
    this.onMove,
  });

  @override
  State<_SeatPositionDraggable> createState() => _SeatPositionDraggableState();
}

class _SeatPositionDraggableState extends State<_SeatPositionDraggable> {
  Offset _localOffset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: _localOffset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          Positioned(
            right: -6,
            bottom: -6,
            child: _EditorHandle(
              icon: Icons.drag_indicator,
              tooltip: 'Move seat',
              cursor: SystemMouseCursors.grab,
              size: 20,
              iconSize: 12,
              onPanUpdate: (delta) => setState(() => _localOffset += delta),
              onPanEnd: () {
                final delta = _localOffset;
                if (delta != Offset.zero) {
                  widget.onMove?.call(delta);
                }
                setState(() => _localOffset = Offset.zero);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorHandle extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final MouseCursor cursor;
  final double size;
  final double iconSize;
  final ValueChanged<Offset> onPanUpdate;
  final VoidCallback onPanEnd;

  const _EditorHandle({
    required this.icon,
    required this.tooltip,
    required this.cursor,
    this.size = 28,
    this.iconSize = 16,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) => onPanUpdate(details.delta),
          onPanEnd: (_) => onPanEnd(),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: iconSize,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

bool get _usesImmediateMouseDrag {
  if (kIsWeb) return true;
  switch (defaultTargetPlatform) {
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return true;
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return false;
  }
}

class _FrontMarker extends StatelessWidget {
  final double width;
  const _FrontMarker({required this.width});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary.withValues(alpha: 0.3);
    return Positioned(
      left: 24,
      top: 24,
      child: SizedBox(
        width: width - 48,
        child: Row(
          children: [
            Expanded(
              child: Container(height: 2, color: color),
            ),
            const SizedBox(width: 12),
            Text(
              'Front',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(height: 2, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlankCanvasHint extends StatelessWidget {
  const _BlankCanvasHint();

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).colorScheme.outlineVariant;
    final text = Theme.of(context).colorScheme.onSurfaceVariant;
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Container(
            width: 360,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_home_work_outlined,
                  size: 30,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Blank canvas',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Turn on Edit room, add furniture, drag seats into place, then drop students onto those seats.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: text,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
