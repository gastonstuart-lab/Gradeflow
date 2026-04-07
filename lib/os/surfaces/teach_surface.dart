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
///   - Poll/quiz placeholder
///   - Teaching mode toolbar
library teach_surface;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/os/os_controller.dart';
import 'package:gradeflow/os/os_palette.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/screens/teacher_whiteboard_screen.dart';

class TeachSurface extends StatefulWidget {
  const TeachSurface({super.key});

  @override
  State<TeachSurface> createState() => _TeachSurfaceState();
}

class _TeachSurfaceState extends State<TeachSurface> {
  _TeachTool _activeTool = _TeachTool.whiteboard;

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
  Widget build(BuildContext context) {
    const teachBg = OSColors.teachBg;

    return Scaffold(
      backgroundColor: teachBg,
      body: Stack(
        children: [
          // ── Main tool area ────────────────────────────────────────────
          Positioned.fill(
            bottom: 0,
            child: _buildToolArea(context),
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
                  context.read<GradeFlowOSController>()
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

  Widget _buildToolArea(BuildContext context) {
    switch (_activeTool) {
      case _TeachTool.whiteboard:
        return const _WhiteboardContainer();
      case _TeachTool.timer:
        return const _TimerTool();
      case _TeachTool.groups:
        return const _GroupPickerTool();
      case _TeachTool.poll:
        return const _PollTool();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOOL ENUM
// ─────────────────────────────────────────────────────────────────────────────

enum _TeachTool { whiteboard, timer, groups, poll }

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

class _WhiteboardContainer extends StatelessWidget {
  const _WhiteboardContainer();

  @override
  Widget build(BuildContext context) {
    // Embed the existing TeacherWhiteboardScreen inside Teach mode.
    // The whiteboard already handles its own touch drawing.
    return Padding(
      padding: const EdgeInsets.only(top: 68),
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
    final seconds = _running || _remainingSeconds > 0
        ? _remainingSeconds % 60
        : 0;
    final progress = (_running || _remainingSeconds > 0)
        ? _remainingSeconds / (_selectedMinutes * 60)
        : 1.0;

    return Padding(
      padding: const EdgeInsets.only(top: 72),
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
                  icon: _running
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
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
          color: filled
              ? OSColors.teachBg
              : Colors.white.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GROUP PICKER TOOL
// ─────────────────────────────────────────────────────────────────────────────

class _GroupPickerTool extends StatefulWidget {
  const _GroupPickerTool();

  @override
  State<_GroupPickerTool> createState() => _GroupPickerToolState();
}

class _GroupPickerToolState extends State<_GroupPickerTool> {
  int _groupSize = 3;
  List<List<String>> _groups = [];

  static const _sampleNames = [
    'Alex', 'Jordan', 'Sam', 'Taylor', 'Morgan', 'Casey',
    'Riley', 'Avery', 'Quinn', 'Blake', 'Hayden', 'Jamie',
  ];

  void _generateGroups() {
    final shuffled = List<String>.from(_sampleNames)..shuffle(math.Random());
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
    return Padding(
      padding: const EdgeInsets.only(top: 72, left: 16, right: 16),
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
                          color: sel
                              ? OSColors.teachAccent
                              : Colors.transparent,
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
                onTap: _generateGroups,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: OSColors.teachAccent,
                    borderRadius: OSRadius.pillBr,
                  ),
                  child: const Text(
                    'Randomise',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: OSColors.teachBg,
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
                      'Tap Randomise to generate groups',
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
  const _PollTool();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 72),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: OSColors.teachAccent.withValues(alpha: 0.12),
                borderRadius: OSRadius.lgBr,
              ),
              child: const Icon(
                Icons.how_to_vote_outlined,
                color: OSColors.teachAccent,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Polls & Quizzes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming in a future update.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
