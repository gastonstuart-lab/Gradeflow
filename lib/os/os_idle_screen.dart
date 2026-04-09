/// GradeFlow OS — Idle / Lock Screen
///
/// [OSIdleScreen] activates after the configured idle timeout and shows:
///   - Current date and time (large, centered)
///   - Next scheduled class (from workspace snapshot)
///   - No private messages, admin alerts, or personal information
///
/// The teacher taps anywhere to dismiss and return to the active surface.
/// This makes the OS safe to leave projected on a screen without exposing
/// personal data.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/os/os_palette.dart';
import 'package:gradeflow/services/global_system_shell_service.dart';

class OSIdleScreen extends StatefulWidget {
  const OSIdleScreen({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  State<OSIdleScreen> createState() => _OSIdleScreenState();
}

class _OSIdleScreenState extends State<OSIdleScreen>
    with SingleTickerProviderStateMixin {
  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shellCtrl = context.watch<GlobalSystemShellController>();
    final snapshot = shellCtrl.workspaceSnapshot;

    // Find next class from snapshot
    final nextClass = snapshot?.activeClasses.isNotEmpty == true
        ? snapshot!.activeClasses.first
        : null;

    return GestureDetector(
      onTap: widget.onDismiss,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF060A12), Color(0xFF0A1020), Color(0xFF060E1A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Ambient glow
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, child) => Opacity(
                  opacity: _pulse.value * 0.18,
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: OSColors.blue,
                    ),
                  ),
                ),
              ),

              // Time
              _IdleClock(now: _now),

              const SizedBox(height: 8),

              // Date
              _IdleDate(now: _now),

              const SizedBox(height: 40),

              // Next class (classroom-safe — just class name, not private data)
              if (nextClass != null)
                _IdleNextClass(className: nextClass.className),

              const Spacer(flex: 3),

              // Dismiss hint
              _IdleDismissHint(),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// IDLE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _IdleClock extends StatelessWidget {
  const _IdleClock({required this.now});
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final hours = now.hour.toString().padLeft(2, '0');
    final minutes = now.minute.toString().padLeft(2, '0');
    return Text(
      '$hours:$minutes',
      style: const TextStyle(
        fontSize: 80,
        fontWeight: FontWeight.w200,
        color: Colors.white,
        letterSpacing: -4,
        height: 1,
      ),
    );
  }
}

class _IdleDate extends StatelessWidget {
  const _IdleDate({required this.now});
  final DateTime now;

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];
  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];

  @override
  Widget build(BuildContext context) {
    final weekday = _weekdays[now.weekday - 1];
    final month = _months[now.month - 1];
    return Text(
      '$weekday, $month ${now.day}',
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w300,
        color: Color(0xAAFFFFFF),
        letterSpacing: 0.4,
      ),
    );
  }
}

class _IdleNextClass extends StatelessWidget {
  const _IdleNextClass({required this.className});
  final String className;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: OSRadius.pillBr,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.class_outlined,
            size: 15,
            color: Colors.white.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 8),
          Text(
            className,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdleDismissHint extends StatelessWidget {
  const _IdleDismissHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Text(
        'Tap anywhere to unlock',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: Colors.white.withValues(alpha: 0.30),
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
