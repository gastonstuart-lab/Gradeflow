import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/models/seating_layout.dart';
import 'package:gradeflow/components/seating/seating_designer_view.dart';

import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/os/os_palette.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/seating_service.dart';
import 'package:gradeflow/services/student_service.dart';

class ClassroomSurface extends StatefulWidget {
  const ClassroomSurface({
    super.key,
    required this.classId,
  });

  final String classId;

  @override
  State<ClassroomSurface> createState() => _ClassroomSurfaceState();
}

class _ClassroomSurfaceState extends State<ClassroomSurface> {
  bool _loading = true;
  bool _toolsOpen = false;
  String? _pickedStudent;
  String? _pickedTable;
  String? _pickLabel;
  final _pickedStudents = <String>{};
  final _random = Random();
  String? _scoreCategory;
  bool _setupMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadClassroom());
    });
  }

  @override
  void didUpdateWidget(covariant ClassroomSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classId != widget.classId) {
      setState(() {
        _loading = true;
        _setupMode = false;
        _pickedStudents.clear();
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
    final layout = context.read<SeatingService>().activeLayout(widget.classId);
    if (layout == null) return;
    final students = context.read<StudentService>().students;
    if (table) {
      final tables = layout.tables
          .where((t) => layout.seats
              .any((s) => s.tableId == t.tableId && s.studentId != null))
          .toList();
      if (tables.isEmpty) return;
      final chosen = tables[_random.nextInt(tables.length)];
      setState(() {
        _pickedTable = chosen.tableId;
        _pickedStudent = null;
        _pickLabel = chosen.label.isEmpty ? 'Selected table' : chosen.label;
        _toolsOpen = false;
      });
    } else {
      final seated = students
          .where(
              (s) => layout.seats.any((seat) => seat.studentId == s.studentId))
          .toList();
      if (seated.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Seat students on the map before picking.')));
        return;
      }
      var available =
          seated.where((s) => !_pickedStudents.contains(s.studentId)).toList();
      if (available.isEmpty) {
        _pickedStudents.clear();
        available = seated;
      }
      final chosen = available[_random.nextInt(available.length)];
      _pickedStudents.add(chosen.studentId);
      setState(() {
        _pickedStudent = chosen.studentId;
        _pickedTable = null;
        _pickLabel =
            '${chosen.englishFirstName} ${chosen.englishLastName}'.trim();
        _toolsOpen = false;
      });
    }
  }

  Widget _toolsPanel(List<Student> students, SeatingService service) {
    final layout = service.activeLayout(widget.classId);
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
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(_setupMode ? 'ROOM SETUP' : 'TEACHING',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5))),
          if (!_setupMode) ...[
            action(Icons.person_search_outlined, 'Pick student', () => _pick()),
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
              title: const Text('Arrange room'),
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
                          child:
                              Text(room.name, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null)
                      service.selectLayout(widget.classId, value);
                  },
                )),
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
                    'Drag furniture on the floor. Use a table’s menu to resize, rotate or change its seats. Tap an empty seat to assign a student.')),
          ],
          Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                  '${students.length} students · ${layout?.tables.length ?? 0} tables · ${layout?.seats.length ?? 0} seats')),
        ])),
      ]),
    );
  }

  void _openPresentation({
    required String className,
    required String subject,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _ClassroomPresentationView(
          classId: widget.classId,
          className: className,
          subject: subject,
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
                    SizedBox(
                        height: 42,
                        child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(children: [
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
    required this.classId,
    required this.students,
    required this.setupMode,
    this.scoreCategory,
    this.highlightedStudentId,
    this.highlightedTableId,
  });

  final String classId;
  final List<Student> students;
  final bool setupMode;
  final String? scoreCategory;
  final String? highlightedStudentId;
  final String? highlightedTableId;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: OSColors.panelSurface(dark).withValues(alpha: 0.72),
        borderRadius: OSRadius.lgBr,
        border: Border.all(
          color: OSColors.panelBorder(dark).withValues(alpha: 0.86),
        ),
      ),
      child: SeatingDesignerView(
        classId: classId,
        students: students,
        autoLoad: false,
        premiumAppearance: true,
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

class _ClassroomPresentationView extends StatelessWidget {
  const _ClassroomPresentationView({
    required this.classId,
    required this.className,
    required this.subject,
  });

  final String classId;
  final String className;
  final String subject;

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
                        Text(
                          className,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          subject,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: OSColors.teachAccent,
                          ),
                        ),
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
                        color: Colors.white.withValues(alpha: 0.24),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: OSColors.teachSurface,
                    borderRadius: OSRadius.mdBr,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: SeatingDesignerView(
                    classId: classId,
                    students: students,
                    autoLoad: false,
                    presentationMode: true,
                    premiumAppearance: true,
                    interactive: false,
                    editRoomMode: false,
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
