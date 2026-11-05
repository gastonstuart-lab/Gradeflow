import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/components/classroom/classroom_tools_drawer.dart';
import 'package:gradeflow/components/seating/seating_designer_view.dart';
import 'package:gradeflow/components/seating/student_picker_sheet.dart';
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
  bool _toolsOpen = true;
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
    context.go(AppRoutes.osClassWorkspace(widget.classId));
  }

  Future<void> _openStudentPicker({
    required List<Student> students,
    required SeatingService seatingService,
  }) async {
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students are available to pick.')),
      );
      return;
    }

    final seatLabels = <String, String>{};
    final layout = seatingService.activeLayout(widget.classId);
    if (layout != null) {
      final orderedSeats = seatingService.orderedSeatsForLayout(layout);
      for (var index = 0; index < orderedSeats.length; index++) {
        final studentId = orderedSeats[index].studentId;
        if (studentId != null && studentId.isNotEmpty) {
          seatLabels[studentId] = 'Seat ${index + 1}';
        }
      }
    }

    final entries = students
        .map(
          (student) => StudentPickerEntry(
            student: student,
            seatLabel: seatLabels[student.studentId],
          ),
        )
        .toList(growable: false);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => StudentPickerSheet(entries: entries),
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
    final activeLayout = seatingService.activeLayout(widget.classId);

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

    final placedSeatCount = activeLayout?.seats
            .where((seat) => (seat.studentId ?? '').trim().isNotEmpty)
            .length ??
        0;
    final seatCount = activeLayout?.seats.length ?? 0;
    final tableCount = activeLayout?.tables.length ?? 0;
    final roomName = seatingService.assignedRoomSetup(widget.classId)?.name;

    return Scaffold(
      backgroundColor: OSColors.appBackground(dark),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 980;

            final map = _ClassroomMapPanel(
              classId: widget.classId,
              students: students,
              setupMode: _setupMode,
              scoreCategory: _scoreCategory,
            );

            final drawer = ClassroomToolsDrawer(
              studentCount: students.length,
              placedSeatCount: placedSeatCount,
              seatCount: seatCount,
              tableCount: tableCount,
              setupMode: _setupMode,
              onClose: () => setState(() => _toolsOpen = false),
              onSetupModeChanged: (value) =>
                  setState(() => _setupMode = value),
              onPickStudent: () {
                unawaited(
                  _openStudentPicker(
                    students: students,
                    seatingService: seatingService,
                  ),
                );
              },
              onOpenStudents: () =>
                  context.go(AppRoutes.osClassStudents(widget.classId)),
              onOpenGradebook: () =>
                  context.go(AppRoutes.osClassGradebook(widget.classId)),
              onOpenSchedule: () =>
                  context.go(AppRoutes.osClassSchedule(widget.classId)),
              onOpenResults: () =>
                  context.go(AppRoutes.osClassResults(widget.classId)),
              onOpenLegacySeating: () =>
                  context.go(AppRoutes.osClassSeating(widget.classId)),
            );

            return Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 10 : 14,
                10,
                compact ? 10 : 14,
                8,
              ),
              child: Column(
                children: [
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
                      subject: classItem.subject,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(margin:EdgeInsets.zero,child:Padding(padding:const EdgeInsets.all(8),child:Wrap(spacing:8,runSpacing:6,children:[
                    OutlinedButton.icon(onPressed:()=>setState(()=>_setupMode=!_setupMode),icon:const Icon(Icons.dashboard_customize_outlined),label:Text(_setupMode?'Finish room setup':'Room setup')),
                    OutlinedButton.icon(onPressed:()=>_openStudentPicker(students:students,seatingService:seatingService),icon:const Icon(Icons.person_search_outlined),label:const Text('Pick student')),
                    OutlinedButton.icon(onPressed:()=>setState(()=>_scoreCategory='Homework'),icon:const Icon(Icons.task_alt),label:Text(_scoreCategory=='Homework'?'Homework check · select a student':'Homework check')),
                    OutlinedButton.icon(onPressed:()=>setState(()=>_scoreCategory='Quizzes'),icon:const Icon(Icons.quiz_outlined),label:Text(_scoreCategory=='Quizzes'?'Quiz scores · select a student':'Quiz scores')),
                    FilledButton.tonalIcon(onPressed:()=>context.go(AppRoutes.osClassGradebook(widget.classId)),icon:const Icon(Icons.grid_on),label:const Text('Full gradebook')),
                    OutlinedButton.icon(onPressed:()=>setState(()=>_toolsOpen=!_toolsOpen),icon:const Icon(Icons.tune),label:const Text('Class tools')),
                  ]))),
                  const SizedBox(height: 10),
                  Expanded(child:Stack(children:[
                    Positioned.fill(child:map),
                    if(_toolsOpen) Positioned(left:0,right:0,bottom:0,height:(constraints.maxHeight*.48).clamp(200.0,340.0),child:drawer),
                  ])),
                ],
              ),
            );
          },
        ),
      ),
    );
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
        gradient: const LinearGradient(colors:[Color(0xff133c67),Color(0xff14817b)]),
        borderRadius: OSRadius.lgBr,
        border: Border.all(
          color: OSColors.panelBorder(dark).withValues(alpha: 0.86),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back to class workspace',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
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
                          color: OSColors.blueSoft,
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
                    setupMode ? 'Setup Room' : 'Teach Mode',
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
  });

  final String classId;
  final List<Student> students;
  final bool setupMode;
  final String? scoreCategory;

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
        editRoomMode: setupMode,
        showToolbar: setupMode,
        showStudentPanel: setupMode,
        showFullScreenButton: false,
        showUseHint: setupMode,
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
                      icon: const Icon(Icons.arrow_back_rounded),
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
