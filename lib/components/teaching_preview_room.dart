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
        const columns = 3;
        const crossGap = 20.0;
        const rowGap = 18.0;
        final width =
            (constraints.maxWidth - (columns - 1) * crossGap) / columns;
        final height = constraints.maxHeight.isFinite
            ? (constraints.maxHeight - rowGap) / 2
            : 210.0;
        return Wrap(
          spacing: crossGap,
          runSpacing: rowGap,
          children: List.generate(
            widget.seats.length ~/ 4,
            (table) => SizedBox(
              width: width,
              height: height,
              child: _table(table),
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

  static const _tableAccents = [
    Color(0xff7c4dff),
    Color(0xff14a870),
    Color(0xff2584ff),
    Color(0xffff982f),
    Color(0xffff5265),
    Color(0xffe7bf00),
  ];

  Color _accentFor(int table) => _tableAccents[table % _tableAccents.length];

  Widget _table(int table) {
    final lit = widget.spotlightTable == table;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = _accentFor(table);
    final tableFill = Color.alphaBlend(
      accent.withValues(alpha: dark ? .34 : .16),
      dark ? const Color(0xff102333) : Colors.white,
    );

    // Source-of-truth room geometry from the original Classroom.html:
    // three seats behind/below each table, with the extra side seat only
    // where the physical room actually has one.
    final showLeftSide = !widget.allSideSeats && table == 0;
    final showRightSide = widget.allSideSeats || table == 2;
    final sideSeat = _seat(table * 4 + 3);
    final sidePlaceholder = const SizedBox(width: 54, height: 54);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(
          vertical: widget.presentation ? 10 : 4,
          horizontal: widget.presentation ? 8 : 2),
      decoration: BoxDecoration(
        color: lit
            ? (dark
                ? const Color(0xff2d2819)
                : const Color(0xfffff7dd))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        border: lit
            ? Border.all(color: const Color(0xffe3ac3c), width: 2)
            : null,
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
                    widthFactor: widget.presentation ? .70 : .66,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: widget.presentation ? 82 : 72,
                      decoration: BoxDecoration(
                        color: tableFill,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color:
                                accent.withValues(alpha: dark ? .98 : .78),
                            width: dark ? 1.9 : 1.5),
                        boxShadow: dark
                            ? [
                                BoxShadow(
                                    color: accent.withValues(alpha: .12),
                                    blurRadius: 14,
                                    spreadRadius: 1)
                              ]
                            : null,
                      ),
                      child: Center(
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                            Text('${table + 1}',
                                style: TextStyle(
                                    fontSize:
                                        widget.presentation ? 30 : 27,
                                    height: 1,
                                    color: dark
                                        ? const Color(0xfff2f7fb)
                                        : const Color(0xff173f4f),
                                    fontWeight: FontWeight.w900)),
                            const SizedBox(height: 3),
                            Text('TABLE',
                                style: TextStyle(
                                    fontSize: 8,
                                    letterSpacing: 1.4,
                                    color: dark
                                        ? const Color(0xffb6c7d6)
                                        : const Color(0xff60758c),
                                    fontWeight: FontWeight.w800)),
                          ])),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              showRightSide ? sideSeat : sidePlaceholder,
            ],
          ),
          SizedBox(height: widget.presentation ? 16 : 10),
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
    final table = slot ~/ 4;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = _accentFor(table);
    final status = widget.homework[id] ?? 'Unchecked';
    final done = status == 'Done';
    final selected =
        id != null && id == widget.selectedStudent || _moving == slot;
    final lit = id != null && widget.spotlightStudent == id;
    final name = widget.students[id] ?? 'Empty';
    final color = widget.checking && done
        ? (dark ? const Color(0xff183c2c) : const Color(0xffdff3e7))
        : (dark ? const Color(0xff14293a) : const Color(0xfff8fbfd));

    Widget token({bool feedback = false}) => Material(
          color: lit
              ? (dark ? const Color(0xff5c4715) : const Color(0xffffe49a))
              : id == null
                  ? (dark ? const Color(0xff0c1b29) : const Color(0xfffbfdff))
                  : color,
          elevation: lit ? 9 : selected ? 4 : 0,
          shadowColor: lit
              ? const Color(0xffdfad3e)
              : const Color(0x331769ce),
          shape: CircleBorder(
              side: BorderSide(
                  color: lit
                      ? const Color(0xffc38b20)
                      : selected
                          ? const Color(0xff28a9ff)
                          : id == null
                              ? accent.withValues(alpha: dark ? .52 : .34)
                              : accent.withValues(alpha: dark ? .92 : .72),
                  width: selected || lit ? 2.5 : 1.25)),
          child: SizedBox(
              width: 54,
              height: 54,
              child: feedback
                  ? Center(
                      child: Text(name, style: const TextStyle(fontSize: 11)))
                  : InkWell(
                      key: id == null ? null : ValueKey('student-$id'),
                      customBorder: const CircleBorder(),
                      onTap: () => _choose(slot),
                      child: Center(
                          child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (id != null &&
                                        widget.studentNumbers.containsKey(id))
                                      Text(widget.studentNumbers[id]!,
                                          style: TextStyle(
                                              fontSize: 9,
                                              color: dark
                                                  ? const Color(0xff9fb4c7)
                                                  : const Color(0xff5c768c),
                                              fontWeight: FontWeight.w800)),
                                    Text(name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: id == null
                                                ? FontWeight.w400
                                                : FontWeight.w600,
                                            color: dark
                                                ? const Color(0xffedf5fb)
                                                : const Color(0xff173f4f))),
                                  ]))),
                    )),
        );

    return SizedBox(
        width: 54,
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
                  shape: BoxShape.circle,
                  boxShadow: candidates.isEmpty
                      ? null
                      : [
                          const BoxShadow(
                              color: Color(0xff8dbbad),
                              blurRadius: 8,
                              spreadRadius: 3)
                        ]),
              child: _arranging && !widget.choosing && id != null
                  ? Draggable<int>(
                      data: slot,
                      feedback: token(feedback: true),
                      childWhenDragging: Opacity(opacity: 0.3, child: token()),
                      child: token(),
                    )
                  : token(),
            ),
          ),
          if (widget.quizMarks != null && id != null && !_arranging) ...[
            const SizedBox(height: 6),
            Text(widget.quizMarks![id]!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10)),
          ],
          if (widget.groupMode && id != null && !_arranging) ...[
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                  color: const Color(0xffe6f1ff),
                  borderRadius: BorderRadius.circular(999)),
              child: Text('Group ${widget.groups[id] ?? '-'}',
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xff1769ce))),
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
                    minimumSize: const Size(54, 28),
                    textStyle: const TextStyle(fontSize: 9.5)),
                onPressed: widget.onPresent == null
                    ? null
                    : () => widget.onPresent!(id),
                child: Text(
                    widget.attendance[id] == 'Present'
                        ? '✓ Present'
                        : widget.attendance[id] ?? 'Present'),
              ),
            ),
          ],
          if (widget.checking && id != null && !_arranging) ...[
            const SizedBox(height: 6),
            Tooltip(
                message: done ? '$name: Done' : 'Mark $name done',
                child: SizedBox(
                    height: 32,
                    child: TextButton(
                      key: ValueKey('done-$id'),
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(54, 30),
                          textStyle: const TextStyle(fontSize: 10)),
                      onPressed: () => widget.onDone(id),
                      child: Text(done ? '✓ Done' : 'Done'),
                    ))),
            if (status != 'Done' && status != 'Unchecked')
              Text(status, style: const TextStyle(fontSize: 10)),
          ],
        ]));
  }
}
