import 'package:flutter/material.dart';
import 'package:gradeflow/models/seating_layout.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/services/seating_service.dart';
import 'package:gradeflow/screens/native_gradebook_screen.dart';

/// Contextual controls for the canonical saved seat, inside the room drawer.
class ClassroomSeatPanel extends StatefulWidget {
  const ClassroomSeatPanel(
      {super.key,
      required this.classId,
      required this.seat,
      required this.table,
      required this.students,
      required this.service,
      required this.arranging,
      this.scoreCategory});
  final String classId;
  final SeatingSeat seat;
  final SeatingTable table;
  final List<Student> students;
  final SeatingService service;
  final bool arranging;
  final String? scoreCategory;
  @override
  State<ClassroomSeatPanel> createState() => _ClassroomSeatPanelState();
}

class _ClassroomSeatPanelState extends State<ClassroomSeatPanel> {
  late final TextEditingController _note =
      TextEditingController(text: widget.seat.note);
  late bool _reminder = widget.seat.reminder;
  String _query = '';
  bool _assigning = false;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seat = widget.seat;
    final student =
        widget.students.where((s) => s.studentId == seat.studentId).firstOrNull;
    final structural = widget.table.type != SeatingTableType.singleDesk &&
        widget.table.type != SeatingTableType.teacherDesk;
    return Padding(
        padding: const EdgeInsets.all(20),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(student?.englishFullName ?? 'Empty seat',
              style: Theme.of(context).textTheme.titleLarge),
          if (student != null) Text(student.chineseName),
          Text(widget.table.label,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          if (student != null)
            FilledButton.icon(
                icon: const Icon(Icons.edit_note),
                label: Text(widget.scoreCategory == null
                    ? 'Add score / Gradebook'
                    : '${widget.scoreCategory} scores'),
                onPressed: () => showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => Dialog(
                        child: SizedBox(
                            width: 1100,
                            height: MediaQuery.sizeOf(context).height * .85,
                            child: NativeGradebookScreen(
                                classId: widget.classId,
                                studentId: student.studentId,
                                initialCategory: widget.scoreCategory))))),
          const SizedBox(height: 12),
          Text('Check-in status',
              style: Theme.of(context).textTheme.titleSmall),
          Wrap(spacing: 6, children: [
            for (final entry in {
              SeatStatusColor.green: 'Steady',
              SeatStatusColor.yellow: 'Check in',
              SeatStatusColor.red: 'Attention',
              SeatStatusColor.blue: 'Support',
              SeatStatusColor.none: 'Clear status'
            }.entries)
              ChoiceChip(
                  label: Text(entry.value),
                  selected: seat.statusColor == entry.key,
                  onSelected: (_) => widget.service
                      .setSeatStatus(widget.classId, seat.seatId, entry.key)),
          ]),
          const SizedBox(height: 16),
          TextField(
              controller: _note,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Seat note', border: OutlineInputBorder())),
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reminder'),
              value: _reminder,
              onChanged: (value) => setState(() => _reminder = value)),
          OutlinedButton(
              onPressed: () async {
                await widget.service.updateSeatNote(widget.classId, seat.seatId,
                    note: _note.text, reminder: _reminder);
                if (context.mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Note saved')));
              },
              child: const Text('Save note')),
          if (widget.arranging) ...[
            const Divider(height: 32),
            Text('SEATING', style: Theme.of(context).textTheme.labelLarge),
            OutlinedButton.icon(
                icon: const Icon(Icons.swap_horiz),
                onPressed: () => setState(() => _assigning = !_assigning),
                label: Text(student == null
                    ? 'Assign student'
                    : 'Swap or replace student')),
            if (_assigning) ...[
              const Text('Choosing a seated student swaps their placement.'),
              TextField(
                  decoration: const InputDecoration(labelText: 'Search roster'),
                  onChanged: (value) =>
                      setState(() => _query = value.toLowerCase())),
              for (final candidate in widget.students.where((s) =>
                  '${s.englishFullName} ${s.chineseName} ${s.seatNo}'
                      .toLowerCase()
                      .contains(_query)))
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(candidate.englishFullName),
                    subtitle: Text(candidate.chineseName),
                    onTap: () async {
                      await widget.service.assignStudentToSeat(
                          widget.classId, seat.seatId, candidate.studentId);
                      if (mounted) setState(() => _assigning = false);
                    }),
            ],
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Lock seat for shuffle'),
                value: seat.locked,
                onChanged: (value) => widget.service
                    .setSeatLocked(widget.classId, seat.seatId, value)),
            if (student != null)
              TextButton(
                  onPressed: () =>
                      widget.service.clearSeat(widget.classId, seat.seatId),
                  child: const Text('Clear seat')),
            if (structural)
              TextButton(
                  onPressed: () =>
                      widget.service.duplicateSeat(widget.classId, seat.seatId),
                  child: const Text('Duplicate seat')),
            if (structural)
              TextButton(
                  onPressed: widget.table.seatCount > 1
                      ? () =>
                          widget.service.removeSeat(widget.classId, seat.seatId)
                      : null,
                  child: const Text('Remove seat')),
          ],
        ]));
  }
}
