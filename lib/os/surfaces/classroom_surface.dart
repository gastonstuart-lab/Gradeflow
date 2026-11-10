import 'package:gradeflow/components/classroom/classroom_seat_panel.dart';
import 'dart:async';
import 'dart:math';
import 'package:gradeflow/components/seating/classroom_picker_animator.dart';
import 'package:gradeflow/os/surfaces/classroom_presentation_view.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/models/seating_layout.dart';
import 'package:gradeflow/components/seating/seating_designer_view.dart';
import 'package:gradeflow/components/seating/planner_v2_dimensions_editor.dart';

import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/os/os_palette.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/seating_service.dart';
import 'package:gradeflow/config/gradeflow_existing_project_preview.dart';
import 'package:gradeflow/services/student_service.dart';

class ClassroomSurface extends StatefulWidget {
  const ClassroomSurface({
    super.key,
    required this.classId,
    this.startInSetup = false,
    this.cleanCanvas = false,
    this.plannerV2 = false,
  });

  final String classId;
  final bool startInSetup;
  final bool cleanCanvas;
  final bool plannerV2;

  @override
  State<ClassroomSurface> createState() => _ClassroomSurfaceState();
}

class _ClassroomSurfaceState extends State<ClassroomSurface> {
  String? _selectedSeat;
  String? _selectedTableId;
  bool _loading = true;
  bool _toolsOpen = false;
  String? _pickedStudent;
  String? _pickedTable;
  String? _pickLabel;
  final _picker = ClassroomPickerAnimator();
  String? _scoreCategory;
  bool _setupMode = false;
  int _fitRevision = 0;
  double _zoomFactor = 1;

  @override
  void initState() {
    super.initState();
    _setupMode = widget.startInSetup;
    _toolsOpen = widget.startInSetup;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadClassroom());
    });
  }

  @override
  void didUpdateWidget(covariant ClassroomSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classId != widget.classId) {
      setState(() {
        _selectedSeat = null;
        _selectedTableId = null;
        _loading = true;
        _setupMode = false;
        _picker.cancel(clearStudentHistory: true);
        _pickedStudent = null;
        _pickedTable = null;
        _pickLabel = null;
        _scoreCategory = null;
        _toolsOpen = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_loadClassroom());
      });
    }
  }

  @override
  void dispose() {
    _picker.cancel();
    super.dispose();
  }

  Future<void> _loadClassroom() async {
    final auth = context.read<AuthService>();
    final classService = context.read<ClassService>();
    final studentService = context.read<StudentService>();
    final seatingService = context.read<SeatingService>();

    try {
      final user = auth.currentUser;
      if (user != null && classService.getClassById(widget.classId) == null) {
        await classService.loadClasses(user.userId);
      }

      await studentService.loadStudents(widget.classId);
      await seatingService.loadRoomSetups();
      await seatingService.loadLayouts(
        widget.classId,
        studentCount: studentService.students.length,
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _backToClass() {
    context.go(AppRoutes.osClasses);
  }

  void _pick({bool table = false}) {
    unawaited(_runPick(table: table));
  }

  Future<void> _runPick({bool table = false}) async {
    final layout = context.read<SeatingService>().activeLayout(widget.classId);
    if (layout == null) return;
    final students = context.read<StudentService>().students;
    final tables = layout.tables
        .where((t) => layout.seats.any((s) =>
            s.tableId == t.tableId &&
            students.any((student) => student.studentId == s.studentId)))
        .toList();
    final seated = students
        .where((s) => layout.seats.any((seat) => seat.studentId == s.studentId))
        .toList();
    final candidateIds = table
        ? tables.map((t) => t.tableId).toList()
        : seated.map((s) => s.studentId).toList();

    if (candidateIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(table
            ? 'No occupied tables to pick.'
            : 'Seat students on the map before picking.'),
      ));
      return;
    }

    final selected = await _picker.animate(
      candidateIds: candidateIds,
      nonRepeatingStudents: !table,
      reduceMotion: MediaQuery.disableAnimationsOf(context),
      onHighlight: (id) {
        if (!mounted) return;
        setState(() {
          _pickedStudent = table ? null : id;
          _pickedTable = table ? id : null;
          _pickLabel = 'Choosing…';
          _toolsOpen = false;
        });
      },
    );
    if (!mounted || selected == null) return;
    setState(() {
      if (table) {
        final chosen = tables.firstWhere((t) => t.tableId == selected);
        _pickLabel = chosen.label.isEmpty ? 'Selected table' : chosen.label;
      } else {
        final chosen = seated.firstWhere((s) => s.studentId == selected);
        _pickLabel =
            '${chosen.englishFirstName} ${chosen.englishLastName}'.trim();
      }
    });
  }

  Future<void> _randomSeating() async {
    final proceed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Random seating'),
      content: const Text('Shuffle student assignments across the existing seats? Locked seats stay unchanged. Tables and chairs will keep their positions.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Shuffle'))]));
    if (proceed != true || !mounted) return;
    try {
      await context.read<SeatingService>().shuffleStudentPlacements(
        widget.classId, context.read<StudentService>().students);
      if (!mounted) return;
      setState(() { _pickedStudent = null; _pickedTable = null; _pickLabel = null; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Random seating saved.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not save random seating. Previous assignments restored.')));
    }
  }

  void _openTimer() => Navigator.of(context).push(MaterialPageRoute<void>(
    fullscreenDialog: true, builder: (_) => const ClassroomTimer(fullPage: true)));

  Widget _toolsPanel(List<Student> students, SeatingService service) {
    final layout = service.activeLayout(widget.classId);
    final seat =
        layout?.seats.where((s) => s.seatId == _selectedSeat).firstOrNull;
    final table =
        layout?.tables.where((t) => t.tableId == seat?.tableId).firstOrNull;
    final selectedTable = layout?.tables
        .where((t) => t.tableId == _selectedTableId).firstOrNull;
    Widget action(IconData icon, String title, VoidCallback onTap) => ListTile(
        leading: Icon(icon),
        title: Text(title),
        onTap: onTap,
        trailing: const Icon(Icons.chevron_right, size: 18));
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 12,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
            child: Row(children: [
              const Expanded(
                  child: Text('Classroom tools',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800))),
              IconButton(
                  tooltip: 'Close tools',
                  onPressed: () => setState(() => _toolsOpen = false),
                  icon: const Icon(Icons.close))
            ])),
        Expanded(
            child:
                ListView(padding: const EdgeInsets.only(bottom: 16), children: [
          if (seat != null && table != null) ...[
            TextButton.icon(
                onPressed: () => setState(() => _selectedSeat = null),
                icon: const Icon(Icons.arrow_back),
                label: const Text('All classroom tools')),
            ClassroomSeatPanel(
                key: ValueKey('${layout!.layoutId}:${seat.seatId}'),
                classId: widget.classId,
                seat: seat,
                table: table,
                students: students,
                service: service,
                arranging: _setupMode,
                scoreCategory: _scoreCategory),
          ] else if (_setupMode && selectedTable != null) ...[
            TextButton.icon(
                onPressed: () => setState(() => _selectedTableId = null),
                icon: const Icon(Icons.arrow_back),
                label: const Text('All room tools')),
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(selectedTable.label.isEmpty ? 'Selected table' : selectedTable.label,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
                    const SizedBox(height: 8),
                    const Text('Drag this table directly to move it. Tap any seat to change its assignment.'),
                  ],
                )),
            if (widget.plannerV2 && layout != null)
              PlannerV2DimensionsEditor(
                key: ValueKey('planner-dimensions:${layout.layoutId}:${selectedTable.tableId}'),
                table: selectedTable,
                room: Size(layout.canvasWidth, layout.canvasHeight),
                onSave: (proposal) => service.commitPlannerV2TableGeometry(
                  widget.classId,
                  proposal,
                ),
              )
            else ...[
              action(Icons.add, 'Increase table size',
                  () => service.resizeTable(widget.classId, selectedTable.tableId, 24, 16)),
              action(Icons.remove, 'Decrease table size',
                  () => service.resizeTable(widget.classId, selectedTable.tableId, -24, -16)),
            ],
            action(Icons.rotate_right, 'Rotate table',
                () => service.rotateTable(widget.classId, selectedTable.tableId)),
            action(Icons.copy_all_outlined, 'Duplicate table',
                () => service.duplicateTable(widget.classId, selectedTable.tableId)),
            action(Icons.delete_outline, 'Remove table', () async {
              final remove = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Remove this table?'),
                  content: const Text('This also removes its seats and their assignments from the current room map.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Remove')),
                  ],
                ),
              );
              if (remove != true || !mounted) return;
              await service.removeTable(widget.classId, selectedTable.tableId);
              if (mounted) setState(() => _selectedTableId = null);
            }),
          ] else ...[
            Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(_setupMode ? 'ROOM SETUP' : 'TEACHING',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5))),
            if (!_setupMode) ...[
              action(
                  Icons.person_search_outlined, 'Pick student', () => _pick()),
              action(Icons.table_restaurant_outlined, 'Pick table',
                  () => _pick(table: true)),
              action(Icons.grid_on_outlined, 'Full gradebook',
                  () => context.go(AppRoutes.osClassGradebook(widget.classId))),
              action(
                  Icons.task_alt,
                  'Homework check',
                  () => setState(() {
                        _scoreCategory = 'Homework';
                        _toolsOpen = false;
                      })),
              action(
                  Icons.quiz_outlined,
                  'Quiz scores',
                  () => setState(() {
                        _scoreCategory = 'Quizzes';
                        _toolsOpen = false;
                      })),
              const Divider(indent: 20, endIndent: 20),
            ],
            SwitchListTile(
                title: const Text('Furniture editing'),
                subtitle: const Text('Move furniture and arrange seats'),
                value: _setupMode,
                onChanged: (v) => setState(() => _setupMode = v)),
            if (_setupMode) ...[
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(layout?.layoutId),
                    initialValue: layout?.layoutId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Room map', border: OutlineInputBorder()),
                    items: service
                        .layoutsForClass(widget.classId)
                        .map((room) => DropdownMenuItem(
                            value: room.layoutId,
                            child: Text(room.name,
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null)
                        service.selectLayout(widget.classId, value);
                    },
                  )),
              action(Icons.meeting_room_outlined,
                  'Use existing shared room', _chooseSharedRoom),
              action(Icons.copy_all_outlined,
                  'Use this room for other classes', _shareRoom),
              const Divider(indent: 20, endIndent: 20),
              action(
                  Icons.table_restaurant_outlined,
                  'Add table',
                  () => service.addTable(
                      widget.classId, SeatingTableType.rectangular,
                      seatCount: 4)),
              action(
                  Icons.circle_outlined,
                  'Add round table',
                  () => service.addTable(widget.classId, SeatingTableType.round,
                      seatCount: 4)),
              action(
                  Icons.desk_outlined,
                  'Add single desk',
                  () => service.addTable(
                      widget.classId, SeatingTableType.singleDesk,
                      seatCount: 1)),
              action(
                  Icons.person_outline,
                  'Add teacher desk',
                  () => service.addTable(
                      widget.classId, SeatingTableType.teacherDesk,
                      seatCount: 0)),
              const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                      'Drag a table or chair directly to move it. Tap a table to edit its shape or size in this panel. Tap an empty seat to assign a student.')),
            ],
            Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                    '${students.length} students · ${layout?.tables.length ?? 0} tables · ${layout?.seats.length ?? 0} seats')),
          ],
        ])),
      ]),
    );
  }

  void _roomMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  /// The room template contains furniture, NOT the originating class's pupils.
  Future<void> _shareRoom() async {
    if (GradeFlowExistingProjectPreview.enabled) {
      _roomMessage('This preview is read-only. Room changes are disabled.');
      return;
    }
    final seats = context.read<SeatingService>();
    final otherClasses = context.read<ClassService>().classes
        .where((item) => item.classId != widget.classId)
        .toList();
    if (seats.activeLayout(widget.classId)?.tables.isEmpty ?? true) {
      _roomMessage('Arrange the physical classroom before sharing it.');
      return;
    }
    if (otherClasses.isEmpty) {
      _roomMessage('There are no other classes to share this room with.');
      return;
    }
    final selectedIds = otherClasses.map((c) => c.classId).toSet();
    final chosen = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          title: const Text('Use this room for other classes'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Copy the physical room only. Students and grades '
                    'remain separate for each class. Existing assigned '
                    'seating maps are kept as alternatives.'),
                CheckboxListTile(
                  title: const Text('All other classes'),
                  dense: true,
                  value: selectedIds.length == otherClasses.length,
                  onChanged: (value) => update(() {
                    if (value == true) {
                      selectedIds.addAll(otherClasses.map((c) => c.classId));
                    } else {
                      selectedIds.clear();
                    }
                  }),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final other in otherClasses)
                        CheckboxListTile(
                          title: Text(other.className),
                          dense: true,
                          value: selectedIds.contains(other.classId),
                          onChanged: (value) => update(() {
                            if (value == true) {
                              selectedIds.add(other.classId);
                            } else {
                              selectedIds.remove(other.classId);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: selectedIds.isEmpty ? null
                  : () => Navigator.pop(dialogContext, Set.of(selectedIds)),
              child: const Text('Reuse room'),
            ),
          ],
        ),
      ),
    );
    if (chosen == null || chosen.isEmpty || !mounted) return;
    try {
      final saved = await seats.saveRoomSetupFromLayout(
        classId: widget.classId,
        name: seats.assignedRoomSetup(widget.classId)?.name ?? 'Shared classroom',
        roomSetupId: seats.assignedRoomSetupId(widget.classId),
      );
      if (saved == null) throw StateError('Could not save source room.');
      var completed = 0;
      for (final targetClassId in chosen) {
        if (await seats.applyRoomSetupToClass(
          classId: targetClassId,
          roomSetupId: saved.roomSetupId,
        ) != null) completed++;
      }
      _roomMessage('Room shared with $completed of ${chosen.length} classes. '
          'Student assignments remain independent.');
    } catch (error) {
      _roomMessage('Room sharing did not complete: $error');
    }
  }

  Future<void> _chooseSharedRoom() async {
    if (GradeFlowExistingProjectPreview.enabled) {
      _roomMessage('This preview is read-only. Room changes are disabled.');
      return;
    }
    final seats = context.read<SeatingService>();
    if (seats.roomSetups.isEmpty) {
      _roomMessage('No shared rooms yet. In your arranged J1 classroom, '
          'choose "Use this room for other classes".');
      return;
    }
    final id = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Use an existing classroom'),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text('Copies furniture and positions, not students. '
                'Existing class seating maps remain available.'),
          ),
          for (final setup in seats.roomSetups)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, setup.roomSetupId),
              child: Text(setup.name),
            ),
        ],
      ),
    );
    if (id == null || !mounted) return;
    try {
      final result = await seats.applyRoomSetupToClass(
          classId: widget.classId, roomSetupId: id);
      if (result == null) throw StateError('Selected room was not available.');
      if (!mounted) return;
      setState(() {
        _selectedSeat = null;
        _selectedTableId = null;
        _fitRevision++;
      });
      _roomMessage('Shared room applied; now arrange this class\'s students.');
    } catch (error) {
      _roomMessage('Could not apply room: $error');
    }
  }

  void _openPresentation({
    required String className,
    required String subject,
  }) {
    _picker.cancel();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ClassroomPresentationView(
          picker: _picker,
          classId: widget.classId,
          className: className,
          subject: subject,
          cleanCanvas: widget.cleanCanvas,
          plannerV2: widget.plannerV2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final classItem =
        context.watch<ClassService>().getClassById(widget.classId);
    final students = context.watch<StudentService>().students;
    final seatingService = context.watch<SeatingService>();

    if (_loading) {
      return _ClassroomState(
        title: 'Loading classroom',
        subtitle: 'Restoring the class roster and room map.',
        loading: true,
        onBack: _backToClass,
      );
    }

    if (classItem == null) {
      return _ClassroomState(
        title: 'Class not found',
        subtitle: 'Return to the class workspace and choose another class.',
        onBack: _backToClass,
      );
    }

    final roomName = seatingService.assignedRoomSetup(widget.classId)?.name;
    final scheme = ColorScheme.fromSeed(
        seedColor: const Color(0xff187f79),
        brightness: Theme.of(context).brightness);
    return Theme(
        data: Theme.of(context).copyWith(colorScheme: scheme),
        child: Scaffold(
          backgroundColor: OSColors.appBackground(dark),
          body: SafeArea(
              bottom: true,
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  child: Column(children: [
                    _ClassroomHeader(
                        className: classItem.className,
                        subject: classItem.subject,
                        studentCount: students.length,
                        roomName: roomName,
                        setupMode: _setupMode,
                        toolsOpen: _toolsOpen,
                        onBack: _backToClass,
                        onToggleTools: () =>
                            setState(() => _toolsOpen = !_toolsOpen),
                        onPresent: () => _openPresentation(
                            className: classItem.className,
                            subject: classItem.subject)),
                    const SizedBox(height: 10),
                    if (widget.plannerV2 && _setupMode)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: seatingService.canUndoPlannerV2(widget.classId)
                                  ? () async {
                                      try {
                                        await seatingService.undoPlannerV2(widget.classId);
                                      } catch (_) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text(
                                              'Could not save Undo. Previous layout restored.',
                                            )),
                                          );
                                        }
                                      }
                                    }
                                  : null,
                              icon: const Icon(Icons.undo, size: 18),
                              label: const Text('Undo'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: seatingService.canRedoPlannerV2(widget.classId)
                                  ? () async {
                                      try {
                                        await seatingService.redoPlannerV2(widget.classId);
                                      } catch (_) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text(
                                              'Could not save Redo. Previous layout restored.',
                                            )),
                                          );
                                        }
                                      }
                                    }
                                  : null,
                              icon: const Icon(Icons.redo, size: 18),
                              label: const Text('Redo'),
                            ),
                            const Spacer(),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  seatingService.plannerV2SaveState(widget.classId) ==
                                      PlannerV2SaveState.failed
                                      ? Icons.error_outline
                                      : seatingService.plannerV2SaveState(widget.classId) ==
                                              PlannerV2SaveState.saved
                                          ? Icons.cloud_done_outlined
                                          : Icons.cloud_upload_outlined,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  switch (seatingService.plannerV2SaveState(widget.classId)) {
                                    PlannerV2SaveState.idle => 'No changes',
                                    PlannerV2SaveState.saving => 'Saving…',
                                    PlannerV2SaveState.saved => 'Saved',
                                    PlannerV2SaveState.failed => 'Save failed',
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    SizedBox(
                        height: 42,
                        child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(children: [
                              TextButton.icon(onPressed: _randomSeating,
                                  icon: const Icon(Icons.shuffle), label: const Text('Random seating')),
                              TextButton.icon(onPressed: () => setState(() { _fitRevision++; _zoomFactor = 1; }),
                                  icon: const Icon(Icons.fit_screen), label: const Text('Fit to screen')),
                              if (widget.plannerV2) TextButton.icon(onPressed: _zoomFactor >= 3 ? null : () => setState(() => _zoomFactor = (_zoomFactor * 1.2).clamp(.25, 3)),
                                  icon: const Icon(Icons.zoom_in), label: const Text('Zoom in')),
                              if (widget.plannerV2) TextButton.icon(onPressed: _zoomFactor <= .25 ? null : () => setState(() => _zoomFactor = (_zoomFactor / 1.2).clamp(.25, 3)),
                                  icon: const Icon(Icons.zoom_out), label: const Text('Zoom out')),
                              TextButton.icon(onPressed: _openTimer,
                                  icon: const Icon(Icons.timer_outlined), label: const Text('Full-page timer')),
                              TextButton.icon(
                                  onPressed: () => _pick(),
                                  icon:
                                      const Icon(Icons.person_search_outlined),
                                  label: const Text('Pick student')),
                              TextButton.icon(
                                  onPressed: () => _pick(table: true),
                                  icon: const Icon(
                                      Icons.table_restaurant_outlined),
                                  label: const Text('Pick table')),
                              TextButton.icon(
                                  onPressed: () => setState(() {
                                        _selectedSeat = null;
                                        _selectedTableId = null;
                                        _setupMode = !_setupMode;
                                        _toolsOpen = _setupMode;
                                      }),
                                  icon: const Icon(
                                      Icons.dashboard_customize_outlined),
                                  label: Text(_setupMode
                                      ? 'Finish arranging'
                                      : 'Arrange room')),
                              if (_pickLabel != null) ...[
                                const SizedBox(width: 12),
                                InputChip(
                                    label: Text(_pickLabel!),
                                    avatar: const Icon(Icons.auto_awesome,
                                        size: 16),
                                    onDeleted: () => setState(() {
                                          _picker.cancel();
                                          _pickedStudent = null;
                                          _pickedTable = null;
                                          _pickLabel = null;
                                        }))
                              ],
                              if (_scoreCategory != null) ...[
                                const SizedBox(width: 12),
                                InputChip(
                                    label: Text(
                                        '$_scoreCategory · select a student'),
                                    onDeleted: () =>
                                        setState(() => _scoreCategory = null))
                              ],
                            ]))),
                    const SizedBox(height: 8),
                    Expanded(
                        child: LayoutBuilder(
                            builder: (context, size) => ClipRect(
                                    child: Stack(children: [
                                  Positioned.fill(
                                      child: _ClassroomMapPanel(
                                          classId: widget.classId,
                                          students: students,
                                          setupMode: _setupMode,
                                          fitRevision: _fitRevision,
                                          zoomFactor: _zoomFactor,
                                          cleanCanvas: widget.cleanCanvas,
                                          plannerV2: widget.plannerV2,
                                          selectedTableId: _selectedTableId,
                                          onSeatSelected: (id) => setState(() {
                                                _selectedSeat = id;
                                                _selectedTableId = null;
                                                _toolsOpen = true;
                                              }),
                                          onTableSelected: (id) => setState(() {
                                                _selectedSeat = null;
                                                _selectedTableId = id;
                                                _toolsOpen = true;
                                              }),
                                          scoreCategory: _scoreCategory,
                                          highlightedStudentId: _pickedStudent,
                                          highlightedTableId: _pickedTable)),
                                  Positioned(
                                      top: 0,
                                      bottom: 0,
                                      right: 0,
                                      width: min(340.0, size.maxWidth * .92),
                                      child: IgnorePointer(
                                          ignoring: !_toolsOpen,
                                          child: ExcludeSemantics(
                                              excluding: !_toolsOpen,
                                              child: AnimatedSlide(
                                                  duration: MediaQuery
                                                          .disableAnimationsOf(
                                                              context)
                                                      ? Duration.zero
                                                      : const Duration(
                                                          milliseconds: 240),
                                                  curve: Curves.easeOutCubic,
                                                  offset: _toolsOpen
                                                      ? Offset.zero
                                                      : const Offset(1.1, 0),
                                                  child: _toolsPanel(students,
                                                      seatingService))))),
                                ])))),
                  ]))),
        ));
  }
}

class _ClassroomHeader extends StatelessWidget {
  const _ClassroomHeader({
    required this.className,
    required this.subject,
    required this.studentCount,
    required this.roomName,
    required this.setupMode,
    required this.toolsOpen,
    required this.onBack,
    required this.onToggleTools,
    required this.onPresent,
  });

  final String className;
  final String subject;
  final int studentCount;
  final String? roomName;
  final bool setupMode;
  final bool toolsOpen;
  final VoidCallback onBack;
  final VoidCallback onToggleTools;
  final VoidCallback onPresent;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xff133c67), Color(0xff14817b)]),
        borderRadius: OSRadius.lgBr,
        border: Border.all(
          color: OSColors.panelBorder(dark).withValues(alpha: 0.86),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back to classes',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        className,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    '$studentCount students',
                    if ((roomName ?? '').trim().isNotEmpty) roomName!.trim(),
                    setupMode ? 'Arrange Mode' : 'Teach Mode',
                  ].join('  •  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onToggleTools,
            style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54)),
            icon: Icon(
              toolsOpen ? Icons.chevron_right_rounded : Icons.tune_rounded,
              size: 18,
            ),
            label: Text(toolsOpen ? 'Hide tools' : 'Show tools'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onPresent,
            icon: const Icon(Icons.present_to_all_rounded, size: 18),
            label: const Text('Present'),
          ),
        ],
      ),
    );
  }
}

class _ClassroomMapPanel extends StatelessWidget {
  const _ClassroomMapPanel({
    this.fitRevision = 0,
    this.zoomFactor = 1,
    required this.classId,
    required this.students,
    required this.setupMode,
    required this.cleanCanvas,
    required this.plannerV2,
    required this.selectedTableId,
    required this.onSeatSelected,
    required this.onTableSelected,
    this.scoreCategory,
    this.highlightedStudentId,
    this.highlightedTableId,
  });

  final int fitRevision;
  final double zoomFactor;
  final String classId;
  final List<Student> students;
  final bool setupMode;
  final bool cleanCanvas;
  final bool plannerV2;
  final String? selectedTableId;
  final ValueChanged<String> onSeatSelected;
  final ValueChanged<String> onTableSelected;
  final String? scoreCategory;
  final String? highlightedStudentId;
  final String? highlightedTableId;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      padding: cleanCanvas ? EdgeInsets.zero : const EdgeInsets.all(8),
      decoration: cleanCanvas
          ? BoxDecoration(color: OSColors.panelSurface(dark).withValues(alpha: 0.72))
          : BoxDecoration(
              color: OSColors.panelSurface(dark).withValues(alpha: 0.72),
              borderRadius: OSRadius.lgBr,
              border: Border.all(color: OSColors.panelBorder(dark).withValues(alpha: 0.86)),
            ),
      child: SeatingDesignerView(
        classId: classId,
        fitRevision: fitRevision,
        zoomFactor: zoomFactor,
        students: students,
        autoLoad: false,
        onSeatSelected: onSeatSelected,
        onTableSelected: onTableSelected,
        premiumAppearance: true,
        simplifiedArrange: cleanCanvas,
        plannerV2: plannerV2,
        selectedTableId: selectedTableId,
        scoreCategory: scoreCategory,
        highlightedStudentId: highlightedStudentId,
        highlightedTableId: highlightedTableId,
        editRoomMode: setupMode,
        allowSeatReassignment: setupMode,
        showToolbar: false,
        showStudentPanel: false,
        showFullScreenButton: false,
        showUseHint: false,
        webMode: kIsWeb,
      ),
    );
  }
}

class _ClassroomState extends StatelessWidget {
  const _ClassroomState({
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.loading = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Scaffold(
      backgroundColor: OSColors.appBackground(dark),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: OSColors.panelSurface(dark),
                borderRadius: OSRadius.lgBr,
                border: Border.all(color: OSColors.panelBorder(dark)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading)
                    const CircularProgressIndicator()
                  else
                    Icon(
                      Icons.meeting_room_outlined,
                      size: 40,
                      color: OSColors.textSubtle(dark),
                    ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: OSColors.textPrimary(dark),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      height: 1.35,
                      color: OSColors.textSubtle(dark),
                    ),
                  ),
                  if (!loading) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white),
                      label: const Text('Back to class'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
