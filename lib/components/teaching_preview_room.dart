import 'package:flutter/material.dart';

/// Synthetic table workspace adapted from Classroom.html's interaction model.
/// The owner holds student IDs and lesson records independently of seat indexes.
class TeachingPreviewRoom extends StatefulWidget {
  final Map<String, String> students;
  final List<String?> seats;
  final Map<String, String> homework;
  final Map<String, String>? quizMarks;
  final bool checking;
  final String? selectedStudent;
  final Map<String, String> studentNumbers;
  final String? spotlightStudent;
  final int? spotlightTable;
  final bool choosing;
  final int tableColumns;
  final bool allSideSeats;
  final ValueChanged<String> onStudent;
  final ValueChanged<String> onDone;
  final void Function(int from, int to) onMove;

  const TeachingPreviewRoom({
    super.key,
    required this.students,
    required this.seats,
    required this.homework,
    this.quizMarks,
    required this.checking,
    required this.selectedStudent,
    this.studentNumbers = const {},
    this.spotlightStudent,
    this.spotlightTable,
    this.choosing = false,
    this.tableColumns = 3,
    this.allSideSeats = false,
    required this.onStudent,
    required this.onDone,
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
        Row(children: [
          Expanded(
              child: Text(
                  _arranging
                      ? 'Drag a student, or tap a student then a seat.'
                      : 'Seats locked for teaching',
                  style:
                      const TextStyle(color: Color(0xff657975), fontSize: 12))),
          const SizedBox(width: 8),
          FilterChip(
            selected: _arranging,
            avatar: Icon(_arranging ? Icons.lock_open : Icons.lock_outline,
                size: 16),
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
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
          color: lit
              ? const Color(0xfffff2ce)
              : Colors.white.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: lit ? const Color(0xffe3ac3c) : const Color(0xffe4e9e0),
              width: 2),
          boxShadow: lit
              ? [
                  const BoxShadow(
                      color: Color(0x44e3ac3c), blurRadius: 22, spreadRadius: 2)
                ]
              : null),
      child: Column(children: [
        Row(children: [
          SizedBox(width: 62, child: sideLeft ? _seat(table * 4 + 3) : null),
          Expanded(
              child: Container(
            height: 88,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xffe6ede5), Color(0xffd5e2d8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xff9eb5a8), width: 2),
            ),
            child: Center(
                child: Text('${table + 1}',
                    style: const TextStyle(
                        fontSize: 30,
                        color: Color(0xff36564c),
                        fontWeight: FontWeight.w600))),
          )),
          SizedBox(width: 62, child: sideRight ? _seat(table * 4 + 3) : null),
        ]),
        const SizedBox(height: 12),
        Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
                3,
                (seat) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: _seat(table * 4 + seat),
                    ))),
        const SizedBox(height: 8),
        Text('Table ${table + 1}',
            style: const TextStyle(fontSize: 11, color: Color(0xff657975))),
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
        ? const Color(0xffdceee2)
        : const Color(0xffe4eef0);

    Widget token({bool feedback = false}) => Material(
          color: lit
              ? const Color(0xffffe49a)
              : id == null
                  ? Colors.white
                  : color,
          elevation: lit ? 9 : 0,
          shadowColor: const Color(0xffdfad3e),
          shape: CircleBorder(
              side: BorderSide(
                  color: lit
                      ? const Color(0xffc38b20)
                      : selected
                          ? const Color(0xff23675c)
                          : const Color(0xffa6b9b5),
                  width: selected || lit ? 3 : 1.5)),
          child: SizedBox(
              width: 60,
              height: 60,
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
                                              color: Color(0xff58756b),
                                              fontWeight: FontWeight.w700)),
                                    Text(name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: id == null
                                                ? FontWeight.w400
                                                : FontWeight.w600,
                                            color: const Color(0xff203c39))),
                                  ]))),
                    )),
        );

    return SizedBox(
        width: 60,
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
                          minimumSize: const Size(60, 32),
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
