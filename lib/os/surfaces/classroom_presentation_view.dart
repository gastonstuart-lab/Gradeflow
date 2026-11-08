import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/components/seating/classroom_picker_animator.dart';
import 'package:gradeflow/components/seating/seating_designer_view.dart';
import 'package:gradeflow/services/seating_service.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/os/os_palette.dart';

/// Projector-friendly view: retains the real saved room without exposing
/// private notes, scores, editing controls, or student-assignment actions.
class ClassroomPresentationView extends StatefulWidget {
  const ClassroomPresentationView({
    super.key,
    required this.classId,
    required this.className,
    required this.subject,
    this.picker,
    this.cleanCanvas = false,
    this.plannerV2 = false,
  });

  final String classId;
  final String className;
  final String subject;
  final ClassroomPickerAnimator? picker;
  final bool cleanCanvas;
  final bool plannerV2;

  @override
  State<ClassroomPresentationView> createState() =>
      _ClassroomPresentationViewState();
}

class _ClassroomPresentationViewState extends State<ClassroomPresentationView> {
  late final _picker = widget.picker ?? ClassroomPickerAnimator();
  String? _highlightedStudent;
  String? _highlightedTable;
  String? _selectedLabel;

  @override
  void dispose() {
    _picker.cancel();
    super.dispose();
  }

  void _pick({bool table = false}) {
    unawaited(_runPick(table: table));
  }

  Future<void> _runPick({bool table = false}) async {
    final layout = context.read<SeatingService>().activeLayout(widget.classId);
    if (layout == null) return;
    final students = context.read<StudentService>().students;
    final eligibleTables = layout.tables
        .where((t) => layout.seats.any((s) =>
            s.tableId == t.tableId &&
            students.any((student) => student.studentId == s.studentId)))
        .toList();
    final eligibleStudents = students
        .where((s) => layout.seats.any((seat) => seat.studentId == s.studentId))
        .toList();
    final ids = table
        ? eligibleTables.map((t) => t.tableId).toList()
        : eligibleStudents.map((s) => s.studentId).toList();
    if (ids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(table
            ? 'No occupied tables to pick.'
            : 'Seat students on the map before picking.'),
      ));
      return;
    }

    final chosen = await _picker.animate(
      candidateIds: ids,
      nonRepeatingStudents: !table,
      reduceMotion: MediaQuery.disableAnimationsOf(context),
      onHighlight: (id) {
        if (!mounted) return;
        setState(() {
          _highlightedStudent = table ? null : id;
          _highlightedTable = table ? id : null;
          _selectedLabel = 'Choosing…';
        });
      },
    );
    if (!mounted || chosen == null) return;

    setState(() {
      if (table) {
        final selected = eligibleTables.firstWhere((t) => t.tableId == chosen);
        _selectedLabel =
            selected.label.isEmpty ? 'Selected table' : selected.label;
      } else {
        final selected =
            eligibleStudents.firstWhere((s) => s.studentId == chosen);
        _selectedLabel =
            '${selected.englishFirstName} ${selected.englishLastName}'.trim();
      }
    });
  }

  void _clearSelection() {
    _picker.cancel();
    setState(() {
      _highlightedStudent = null;
      _highlightedTable = null;
      _selectedLabel = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final students = context.watch<StudentService>().students;
    return Scaffold(
      backgroundColor: OSColors.teachBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.className,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Colors.white)),
                        Text(widget.subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: OSColors.teachAccent)),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_fullscreen_rounded),
                    label: const Text('Exit presentation'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.24))),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _pick(),
                        icon: const Icon(Icons.person_search_outlined),
                        label: const Text('Pick student'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _pick(table: true),
                        icon: const Icon(Icons.table_restaurant_outlined),
                        label: const Text('Pick table'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      const _FullscreenTimer(),
                      if (_selectedLabel != null) ...[
                        const SizedBox(width: 12),
                        InputChip(
                          label: Text(_selectedLabel!),
                          avatar: const Icon(Icons.auto_awesome, size: 16),
                          onDeleted: _clearSelection,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: OSColors.teachSurface,
                    borderRadius: OSRadius.mdBr,
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.10)),
                  ),
                  child: SeatingDesignerView(
                    classId: widget.classId,
                    students: students,
                    autoLoad: false,
                    presentationMode: true,
                    premiumAppearance: true,
                    simplifiedArrange: widget.cleanCanvas,
                    plannerV2: widget.plannerV2,
                    interactive: false,
                    editRoomMode: false,
                    highlightedStudentId: _highlightedStudent,
                    highlightedTableId: _highlightedTable,
                    showToolbar: false,
                    showStudentPanel: false,
                    showFullScreenButton: false,
                    showUseHint: false,
                    webMode: kIsWeb,
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

class _FullscreenTimer extends StatefulWidget {
  const _FullscreenTimer();

  @override
  State<_FullscreenTimer> createState() => _FullscreenTimerState();
}

class _FullscreenTimerState extends State<_FullscreenTimer> {
  int _selectedMinutes = 3;
  int _remainingSeconds = 180;
  DateTime? _deadline;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    final deadline = _deadline;
    if (!mounted || deadline == null) return;
    final left = max(
        0, (deadline.difference(DateTime.now()).inMilliseconds / 1000).ceil());
    setState(() => _remainingSeconds = left);
    if (left == 0) {
      _ticker?.cancel();
      setState(() => _deadline = null);
    }
  }

  void _toggle() {
    if (_deadline != null) {
      _tick();
      _ticker?.cancel();
      setState(() => _deadline = null);
    } else {
      if (_remainingSeconds == 0) {
        _remainingSeconds = _selectedMinutes * 60;
      }
      setState(() =>
          _deadline = DateTime.now().add(Duration(seconds: _remainingSeconds)));
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  void _setMinutes(int minutes) {
    _ticker?.cancel();
    setState(() {
      _selectedMinutes = minutes;
      _remainingSeconds = minutes * 60;
      _deadline = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mm = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final ss = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return Row(mainAxisSize: MainAxisSize.min, children: [
      PopupMenuButton<int>(
        tooltip: 'Set timer duration',
        icon: const Icon(Icons.timer_outlined, color: Colors.white),
        onSelected: _setMinutes,
        itemBuilder: (_) => const [
          PopupMenuItem(value: 1, child: Text('1 minute')),
          PopupMenuItem(value: 3, child: Text('3 minutes')),
          PopupMenuItem(value: 5, child: Text('5 minutes')),
          PopupMenuItem(value: 10, child: Text('10 minutes')),
        ],
      ),
      OutlinedButton.icon(
        onPressed: _toggle,
        icon: Icon(
            _deadline == null ? Icons.play_arrow_rounded : Icons.pause_rounded),
        label: Text('$mm:$ss'),
        style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
      ),
      IconButton(
        tooltip: 'Reset timer',
        onPressed: () => _setMinutes(_selectedMinutes),
        icon: const Icon(Icons.restart_alt_rounded, color: Colors.white),
      ),
    ]);
  }
}
