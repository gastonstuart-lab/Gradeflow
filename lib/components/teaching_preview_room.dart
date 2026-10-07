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
  Widget build(BuildContext context) => Column(children: [
        if (!widget.presentation) ...[
          Row(children: [
            Expanded(
                child: Text(
                    _arranging
                        ? 'Drag a student, or tap a student then a seat.'
                        : 'Seating is locked while you teach',
                    style: const TextStyle(
                        color: Color(0xff60758c),
                        fontWeight: FontWeight.w600,
                        fontSize: 12))),
            const SizedBox(width: 8),
            FilterChip(
              selected: _arranging,
              showCheckmark: false,
              backgroundColor: Colors.white,
              selectedColor: const Color(0xffe2f3f1),
              side: BorderSide(
                  color: _arranging
                      ? const Color(0xff8fcfc7)
                      : const Color(0xffd7e3ed)),
              avatar: Icon(_arranging ? Icons.lock_open : Icons.lock_outline,
                  size: 16,
                  color: _arranging
                      ? const Color(0xff148b88)
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
          const SizedBox(height: 20),
        ],
        LayoutBuilder(builder: (context, constraints) {
          final available = constraints.maxWidth >= 780
              ? 3
              : constraints.maxWidth >= 500
                  ? 2
                  : 1;
          final columns =
              widget.tableColumns < available ? widget.tableColumns : available;
          final width = (constraints.maxWidth - (columns - 1) * 18) / columns;
          return Wrap(
              spacing: 18,
              runSpacing: 26,
              children: List.generate(
                  widget.seats.length ~/ 4,
                  (table) => SizedBox(
                        width: width,
                        child: _table(table),
                      )));
        }),
      ]);

  Widget _table(int table) {
    final sideLeft = widget.allSideSeats ? table.isEven : table == 0;
    final sideRight = widget.allSideSeats ? table.isOdd : table == 2;
    final lit = widget.spotlightTable == table;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 110),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
          gradient: lit
              ? const LinearGradient(
                  colors: [Color(0xfffff7dd), Color(0xffffefd0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight)
              : const LinearGradient(
                  colors: [Colors.white, Color(0xfff7fbfd)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: lit ? const Color(0xffe3ac3c) : const Color(0xffdbe6ee),
              width: lit ? 2 : 1),
          boxShadow: [
            if (lit)
              const BoxShadow(
                  color: Color(0x44e3ac3c), blurRadius: 22, spreadRadius: 2)
            else
              const BoxShadow(
                  color: Color(0x10163f65),
                  blurRadius: 18,
                  offset: Offset(0, 7)),
          ]),
      child: Column(children: [
        Row(children: [
          SizedBox(width: 56, child: sideLeft ? _seat(table * 4 + 3) : null),
          Expanded(
              child: Container(
            height: 70,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xffe9f4f6), Color(0xffdceae8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xff9fc4c2), width: 1.5),
            ),
            child: Center(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  Text('${table + 1}',
                      style: const TextStyle(
                          fontSize: 27,
                          height: 1,
                          color: Color(0xff285b5a),
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  const Text('TABLE',
                      style: TextStyle(
                          fontSize: 8,
                          letterSpacing: 1.4,
                          color: Color(0xff6b8987),
                          fontWeight: FontWeight.w800)),
                ])),
          )),
          SizedBox(width: 56, child: sideRight ? _seat(table * 4 + 3) : null),
        ]),
        const SizedBox(height: 8),
        Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
                3,
                (seat) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _seat(table * 4 + seat),
                    ))),
        const SizedBox(height: 4),
        Text('Table ${table + 1}',
            style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Color(0xff60758c))),
      ]),
    );
  }

  Widget _seat(int slot) {
    final id = widget.seats[slot];
    final status = widget.homework[id] ?? 'Unchecked';
    final done = status == 'Done';
    final selected =
        id != null && id == widget.selectedStudent || _moving == slot;
    final lit = id != null && widget.spotlightStudent == id;
    final name = widget.students[id] ?? 'Empty';
    final color = widget.checking && done
        ? const Color(0xffdff3e7)
        : const Color(0xffeaf3f5);

    Widget token({bool feedback = false}) => Material(
          color: lit
              ? const Color(0xffffe49a)
              : id == null
                  ? const Color(0xfffbfdff)
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
                          ? const Color(0xff1769ce)
                          : id == null
                              ? const Color(0xffc5d3de)
                              : const Color(0xff9fb9bb),
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
                                          style: const TextStyle(
                                              fontSize: 9,
                                              color: Color(0xff5c768c),
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
                                            color: const Color(0xff173f4f))),
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
