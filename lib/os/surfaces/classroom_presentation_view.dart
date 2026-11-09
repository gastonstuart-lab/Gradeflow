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
          padding: const EdgeInsets.fromLTRB(7, 5, 7, 6),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, width) {
                  final title = Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.className,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      Text(widget.subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: OSColors.teachAccent)),
                    ],
                  );
                  final controls = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _pick(),
                        icon: const Icon(Icons.person_search_outlined),
                        label: const Text('Pick student'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        onPressed: () => _pick(table: true),
                        icon: const Icon(Icons.table_restaurant_outlined),
                        label: const Text('Pick table'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white),
                      ),
                      const SizedBox(width: 6),
                      const ClassroomTimer(),
                      if (_selectedLabel != null) ...[
                        const SizedBox(width: 6),
                        InputChip(
                          label: Text(_selectedLabel!),
                          avatar: const Icon(Icons.auto_awesome, size: 16),
                          onDeleted: _clearSelection,
                        ),
                      ],
                    ],
                  );
                  final exit = OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_fullscreen_rounded,
                        size: 17),
                    label: const Text('Exit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.24),
                      ),
                    ),
                  );
                  if (width.maxWidth < 900) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(children: [
                          Expanded(child: title),
                          exit,
                        ]),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 42,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: controls,
                          ),
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      SizedBox(
                        width: width.maxWidth < 1150 ? 230 : 320,
                        child: title,
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: controls,
                        ),
                      ),
                      const SizedBox(width: 8),
                      exit,
                    ],
                  );
                },
              ),
              const SizedBox(height: 5),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(3),
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

class ClassroomTimer extends StatefulWidget {
  const ClassroomTimer({super.key, this.fullPage = false});
  final bool fullPage;

  @override
  State<ClassroomTimer> createState() => ClassroomTimerState();
}

class ClassroomTimerState extends State<ClassroomTimer> {
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
    final controls = Row(mainAxisSize: MainAxisSize.min, children: [
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
        label: Text(widget.fullPage ? '${_deadline == null ? 'Start' : 'Pause'} $mm:$ss' : '$mm:$ss'),
        style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
      ),
      IconButton(
        tooltip: 'Reset timer',
        onPressed: () => _setMinutes(_selectedMinutes),
        icon: const Icon(Icons.restart_alt_rounded, color: Colors.white),
      ),
    ]);
    if (!widget.fullPage) return controls;
    return Scaffold(
      backgroundColor: const Color(0xff102a30),
      appBar: AppBar(backgroundColor: const Color(0xff102a30), foregroundColor: Colors.white, title: const Text('Classroom timer'),
        leading: IconButton(tooltip: 'Close timer', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))),
      body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Semantics(liveRegion: _remainingSeconds == 0, child: Text('$mm:$ss',
          style: TextStyle(fontSize: MediaQuery.sizeOf(context).shortestSide * .24,
            color: Colors.white, fontWeight: FontWeight.w700))),
        if (_remainingSeconds == 0) const Text('Time is up', style: TextStyle(color: Colors.white, fontSize: 28)),
        controls,
      ])),
    );
  }
}
