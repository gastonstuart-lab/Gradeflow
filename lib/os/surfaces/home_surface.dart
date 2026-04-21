// GradeFlow OS — Home Surface
//
// The teacher's primary landing surface should read like an actual OS home:
// a desktop stage, pinned apps, glanceable live signals, and secondary
// portals tucked off to the side instead of one long dashboard feed.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/components/workspace_shell.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/os/os_app_model.dart';
import 'package:gradeflow/os/os_controller.dart';
import 'package:gradeflow/os/os_palette.dart';
import 'package:gradeflow/os/os_touch_feedback.dart';
import 'package:gradeflow/providers/app_providers.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/communication_service.dart';
import 'package:gradeflow/services/dashboard_weather_service.dart';
import 'package:gradeflow/services/global_system_shell_service.dart';
import 'package:gradeflow/services/teacher_workspace_snapshot_service.dart';

class HomeSurface extends StatelessWidget {
  const HomeSurface({super.key});

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<GlobalSystemShellController>();
    final snapshot = shell.workspaceSnapshot;
    final auth = context.watch<AuthService>();
    final user = auth.currentUser ?? snapshot?.user;
    final serviceClasses = context.watch<ClassService>().activeClasses;
    final classes = serviceClasses.isNotEmpty
        ? serviceClasses
        : (snapshot?.activeClasses ?? const <Class>[]);
    final reminders = snapshot?.pendingReminders ??
        const <TeacherWorkspaceReminderSnapshot>[];
    final totalStudents = snapshot?.totalStudents ?? 0;
    final unread = context.watch<CommunicationService>().totalUnreadCount;
    final now = DateTime.now();
    final primaryClass = _selectPrimaryClass(snapshot?.activeClasses, classes);
    final primaryReminder = reminders.isNotEmpty ? reminders.first : null;
    final teacherName = _firstName(user?.fullName ?? '');
    final schoolName = _schoolName(user?.schoolName);
    final controller = context.read<GradeFlowOSController>();
    final themeMode = context.watch<ThemeModeNotifier>().themeMode;
    final toggleTheme = context.read<ThemeModeNotifier>().toggleTheme;

    return Scaffold(
      backgroundColor: OSColors.bg(context.isDark),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop =
                constraints.maxWidth >= 1220 && constraints.maxHeight >= 760;
            final horizontalPadding = constraints.maxWidth < 760 ? 14.0 : 20.0;
            final contentPadding = EdgeInsets.fromLTRB(
              horizontalPadding,
              10,
              horizontalPadding,
              24,
            );

            return Stack(
              children: [
                const Positioned.fill(child: _HomeBackdrop()),
                Positioned.fill(
                  child: isDesktop
                      ? Padding(
                          padding: contentPadding,
                          child: _HomeDesktopLayout(
                            teacherName: teacherName,
                            schoolName: schoolName,
                            primaryClass: primaryClass,
                            classes: classes,
                            reminders: reminders,
                            primaryReminder: primaryReminder,
                            totalStudents: totalStudents,
                            unread: unread,
                            now: now,
                            themeMode: themeMode,
                            onShadeTap: controller.openShade,
                            onAssistantTap: controller.openAssistant,
                            onLauncherTap: controller.openLauncher,
                            onThemeTap: toggleTheme,
                          ),
                        )
                      : SingleChildScrollView(
                          padding: contentPadding,
                          child: _HomeStackedLayout(
                            width: constraints.maxWidth,
                            teacherName: teacherName,
                            schoolName: schoolName,
                            primaryClass: primaryClass,
                            classes: classes,
                            reminders: reminders,
                            primaryReminder: primaryReminder,
                            totalStudents: totalStudents,
                            unread: unread,
                            now: now,
                            themeMode: themeMode,
                            onShadeTap: controller.openShade,
                            onAssistantTap: controller.openAssistant,
                            onLauncherTap: controller.openLauncher,
                            onThemeTap: toggleTheme,
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Class? _selectPrimaryClass(
    List<Class>? snapshotClasses,
    List<Class> serviceClasses,
  ) {
    final candidates = snapshotClasses != null && snapshotClasses.isNotEmpty
        ? snapshotClasses
        : serviceClasses;
    return candidates.isNotEmpty ? candidates.first : null;
  }
}

class _HomeDesktopLayout extends StatelessWidget {
  const _HomeDesktopLayout({
    required this.teacherName,
    required this.schoolName,
    required this.primaryClass,
    required this.classes,
    required this.reminders,
    required this.primaryReminder,
    required this.totalStudents,
    required this.unread,
    required this.now,
    required this.themeMode,
    required this.onShadeTap,
    required this.onAssistantTap,
    required this.onLauncherTap,
    required this.onThemeTap,
  });

  final String teacherName;
  final String schoolName;
  final Class? primaryClass;
  final List<Class> classes;
  final List<TeacherWorkspaceReminderSnapshot> reminders;
  final TeacherWorkspaceReminderSnapshot? primaryReminder;
  final int totalStudents;
  final int unread;
  final DateTime now;
  final ThemeMode themeMode;
  final VoidCallback onShadeTap;
  final VoidCallback onAssistantTap;
  final VoidCallback onLauncherTap;
  final VoidCallback onThemeTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HomeSystemStrip(
          teacherName: teacherName,
          schoolName: schoolName,
          unread: unread,
          now: now,
          themeMode: themeMode,
          onShadeTap: onShadeTap,
          onAssistantTap: onAssistantTap,
          onThemeTap: onThemeTap,
        ),
        const SizedBox(height: 18),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 244,
                child: Column(
                  children: [
                    Expanded(
                      flex: 4,
                      child: _HomeShortcutShelf(
                        unread: unread,
                        themeMode: themeMode,
                        onAssistantTap: onAssistantTap,
                        onLauncherTap: onLauncherTap,
                        onThemeTap: onThemeTap,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      flex: 5,
                      child: _HomeClassroomsPanel(
                        classes: classes,
                        scrollable: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: _HomeStagePanel(
                  teacherName: teacherName,
                  schoolName: schoolName,
                  primaryClass: primaryClass,
                  primaryReminder: primaryReminder,
                  classCount: classes.length,
                  totalStudents: totalStudents,
                  unread: unread,
                  reminderCount: reminders.length,
                  now: now,
                  compact: false,
                  onAssistantTap: onAssistantTap,
                  onLauncherTap: onLauncherTap,
                ),
              ),
              const SizedBox(width: 18),
              SizedBox(
                width: 320,
                child: Column(
                  children: [
                    const _HomeWeatherPanel(),
                    const SizedBox(height: 16),
                    _HomeAudioPanel(
                        onTap: () => context.go(AppRoutes.dashboard)),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _HomeAgendaPanel(
                        reminders: reminders,
                        scrollable: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeStackedLayout extends StatelessWidget {
  const _HomeStackedLayout({
    required this.width,
    required this.teacherName,
    required this.schoolName,
    required this.primaryClass,
    required this.classes,
    required this.reminders,
    required this.primaryReminder,
    required this.totalStudents,
    required this.unread,
    required this.now,
    required this.themeMode,
    required this.onShadeTap,
    required this.onAssistantTap,
    required this.onLauncherTap,
    required this.onThemeTap,
  });

  final double width;
  final String teacherName;
  final String schoolName;
  final Class? primaryClass;
  final List<Class> classes;
  final List<TeacherWorkspaceReminderSnapshot> reminders;
  final TeacherWorkspaceReminderSnapshot? primaryReminder;
  final int totalStudents;
  final int unread;
  final DateTime now;
  final ThemeMode themeMode;
  final VoidCallback onShadeTap;
  final VoidCallback onAssistantTap;
  final VoidCallback onLauncherTap;
  final VoidCallback onThemeTap;

  @override
  Widget build(BuildContext context) {
    final useTwoColumns = width >= 880;
    final stageHeight = width < 700 ? 456.0 : 500.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HomeSystemStrip(
          teacherName: teacherName,
          schoolName: schoolName,
          unread: unread,
          now: now,
          themeMode: themeMode,
          onShadeTap: onShadeTap,
          onAssistantTap: onAssistantTap,
          onThemeTap: onThemeTap,
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: stageHeight,
          child: _HomeStagePanel(
            teacherName: teacherName,
            schoolName: schoolName,
            primaryClass: primaryClass,
            primaryReminder: primaryReminder,
            classCount: classes.length,
            totalStudents: totalStudents,
            unread: unread,
            reminderCount: reminders.length,
            now: now,
            compact: true,
            onAssistantTap: onAssistantTap,
            onLauncherTap: onLauncherTap,
          ),
        ),
        const SizedBox(height: 16),
        _HomeShortcutShelf(
          unread: unread,
          themeMode: themeMode,
          onAssistantTap: onAssistantTap,
          onLauncherTap: onLauncherTap,
          onThemeTap: onThemeTap,
        ),
        const SizedBox(height: 16),
        if (useTwoColumns)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _HomeSignalsPanel(
                  classCount: classes.length,
                  totalStudents: totalStudents,
                  unread: unread,
                  reminderCount: reminders.length,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _HomePortalsPanel(
                  reminderCount: reminders.length,
                ),
              ),
            ],
          )
        else ...[
          _HomeSignalsPanel(
            classCount: classes.length,
            totalStudents: totalStudents,
            unread: unread,
            reminderCount: reminders.length,
          ),
          const SizedBox(height: 16),
          _HomePortalsPanel(
            reminderCount: reminders.length,
          ),
        ],
        const SizedBox(height: 16),
        if (useTwoColumns)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _HomeClassroomsPanel(
                  classes: classes,
                  scrollable: false,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _HomeAgendaPanel(
                  reminders: reminders,
                  scrollable: false,
                ),
              ),
            ],
          )
        else ...[
          _HomeClassroomsPanel(
            classes: classes,
            scrollable: false,
          ),
          const SizedBox(height: 16),
          _HomeAgendaPanel(
            reminders: reminders,
            scrollable: false,
          ),
        ],
      ],
    );
  }
}

class _HomeBackdrop extends StatelessWidget {
  const _HomeBackdrop();

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: dark
                  ? const [
                      Color(0xFF07111D),
                      Color(0xFF0A1624),
                      Color(0xFF0E1420),
                    ]
                  : const [
                      Color(0xFFF3F7FF),
                      Color(0xFFE8F0FB),
                      Color(0xFFF6F8FC),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned(
          top: -140,
          left: -80,
          child: _BackdropOrb(
            size: 320,
            color: OSColors.blue,
            opacity: dark ? 0.22 : 0.14,
          ),
        ),
        Positioned(
          top: 110,
          right: 140,
          child: _BackdropOrb(
            size: 220,
            color: OSColors.indigo,
            opacity: dark ? 0.16 : 0.10,
          ),
        ),
        Positioned(
          bottom: -180,
          right: -40,
          child: _BackdropOrb(
            size: 420,
            color: OSColors.green,
            opacity: dark ? 0.14 : 0.10,
          ),
        ),
        Positioned(
          left: 32,
          right: 32,
          bottom: -132,
          child: IgnorePointer(
            child: Container(
              height: 260,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(180),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: dark
                      ? [
                          Colors.transparent,
                          const Color(0xFF07101A).withValues(alpha: 0.78),
                        ]
                      : [
                          Colors.transparent,
                          const Color(0xFFF2F7FF).withValues(alpha: 0.90),
                        ],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _BackdropGridPainter(dark: dark),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.18, -0.68),
                  radius: 1.18,
                  colors: [
                    Colors.white.withValues(alpha: dark ? 0.08 : 0.18),
                    Colors.transparent,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BackdropOrb extends StatelessWidget {
  const _BackdropOrb({
    required this.size,
    required this.color,
    required this.opacity,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 48, sigmaY: 48),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: opacity),
          ),
        ),
      ),
    );
  }
}

class _BackdropGridPainter extends CustomPainter {
  const _BackdropGridPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = (dark ? Colors.white : Colors.black).withValues(
        alpha: dark ? 0.035 : 0.04,
      )
      ..strokeWidth = 1;
    const step = 56.0;

    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..color = OSColors.blue.withValues(alpha: dark ? 0.11 : 0.08);

    final rect = Rect.fromCircle(
      center: Offset(size.width * 0.82, size.height * 0.18),
      radius: size.shortestSide * 0.28,
    );
    canvas.drawArc(rect, 0.4, 2.8, false, arcPaint);

    final lowerRect = Rect.fromCircle(
      center: Offset(size.width * 0.15, size.height * 0.84),
      radius: size.shortestSide * 0.22,
    );
    canvas.drawArc(lowerRect, 3.3, 2.7, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _BackdropGridPainter oldDelegate) {
    return dark != oldDelegate.dark;
  }
}

class _HomeSystemStrip extends StatelessWidget {
  const _HomeSystemStrip({
    required this.teacherName,
    required this.schoolName,
    required this.unread,
    required this.now,
    required this.themeMode,
    required this.onShadeTap,
    required this.onAssistantTap,
    required this.onThemeTap,
  });

  final String teacherName;
  final String schoolName;
  final int unread;
  final DateTime now;
  final ThemeMode themeMode;
  final VoidCallback onShadeTap;
  final VoidCallback onAssistantTap;
  final VoidCallback onThemeTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final compact = MediaQuery.sizeOf(context).width < 720;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _GlassPanel(
            tone: _HomePanelTone.whisper,
            radius: 24,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5C8AFF), Color(0xFF5EC7E6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: OSRadius.mdBr,
                  ),
                  child: const Icon(
                    Icons.cast_for_education_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GradeFlow OS',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: OSColors.text(dark),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        teacherName.isEmpty
                            ? schoolName
                            : '$teacherName · $schoolName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: OSColors.textSecondary(dark),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        _GlassPanel(
          tone: _HomePanelTone.whisper,
          radius: 24,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 16,
            vertical: 12,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatClock(now),
                    style: TextStyle(
                      fontSize: compact ? 18 : 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      color: OSColors.text(dark),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDateLine(now),
                    style: TextStyle(
                      fontSize: 11,
                      color: OSColors.textSecondary(dark),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              _TopStripButton(
                icon: Icons.notifications_outlined,
                semanticLabel: 'Attention center',
                badge: unread > 0 ? '$unread' : null,
                onTap: onShadeTap,
              ),
              const SizedBox(width: 8),
              _TopStripButton(
                icon: themeMode == ThemeMode.light
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                semanticLabel: 'Toggle theme',
                onTap: onThemeTap,
              ),
              const SizedBox(width: 8),
              _TopStripButton(
                icon: Icons.auto_awesome_rounded,
                semanticLabel: 'Assistant',
                onTap: onAssistantTap,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopStripButton extends StatelessWidget {
  const _TopStripButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: OSTouchFeedback(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        minSize: const Size(42, 42),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: dark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.white.withValues(alpha: 0.74),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.8),
                ),
              ),
              child: Icon(
                icon,
                size: 18,
                color: OSColors.textSecondary(dark),
              ),
            ),
            if (badge != null)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: OSColors.urgent,
                    borderRadius: OSRadius.pillBr,
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HomeStagePanel extends StatelessWidget {
  const _HomeStagePanel({
    required this.teacherName,
    required this.schoolName,
    required this.primaryClass,
    required this.primaryReminder,
    required this.classCount,
    required this.totalStudents,
    required this.unread,
    required this.reminderCount,
    required this.now,
    required this.compact,
    required this.onAssistantTap,
    required this.onLauncherTap,
  });

  final String teacherName;
  final String schoolName;
  final Class? primaryClass;
  final TeacherWorkspaceReminderSnapshot? primaryReminder;
  final int classCount;
  final int totalStudents;
  final int unread;
  final int reminderCount;
  final DateTime now;
  final bool compact;
  final VoidCallback onAssistantTap;
  final VoidCallback onLauncherTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final stageGradient = LinearGradient(
      colors: dark
          ? const [
              Color(0x661B3150),
              Color(0x55111C2E),
              Color(0x6618223B),
            ]
          : const [
              Color(0xE8FFFFFF),
              Color(0xE1F4F8FF),
              Color(0xD8EEF4FF),
            ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return _GlassPanel(
      tone: _HomePanelTone.stage,
      radius: compact ? WorkspaceRadius.shellCompact : WorkspaceRadius.shell,
      padding: EdgeInsets.all(compact ? 22 : 30),
      gradient: stageGradient,
      child: Stack(
        children: [
          Positioned(
            top: -54,
            right: -28,
            child: _StageOrb(
              size: compact ? 160 : 220,
              color: OSColors.indigo,
            ),
          ),
          Positioned(
            bottom: -80,
            left: -36,
            child: _StageOrb(
              size: compact ? 140 : 180,
              color: OSColors.cyan,
            ),
          ),
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _PanelEyebrow(label: 'Home Stage'),
                    const Spacer(),
                    _StageStatusChip(
                      text: classCount == 0
                          ? 'No active classes'
                          : '$classCount active classes',
                    ),
                  ],
                ),
                SizedBox(height: compact ? 18 : 24),
                Text(
                  _formatClock(now),
                  style: TextStyle(
                    fontSize: compact ? 58 : 84,
                    height: 0.92,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -2.4,
                    color: OSColors.text(dark),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatLongDate(now),
                  style: TextStyle(
                    fontSize: compact ? 15 : 16,
                    fontWeight: FontWeight.w600,
                    color: OSColors.textSecondary(dark),
                  ),
                ),
                SizedBox(height: compact ? 20 : 24),
                Text(
                  _stageHeadline(teacherName, primaryClass),
                  style: TextStyle(
                    fontSize: compact ? 26 : 34,
                    height: 1.04,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.0,
                    color: OSColors.text(dark),
                  ),
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Text(
                    _stageSupportLine(
                      primaryClass: primaryClass,
                      primaryReminder: primaryReminder,
                      classCount: classCount,
                      unread: unread,
                      schoolName: schoolName,
                      now: now,
                    ),
                    style: TextStyle(
                      fontSize: compact ? 13 : 14,
                      height: 1.5,
                      color: OSColors.textSecondary(dark),
                    ),
                  ),
                ),
                SizedBox(height: compact ? 18 : 22),
                if (compact)
                  Column(
                    children: [
                      _StageSpotlightTile(
                        title: 'Focus room',
                        icon: Icons.class_rounded,
                        accent: OSColors.green,
                        headline: primaryClass?.className ?? 'No room pinned',
                        detail: primaryClass == null
                            ? 'Open Classes to pin your first active workspace.'
                            : primaryClass!.subject,
                        onTap: primaryClass == null
                            ? null
                            : () => context.go(
                                  '${AppRoutes.osClass}/${primaryClass!.classId}',
                                ),
                      ),
                      const SizedBox(height: 12),
                      _StageSpotlightTile(
                        title: 'Agenda',
                        icon: Icons.event_note_outlined,
                        accent: OSColors.amber,
                        headline: primaryReminder == null
                            ? 'No pending reminders'
                            : _relativeReminderLabel(primaryReminder!, now),
                        detail: primaryReminder == null
                            ? 'Your day is currently clear.'
                            : _trimLine(primaryReminder!.text, 88),
                        onTap: () => context.go(AppRoutes.dashboard),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _StageSpotlightTile(
                          title: 'Focus room',
                          icon: Icons.class_rounded,
                          accent: OSColors.green,
                          headline: primaryClass?.className ?? 'No room pinned',
                          detail: primaryClass == null
                              ? 'Open Classes to pin your first active workspace.'
                              : primaryClass!.subject,
                          onTap: primaryClass == null
                              ? null
                              : () => context.go(
                                    '${AppRoutes.osClass}/${primaryClass!.classId}',
                                  ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StageSpotlightTile(
                          title: 'Agenda',
                          icon: Icons.event_note_outlined,
                          accent: OSColors.amber,
                          headline: primaryReminder == null
                              ? 'No pending reminders'
                              : _relativeReminderLabel(primaryReminder!, now),
                          detail: primaryReminder == null
                              ? 'Your day is currently clear.'
                              : _trimLine(primaryReminder!.text, 88),
                          onTap: () => context.go(AppRoutes.dashboard),
                        ),
                      ),
                    ],
                  ),
                SizedBox(height: compact ? 18 : 22),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _StageMetricPill(
                      icon: Icons.people_alt_outlined,
                      label: 'Students',
                      value: totalStudents == 0 ? 'Syncing' : '$totalStudents',
                    ),
                    _StageMetricPill(
                      icon: Icons.notifications_active_outlined,
                      label: 'Messages',
                      value: unread == 0 ? 'Quiet' : '$unread unread',
                    ),
                    _StageMetricPill(
                      icon: Icons.event_available_outlined,
                      label: 'Reminders',
                      value:
                          reminderCount == 0 ? 'Clear' : '$reminderCount due',
                    ),
                  ],
                ),
                SizedBox(height: compact ? 14 : 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _StageActionButton(
                      label: 'Teach Mode',
                      icon: Icons.cast_for_education_rounded,
                      accent: OSColors.blue,
                      filled: true,
                      onTap: () => context.go(AppRoutes.osTeach),
                    ),
                    _StageActionButton(
                      label: 'Classes',
                      icon: Icons.class_rounded,
                      accent: OSColors.green,
                      onTap: () => context.go(AppRoutes.classes),
                    ),
                    _StageActionButton(
                      label: 'Messages',
                      icon: Icons.forum_rounded,
                      accent: OSColors.cyan,
                      onTap: () => context.go(AppRoutes.communication),
                    ),
                    _StageActionButton(
                      label: 'Assistant',
                      icon: Icons.auto_awesome_rounded,
                      accent: OSColors.indigo,
                      onTap: onAssistantTap,
                    ),
                    _StageActionButton(
                      label: 'Launcher',
                      icon: Icons.grid_view_rounded,
                      accent: OSColors.amber,
                      onTap: onLauncherTap,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StageOrb extends StatelessWidget {
  const _StageOrb({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 36, sigmaY: 36),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.16),
          ),
        ),
      ),
    );
  }
}

class _StageStatusChip extends StatelessWidget {
  const _StageStatusChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(WorkspaceRadius.pill),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.72),
        ),
      ),
      child: Text(
        text,
        style: WorkspaceTypography.utility(
          context,
          color: OSColors.textSecondary(dark),
        )?.copyWith(fontSize: 11),
      ),
    );
  }
}

class _StageSpotlightTile extends StatelessWidget {
  const _StageSpotlightTile({
    required this.title,
    required this.icon,
    required this.accent,
    required this.headline,
    required this.detail,
    this.onTap,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final String headline;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return OSTouchFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      minSize: const Size(120, 96),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: dark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.78),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: OSRadius.mdBr,
              ),
              child: Icon(icon, size: 20, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: OSColors.textMuted(dark),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: OSColors.text(dark),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: OSColors.textSecondary(dark),
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: OSColors.textMuted(dark),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StageMetricPill extends StatelessWidget {
  const _StageMetricPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.72),
        borderRadius: OSRadius.pillBr,
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.76),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: OSColors.blueSoft),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: OSColors.textMuted(dark),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: OSColors.text(dark),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StageActionButton extends StatelessWidget {
  const _StageActionButton({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return OSTouchFeedback(
      onTap: onTap,
      borderRadius: OSRadius.pillBr,
      minSize: const Size(132, 46),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: filled
              ? LinearGradient(
                  colors: [accent, accent.withValues(alpha: 0.72)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: filled
              ? null
              : (dark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.72)),
          borderRadius: OSRadius.pillBr,
          border: Border.all(
            color: filled
                ? Colors.white.withValues(alpha: 0.08)
                : (dark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.76)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: filled ? Colors.white : accent,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: filled ? Colors.white : OSColors.text(dark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeShortcutShelf extends StatelessWidget {
  const _HomeShortcutShelf({
    required this.unread,
    required this.themeMode,
    required this.onAssistantTap,
    required this.onLauncherTap,
    required this.onThemeTap,
  });

  final int unread;
  final ThemeMode themeMode;
  final VoidCallback onAssistantTap;
  final VoidCallback onLauncherTap;
  final VoidCallback onThemeTap;

  @override
  Widget build(BuildContext context) {
    final shortcuts = <_HomeShortcutData>[
      _shortcutFromApp(OSAppId.teach,
          onTap: () => context.go(AppRoutes.osTeach)),
      _shortcutFromApp(OSAppId.classes,
          onTap: () => context.go(AppRoutes.classes)),
      _shortcutFromApp(
        OSAppId.whiteboard,
        onTap: () => context.push(AppRoutes.whiteboard),
      ),
      _shortcutFromApp(
        OSAppId.messages,
        onTap: () => context.go(AppRoutes.communication),
        badge: unread > 0 ? '$unread' : null,
      ),
      _HomeShortcutData(
        label: 'Assistant',
        icon: Icons.auto_awesome_rounded,
        accent: OSColors.indigo,
        onTap: onAssistantTap,
      ),
      _HomeShortcutData(
        label: 'Launcher',
        icon: Icons.grid_view_rounded,
        accent: OSColors.amber,
        onTap: onLauncherTap,
      ),
      _HomeShortcutData(
        label: themeMode == ThemeMode.light ? 'Dark mode' : 'Light mode',
        icon: themeMode == ThemeMode.light
            ? Icons.dark_mode_rounded
            : Icons.light_mode_rounded,
        accent: OSColors.blue,
        onTap: onThemeTap,
      ),
    ];

    return _GlassPanel(
      tone: _HomePanelTone.whisper,
      radius: 28,
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compactGrid = constraints.maxHeight < 360;
          final tileWidth =
              ((constraints.maxWidth - (compactGrid ? 10 : 12)) / 2)
                  .clamp(74.0, 88.0);

          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _PanelEyebrow(label: 'Pinned Apps'),
                const SizedBox(height: 8),
                Text(
                  'Quick launch',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: OSColors.text(context.isDark),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Teach, message, and open the tools you use most.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: OSColors.textSecondary(context.isDark),
                  ),
                ),
                SizedBox(height: compactGrid ? 12 : 14),
                Align(
                  alignment: Alignment.topLeft,
                  child: Wrap(
                    spacing: compactGrid ? 10 : 12,
                    runSpacing: compactGrid ? 12 : 14,
                    children: [
                      for (final shortcut in shortcuts)
                        _HomeShortcutIcon(
                          data: shortcut,
                          width: tileWidth,
                          iconBoxSize: compactGrid ? 56 : 60,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  _HomeShortcutData _shortcutFromApp(
    String appId, {
    required VoidCallback onTap,
    String? badge,
  }) {
    final app = OSAppRegistry.findById(appId)!;
    return _HomeShortcutData(
      label: app.name,
      icon: app.icon,
      accent: app.color ?? OSColors.blue,
      badge: badge,
      onTap: onTap,
    );
  }
}

class _HomeShortcutData {
  const _HomeShortcutData({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.badge,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final String? badge;
}

class _HomeShortcutIcon extends StatelessWidget {
  const _HomeShortcutIcon({
    required this.data,
    this.width = 88,
    this.iconBoxSize = 60,
  });

  final _HomeShortcutData data;
  final double width;
  final double iconBoxSize;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return OSTouchFeedback(
      onTap: data.onTap,
      borderRadius: OSRadius.lgBr,
      minSize: Size(width, width),
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: iconBoxSize,
                  height: iconBoxSize,
                  decoration: BoxDecoration(
                    color: data.accent.withValues(alpha: 0.14),
                    borderRadius:
                        BorderRadius.circular(OSSpacing.appIconRadius),
                    border: Border.all(
                      color: data.accent.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Icon(
                    data.icon,
                    size: iconBoxSize * 0.42,
                    color: data.accent,
                  ),
                ),
                if (data.badge != null)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: OSColors.urgent,
                        borderRadius: OSRadius.pillBr,
                        border: Border.all(
                          color: dark
                              ? OSColors.bg(true)
                              : Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      child: Text(
                        data.badge!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              data.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: OSColors.textSecondary(dark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeSignalsPanel extends StatelessWidget {
  const _HomeSignalsPanel({
    required this.classCount,
    required this.totalStudents,
    required this.unread,
    required this.reminderCount,
  });

  final int classCount;
  final int totalStudents;
  final int unread;
  final int reminderCount;

  @override
  Widget build(BuildContext context) {
    final attentionCount = [
      if (classCount == 0) 1,
      if (unread > 0) 1,
      if (reminderCount > 0) 1,
    ].length;

    return _GlassPanel(
      tone: _HomePanelTone.whisper,
      radius: 28,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelEyebrow(label: 'Daily Signals'),
          const SizedBox(height: 8),
          Text(
            attentionCount == 0
                ? 'Everything is steady'
                : '$attentionCount area${attentionCount == 1 ? '' : 's'} need a look',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: OSColors.text(context.isDark),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            classCount == 0
                ? 'Create a class first, then GradeFlow can stage your day.'
                : 'Classes, messages, and reminders are ready at a glance.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: OSColors.textSecondary(context.isDark),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SignalMetricTile(
                  label: 'Classes',
                  value: '$classCount',
                  icon: Icons.class_rounded,
                  accent: OSColors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SignalMetricTile(
                  label: 'Students',
                  value: '$totalStudents',
                  icon: Icons.people_alt_outlined,
                  accent: OSColors.cyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _SignalMetricTile(
                  label: 'Messages',
                  value: unread == 0 ? 'Quiet' : '$unread',
                  icon: Icons.forum_outlined,
                  accent: OSColors.blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SignalMetricTile(
                  label: 'Reminders',
                  value: reminderCount == 0 ? 'Clear' : '$reminderCount',
                  icon: Icons.event_note_outlined,
                  accent: OSColors.amber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignalMetricTile extends StatelessWidget {
  const _SignalMetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.72),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: OSColors.textMuted(dark),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: OSColors.text(dark),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeWeatherPanel extends StatefulWidget {
  const _HomeWeatherPanel();

  @override
  State<_HomeWeatherPanel> createState() => _HomeWeatherPanelState();
}

class _HomeWeatherPanelState extends State<_HomeWeatherPanel> {
  late final DashboardWeatherService _service = DashboardWeatherService();
  late final Future<DashboardWeatherSnapshot> _weather =
      _service.fetchForecast();

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return FutureBuilder<DashboardWeatherSnapshot>(
      future: _weather,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final hasError = snapshot.hasError && data == null;
        final forecast =
            data?.forecast.take(2).toList() ?? const <DashboardForecastDay>[];

        return _GlassPanel(
          tone: _HomePanelTone.whisper,
          radius: 28,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: _PanelEyebrow(label: 'Weather')),
                  Icon(
                    data == null
                        ? Icons.cloud_queue_rounded
                        : _weatherIcon(data.weatherCode),
                    color: OSColors.blue,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                hasError
                    ? 'Forecast unavailable'
                    : loading
                        ? 'Checking forecast'
                        : '${data!.temperatureC.round()} C ${_weatherLabel(data.weatherCode)}',
                style: TextStyle(
                  fontSize: 18,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: OSColors.text(dark),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                hasError
                    ? 'Weather will return when the network responds.'
                    : loading
                        ? 'Taichung City'
                        : '${data!.locationName} - feels like ${data.apparentTempC.round()} C',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: OSColors.textSecondary(dark),
                ),
              ),
              if (forecast.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (int index = 0; index < forecast.length; index++) ...[
                      if (index > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _WeatherForecastTile(day: forecast[index]),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _WeatherForecastTile extends StatelessWidget {
  const _WeatherForecastTile({required this.day});

  final DashboardForecastDay day;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.70),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_weatherIcon(day.weatherCode), size: 16, color: OSColors.blue),
          const SizedBox(height: 8),
          Text(
            _formatDateLine(day.date),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: OSColors.textMuted(dark),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${day.maxTempC.round()} / ${day.minTempC.round()} C',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: OSColors.text(dark),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeAudioPanel extends StatelessWidget {
  const _HomeAudioPanel({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return OSTouchFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      minSize: const Size(180, 104),
      child: _GlassPanel(
        tone: _HomePanelTone.whisper,
        radius: 28,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: OSColors.indigo.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: OSColors.indigo.withValues(alpha: 0.22),
                ),
              ),
              child: const Icon(
                Icons.graphic_eq_rounded,
                color: OSColors.indigo,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _PanelEyebrow(label: 'Audio'),
                  const SizedBox(height: 6),
                  Text(
                    'Classroom radio',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: OSColors.text(dark),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Open focus audio and live stations.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: OSColors.textSecondary(dark),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: OSColors.textMuted(dark),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeAgendaPanel extends StatelessWidget {
  const _HomeAgendaPanel({
    required this.reminders,
    required this.scrollable,
  });

  final List<TeacherWorkspaceReminderSnapshot> reminders;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final visibleReminders =
        scrollable ? reminders : reminders.take(4).toList();
    final dark = context.isDark;
    final headerChildren = <Widget>[
      const _PanelEyebrow(label: 'Agenda'),
      const SizedBox(height: 8),
      Text(
        reminders.isEmpty ? 'No pending reminders' : 'Upcoming reminders',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: OSColors.text(dark),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        reminders.isEmpty
            ? 'Nothing is queued right now.'
            : 'The next few actions stay ready without crowding the day.',
        style: TextStyle(
          fontSize: 12,
          height: 1.45,
          color: OSColors.textSecondary(dark),
        ),
      ),
      const SizedBox(height: 10),
    ];

    return _GlassPanel(
      tone: _HomePanelTone.whisper,
      radius: 28,
      padding: const EdgeInsets.all(16),
      child: scrollable
          ? ListView(
              padding: EdgeInsets.zero,
              children: [
                ...headerChildren,
                if (reminders.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: dark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.white.withValues(alpha: 0.66),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: dark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                    child: Text(
                      'Your day is currently clear. New reminders from the planning hub will surface here automatically.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: OSColors.textSecondary(dark),
                      ),
                    ),
                  )
                else
                  for (int index = 0;
                      index < visibleReminders.length;
                      index++) ...[
                    _ReminderTile(
                      reminder: visibleReminders[index],
                      now: DateTime.now(),
                    ),
                    if (index != visibleReminders.length - 1)
                      const SizedBox(height: 10),
                  ],
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...headerChildren,
                if (reminders.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: dark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.white.withValues(alpha: 0.66),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: dark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                    child: Text(
                      'Your day is currently clear. New reminders from the planning hub will surface here automatically.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: OSColors.textSecondary(dark),
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      for (int index = 0;
                          index < visibleReminders.length;
                          index++) ...[
                        _ReminderTile(
                          reminder: visibleReminders[index],
                          now: DateTime.now(),
                        ),
                        if (index != visibleReminders.length - 1)
                          const SizedBox(height: 10),
                      ],
                      if (reminders.length > visibleReminders.length) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '+${reminders.length - visibleReminders.length} more in the planning hub',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: OSColors.textMuted(dark),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    required this.reminder,
    required this.now,
  });

  final TeacherWorkspaceReminderSnapshot reminder;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final dueLabel = _relativeReminderLabel(reminder, now);
    final accent = _reminderAccent(reminder, now);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.72),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dueLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _trimLine(reminder.text, 110),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: OSColors.text(dark),
                  ),
                ),
                if (reminder.classIds.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${reminder.classIds.length} class context${reminder.classIds.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: OSColors.textMuted(dark),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _reminderAccent(
    TeacherWorkspaceReminderSnapshot reminder,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(
      reminder.timestamp.year,
      reminder.timestamp.month,
      reminder.timestamp.day,
    );
    final difference = due.difference(today).inDays;
    if (difference < 0) return OSColors.urgent;
    if (difference == 0) return OSColors.coral;
    if (difference <= 2) return OSColors.amber;
    return OSColors.cyan;
  }
}

class _HomePortalsPanel extends StatelessWidget {
  const _HomePortalsPanel({
    required this.reminderCount,
  });

  final int reminderCount;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      tone: _HomePanelTone.whisper,
      radius: 28,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelEyebrow(label: 'Workspaces'),
          const SizedBox(height: 8),
          Text(
            'Planning and admin',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: OSColors.text(context.isDark),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Deeper setup stays nearby when you need it.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: OSColors.textSecondary(context.isDark),
            ),
          ),
          const SizedBox(height: 12),
          _PanelActionTile(
            icon: Icons.space_dashboard_outlined,
            accent: OSColors.blue,
            title: 'Planning Hub',
            subtitle: reminderCount == 0
                ? 'Schedules, imports, and planning details'
                : '$reminderCount planning reminder${reminderCount == 1 ? '' : 's'} ready',
            onTap: () => context.go(AppRoutes.dashboard),
          ),
          const SizedBox(height: 8),
          _PanelActionTile(
            icon: Icons.admin_panel_settings_rounded,
            accent: OSColors.textSecondary(context.isDark),
            title: 'Connected Workspace',
            subtitle: 'Admin, school links, and settings',
            onTap: () => context.go(AppRoutes.admin),
          ),
        ],
      ),
    );
  }
}

class _HomeClassroomsPanel extends StatelessWidget {
  const _HomeClassroomsPanel({
    required this.classes,
    required this.scrollable,
  });

  final List<Class> classes;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final visibleClasses = scrollable ? classes : classes.take(4).toList();
    final dark = context.isDark;
    final headerChildren = <Widget>[
      const _PanelEyebrow(label: 'Classrooms'),
      const SizedBox(height: 8),
      Text(
        classes.isEmpty ? 'No active classes' : 'Active classes',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: OSColors.text(dark),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        classes.isEmpty
            ? 'Create your first class to start teaching from here.'
            : 'Open the next class workspace directly.',
        style: TextStyle(
          fontSize: 12,
          height: 1.45,
          color: OSColors.textSecondary(dark),
        ),
      ),
      const SizedBox(height: 12),
    ];

    return _GlassPanel(
      tone: _HomePanelTone.whisper,
      radius: 28,
      padding: const EdgeInsets.all(16),
      child: scrollable
          ? ListView(
              padding: EdgeInsets.zero,
              children: [
                ...headerChildren,
                if (classes.isEmpty)
                  _PanelActionTile(
                    icon: Icons.class_rounded,
                    accent: OSColors.green,
                    title: 'Open Classes',
                    subtitle: 'Create or organize class workspaces',
                    onTap: () => context.go(AppRoutes.classes),
                  )
                else
                  for (int index = 0;
                      index < visibleClasses.length;
                      index++) ...[
                    _ClassroomTile(classItem: visibleClasses[index]),
                    if (index != visibleClasses.length - 1)
                      const SizedBox(height: 10),
                  ],
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...headerChildren,
                if (classes.isEmpty)
                  _PanelActionTile(
                    icon: Icons.class_rounded,
                    accent: OSColors.green,
                    title: 'Open Classes',
                    subtitle: 'Create or organize class workspaces',
                    onTap: () => context.go(AppRoutes.classes),
                  )
                else
                  Column(
                    children: [
                      for (int index = 0;
                          index < visibleClasses.length;
                          index++) ...[
                        _ClassroomTile(classItem: visibleClasses[index]),
                        if (index != visibleClasses.length - 1)
                          const SizedBox(height: 10),
                      ],
                      if (classes.length > visibleClasses.length) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '+${classes.length - visibleClasses.length} more class rooms',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: OSColors.textMuted(dark),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
    );
  }
}

class _ClassroomTile extends StatelessWidget {
  const _ClassroomTile({required this.classItem});

  final Class classItem;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return OSTouchFeedback(
      onTap: () => context.go('${AppRoutes.osClass}/${classItem.classId}'),
      borderRadius: BorderRadius.circular(20),
      minSize: const Size(120, 62),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: dark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.white.withValues(alpha: 0.66),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.72),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF58C78B), Color(0xFF5EC7E6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: OSRadius.mdBr,
              ),
              child: const Icon(
                Icons.class_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    classItem.className,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: OSColors.text(dark),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    classItem.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: OSColors.textSecondary(dark),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: OSColors.textMuted(dark),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelActionTile extends StatelessWidget {
  const _PanelActionTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return OSTouchFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      minSize: const Size(120, 56),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: dark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.white.withValues(alpha: 0.66),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.72),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: OSRadius.mdBr,
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: OSColors.text(dark),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.3,
                      color: OSColors.textSecondary(dark),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: OSColors.textMuted(dark),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

enum _HomePanelTone { stage, tool, whisper }

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 28,
    this.gradient,
    this.tone = _HomePanelTone.tool,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Gradient? gradient;
  final _HomePanelTone tone;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final (baseColor, secondaryColor, borderColor, shadowEmphasis, blurSigma) =
        switch (tone) {
      _HomePanelTone.stage => (
          dark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.82),
          dark
              ? const Color(0xFF17253A).withValues(alpha: 0.58)
              : const Color(0xFFEAF4FF).withValues(alpha: 0.95),
          dark
              ? WorkspaceChrome.panelBorderColor(context, emphasis: 0.42)
              : Colors.white.withValues(alpha: 0.86),
          dark ? 1.25 : 1.08,
          WorkspaceChrome.panelBlur,
        ),
      _HomePanelTone.whisper => (
          dark
              ? Colors.white.withValues(alpha: 0.045)
              : Colors.white.withValues(alpha: 0.60),
          dark
              ? const Color(0xFF101827).withValues(alpha: 0.26)
              : const Color(0xFFF4F8FF).withValues(alpha: 0.78),
          dark
              ? WorkspaceChrome.panelBorderColor(context, emphasis: 0.18)
              : Colors.white.withValues(alpha: 0.66),
          dark ? 0.42 : 0.34,
          WorkspaceChrome.panelBlur * 0.78,
        ),
      _HomePanelTone.tool => (
          dark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.white.withValues(alpha: 0.74),
          dark
              ? const Color(0xFF162132).withValues(alpha: 0.44)
              : const Color(0xFFF5F9FF).withValues(alpha: 0.92),
          dark
              ? WorkspaceChrome.panelBorderColor(context, emphasis: 0.34)
              : Colors.white.withValues(alpha: 0.8),
          dark ? 1.0 : 0.94,
          WorkspaceChrome.panelBlur * 0.92,
        ),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: blurSigma,
          sigmaY: blurSigma,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor),
            boxShadow: WorkspaceChrome.panelShadow(
              context,
              emphasis: shadowEmphasis,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    gradient: gradient ??
                        LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            baseColor,
                            secondaryColor,
                            baseColor,
                          ],
                        ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Container(
                    height: 1,
                    color: WorkspaceChrome.glassHighlight(context).withValues(
                      alpha: tone == _HomePanelTone.whisper ? 0.55 : 1.0,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: padding,
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelEyebrow extends StatelessWidget {
  const _PanelEyebrow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: WorkspaceTypography.eyebrow(context)?.copyWith(
        color: OSColors.textMuted(context.isDark),
      ),
    );
  }
}

String _firstName(String fullName) {
  final normalized = fullName.trim();
  if (normalized.isEmpty) {
    return 'Teacher';
  }
  return normalized.split(RegExp(r'\s+')).first;
}

String _schoolName(String? rawSchoolName) {
  final normalized = rawSchoolName?.trim() ?? '';
  return normalized.isEmpty ? 'Teacher workspace' : normalized;
}

String _formatClock(DateTime now) {
  final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
  final minute = now.minute.toString().padLeft(2, '0');
  final suffix = now.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

String _formatDateLine(DateTime now) {
  const weekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${weekdays[now.weekday - 1]} ${months[now.month - 1]} ${now.day}';
}

String _formatLongDate(DateTime now) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
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
    'December',
  ];
  return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
}

IconData _weatherIcon(int code) {
  if (code == 0) return Icons.wb_sunny_outlined;
  if (code <= 3) return Icons.cloud_queue_rounded;
  if (code == 45 || code == 48) return Icons.foggy;
  if (code >= 51 && code <= 67) return Icons.grain_rounded;
  if (code >= 71 && code <= 77) return Icons.ac_unit_rounded;
  if (code >= 80 && code <= 82) return Icons.water_drop_outlined;
  if (code >= 95) return Icons.thunderstorm_outlined;
  return Icons.cloud_outlined;
}

String _weatherLabel(int code) {
  if (code == 0) return 'Clear';
  if (code <= 3) return 'Partly cloudy';
  if (code == 45 || code == 48) return 'Foggy';
  if (code >= 51 && code <= 67) return 'Drizzle';
  if (code >= 71 && code <= 77) return 'Snow';
  if (code >= 80 && code <= 82) return 'Showers';
  if (code >= 95) return 'Thunderstorms';
  return 'Forecast';
}

String _stageHeadline(String teacherName, Class? primaryClass) {
  if (primaryClass != null) {
    return 'Ready for ${primaryClass.className}';
  }
  if (teacherName.isNotEmpty && teacherName != 'Teacher') {
    return 'Welcome back, $teacherName';
  }
  return 'Welcome back';
}

String _stageSupportLine({
  required Class? primaryClass,
  required TeacherWorkspaceReminderSnapshot? primaryReminder,
  required int classCount,
  required int unread,
  required String schoolName,
  required DateTime now,
}) {
  if (primaryReminder != null) {
    return '${_relativeReminderLabel(primaryReminder, now)}. ${_trimLine(primaryReminder.text, 96)}';
  }
  if (unread > 0) {
    return '$unread unread conversation${unread == 1 ? '' : 's'} are waiting in Messages. Keep the day moving from here, then dive deeper only when needed.';
  }
  if (primaryClass != null) {
    return '${primaryClass.subject} is pinned as your lead classroom surface. $classCount class workspace${classCount == 1 ? '' : 's'} are ready from $schoolName.';
  }
  return 'Pin a class and enter Teach Mode when you are ready.';
}

String _relativeReminderLabel(
  TeacherWorkspaceReminderSnapshot reminder,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  final dueDate = DateTime(
    reminder.timestamp.year,
    reminder.timestamp.month,
    reminder.timestamp.day,
  );
  final difference = dueDate.difference(today).inDays;
  if (difference < 0) {
    return 'Overdue';
  }
  if (difference == 0) {
    return 'Due today';
  }
  if (difference == 1) {
    return 'Due tomorrow';
  }
  return 'Due in $difference days';
}

String _trimLine(String value, int maxLength) {
  final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.length <= maxLength) {
    return normalized;
  }
  return '${normalized.substring(0, maxLength - 1)}...';
}
