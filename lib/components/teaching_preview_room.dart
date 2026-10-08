import 'package:flutter/material.dart';

/// Synthetic table workspace adapted from Classroom.html's interaction model.
/// The owner holds student IDs and lesson records independently of seat indexes.
class TeachingPreviewRoom extends StatefulWidget {
  final Map<String, String> students;
  final List<String?> seats;
  final Map<String, String> homework;
  final Map<String, String>? quizMarks;
  final Map<String, String> attendance;
  final Map<String, int> groups;
  final bool checking;
  final bool attendanceMode;
  final bool groupMode;
  final bool presentation;
  final String? selectedStudent;
  final Map<String, String> studentNumbers;
  final String? spotlightStudent;
  final int? spotlightTable;
  final bool choosing;
  final int tableColumns;
  final bool allSideSeats;
  final ValueChanged<String> onStudent;
  final ValueChanged<String> onDone;
  final ValueChanged<String>? onPresent;
  final void Function(int from, int to) onMove;

  const TeachingPreviewRoom({
    super.key,
    required this.students,
    required this.seats,
    required this.homework,
    this.quizMarks,
    this.attendance = const {},
    this.groups = const {},
    required this.checking,
    this.attendanceMode = false,
    this.groupMode = false,
    this.presentation = false,
    required this.selectedStudent,
    this.studentNumbers = const {},
    this.spotlightStudent,
    this.spotlightTable,
    this.choosing = false,
    this.tableColumns = 3,
    this.allSideSeats = false,
    required this.onStudent,
    required this.onDone,
    this.onPresent,
    required this.onMove,
  });

  @override
  State<TeachingPreviewRoom> createState() => _TeachingPreviewRoomState();
}

class _TeachingPreviewRoomState extends State<TeachingPreviewRoom> {
  bool _arranging = false;
  int? _moving;

  void _choose(int slot) {
    if (widget.choosing) return;
    if (!_arranging) {
      final student = widget.seats[slot];
      if (student != null) widget.onStudent(student);
    } else if (_moving == null) {
      if (widget.seats[slot] != null) setState(() => _moving = slot);
    } else {
      widget.onMove(_moving!, slot);
      setState(() => _moving = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.presentation) {
      return LayoutBuilder(builder: (context, constraints) {
        const crossGap = 20.0;
        const rowGap = 18.0;
        final available = constraints.maxWidth >= 780
            ? 3
            : constraints.maxWidth >= 500
                ? 2
                : 1;
        final columns =
            widget.tableColumns < available ? widget.tableColumns : available;
        // Fit the existing furniture as one composition. Dividing viewport
        // height between rows stretches the aisle while furniture stays small.
        const tableWidth = 480.0;
        final roomWidth = columns * tableWidth + (columns - 1) * crossGap;
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : 0,
            ),
            child: Center(
              child: SizedBox(
                width: constraints.maxWidth,
                child: FittedBox(
                  fit: BoxFit.fitWidth,
                  child: SizedBox(
                    width: roomWidth,
                    child: Wrap(
                      spacing: crossGap,
                      runSpacing: rowGap,
                      children: List.generate(
                        widget.seats.length ~/ 4,
                        (table) => SizedBox(
                          width: tableWidth,
                          child: _table(table),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      });
    }

    return Column(children: [
      Row(children: [
        Expanded(
            child: Text(
                _arranging
                    ? 'Drag a student, or tap a student then a seat.'
                    : 'Seating is locked while you teach',
                style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xff9fb4c7)
                        : const Color(0xff60758c),
                    fontWeight: FontWeight.w600,
                    fontSize: 12))),
        const SizedBox(width: 8),
        FilterChip(
          selected: _arranging,
          showCheckmark: false,
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xff102334)
              : Colors.white,
          selectedColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xff123b3a)
              : const Color(0xffe2f3f1),
          side: BorderSide(
              color: _arranging
                  ? const Color(0xff8fcfc7)
                  : Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xff29445e)
                      : const Color(0xffd7e3ed)),
          avatar: Icon(_arranging ? Icons.lock_open : Icons.lock_outline,
              size: 16,
              color: _arranging
                  ? const Color(0xff148b88)
                  : Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xff9fb4c7)
                      : const Color(0xff60758c)),
          label: Text(_arranging ? 'Lock seats' : 'Arrange seats'),
          onSelected: widget.choosing
              ? null
              : (_) => setState(() {
                    _arranging = !_arranging;
                    _moving = null;
                  }),
        ),
      ]),
      const SizedBox(height: 14),
      LayoutBuilder(builder: (context, constraints) {
        final available = constraints.maxWidth >= 780
            ? 3
            : constraints.maxWidth >= 500
                ? 2
                : 1;
        final columns =
            widget.tableColumns < available ? widget.tableColumns : available;
        final width = (constraints.maxWidth - (columns - 1) * 22) / columns;
        return Wrap(
            spacing: 22,
            runSpacing: 24,
            children: List.generate(
                widget.seats.length ~/ 4,
                (table) => SizedBox(
                      width: width,
                      child: _table(table),
                    )));
      }),
    ]);
  }

  Widget _table(int table) {
    final lit = widget.spotlightTable == table;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tableSurface = lit
        ? (dark ? const Color(0xff302b1f) : const Color(0xfffff8e7))
        : (dark ? const Color(0xff142536) : const Color(0xfff9fbfd));
    final tableLine = lit
        ? const Color(0xffd5a13a)
        : (dark ? const Color(0xff385066) : const Color(0xffcbd8e3));

    // Preserve the original Classroom.html geometry exactly: three seats
    // behind/below each table, with the physical side seats only where the
    // room actually has them.
    final showLeftSide = !widget.allSideSeats && table == 0;
    final showRightSide = widget.allSideSeats || table == 2;
    final sideSeat = _seat(table * 4 + 3);
    final sideSize = widget.presentation ? 72.0 : 64.0;
    final sidePlaceholder = SizedBox(width: sideSize, height: sideSize);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(
          vertical: widget.presentation ? 10 : 4,
          horizontal: widget.presentation ? 8 : 2),
      decoration: BoxDecoration(
        color: lit
            ? (dark
                ? const Color(0x2239a0ff)
                : const Color(0x143b82f6))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: widget.presentation
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              showLeftSide ? sideSeat : sidePlaceholder,
              const SizedBox(width: 10),
              Expanded(
                child: Center(
                  child: FractionallySizedBox(
                    widthFactor: widget.presentation ? .72 : .68,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: widget.presentation ? 88 : 74,
                      decoration: BoxDecoration(
                        color: tableSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: tableLine,
                          width: lit ? 2 : 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: dark
                                ? Colors.black.withValues(alpha: .18)
                                : const Color(0x15173f62),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'TABLE ${table + 1}',
                          style: TextStyle(
                            fontSize: widget.presentation ? 14 : 11,
                            letterSpacing: 1.45,
                            color: dark
                                ? const Color(0xffd8e4ee)
                                : const Color(0xff4c657b),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              showRightSide ? sideSeat : sidePlaceholder,
            ],
          ),
          SizedBox(height: widget.presentation ? 18 : 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _seat(table * 4),
              _seat(table * 4 + 1),
              _seat(table * 4 + 2),
            ],
          ),
        ],
      ),
    );
  }

  Widget _seat(int slot) {
    final id = widget.seats[slot];
    final dark = Theme.of(context).brightness == Brightness.dark;
    final status = widget.homework[id] ?? 'Unchecked';
    final done = status == 'Done';
    final selected =
        (id != null && id == widget.selectedStudent) || _moving == slot;
    final lit = id != null && widget.spotlightStudent == id;
    final name = widget.students[id] ?? 'Empty';
    final slotWidth = widget.presentation ? 72.0 : 64.0;
    final chairWidth = widget.presentation ? 56.0 : 48.0;
    final chairHeight = widget.presentation ? 46.0 : 40.0;

    final baseFill = id == null
        ? (dark ? const Color(0xff0e1c29) : const Color(0xfff5f8fb))
        : (dark ? const Color(0xff172a3a) : Colors.white);
    final borderColor = lit
        ? const Color(0xffd5a13a)
        : selected
            ? const Color(0xff2584ff)
            : done && widget.checking
                ? const Color(0xff4f9b73)
                : (dark
                    ? const Color(0xff385066)
                    : const Color(0xffcbd8e3));

    Widget token({bool feedback = false}) => Material(
          color: Colors.transparent,
          child: SizedBox(
            width: slotWidth,
            child: InkWell(
              key: id == null ? null : ValueKey('student-$id'),
              borderRadius: BorderRadius.circular(13),
              onTap: feedback ? null : () => _choose(slot),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: chairWidth,
                      height: chairHeight,
                      decoration: BoxDecoration(
                        color: lit
                            ? (dark
                                ? const Color(0xff4b3c1c)
                                : const Color(0xffffedbd))
                            : baseFill,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: borderColor,
                          width: selected || lit ? 2 : 1.2,
                        ),
                        boxShadow: selected || lit
                            ? [
                                BoxShadow(
                                  color: (lit
                                          ? const Color(0xffd5a13a)
                                          : const Color(0xff2584ff))
                                      .withValues(alpha: .18),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Stack(children: [
                        Center(
                          child: Icon(
                            id == null
                                ? Icons.event_seat_outlined
                                : Icons.event_seat_rounded,
                            size: widget.presentation ? 25 : 21,
                            color: id == null
                                ? (dark
                                    ? const Color(0xff60758c)
                                    : const Color(0xffa4b2bf))
                                : (dark
                                    ? const Color(0xffdce7f0)
                                    : const Color(0xff536d83)),
                          ),
                        ),
                        if (id != null &&
                            widget.studentNumbers.containsKey(id))
                          Positioned(
                            right: 4,
                            top: 3,
                            child: Text(
                              widget.studentNumbers[id]!,
                              style: TextStyle(
                                fontSize: widget.presentation ? 9 : 8,
                                height: 1,
                                color: dark
                                    ? const Color(0xff9fb4c7)
                                    : const Color(0xff60758c),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        if (done && widget.checking && id != null)
                          const Positioned(
                            left: 4,
                            top: 4,
                            child: Icon(Icons.check_circle_rounded,
                                size: 10, color: Color(0xff4f9b73)),
                          ),
                      ]),
                    ),
                    const SizedBox(height: 4),
                    if (id != null)
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: widget.presentation ? 12 : 10.5,
                          height: 1.1,
                          fontWeight: selected || lit
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: dark
                              ? const Color(0xffedf5fb)
                              : const Color(0xff29465d),
                        ),
                      )
                    else
                      const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        );

    return SizedBox(
      width: slotWidth,
      child: Column(children: [
        DragTarget<int>(
          key: ValueKey('seat-$slot'),
          onWillAcceptWithDetails: (details) =>
              _arranging && !widget.choosing && details.data != slot,
          onAcceptWithDetails: (details) {
            widget.onMove(details.data, slot);
            setState(() => _moving = null);
          },
          builder: (context, candidates, rejected) => DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: candidates.isEmpty
                  ? null
                  : [
                      const BoxShadow(
                        color: Color(0x662584ff),
                        blurRadius: 9,
                        spreadRadius: 2,
                      ),
                    ],
            ),
            child: _arranging && !widget.choosing && id != null
                ? Draggable<int>(
                    data: slot,
                    feedback: token(feedback: true),
                    childWhenDragging:
                        Opacity(opacity: .28, child: token()),
                    child: token(),
                  )
                : token(),
          ),
        ),
        if (widget.quizMarks != null && id != null && !_arranging) ...[
          const SizedBox(height: 5),
          Text(widget.quizMarks![id]!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10)),
        ],
        if (widget.groupMode && id != null && !_arranging) ...[
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
                color: dark
                    ? const Color(0xff17334f)
                    : const Color(0xffe8f2ff),
                borderRadius: BorderRadius.circular(999)),
            child: Text('Group ${widget.groups[id] ?? '-'}',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: dark
                        ? const Color(0xffb8d7ff)
                        : const Color(0xff1769ce))),
          ),
        ],
        if (widget.attendanceMode && id != null && !_arranging) ...[
          const SizedBox(height: 5),
          SizedBox(
            height: 30,
            child: TextButton(
              key: ValueKey('present-$id'),
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size(slotWidth, 28),
                  textStyle: const TextStyle(fontSize: 9.5)),
              onPressed: widget.onPresent == null
                  ? null
                  : () => widget.onPresent!(id),
              child: Text(widget.attendance[id] == 'Present'
                  ? '✓ Present'
                  : widget.attendance[id] ?? 'Present'),
            ),
          ),
        ],
        if (widget.checking && id != null && !_arranging) ...[
          const SizedBox(height: 5),
          Tooltip(
            message: done ? '$name: Done' : 'Mark $name done',
            child: SizedBox(
              height: 30,
              child: TextButton(
                key: ValueKey('done-$id'),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size(slotWidth, 28),
                    textStyle: const TextStyle(fontSize: 9.5)),
                onPressed: () => widget.onDone(id),
                child: Text(done ? '✓ Done' : 'Done'),
              ),
            ),
          ),
          if (status != 'Done' && status != 'Unchecked')
            Text(status, style: const TextStyle(fontSize: 9.5)),
        ],
      ]),
    );
  }

}
