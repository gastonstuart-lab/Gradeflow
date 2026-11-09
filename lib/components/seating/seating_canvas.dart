import 'package:gradeflow/components/seating/classroom_map_framing.dart';
import 'package:gradeflow/components/seating/planner_v2_geometry.dart';
import 'package:gradeflow/components/classroom/classroom_materials.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gradeflow/models/seating_layout.dart';
import 'package:gradeflow/models/student.dart';

const double _editorSeatAreaPadding = 180;
const double _presentationSeatAreaPadding = 120;
const double _editorSeatSize = 56;
const double _presentationSeatSize = 70;

class SeatingCanvas extends StatefulWidget {
  final SeatingLayout layout;
  final Map<String, Student> studentsById;
  final bool designMode;
  final bool interactive;
  final bool presentationMode;
  final bool premiumAppearance;
  final bool simplifiedArrange;
  final bool plannerV2;
  final String? selectedTableId;
  final ValueChanged<SeatingTable>? onPlannerV2Commit;
  final ValueChanged<SeatingSeat>? onPlannerV2SeatCommit;
  final ValueChanged<String>? onTableSelected;
  final TransformationController? transformationController;

  /// Whether roster seating can be changed on this canvas.
  final bool allowSeatReassignment;
  final String? highlightedStudentId;
  final String? highlightedTableId;
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
    this.premiumAppearance = false,
    this.simplifiedArrange = false,
    this.plannerV2 = false,
    this.selectedTableId,
    this.onPlannerV2Commit,
    this.onPlannerV2SeatCommit,
    this.onTableSelected,
    this.transformationController,
    this.allowSeatReassignment = true,
    this.highlightedStudentId,
    this.highlightedTableId,
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
  State<SeatingCanvas> createState() => _SeatingCanvasState();
}

class _SeatingCanvasState extends State<SeatingCanvas> {
  final Map<String, SeatingTable> _tablePreviews = {};
  @override
  Widget build(BuildContext context) {
    final boundary =
        Size(widget.layout.canvasWidth, widget.layout.canvasHeight);
    return RepaintBoundary(
      child: InteractiveViewer(
        transformationController: widget.transformationController,
        maxScale: 2.6,
        minScale: widget.premiumAppearance ? 0.001 : 0.6,
        boundaryMargin:
            EdgeInsets.all(widget.premiumAppearance ? double.infinity : 200),
        panEnabled: !widget.premiumAppearance && !widget.plannerV2,
        scaleEnabled: !widget.premiumAppearance && !widget.plannerV2,
        constrained: false,
        child: SizedBox(
          width: boundary.width,
          height: boundary.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (widget.plannerV2)
                const Positioned.fill(child: IgnorePointer(child: ColoredBox(color: Color(0xffe7eee9)))),
              if (widget.premiumAppearance && !widget.simplifiedArrange)
                Positioned.fromRect(
                    rect: ClassroomMapFraming.roomBounds(widget.layout),
                    child: IgnorePointer(
                        child: DecoratedBox(
                            decoration: ClassroomMaterials.floor(
                                Theme.of(context).brightness ==
                                    Brightness.dark),
                            child: CustomPaint(
                                painter: ClassroomFloorPainter(
                                    Theme.of(context).brightness ==
                                        Brightness.dark))))),
              if (widget.showFrontMarker && !widget.premiumAppearance)
                _FrontMarker(width: boundary.width),
              if (widget.showFrontMarker && widget.premiumAppearance)
                Positioned(
                    left:
                        ClassroomMapFraming.roomBounds(widget.layout, compact: widget.simplifiedArrange)
                                .center
                                .dx -
                            90,
                    top: ClassroomMapFraming.roomBounds(widget.layout, compact: widget.simplifiedArrange).top +
                        20,
                    width: 180,
                    height: 32,
                    child: IgnorePointer(
                        child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: const Color(0xff244747),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: const Color(0xff9cae9f), width: 3)),
                            child: const Text('FRONT OF ROOM',
                                style: TextStyle(
                                    color: Color(0xffe7eee3),
                                    fontSize: 11,
                                    letterSpacing: 1.4,
                                    fontWeight: FontWeight.w700))))),
              if (widget.layout.tables.isEmpty) const _BlankCanvasHint(),
              for (final table in widget.layout.tables)
                _SeatingTableDraggable(
                  table: table,
                  onMove: (delta) =>
                      widget.onMoveTable?.call(table.tableId, delta),
                  onResize: (delta) =>
                      widget.onResizeTable?.call(table.tableId, delta),
                  padding: _seatAreaPadding(widget.presentationMode),
                  enabled: widget.designMode,
                  directDrag: widget.simplifiedArrange && !widget.plannerV2,
                  plannerV2: widget.plannerV2 &&
                      widget.designMode &&
                      widget.interactive,
                  selected: widget.selectedTableId == table.tableId,
                  viewTransform: widget.transformationController,
                  roomSize: boundary,
                  toViewport: (global) =>
                      (context.findRenderObject()! as RenderBox)
                          .globalToLocal(global),
                  onProposalCommitted: widget.onPlannerV2Commit,
                  onPreview: (proposal) => setState(() {
                    if (proposal == null) {
                      _tablePreviews.remove(table.tableId);
                    } else {
                      _tablePreviews[table.tableId] = proposal;
                    }
                  }),
                  previewBuilder: widget.plannerV2
                      ? (candidate) => TableWidget(
                            table: candidate,
                            seats: widget.plannerV2
                                ? []
                                : widget.layout.seats
                                    .where(
                                        (seat) => seat.tableId == table.tableId)
                                    .toList(),
                            studentsById: widget.studentsById,
                            designMode: widget.designMode,
                            interactive: widget.interactive,
                            presentationMode: widget.presentationMode,
                            premiumAppearance: widget.premiumAppearance,
                            simplifiedArrange: widget.simplifiedArrange,
                            allowSeatReassignment: widget.allowSeatReassignment,
                            highlightedStudentId: widget.highlightedStudentId,
                            highlightedTableId:
                                widget.selectedTableId == table.tableId
                                    ? table.tableId
                                    : widget.highlightedTableId,
                            onTableSelected: widget.onTableSelected == null
                                ? null
                                : () => widget.onTableSelected!(table.tableId),
                            onSeatTap: (seatId) =>
                                widget.onSeatTap?.call(seatId),
                          )
                      : null,
                  child: TableWidget(
                    table: table,
                    seats: widget.plannerV2
                        ? []
                        : widget.layout.seats
                            .where((seat) => seat.tableId == table.tableId)
                            .toList(),
                    studentsById: widget.studentsById,
                    designMode: widget.designMode,
                    interactive: widget.interactive,
                    presentationMode: widget.presentationMode,
                    premiumAppearance: widget.premiumAppearance,
                    simplifiedArrange: widget.simplifiedArrange,
                    onTableSelected: widget.onTableSelected == null
                        ? null
                        : () => widget.onTableSelected!(table.tableId),
                    allowSeatReassignment: widget.allowSeatReassignment,
                    highlightedStudentId: widget.highlightedStudentId,
                    highlightedTableId: widget.highlightedTableId,
                    onRemove: () => widget.onRemoveTable?.call(table.tableId),
                    onUpdateTable: (type, count) =>
                        widget.onUpdateTable?.call(table.tableId, type, count),
                    onEditTable: () => widget.onEditTable?.call(table.tableId),
                    onDuplicateTable: () =>
                        widget.onDuplicateTable?.call(table.tableId),
                    onRotateTable: () =>
                        widget.onRotateTable?.call(table.tableId),
                    onMoveSeat: (seatId, delta) =>
                        widget.onMoveSeat?.call(seatId, delta),
                    onTableDrop: (data) =>
                        widget.onTableDrop?.call(table.tableId, data),
                    onSeatDrop: (seatId, data) =>
                        widget.onSeatDrop?.call(seatId, data),
                    onSeatTap: (seatId) => widget.onSeatTap?.call(seatId),
                  ),
                ),
              if (widget.plannerV2)
                for (final seat in widget.layout.seats)
                  if (widget.layout.tables
                      .any((t) => t.tableId == seat.tableId))
                    _PlannerV2SeatDraggable(
                      key: ValueKey('v2-seat-${seat.seatId}'),
                      seat: seat,
                      table: _tablePreviews[seat.tableId] ??
                          widget.layout.tables
                              .firstWhere((t) => t.tableId == seat.tableId),
                      roomSize: boundary,
                      size: widget.presentationMode
                          ? _presentationSeatSize
                          : _editorSeatSize,
                      enabled: widget.designMode && widget.interactive,
                      viewTransform: widget.transformationController,
                      toViewport: (global) =>
                          (context.findRenderObject()! as RenderBox)
                              .globalToLocal(global),
                      onCommit: widget.onPlannerV2SeatCommit,
                      onTap: widget.interactive
                          ? () => widget.onSeatTap?.call(seat.seatId)
                          : null,
                      child: SeatWidget(
                        seat: seat,
                        student: widget.studentsById[seat.studentId],
                        acceptDrops:
                            widget.interactive && widget.allowSeatReassignment,
                        allowStudentDrag: widget.interactive &&
                            widget.allowSeatReassignment &&
                            !widget.designMode,
                        presentationMode: widget.presentationMode,
                        premiumAppearance: widget.premiumAppearance,
                        highlighted: (seat.studentId != null &&
                                seat.studentId ==
                                    widget.highlightedStudentId) ||
                            seat.tableId == widget.highlightedTableId,
                        onSeatDrop: (data) =>
                            widget.onSeatDrop?.call(seat.seatId, data),
                        onTap: widget.designMode
                            ? null
                            : () => widget.onSeatTap?.call(seat.seatId),
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
  final bool premiumAppearance;
  final bool simplifiedArrange;
  final VoidCallback? onTableSelected;
  final bool allowSeatReassignment;
  final String? highlightedStudentId;
  final String? highlightedTableId;
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
    this.premiumAppearance = false,
    this.simplifiedArrange = false,
    this.onTableSelected,
    this.allowSeatReassignment = true,
    this.highlightedStudentId,
    this.highlightedTableId,
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
    final canDropOnTable = interactive &&
        allowSeatReassignment &&
        onTableDrop != null &&
        hasOpenSeat;

    Widget buildTableBody(bool isDropActive) {
      final scheme = Theme.of(context).colorScheme;
      final tableDecoration = premiumAppearance
          ? ClassroomMaterials.tabletop(
                  Theme.of(context).brightness == Brightness.dark, isDropActive)
              .copyWith(
                  borderRadius: BorderRadius.circular(
                      table.type == SeatingTableType.round ? 60 : 14))
          : BoxDecoration(
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
                  color:
                      Colors.black.withValues(alpha: isDropActive ? 0.1 : 0.06),
                  blurRadius: isDropActive ? 14 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            );

      return AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 140),
        width: table.width,
        height: table.height,
        key: ValueKey('table-visual-${table.tableId}'),
        decoration: highlightedTableId == table.tableId
            ? tableDecoration.copyWith(
                border: Border.all(color: const Color(0xffffbc42), width: 4),
                boxShadow: [
                    const BoxShadow(
                        color: Color(0x66ffbc42),
                        blurRadius: 24,
                        spreadRadius: 4)
                  ])
            : tableDecoration,
        padding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            if (premiumAppearance)
              Positioned.fill(
                  child: IgnorePointer(
                      child: CustomPaint(
                          painter:
                              ClassroomOakPainter(table.tableId.hashCode)))),
            Align(
              alignment: Alignment.center,
              child: Text(
                tableLabel,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: premiumAppearance
                          ? const Color(0xff493c2b)
                          : table.type == SeatingTableType.teacherDesk
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

    final selectableTableBody = designMode && simplifiedArrange && interactive
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTableSelected,
            child: tableBody,
          )
        : tableBody;

    return SizedBox(
      width: areaWidth,
      height: areaHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: center.dx - table.width / 2,
            top: center.dy - table.height / 2,
            child: selectableTableBody,
          ),
          if (designMode && interactive && !simplifiedArrange)
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
      premiumAppearance: premiumAppearance,
      highlighted:
          highlightedStudentId == seat.studentId && seat.studentId != null ||
              highlightedTableId == seat.tableId,
      acceptDrops: interactive && allowSeatReassignment,
      allowStudentDrag: interactive && allowSeatReassignment && !designMode,
      presentationMode: presentationMode,
      onSeatDrop: (data) => onSeatDrop?.call(seat.seatId, data),
      onTap: interactive ? () => onSeatTap?.call(seat.seatId) : null,
    );

    if (designMode && interactive) {
      child = _SeatPositionDraggable(
        directDrag: simplifiedArrange,
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
  final bool premiumAppearance;
  final bool highlighted;
  final ValueChanged<StudentDragData>? onSeatDrop;
  final VoidCallback? onTap;

  const SeatWidget({
    super.key,
    required this.seat,
    required this.student,
    required this.acceptDrops,
    required this.allowStudentDrag,
    required this.presentationMode,
    this.premiumAppearance = false,
    this.highlighted = false,
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
    final noteIcon = presentationMode
        ? null
        : seat.reminder
            ? Icons.notifications_active_outlined
            : seat.note.trim().isNotEmpty
                ? Icons.sticky_note_2_outlined
                : null;
    final iconSize = presentationMode ? 20.0 : 18.0;
    final verticalPadding = presentationMode ? 8.0 : 6.0;

    Widget buildSeatVisual({bool isDropTarget = false}) {
      final scheme = Theme.of(context).colorScheme;
      if (premiumAppearance) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        final occupied = student != null;
        final edge = highlighted
            ? const Color(0xffffbc42)
            : isDropTarget
                ? scheme.primary
                : seat.statusColor != SeatStatusColor.none
                    ? statusColor
                    : dark
                        ? const Color(0xff517b7b)
                        : const Color(0xff397570);
        return Tooltip(
            message: student?.englishFullName ?? 'Empty seat',
            child: SizedBox(
                width: size,
                height: size,
                child: Column(children: [
                  Expanded(
                      child: AnimatedContainer(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 160),
                          width: size - 6,
                          decoration: BoxDecoration(
                              color: occupied
                                  ? null
                                  : dark
                                      ? const Color(0xff1a2d35)
                                      : const Color(0xffdce5df),
                              gradient: occupied
                                  ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: highlighted
                                          ? const [
                                              Color(0xff80652c),
                                              Color(0xff54401c)
                                            ]
                                          : dark
                                              ? const [
                                                  Color(0xff326a70),
                                                  Color(0xff234c53)
                                                ]
                                              : const [
                                                  Color(0xff318b87),
                                                  Color(0xff206864)
                                                ])
                                  : null,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                  color: edge, width: highlighted ? 3 : 1.2),
                              boxShadow: [
                                BoxShadow(
                                    color: highlighted
                                        ? const Color(0x66ffbc42)
                                        : const Color(0x3435443d),
                                    blurRadius: highlighted ? 16 : 5,
                                    offset: const Offset(0, 3))
                              ]),
                          child: Stack(children: [
                            if (occupied)
                              Positioned(
                                  top: 4,
                                  left: 7,
                                  right: 7,
                                  height: 5,
                                  child: DecoratedBox(
                                      decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: .15),
                                          borderRadius:
                                              BorderRadius.circular(4)))),
                            Center(
                                child: Padding(
                                    padding: const EdgeInsets.only(top: 7),
                                    child: occupied && student!.seatNo != null
                                        ? Text(
                                            '${student!.seatNo}'
                                                .padLeft(2, '0'),
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800))
                                        : Icon(
                                            occupied
                                                ? Icons.person
                                                : Icons.event_seat_outlined,
                                            size: 18,
                                            color: occupied
                                                ? Colors.white
                                                : dark
                                                    ? const Color(0xff7d999a)
                                                    : const Color(
                                                        0xff78978e)))),
                            if (seat.locked && !presentationMode)
                              const Positioned(
                                  top: 1,
                                  right: 1,
                                  child: Icon(Icons.push_pin,
                                      size: 10, color: Color(0xffffe1a4))),
                            if (noteIcon != null)
                              Positioned(
                                  top: 1,
                                  left: 1,
                                  child: Icon(noteIcon,
                                      size: 11,
                                      color: seat.reminder
                                          ? const Color(0xffffcf83)
                                          : Colors.white)),
                          ]))),
                  const SizedBox(height: 3),
                  SizedBox(
                      height: 15,
                      child: Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11,
                              height: 1.1,
                              color: dark
                                  ? const Color(0xffe4efea)
                                  : const Color(0xff23483f),
                              fontWeight: FontWeight.w700))),
                ])));
      }
      return AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 160),
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: premiumAppearance && student != null && !isDropTarget
              ? const LinearGradient(
                  colors: [Color(0xff317e79), Color(0xff205e5b)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight)
              : null,
          color: isDropTarget
              ? scheme.primaryContainer
              : premiumAppearance
                  ? (student == null
                      ? const Color(0xffdce5df)
                      : const Color(0xff2d7771))
                  : statusColor.withValues(
                      alpha: seat.statusColor == SeatStatusColor.none
                          ? 0.06
                          : 0.22,
                    ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlighted
                ? const Color(0xffffbc42)
                : isDropTarget
                    ? scheme.primary
                    : premiumAppearance &&
                            seat.statusColor == SeatStatusColor.none
                        ? const Color(0xff397570)
                        : statusColor.withValues(alpha: 0.65),
            width: highlighted
                ? 4
                : isDropTarget
                    ? 2.2
                    : 1.5,
          ),
          boxShadow: highlighted
              ? [
                  const BoxShadow(
                      color: Color(0x99ffbc42), blurRadius: 22, spreadRadius: 3)
                ]
              : isDropTarget
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
                    color: premiumAppearance && student != null
                        ? Colors.white
                        : isDropTarget
                            ? scheme.primary
                            : statusColor,
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
                            fontSize: premiumAppearance
                                ? (presentationMode ? 12 : 10.5)
                                : (presentationMode ? 10 : 9),
                            height: 1.0,
                            fontWeight: FontWeight.w600,
                            color: premiumAppearance && student != null
                                ? Colors.white
                                : scheme.onSurface,
                          ),
                    ),
                ],
              ),
            ),
            if (seat.locked && !presentationMode)
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

    return Semantics(
      identifier: 'classroom-seat-${seat.seatId}',
      label: student == null ? 'Empty seat' : 'Seat for $label',
      child: content,
    );
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
          child: Text('Table settings'),
        ),
        const PopupMenuItem(
          value: _TableAction.duplicate,
          child: Text('Duplicate table'),
        ),
        if (_canRotate(table))
          const PopupMenuItem(
            value: _TableAction.rotate,
            child: Text('Rotate'),
          ),
        const PopupMenuItem(
          value: _TableAction.remove,
          child: Text('Delete table'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _TableAction.rect2,
          child: Text('Table - 2 seats'),
        ),
        const PopupMenuItem(
          value: _TableAction.rect4,
          child: Text('Table - 4 seats'),
        ),
        const PopupMenuItem(
          value: _TableAction.square4,
          child: Text('Square table - 4 seats'),
        ),
        const PopupMenuItem(
          value: _TableAction.rect6,
          child: Text('Table - 6 seats'),
        ),
        const PopupMenuItem(
          value: _TableAction.paired6,
          child: Text('Paired tables - 6 seats'),
        ),
        const PopupMenuItem(
          value: _TableAction.long8,
          child: Text('Long table - 8 seats'),
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
  final ValueChanged<SeatingTable?>? onPreview;
  final Widget child;
  final bool enabled;
  final bool directDrag;
  final bool plannerV2;
  final bool selected;
  final TransformationController? viewTransform;
  final Size? roomSize;
  final Offset Function(Offset global)? toViewport;
  final ValueChanged<SeatingTable>? onProposalCommitted;
  final Widget Function(SeatingTable)? previewBuilder;
  final double padding;
  final void Function(Offset delta)? onMove;
  final void Function(Offset delta)? onResize;

  const _SeatingTableDraggable({
    required this.table,
    this.onPreview,
    required this.child,
    required this.enabled,
    this.directDrag = false,
    this.plannerV2 = false,
    this.selected = false,
    this.viewTransform,
    this.roomSize,
    this.toViewport,
    this.onProposalCommitted,
    this.previewBuilder,
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
  PlannerV2Gesture? _gesture;
  SeatingTable? _proposal;
  int? _activePointer;
  final FocusNode _gestureFocus = FocusNode(debugLabel: 'Planner V2 gesture');

  @override
  void dispose() {
    _gestureFocus.dispose();
    super.dispose();
  }

  void _start(PointerDownEvent event) {
    if (!widget.enabled ||
        !widget.plannerV2 ||
        widget.toViewport == null ||
        widget.roomSize == null ||
        widget.viewTransform == null) return;
    final offset = event.localPosition;
    final inTable = offset.dx >= widget.padding &&
        offset.dx <= widget.padding + widget.table.width &&
        offset.dy >= widget.padding &&
        offset.dy <= widget.padding + widget.table.height;
    if (!inTable) return; // Seat tap/drag is handled independently.
    final nearCorner = widget.selected &&
        offset.dx >= widget.padding + widget.table.width - 28 &&
        offset.dy >= widget.padding + widget.table.height - 28;
    _gesture = PlannerV2Geometry.begin(
      table: widget.table,
      pointer: widget.toViewport!(event.position),
      viewTransform: widget.viewTransform!.value,
      roomSize: widget.roomSize!,
      action:
          nearCorner ? PlannerV2Action.resizeBottomRight : PlannerV2Action.move,
    );
    _activePointer = event.pointer;
    _gestureFocus.requestFocus();
  }

  void _move(PointerMoveEvent event) {
    if (_gesture == null || _activePointer != event.pointer) return;
    setState(
        () => _proposal = _gesture!.update(widget.toViewport!(event.position)));
    widget.onPreview?.call(_proposal);
  }

  void _finish(int pointer, {bool cancel = false}) {
    if (_gesture == null || _activePointer != pointer) return;
    final next = _proposal;
    _gesture = null;
    _activePointer = null;
    setState(() => _proposal = null);
    widget.onPreview?.call(null);
    if (!cancel && next != null) widget.onProposalCommitted?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final shown = _proposal ?? widget.table;
    final left = shown.x - shown.width / 2 - widget.padding;
    final top = shown.y - shown.height / 2 - widget.padding;
    final handleInset = widget.padding - 14;
    final source = widget.previewBuilder?.call(shown) ?? widget.child;
    final content = widget.enabled && widget.directDrag
        ? GestureDetector(
            behavior: HitTestBehavior.deferToChild,
            onPanUpdate: (details) =>
                setState(() => _localOffset += details.delta),
            onPanEnd: (_) {
              final delta = _localOffset;
              if (delta != Offset.zero) widget.onMove?.call(delta);
              setState(() => _localOffset = Offset.zero);
            },
            child: source,
          )
        : source;
    return Positioned(
      left: left + _localOffset.dx,
      top: top + _localOffset.dy,
      child: Focus(
        focusNode: _gestureFocus,
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape &&
              _activePointer != null) {
            _finish(_activePointer!, cancel: true);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Listener(
          onPointerDown: widget.plannerV2 ? _start : null,
          onPointerMove: widget.plannerV2 ? _move : null,
          onPointerUp: widget.plannerV2 ? (e) => _finish(e.pointer) : null,
          onPointerCancel:
              widget.plannerV2 ? (e) => _finish(e.pointer, cancel: true) : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              content,
              if (widget.enabled && !widget.directDrag && !widget.plannerV2)
                Positioned(
                  left: handleInset,
                  top: handleInset,
                  child: _EditorHandle(
                    icon: Icons.open_with,
                    tooltip: 'Move table',
                    cursor: SystemMouseCursors.grab,
                    onPanUpdate: (delta) =>
                        setState(() => _localOffset += delta),
                    onPanEnd: () {
                      final delta = _localOffset;
                      if (delta != Offset.zero) {
                        widget.onMove?.call(delta);
                      }
                      setState(() => _localOffset = Offset.zero);
                    },
                  ),
                ),
              if (widget.enabled && !widget.directDrag && !widget.plannerV2)
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
              if (widget.plannerV2 && widget.enabled && widget.selected)
                Positioned(
                  left: widget.padding + shown.width - 15,
                  top: widget.padding + shown.height - 15,
                  child: const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xff176f73),
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: Icon(Icons.open_in_full,
                            size: 15, color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeatPositionDraggable extends StatefulWidget {
  final Widget child;
  final bool directDrag;
  final void Function(Offset delta)? onMove;

  const _SeatPositionDraggable({
    required this.child,
    this.directDrag = false,
    this.onMove,
  });

  @override
  State<_SeatPositionDraggable> createState() => _SeatPositionDraggableState();
}

class _SeatPositionDraggableState extends State<_SeatPositionDraggable> {
  Offset _localOffset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final content = widget.directDrag
        ? GestureDetector(
            behavior: HitTestBehavior.deferToChild,
            onPanUpdate: (details) =>
                setState(() => _localOffset += details.delta),
            onPanEnd: (_) {
              final delta = _localOffset;
              if (delta != Offset.zero) widget.onMove?.call(delta);
              setState(() => _localOffset = Offset.zero);
            },
            child: widget.child,
          )
        : widget.child;
    return Transform.translate(
      offset: _localOffset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          content,
          if (!widget.directDrag)
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
                  'Build your classroom',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Open Setup Room, add a table or desk, drag it into place, then drop students onto seats.',
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

/// A room-level target stays hittable after leaving its original table area.
/// Flutter retains the pointer-down hit path until up/cancel, even when the
/// target moves. Only that pointer may update or finish this gesture.
class _PlannerV2SeatDraggable extends StatefulWidget {
  const _PlannerV2SeatDraggable(
      {super.key,
      required this.seat,
      required this.table,
      required this.roomSize,
      required this.size,
      required this.enabled,
      required this.viewTransform,
      required this.toViewport,
      required this.onCommit,
      required this.onTap,
      required this.child});
  final SeatingSeat seat;
  final SeatingTable table;
  final Size roomSize;
  final double size;
  final bool enabled;
  final TransformationController? viewTransform;
  final Offset Function(Offset) toViewport;
  final ValueChanged<SeatingSeat>? onCommit;
  final VoidCallback? onTap;
  final Widget child;
  @override
  State<_PlannerV2SeatDraggable> createState() =>
      _PlannerV2SeatDraggableState();
}

class _PlannerV2SeatDraggableState extends State<_PlannerV2SeatDraggable> {
  final _focus = FocusNode(debugLabel: 'Planner V2 seat');
  int? _pointer;
  Offset? _down;
  PlannerV2SeatGesture? _gesture;
  SeatingSeat? _proposal;
  bool _dragged = false;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _PlannerV2SeatDraggable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled ||
        oldWidget.seat.x != widget.seat.x ||
        oldWidget.seat.y != widget.seat.y ||
        oldWidget.table.x != widget.table.x ||
        oldWidget.table.y != widget.table.y) {
      _pointer = null;
      _gesture = null;
      _proposal = null;
      _dragged = false;
    }
  }

  void _start(PointerDownEvent event) {
    if (_pointer != null || event.buttons != 1) return;
    _pointer = event.pointer;
    _down = event.position;
    _dragged = false;
    _gesture = PlannerV2SeatGesture(
        seat: widget.seat,
        table: widget.table,
        pointer: widget.toViewport(event.position),
        viewTransform: widget.viewTransform?.value ?? Matrix4.identity(),
        roomSize: widget.roomSize,
        seatSize: widget.size);
    _focus.requestFocus();
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointer || _gesture == null) return;
    if (!_dragged && (event.position - _down!).distance < 5) return;
    _dragged = true;
    setState(
        () => _proposal = _gesture!.update(widget.toViewport(event.position)));
  }

  void _finish(int pointer, {bool cancel = false}) {
    if (pointer != _pointer) return;
    final proposal = _proposal;
    final tapped = !_dragged;
    _pointer = null;
    _gesture = null;
    setState(() {
      _proposal = null;
      _dragged = false;
    });
    if (cancel) return;
    if (tapped) {
      widget.onTap?.call();
    } else if (proposal != null &&
        (proposal.x != widget.seat.x || proposal.y != widget.seat.y)) {
      widget.onCommit?.call(proposal);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = _proposal ?? widget.seat;
    return Positioned(
      left: widget.table.x + shown.x - widget.size / 2,
      top: widget.table.y + shown.y - widget.size / 2,
      width: widget.size,
      height: widget.size,
      child: Focus(
          focusNode: _focus,
          onKeyEvent: (_, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape &&
                _pointer != null) {
              _finish(_pointer!, cancel: true);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: MouseRegion(
              cursor:
                  widget.enabled ? SystemMouseCursors.grab : MouseCursor.defer,
              child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: widget.enabled ? _start : null,
                  onPointerMove: widget.enabled ? _move : null,
                  onPointerUp:
                      widget.enabled ? (e) => _finish(e.pointer) : null,
                  onPointerCancel: widget.enabled
                      ? (e) => _finish(e.pointer, cancel: true)
                      : null,
                  child: Semantics(
                      onTap: widget.enabled ? widget.onTap : null,
                      child: widget.child)))),
    );
  }
}
