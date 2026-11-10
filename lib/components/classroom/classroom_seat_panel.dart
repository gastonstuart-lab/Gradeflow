import 'package:flutter/material.dart';
import 'package:gradeflow/models/seating_layout.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/services/seating_service.dart';
import 'package:gradeflow/screens/native_gradebook_screen.dart';
import 'package:gradeflow/services/gradebook_workspace.dart';
import 'package:gradeflow/repositories/repository_factory.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/models/grade_item.dart';
import 'package:provider/provider.dart';

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
          if (student != null) ...[
            ClassroomQuickGradeEditor(
              key: ValueKey('quick-grade:${widget.classId}:${student.studentId}'),
              classId: widget.classId,
              studentId: student.studentId,
              initialCategory: widget.scoreCategory,
            ),
            const SizedBox(height: 10),
          ],
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


/// In-seat score entry using the SAME repository and grading items as the
/// full gradebook. No synthetic scores or separate browser storage.
class ClassroomQuickGradeEditor extends StatefulWidget {
  const ClassroomQuickGradeEditor({
    super.key,
    required this.classId,
    required this.studentId,
    this.initialCategory,
  });
  final String classId;
  final String studentId;
  final String? initialCategory;

  @override
  State<ClassroomQuickGradeEditor> createState() =>
      _ClassroomQuickGradeEditorState();
}

class _ClassroomQuickGradeEditorState extends State<ClassroomQuickGradeEditor> {
  late final GradebookWorkspace book;
  final TextEditingController score = TextEditingController();
  String? itemId;
  String? status;
  bool busy = false;
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    book = GradebookWorkspace(RepositoryFactory.instance, widget.classId);
    _load();
  }

  Future<void> _load() async {
    try {
      await book.load();
      if (!mounted) return;
      setState(() {
        loaded = true;
        _selectItem(widget.initialCategory);
      });
    } catch (error) {
      if (mounted) setState(() => status = 'Scores unavailable: $error');
    }
  }

  void _selectItem(String? preferred) {
    final options = book.items.where((item) => item.isActive && item.name.toLowerCase() != 'category total').toList();
    final preferredCategory = book.categories
        .where((c) => GradebookWorkspace.canonical(c.name) == preferred)
        .firstOrNull?.categoryId;
    final chosen = options
            .where((item) => item.categoryId == preferredCategory)
            .firstOrNull ??
        options.firstOrNull;
    itemId = chosen?.gradeItemId;
    _syncScore();
  }

  GradeItem? get selectedItem =>
      book.items.where((item) => item.gradeItemId == itemId).firstOrNull;

  void _syncScore() {
    final item = selectedItem;
    final value = item == null
        ? null
        : book.score(widget.studentId, item.gradeItemId);
    score.text = value == null
        ? ''
        : value.toStringAsFixed(2).replaceFirst(RegExp(r'\.00$'), '');
    status = null;
  }

  @override
  void didUpdateWidget(covariant ClassroomQuickGradeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCategory != widget.initialCategory && loaded) {
      setState(() => _selectItem(widget.initialCategory));
    }
  }

  @override
  void dispose() {
    score.dispose();
    book.dispose();
    super.dispose();
  }

  void _step(int delta) {
    final item = selectedItem;
    if (item == null || busy) return;
    final previous = double.tryParse(score.text.trim()) ?? 0;
    final next = (previous + delta).clamp(0, item.maxScore).toDouble();
    setState(() {
      score.text = next.toStringAsFixed(2).replaceFirst(RegExp(r'\.00$'), '');
      status = 'Not saved';
    });
  }

  Future<void> _save() async {
    final item = selectedItem;
    if (item == null || busy) return;
    final raw = score.text.trim();
    final value = raw.isEmpty ? null : double.tryParse(raw);
    if (raw.isNotEmpty &&
        (value == null || !value.isFinite || value < 0 || value > item.maxScore)) {
      setState(() => status = 'Enter 0–${item.maxScore}, or leave blank.');
      return;
    }
    final teacher = context.read<AuthService>().currentUser?.userId;
    if (teacher == null) {
      setState(() => status = 'Sign in before saving scores.');
      return;
    }
    setState(() {
      busy = true;
      status = 'Saving…';
    });
    try {
      await book.saveScore(widget.studentId, item, value, teacher);
      if (!mounted) return;
      setState(() {
        status = book.saveState == GradebookSaveState.historyIncomplete
            ? 'Saved; history needs review.'
            : 'Saved';
      });
    } catch (error) {
      if (mounted) setState(() => status = 'Not saved: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = selectedItem;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Quick grade', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (!loaded)
              Text(status ?? 'Loading assessments…')
            else if (book.items.where((i) => i.isActive && i.name.toLowerCase() != 'category total').isEmpty)
              const Text('No assessments yet. Add one in the full Gradebook.')
            else ...[
              DropdownButtonFormField<String>(
                key: ValueKey('assessment:$itemId'),
                isExpanded: true,
                initialValue: itemId,
                decoration: const InputDecoration(
                  labelText: 'Assessment',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: book.items.where((i) => i.isActive && i.name.toLowerCase() != 'category total').map((i) =>
                  DropdownMenuItem<String>(
                    value: i.gradeItemId,
                    child: Text(i.name, overflow: TextOverflow.ellipsis),
                  )).toList(),
                onChanged: busy ? null : (id) => setState(() {
                  itemId = id;
                  _syncScore();
                }),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Decrease by one',
                    onPressed: busy ? null : () => _step(-1),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Expanded(
                    child: TextField(
                      controller: score,
                      enabled: !busy,
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Out of ${item?.maxScore ?? 100}',
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() => status = 'Not saved'),
                      onSubmitted: (_) => _save(),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Increase by one',
                    onPressed: busy ? null : () => _step(1),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: busy ? null : _save,
                child: const Text('Save score'),
              ),
              if (status != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(status!, style: Theme.of(context).textTheme.bodySmall),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
