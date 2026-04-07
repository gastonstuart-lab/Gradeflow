/// GradeFlow OS — Home Surface
///
/// The teacher's primary landing surface. It should feel like a dedicated
/// device home rather than a bridge into the legacy dashboard:
///   - compact system strip
///   - prominent daily command card
///   - widget-led workspace grid
///   - quick app launch and class focus areas
///   - legacy dashboard access as a secondary utility, not a second page

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/os/os_app_model.dart';
import 'package:gradeflow/os/os_assistant.dart';
import 'package:gradeflow/os/os_controller.dart';
import 'package:gradeflow/os/os_palette.dart';
import 'package:gradeflow/os/os_touch_feedback.dart';
import 'package:gradeflow/os/os_widget_host.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/communication_service.dart';
import 'package:gradeflow/services/global_system_shell_service.dart';

class HomeSurface extends StatelessWidget {
  const HomeSurface({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final shell = context.watch<GlobalSystemShellController>();
    final classes = context.watch<ClassService>().activeClasses;
    final snapshot = shell.workspaceSnapshot;
    final pendingReminders = snapshot?.pendingReminders ?? const [];
    final totalStudents = snapshot?.totalStudents ?? 0;
    final unread = context.watch<CommunicationService>().totalUnreadCount;
    final now = DateTime.now();
    final firstClass = _selectPrimaryClass(snapshot?.activeClasses, classes);

    return Scaffold(
      backgroundColor: OSColors.bg(dark),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isPhone = constraints.maxWidth < 700;
            final compact = constraints.maxWidth < 1080;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isPhone ? 14 : 20,
                10,
                isPhone ? 14 : 20,
                24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HomeSystemStrip(
                    unread: unread,
                    onShadeTap: context.read<GradeFlowOSController>().openShade,
                  ),
                  const SizedBox(height: 16),
                  _HomeCommandDeck(
                    firstClass: firstClass,
                    pendingReminderCount: pendingReminders.length,
                    totalStudents: totalStudents,
                    onTeachTap: () => context.go(AppRoutes.osTeach),
                    onAssistantTap:
                        context.read<GradeFlowOSController>().openAssistant,
                    onLauncherTap:
                        context.read<GradeFlowOSController>().openLauncher,
                    now: now,
                  ),
                  const SizedBox(height: 18),
                  if (compact) ...[
                    _HomePrimaryColumn(
                      columns: isPhone ? 1 : 2,
                      classes: classes,
                    ),
                    const SizedBox(height: 16),
                    _HomeSecondaryColumn(
                      primaryClass: firstClass,
                      pendingReminderCount: pendingReminders.length,
                      unread: unread,
                    ),
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 8,
                          child: _HomePrimaryColumn(
                            columns: constraints.maxWidth >= 1440 ? 4 : 3,
                            classes: classes,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          flex: 4,
                          child: _HomeSecondaryColumn(
                            primaryClass: firstClass,
                            pendingReminderCount: pendingReminders.length,
                            unread: unread,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Class? _selectPrimaryClass(
      List<Class>? snapshotClasses, List<Class> serviceClasses) {
    final candidates = snapshotClasses != null && snapshotClasses.isNotEmpty
        ? snapshotClasses
        : serviceClasses;
    return candidates.isNotEmpty ? candidates.first : null;
  }
}

class _HomeSystemStrip extends StatelessWidget {
  const _HomeSystemStrip({
    required this.unread,
    required this.onShadeTap,
  });

  final int unread;
  final VoidCallback onShadeTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;
    final firstName = _firstName(user?.fullName ?? '');
    final now = TimeOfDay.fromDateTime(DateTime.now()).format(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: dark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: OSRadius.pillBr,
              border: Border.all(color: OSColors.border(dark), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 30,
                  height: 30,
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
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GradeFlow OS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: OSColors.text(dark),
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      firstName.isEmpty
                          ? 'Teacher workspace'
                          : '$firstName workspace',
                      style: TextStyle(
                        fontSize: 11,
                        color: OSColors.textSecondary(dark),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            now,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: OSColors.textSecondary(dark),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 10),
          OSTouchFeedback(
            onTap: onShadeTap,
            minSize: const Size(44, 44),
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: dark
                        ? Colors.white.withValues(alpha: 0.07)
                        : Colors.black.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_outlined,
                    size: 18,
                    color: OSColors.textSecondary(dark),
                  ),
                ),
                if (unread > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: OSColors.urgent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: OSColors.bg(dark),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const OSAssistantFab(),
        ],
      ),
    );
  }

  String _firstName(String fullName) {
    final parts = fullName.trim().split(' ');
    return parts.isNotEmpty ? parts.first : '';
  }
}

class _HomeCommandDeck extends StatelessWidget {
  const _HomeCommandDeck({
    required this.firstClass,
    required this.pendingReminderCount,
    required this.totalStudents,
    required this.onTeachTap,
    required this.onAssistantTap,
    required this.onLauncherTap,
    required this.now,
  });

  final Class? firstClass;
  final int pendingReminderCount;
  final int totalStudents;
  final VoidCallback onTeachTap;
  final VoidCallback onAssistantTap;
  final VoidCallback onLauncherTap;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: OSRadius.xlBr,
        gradient: LinearGradient(
          colors: dark
              ? const [Color(0xFF132235), Color(0xFF0F1725), Color(0xFF102940)]
              : const [Color(0xFFF8FBFF), Color(0xFFEAF1FA), Color(0xFFDDE8F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: OSColors.border(dark), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.24 : 0.08),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _headlineForHour(now.hour),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              color: OSColors.blueSoft,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Teacher command center',
            style: TextStyle(
              fontSize: 28,
              height: 1.05,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.1,
              color: OSColors.text(dark),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            firstClass != null
                ? '${firstClass!.className} · ${firstClass!.subject}. Your classes, tools, and assistant are always one tap away.'
                : 'Your classes, teaching tools, and assistant are always one tap away.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: OSColors.textSecondary(dark),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _DeckMetricPill(
                icon: Icons.class_rounded,
                label: firstClass?.className ?? 'No class selected',
                value: firstClass?.subject ?? 'Classes',
                accent: OSColors.green,
              ),
              _DeckMetricPill(
                icon: Icons.notifications_active_outlined,
                label: 'Reminders',
                value: pendingReminderCount == 0
                    ? 'All clear'
                    : '$pendingReminderCount pending',
                accent: OSColors.amber,
              ),
              _DeckMetricPill(
                icon: Icons.people_alt_outlined,
                label: 'Students',
                value: totalStudents == 0 ? 'Syncing' : '$totalStudents total',
                accent: OSColors.cyan,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _PrimaryActionChip(
                label: 'Enter Teach Mode',
                icon: Icons.cast_for_education_rounded,
                onTap: onTeachTap,
                filled: true,
              ),
              _PrimaryActionChip(
                label: 'Ask Assistant',
                icon: Icons.auto_awesome_rounded,
                onTap: onAssistantTap,
              ),
              _PrimaryActionChip(
                label: 'Open Launcher',
                icon: Icons.grid_view_rounded,
                onTap: onLauncherTap,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _headlineForHour(int hour) {
    if (hour < 12) return 'Morning overview';
    if (hour < 17) return 'Afternoon flow';
    return 'Evening wrap-up';
  }
}

class _HomePrimaryColumn extends StatelessWidget {
  const _HomePrimaryColumn({
    required this.columns,
    required this.classes,
  });

  final int columns;
  final List<Class> classes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(
          title: 'Workspace widgets',
          subtitle: 'Live teaching state, reminders, and launch actions.',
        ),
        const SizedBox(height: 12),
        OSWidgetHost(
          columns: columns,
          widgets: kHomePrimaryWidgets,
        ),
        const SizedBox(height: 16),
        const _SectionHeading(
          title: 'Class focus',
          subtitle: 'Jump directly into the rooms that need attention.',
        ),
        const SizedBox(height: 12),
        _ClassFocusRail(classes: classes),
      ],
    );
  }
}

class _HomeSecondaryColumn extends StatelessWidget {
  const _HomeSecondaryColumn({
    required this.primaryClass,
    required this.pendingReminderCount,
    required this.unread,
  });

  final Class? primaryClass;
  final int pendingReminderCount;
  final int unread;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(
          title: 'Quick tools',
          subtitle: 'Core apps and secondary system access.',
        ),
        const SizedBox(height: 12),
        _LaunchPanel(
          primaryClass: primaryClass,
          unread: unread,
        ),
        const SizedBox(height: 16),
        _LegacyAccessPanel(
          pendingReminderCount: pendingReminderCount,
        ),
      ],
    );
  }
}

class _DashboardNavCard extends StatelessWidget {
  const _DashboardNavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return OSTouchFeedback(
      onTap: onTap,
      borderRadius: OSRadius.lgBr,
      minSize: const Size(120, 52),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: OSColors.surface(dark),
          borderRadius: OSRadius.lgBr,
          border: Border.all(color: OSColors.border(dark), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: OSColors.blue.withValues(alpha: 0.12),
                borderRadius: OSRadius.mdBr,
              ),
              child: Icon(icon, color: OSColors.blue, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: OSColors.text(dark),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
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
              color: OSColors.textMuted(dark),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: OSColors.text(dark),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: OSColors.textSecondary(dark),
          ),
        ),
      ],
    );
  }
}

class _DeckMetricPill extends StatelessWidget {
  const _DeckMetricPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: OSRadius.pillBr,
        border: Border.all(color: OSColors.border(dark), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
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

class _PrimaryActionChip extends StatelessWidget {
  const _PrimaryActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final background = filled
        ? const LinearGradient(
            colors: [Color(0xFF5C8AFF), Color(0xFF7869F0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : null;

    return OSTouchFeedback(
      onTap: onTap,
      borderRadius: OSRadius.pillBr,
      minSize: const Size(138, 44),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          gradient: background,
          color: background == null
              ? (dark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.72))
              : null,
          borderRadius: OSRadius.pillBr,
          border: Border.all(
            color: background == null
                ? OSColors.border(dark)
                : Colors.white.withValues(alpha: 0.10),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: filled ? Colors.white : OSColors.text(dark),
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

class _LaunchPanel extends StatelessWidget {
  const _LaunchPanel({
    required this.unread,
  });

  final int unread;

  @override
  Widget build(BuildContext context) {
    final apps = <OSApp>[
      OSAppRegistry.findById(OSAppId.teach)!,
      OSAppRegistry.findById(OSAppId.whiteboard)!,
      OSAppRegistry.findById(OSAppId.messages)!,
      OSAppRegistry.findById(OSAppId.connected)!,
    ];

    return Column(
      children: [
        for (final app in apps) ...[
          _LaunchAppTile(
            app: app,
            badge: app.id == OSAppId.messages && unread > 0 ? '$unread' : null,
            onTap: () => _openApp(context, app),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 2),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 10),
            child: Text(
              'All classes',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: OSColors.textSecondary(context.isDark),
              ),
            ),
          ),
        ),
        _SecondaryUtilityTile(
          icon: Icons.class_rounded,
          title: 'Class list',
          subtitle: 'Browse every class and open a workspace',
          onTap: () => context.go(AppRoutes.classes),
        ),
      ],
    );
  }

  void _openApp(BuildContext context, OSApp app) {
    final route = app.route;
    if (route != null) {
      context.go(route);
    }
  }
}

class _LaunchAppTile extends StatelessWidget {
  const _LaunchAppTile({
    required this.app,
    required this.onTap,
    this.badge,
  });

  final OSApp app;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final accent = app.color ?? OSColors.blue;
    return OSTouchFeedback(
      onTap: onTap,
      borderRadius: OSRadius.lgBr,
      minSize: const Size(130, 56),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: OSColors.surface(dark),
          borderRadius: OSRadius.lgBr,
          border: Border.all(color: OSColors.border(dark), width: 1),
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
              child: Icon(app.icon, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: OSColors.text(dark),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    app.description ?? '',
                    style: TextStyle(
                      fontSize: 11,
                      color: OSColors.textSecondary(dark),
                    ),
                  ),
                ],
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              )
            else
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

class _LegacyAccessPanel extends StatelessWidget {
  const _LegacyAccessPanel({
    required this.pendingReminderCount,
  });

  final int pendingReminderCount;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: dark
              ? Colors.white.withValues(alpha: 0.035)
              : Colors.black.withValues(alpha: 0.018),
          borderRadius: OSRadius.xlBr,
          border: Border.all(
            color: OSColors.border(dark).withValues(alpha: 0.65),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'More',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: OSColors.textSecondary(dark),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Full workspace views, admin tools, and settings.',
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: OSColors.textMuted(dark),
              ),
            ),
            const SizedBox(height: 10),
            _SecondaryUtilityTile(
              icon: Icons.space_dashboard_outlined,
              title: 'Full Dashboard',
              subtitle: pendingReminderCount > 0
                  ? '$pendingReminderCount reminders are also visible from the dashboard views'
                  : 'Open the legacy workspace and planning views',
              onTap: () => context.go(AppRoutes.dashboard),
            ),
            const SizedBox(height: 6),
            _SecondaryUtilityTile(
              icon: Icons.admin_panel_settings_rounded,
              title: 'Connected Workspace',
              subtitle: 'Admin tools, school links, and settings',
              onTap: () => context.go(AppRoutes.admin),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryUtilityTile extends StatelessWidget {
  const _SecondaryUtilityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return OSTouchFeedback(
      onTap: onTap,
      borderRadius: OSRadius.mdBr,
      minSize: const Size(120, 48),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: dark
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.black.withValues(alpha: 0.012),
          borderRadius: OSRadius.mdBr,
          border: Border.all(
            color: OSColors.border(dark).withValues(alpha: 0.55),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: OSColors.textSecondary(dark)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: OSColors.text(dark),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: OSColors.textMuted(dark),
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: OSColors.textMuted(dark),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassFocusRail extends StatelessWidget {
  const _ClassFocusRail({required this.classes});

  final List<Class> classes;

  @override
  Widget build(BuildContext context) {
    if (classes.isEmpty) {
      return const _DashboardNavCard(
        icon: Icons.class_rounded,
        title: 'No classes yet',
        subtitle: 'Use the Classes app to create your first teaching workspace',
      );
    }

    final visible = classes.take(3).toList();
    return Column(
      children: [
        for (final item in visible) ...[
          _ClassFocusCard(classItem: item),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ClassFocusCard extends StatelessWidget {
  const _ClassFocusCard({required this.classItem});

  final Class classItem;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return OSTouchFeedback(
      onTap: () => context.go('${AppRoutes.osClass}/${classItem.classId}'),
      borderRadius: OSRadius.lgBr,
      minSize: const Size(140, 60),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: OSColors.surface(dark),
          borderRadius: OSRadius.lgBr,
          border: Border.all(color: OSColors.border(dark), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
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
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: OSColors.text(dark),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    classItem.subject,
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
              color: OSColors.textMuted(dark),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
