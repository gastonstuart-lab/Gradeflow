/// GradeFlow OS — Teach Surface
///
/// Classroom-safe teaching mode.  Designed for front-of-class projection
/// on Surface Pro, iPad, or any large screen.
///
/// STRICT privacy rules enforced here:
///   - No personal messages shown
///   - No admin alerts shown
///   - No private student data exposed
///   - No staff-only surfaces visible
///
/// What IS available:
///   - Full-screen Whiteboard (primary surface)
///   - Countdown Timer
///   - Name/Group picker
///   - Quick file access (display-only)
///   - Quick poll
///   - Teaching mode toolbar

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/os/os_controller.dart';
import 'package:gradeflow/os/os_palette.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/screens/teacher_whiteboard_screen.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/student_service.dart';

const double _teachContentTopInset = 118;

class TeachSurface extends StatefulWidget {
  const TeachSurface({super.key});

  @override
  State<TeachSurface> createState() => _TeachSurfaceState();
}

class _TeachSurfaceState extends State<TeachSurface> {
  _TeachTool _activeTool = _TeachTool.whiteboard;
  String? _observedClassId;
  bool _loadingContext = false;
  String? _contextError;
  Class? _activeClass;
  List<Student> _roster = const <Student>[];
  final TextEditingController _pollQuestionCtrl =
      TextEditingController(text: 'Quick check-in');
  _PollMode _pollMode = _PollMode.abcd;
  Map<String, int> _pollCounts = _initialPollCounts(_PollMode.abcd);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<GradeFlowOSController>().setSurface(OSSurface.teach);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final activeClassId =
        Provider.of<GradeFlowOSController>(context).activeClassId;
    if (_observedClassId == activeClassId) return;
    _observedClassId = activeClassId;
    if (activeClassId == null || activeClassId.trim().isEmpty) {
      _loadingContext = false;
      _contextError = null;
      _activeClass = null;
      _roster = const <Student>[];
    } else {
      _loadingContext = true;
      _contextError = null;
      _activeClass = null;
      _roster = const <Student>[];
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_loadTeachContext(activeClassId));
      }
    });
  }

  @override
  void dispose() {
    _pollQuestionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const teachBg = OSColors.teachBg;

    return Scaffold(
      backgroundColor: teachBg,
      body: Stack(
        children: [
          // ── Main tool area ────────────────────────────────────────────
          Positioned.fill(
            bottom: 0,
            child: _buildSurfaceBody(context),
          ),

          if (_activeClass != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 64, 12, 0),
                  child: _TeachContextStrip(
                    className: _activeClass!.className,
                    studentCount: _roster.length,
                  ),
                ),
              ),
            ),

          // ── Teaching mode toolbar (top) ─────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: _TeachToolbar(
                activeTool: _activeTool,
                onToolSelected: (t) => setState(() => _activeTool = t),
                onExit: () {
                  context
                      .read<GradeFlowOSController>()
                      .setSurface(OSSurface.home);
                  context.go(AppRoutes.osHome);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadTeachContext(String? classId) async {
    if (classId == null || classId.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _loadingContext = false;
        _contextError = null;
        _activeClass = null;
        _roster = const <Student>[];
        _resetPollState();
      });
      return;
    }

    setState(() {
      _loadingContext = true;
      _contextError = null;
      _activeClass = null;
      _roster = const <Student>[];
      _resetPollState();
    });

    final auth = context.read<AuthService>();
    final classService = context.read<ClassService>();
    final studentService = context.read<StudentService>();

    try {
      var classItem = classService.getClassById(classId);
      final user = auth.currentUser;
      if (classItem == null && user != null) {
        await classService.loadClasses(user.userId);
        classItem = classService.getClassById(classId);
      }

      await studentService.loadStudents(classId);

      if (!mounted || _observedClassId != classId) return;
      setState(() {
        _loadingContext = false;
        _activeClass = classItem;
        _roster = List<Student>.from(studentService.students);
        _contextError = classItem == null
            ? 'We could not restore the selected class for Teach Mode.'
            : null;
      });
    } catch (e) {
      debugPrint('Teach Mode failed to load class context: $e');
      if (!mounted || _observedClassId != classId) return;
      setState(() {
        _loadingContext = false;
        _activeClass = null;
        _roster = const <Student>[];
        _contextError = 'Teach Mode could not load the current class.';
      });
    }
  }

  Widget _buildSurfaceBody(BuildContext context) {
    if (_loadingContext) {
      return const _TeachLoadingState();
    }

    final activeClassId = _observedClassId;
    if (activeClassId == null || activeClassId.trim().isEmpty) {
      return _TeachEmptyState(
        icon: Icons.class_outlined,
        title: 'No class selected',
        subtitle:
            'Open a class workspace first, then enter Teach Mode to use the live roster, group picker, and quick poll.',
        primaryLabel: 'Open classes',
        onPrimary: () => context.go(AppRoutes.classes),
        secondaryLabel: 'Back home',
        onSecondary: () => context.go(AppRoutes.osHome),
      );
    }

    if (_activeClass == null) {
      return _TeachEmptyState(
        icon: Icons.cast_for_education_outlined,
        title: 'Class unavailable',
        subtitle: _contextError ??
            'We could not restore this class for Teach Mode right now.',
        primaryLabel: 'Open classes',
        onPrimary: () => context.go(AppRoutes.classes),
        secondaryLabel: 'Back home',
        onSecondary: () => context.go(AppRoutes.osHome),
      );
    }

    return _buildToolArea(context);
  }

  Widget _buildToolArea(BuildContext context) {
    switch (_activeTool) {
      case _TeachTool.whiteboard:
        return const _WhiteboardContainer();
      case _TeachTool.timer:
        return const _TimerTool();
      case _TeachTool.groups:
        return _GroupPickerTool(
          key: ValueKey('teach-groups-${_activeClass!.classId}'),
          studentNames: _roster.map(_displayStudentName).toList(),
        );
      case _TeachTool.poll:
        return _PollTool(
          questionController: _pollQuestionCtrl,
          mode: _pollMode,
          counts: _pollCounts,
          onModeChanged: _setPollMode,
          onVote: _vote,
          onReset: _resetPoll,
        );
    }
  }

  void _setPollMode(_PollMode mode) {
    if (_pollMode == mode) return;
    setState(() {
      _pollMode = mode;
      _pollCounts = _initialPollCounts(mode);
    });
  }

  void _vote(String option) {
    setState(() {
      _pollCounts = {
        for (final entry in _pollCounts.entries) entry.key: entry.value,
      };
      _pollCounts[option] = (_pollCounts[option] ?? 0) + 1;
    });
  }

  void _resetPoll() {
    setState(_resetPollState);
  }

  void _resetPollState() {
    _pollMode = _PollMode.abcd;
    _pollCounts = _initialPollCounts(_PollMode.abcd);
    _pollQuestionCtrl.text = 'Quick check-in';
  }

  static Map<String, int> _initialPollCounts(_PollMode mode) => {
        for (final option in _pollOptionsFor(mode)) option: 0,
      };

  static List<String> _pollOptionsFor(_PollMode mode) => mode == _PollMode.yesNo
      ? const ['Yes', 'No']
      : const ['A', 'B', 'C', 'D'];

  static String _displayStudentName(Student student) {
    final chinese = student.chineseName.trim();
    if (chinese.isNotEmpty) return chinese;

    final english = student.englishFullName.trim();
    if (english.isNotEmpty) return english;

    final fallback = student.englishFirstName.trim();
    return fallback.isNotEmpty ? fallback : 'Student';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOOL ENUM
// ─────────────────────────────────────────────────────────────────────────────

enum _TeachTool { whiteboard, timer, groups, poll }

enum _PollMode { abcd, yesNo }

// ─────────────────────────────────────────────────────────────────────────────
// TEACH TOOLBAR
// ─────────────────────────────────────────────────────────────────────────────

class _TeachToolbar extends StatelessWidget {
  const _TeachToolbar({
    required this.activeTool,
    required this.onToolSelected,
    required this.onExit,
  });

  final _TeachTool activeTool;
  final ValueChanged<_TeachTool> onToolSelected;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xCC101820);
    const activeText = OSColors.teachAccent;
    const inactiveText = Color(0xFF7A8FA8);

    return Container(
      height: 52,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: OSRadius.pillBr,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Mode label
          Padding(
            padding: const EdgeInsets.only(left: 14, right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cast_for_education_rounded,
                  size: 14,
                  color: activeText,
                ),
                const SizedBox(width: 5),
                const Text(
                  'TEACH',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: activeText,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

          Container(
            width: 1,
            height: 22,
            color: Colors.white.withValues(alpha: 0.1),
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),

          // Tool buttons
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ToolButton(
                    icon: Icons.draw_rounded,
                    label: 'Board',
                    tool: _TeachTool.whiteboard,
                    active: activeTool,
                    onTap: onToolSelected,
                  ),
                  _ToolButton(
                    icon: Icons.timer_outlined,
                    label: 'Timer',
                    tool: _TeachTool.timer,
                    active: activeTool,
                    onTap: onToolSelected,
                  ),
                  _ToolButton(
                    icon: Icons.group_rounded,
                    label: 'Groups',
                    tool: _TeachTool.groups,
                    active: activeTool,
                    onTap: onToolSelected,
                  ),
                  _ToolButton(
                    icon: Icons.how_to_vote_outlined,
                    label: 'Poll',
                    tool: _TeachTool.poll,
                    active: activeTool,
                    onTap: onToolSelected,
                  ),
                ],
              ),
            ),
          ),

          // Exit button
          GestureDetector(
            onTap: onExit,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: OSRadius.pillBr,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close_rounded, size: 13, color: inactiveText),
                  SizedBox(width: 4),
                  Text(
                    'Exit',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: inactiveText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.tool,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final _TeachTool tool;
  final _TeachTool active;
  final ValueChanged<_TeachTool> onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = tool == active;
    const activeText = OSColors.teachAccent;
    const inactiveText = Color(0xFF7A8FA8);

    return GestureDetector(
      onTap: () => onTap(tool),
      child: AnimatedContainer(
        duration: OSMotion.fast,
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? activeText.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: OSRadius.pillBr,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? activeText : inactiveText,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? activeText : inactiveText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WHITEBOARD CONTAINER
// ─────────────────────────────────────────────────────────────────────────────

class _TeachContextStrip extends StatelessWidget {
  const _TeachContextStrip({
    required this.className,
    required this.studentCount,
  });

  final String className;
  final int studentCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xCC101820),
        borderRadius: OSRadius.pillBr,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.class_rounded,
            size: 14,
            color: OSColors.teachAccent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              className,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$studentCount students',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeachLoadingState extends StatelessWidget {
  const _TeachLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: _teachContentTopInset),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: OSColors.teachAccent,
            ),
            SizedBox(height: 16),
            Text(
              'Loading class context',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeachEmptyState extends StatelessWidget {
  const _TeachEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, _teachContentTopInset, 20, 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: OSRadius.xlBr,
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: OSColors.teachAccent.withValues(alpha: 0.12),
                    borderRadius: OSRadius.lgBr,
                  ),
                  child: Icon(
                    icon,
                    color: OSColors.teachAccent,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: onPrimary,
                      icon: const Icon(Icons.class_rounded),
                      label: Text(primaryLabel),
                      style: FilledButton.styleFrom(
                        backgroundColor: OSColors.teachAccent,
                        foregroundColor: OSColors.teachBg,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: onSecondary,
                      icon: const Icon(Icons.home_rounded),
                      label: Text(secondaryLabel),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WhiteboardContainer extends StatelessWidget {
  const _WhiteboardContainer();

  @override
  Widget build(BuildContext context) {
    // Embed the existing TeacherWhiteboardScreen inside Teach mode.
    // The whiteboard already handles its own touch drawing.
    return Padding(
      padding: const EdgeInsets.only(top: _teachContentTopInset),
      child: TeacherWhiteboardScreen(
        controller: null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TIMER TOOL
// ─────────────────────────────────────────────────────────────────────────────

class _TimerTool extends StatefulWidget {
  const _TimerTool();

  @override
  State<_TimerTool> createState() => _TimerToolState();
}

class _TimerToolState extends State<_TimerTool> {
  static const _presets = [1, 2, 3, 5, 10, 15, 20, 25, 30];

  int _selectedMinutes = 5;
  int _remainingSeconds = 0;
  bool _running = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _remainingSeconds = _selectedMinutes * 60;
    _running = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _running = false;
          _timer?.cancel();
        }
      });
    });
    setState(() {});
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _running = false);
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _running = false;
      _remainingSeconds = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_running || _remainingSeconds > 0
        ? _remainingSeconds ~/ 60
        : _selectedMinutes);
    final seconds =
        _running || _remainingSeconds > 0 ? _remainingSeconds % 60 : 0;
    final progress = (_running || _remainingSeconds > 0)
        ? _remainingSeconds / (_selectedMinutes * 60)
        : 1.0;

    return Padding(
      padding: const EdgeInsets.only(top: _teachContentTopInset),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Circular timer
            SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      color: _remainingSeconds < 30 && _running
                          ? OSColors.urgent
                          : OSColors.teachAccent,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w200,
                          color: Colors.white,
                          letterSpacing: -3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Control buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TimerButton(
                  icon: Icons.replay_rounded,
                  onTap: _reset,
                  subtle: true,
                ),
                const SizedBox(width: 12),
                _TimerButton(
                  icon:
                      _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  onTap: _running ? _pause : _start,
                  filled: true,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Preset selector
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: _presets.map((p) {
                  final selected = p == _selectedMinutes && !_running;
                  return GestureDetector(
                    onTap: _running
                        ? null
                        : () => setState(() => _selectedMinutes = p),
                    child: AnimatedContainer(
                      duration: OSMotion.fast,
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? OSColors.teachAccent.withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: OSRadius.pillBr,
                        border: Border.all(
                          color: selected
                              ? OSColors.teachAccent
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${p}m',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? OSColors.teachAccent
                              : Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimerButton extends StatelessWidget {
  const _TimerButton({
    required this.icon,
    required this.onTap,
    this.filled = false,
    this.subtle = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: filled ? 64 : 48,
        height: filled ? 64 : 48,
        decoration: BoxDecoration(
          color: filled
              ? OSColors.teachAccent
              : Colors.white.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: filled ? 30 : 22,
          color:
              filled ? OSColors.teachBg : Colors.white.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GROUP PICKER TOOL
// ─────────────────────────────────────────────────────────────────────────────

class _GroupPickerTool extends StatefulWidget {
  const _GroupPickerTool({
    super.key,
    required this.studentNames,
  });

  final List<String> studentNames;

  @override
  State<_GroupPickerTool> createState() => _GroupPickerToolState();
}

class _GroupPickerToolState extends State<_GroupPickerTool> {
  int _groupSize = 3;
  List<List<String>> _groups = [];

  void _generateGroups() {
    if (widget.studentNames.isEmpty) return;
    final shuffled = List<String>.from(widget.studentNames)
      ..shuffle(math.Random());
    final groups = <List<String>>[];
    for (int i = 0; i < shuffled.length; i += _groupSize) {
      groups.add(shuffled.sublist(
        i,
        (i + _groupSize).clamp(0, shuffled.length),
      ));
    }
    setState(() => _groups = groups);
  }

  @override
  Widget build(BuildContext context) {
    final canGenerate = widget.studentNames.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(
          top: _teachContentTopInset, left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Group Size',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9BA8BB),
                ),
              ),
              const SizedBox(width: 12),
              Row(
                children: [2, 3, 4, 5].map((n) {
                  final sel = n == _groupSize;
                  return GestureDetector(
                    onTap: () => setState(() => _groupSize = n),
                    child: AnimatedContainer(
                      duration: OSMotion.fast,
                      margin: const EdgeInsets.only(right: 6),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: sel
                            ? OSColors.teachAccent.withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: OSRadius.mdBr,
                        border: Border.all(
                          color:
                              sel ? OSColors.teachAccent : Colors.transparent,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$n',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: sel
                                ? OSColors.teachAccent
                                : Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const Spacer(),
              GestureDetector(
                onTap: canGenerate ? _generateGroups : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: canGenerate
                        ? OSColors.teachAccent
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: OSRadius.pillBr,
                  ),
                  child: Text(
                    'Randomise',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: canGenerate
                          ? OSColors.teachBg
                          : Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _groups.isEmpty
                ? Center(
                    child: Text(
                      widget.studentNames.isEmpty
                          ? 'No student names are available for this class yet'
                          : 'Tap Randomise to generate groups',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  )
                : Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _groups.asMap().entries.map((entry) {
                      return Container(
                        width: 140,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: OSRadius.lgBr,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Group ${entry.key + 1}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: OSColors.teachAccent,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            for (final name in entry.value)
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POLL TOOL (placeholder)
// ─────────────────────────────────────────────────────────────────────────────

class _PollTool extends StatelessWidget {
  const _PollTool({
    required this.questionController,
    required this.mode,
    required this.counts,
    required this.onModeChanged,
    required this.onVote,
    required this.onReset,
  });

  final TextEditingController questionController;
  final _PollMode mode;
  final Map<String, int> counts;
  final ValueChanged<_PollMode> onModeChanged;
  final ValueChanged<String> onVote;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final options = mode == _PollMode.yesNo
        ? const ['Yes', 'No']
        : const ['A', 'B', 'C', 'D'];
    final total = counts.values.fold<int>(0, (sum, value) => sum + value);

    double pct(String option) {
      if (total == 0) return 0;
      return (counts[option] ?? 0) / total;
    }

    Widget resultBar(String option) {
      final votes = counts[option] ?? 0;
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth * pct(option))
              .clamp(0.0, constraints.maxWidth)
              .toDouble();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    option,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$votes',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Stack(
                children: [
                  Container(
                    height: 12,
                    width: constraints.maxWidth,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: OSRadius.pillBr,
                    ),
                  ),
                  AnimatedContainer(
                    duration: OSMotion.fast,
                    height: 12,
                    width: width,
                    decoration: BoxDecoration(
                      color: OSColors.teachAccent,
                      borderRadius: OSRadius.pillBr,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, _teachContentTopInset, 16, 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: OSRadius.xlBr,
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.how_to_vote_outlined,
                      color: OSColors.teachAccent,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Quick Poll',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      '$total votes',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.68),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: questionController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Prompt',
                    labelStyle:
                        TextStyle(color: Colors.white.withValues(alpha: 0.72)),
                    hintText: 'Type a prompt for the room',
                    hintStyle:
                        TextStyle(color: Colors.white.withValues(alpha: 0.42)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                      borderSide: BorderSide(color: OSColors.teachAccent),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ChoiceChip(
                      label: const Text('A/B/C/D'),
                      selected: mode == _PollMode.abcd,
                      onSelected: (_) => onModeChanged(_PollMode.abcd),
                      selectedColor:
                          OSColors.teachAccent.withValues(alpha: 0.22),
                      labelStyle: TextStyle(
                        color: mode == _PollMode.abcd
                            ? OSColors.teachAccent
                            : Colors.white.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('Yes / No'),
                      selected: mode == _PollMode.yesNo,
                      onSelected: (_) => onModeChanged(_PollMode.yesNo),
                      selectedColor:
                          OSColors.teachAccent.withValues(alpha: 0.22),
                      labelStyle: TextStyle(
                        color: mode == _PollMode.yesNo
                            ? OSColors.teachAccent
                            : Colors.white.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: options
                      .map(
                        (option) => FilledButton(
                          onPressed: () => onVote(option),
                          style: FilledButton.styleFrom(
                            backgroundColor: OSColors.teachAccent,
                            foregroundColor: OSColors.teachBg,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                          ),
                          child: Text(
                            option,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                for (final option in options) ...[
                  resultBar(option),
                  if (option != options.last) const SizedBox(height: 10),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: onReset,
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('Reset poll'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
