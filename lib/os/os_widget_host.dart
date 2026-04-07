/// GradeFlow OS — Widget Host System
///
/// Provides the widget model and renderer for the OS home screen.
///
/// This version keeps the API small but makes the Home surface more native by
/// supporting richer widget types, responsive spans, and a simple registry.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/os/os_palette.dart';
import 'package:gradeflow/os/os_touch_feedback.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/communication_service.dart';
import 'package:gradeflow/services/global_system_shell_service.dart';

enum OSWidgetType {
  teacherPulse,
  nextClass,
  messagesSummary,
  reminderStack,
  quickLaunch,
  classHealth,
  classDeck,
}

enum OSWidgetSize {
  compact,
  regular,
  wide,
  full,
}

class OSWidgetConfig {
  const OSWidgetConfig({
    required this.id,
    required this.type,
    this.size = OSWidgetSize.regular,
  });

  final String id;
  final OSWidgetType type;
  final OSWidgetSize size;
}

const List<OSWidgetConfig> kHomePrimaryWidgets = [
  OSWidgetConfig(
    id: 'w-pulse',
    type: OSWidgetType.teacherPulse,
    size: OSWidgetSize.wide,
  ),
  OSWidgetConfig(
    id: 'w-next-class',
    type: OSWidgetType.nextClass,
    size: OSWidgetSize.regular,
  ),
  OSWidgetConfig(
    id: 'w-messages',
    type: OSWidgetType.messagesSummary,
    size: OSWidgetSize.regular,
  ),
  OSWidgetConfig(
    id: 'w-reminders',
    type: OSWidgetType.reminderStack,
    size: OSWidgetSize.regular,
  ),
  OSWidgetConfig(
    id: 'w-quick-launch',
    type: OSWidgetType.quickLaunch,
    size: OSWidgetSize.wide,
  ),
  OSWidgetConfig(
    id: 'w-health',
    type: OSWidgetType.classHealth,
    size: OSWidgetSize.wide,
  ),
];

const List<OSWidgetConfig> kDefaultWidgetLayout = kHomePrimaryWidgets;

extension on OSWidgetSize {
  int spanFor(int columns) {
    switch (this) {
      case OSWidgetSize.compact:
        return 1;
      case OSWidgetSize.regular:
        return columns >= 3 ? 1 : (columns > 1 ? 1 : columns);
      case OSWidgetSize.wide:
        return columns <= 2 ? columns : 2;
      case OSWidgetSize.full:
        return columns;
    }
  }
}

class OSWidgetHost extends StatelessWidget {
  const OSWidgetHost({
    super.key,
    this.widgets = kDefaultWidgetLayout,
    this.columns = 3,
  });

  final List<OSWidgetConfig> widgets;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final resolvedColumns = columns < 1 ? 1 : columns;
    final rows = <_WidgetRowData>[];
    var currentItems = <_WidgetRowItem>[];
    var usedSpan = 0;

    for (final widget in widgets) {
      final span =
          widget.size.spanFor(resolvedColumns).clamp(1, resolvedColumns);
      if (span == resolvedColumns) {
        if (currentItems.isNotEmpty) {
          rows.add(_WidgetRowData(items: currentItems, usedSpan: usedSpan));
          currentItems = <_WidgetRowItem>[];
          usedSpan = 0;
        }
        rows.add(
          _WidgetRowData(
            items: [_WidgetRowItem(config: widget, span: resolvedColumns)],
            usedSpan: resolvedColumns,
          ),
        );
        continue;
      }

      if (usedSpan + span > resolvedColumns) {
        rows.add(_WidgetRowData(items: currentItems, usedSpan: usedSpan));
        currentItems = <_WidgetRowItem>[];
        usedSpan = 0;
      }

      currentItems.add(_WidgetRowItem(config: widget, span: span));
      usedSpan += span;
    }

    if (currentItems.isNotEmpty) {
      rows.add(_WidgetRowData(items: currentItems, usedSpan: usedSpan));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < row.items.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  flex: row.items[i].span,
                  child: _OSWidgetRenderer(config: row.items[i].config),
                ),
              ],
              if (row.usedSpan < resolvedColumns) ...[
                const SizedBox(width: 12),
                Expanded(
                  flex: resolvedColumns - row.usedSpan,
                  child: const SizedBox.shrink(),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _WidgetRowData {
  const _WidgetRowData({required this.items, required this.usedSpan});

  final List<_WidgetRowItem> items;
  final int usedSpan;
}

class _WidgetRowItem {
  const _WidgetRowItem({required this.config, required this.span});

  final OSWidgetConfig config;
  final int span;
}

class _OSWidgetRenderer extends StatelessWidget {
  const _OSWidgetRenderer({required this.config});

  final OSWidgetConfig config;

  @override
  Widget build(BuildContext context) {
    switch (config.type) {
      case OSWidgetType.teacherPulse:
        return const OSTeacherPulseWidget();
      case OSWidgetType.nextClass:
        return const OSNextClassWidget();
      case OSWidgetType.messagesSummary:
        return const OSMessagesSummaryWidget();
      case OSWidgetType.reminderStack:
        return const OSReminderStackWidget();
      case OSWidgetType.quickLaunch:
        return const OSQuickLaunchWidget();
      case OSWidgetType.classHealth:
        return const OSClassHealthWidget();
      case OSWidgetType.classDeck:
        return const OSClassDeckWidget();
    }
  }
}

class _WidgetCard extends StatelessWidget {
  const _WidgetCard({
    required this.child,
    this.onTap,
    this.minHeight = 110,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return OSTouchFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(OSSpacing.widgetCorner),
      minSize: const Size(120, 56),
      child: AnimatedContainer(
        duration: OSMotion.fast,
        constraints: BoxConstraints(minHeight: minHeight),
        padding: const EdgeInsets.all(OSSpacing.widgetPad),
        decoration: BoxDecoration(
          color: OSColors.surface(dark),
          borderRadius: BorderRadius.circular(OSSpacing.widgetCorner),
          border: Border.all(
            color: OSColors.border(dark),
            width: 1,
          ),
        ),
        child: child,
      ),
    );
  }
}

class OSTeacherPulseWidget extends StatelessWidget {
  const OSTeacherPulseWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final snapshot =
        context.watch<GlobalSystemShellController>().workspaceSnapshot;
    final classes = snapshot?.activeClasses ?? const <Class>[];
    final reminders = snapshot?.pendingReminders ?? const [];
    final totalStudents = snapshot?.totalStudents ?? 0;

    return _WidgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Teacher Pulse',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: OSColors.textSecondary(dark),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: OSColors.blue,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            classes.isEmpty
                ? 'Your day is clear'
                : '${classes.length} active classes are ready',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
              color: OSColors.text(dark),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            reminders.isEmpty
                ? 'No pending reminders right now.'
                : '${reminders.length} reminders still need attention.',
            style: TextStyle(
              fontSize: 12,
              color: OSColors.textSecondary(dark),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _InlineMetric(
                label: 'Classes',
                value: '${classes.length}',
                accent: OSColors.green,
              ),
              const SizedBox(width: 10),
              _InlineMetric(
                label: 'Students',
                value: '$totalStudents',
                accent: OSColors.cyan,
              ),
              const SizedBox(width: 10),
              _InlineMetric(
                label: 'Reminders',
                value: '${reminders.length}',
                accent: OSColors.amber,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class OSNextClassWidget extends StatelessWidget {
  const OSNextClassWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final snapshot =
        context.watch<GlobalSystemShellController>().workspaceSnapshot;
    final classService = context.watch<ClassService>();
    final classes = snapshot?.activeClasses.isNotEmpty == true
        ? snapshot!.activeClasses
        : classService.activeClasses;
    final nextClass = classes.isNotEmpty ? classes.first : null;

    return _WidgetCard(
      onTap: nextClass != null
          ? () => context.go('${AppRoutes.osClass}/${nextClass.classId}')
          : () => context.go(AppRoutes.classes),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.class_rounded,
                size: 16,
                color: OSColors.green,
              ),
              const SizedBox(width: 6),
              Text(
                'Next Class',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: OSColors.green,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (nextClass != null) ...[
            Text(
              nextClass.className,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: OSColors.text(dark),
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              nextClass.subject,
              style: TextStyle(
                fontSize: 11,
                color: OSColors.textSecondary(dark),
              ),
            ),
          ] else
            Text(
              'No classes yet',
              style: TextStyle(
                fontSize: 14,
                color: OSColors.textMuted(dark),
              ),
            ),
        ],
      ),
    );
  }
}

class OSMessagesSummaryWidget extends StatelessWidget {
  const OSMessagesSummaryWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final communication = context.watch<CommunicationService>();
    final unread = communication.totalUnreadCount;

    return _WidgetCard(
      onTap: () => context.go(AppRoutes.communication),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.forum_rounded, size: 16, color: OSColors.blue),
              const SizedBox(width: 6),
              Text(
                'Messages',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: OSColors.blue,
                  letterSpacing: 0.4,
                ),
              ),
              if (unread > 0) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: OSColors.urgent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$unread',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (unread > 0) ...[
            Text(
              '$unread unread',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: OSColors.text(dark),
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Tap to open inbox',
              style: TextStyle(
                fontSize: 11,
                color: OSColors.textSecondary(dark),
              ),
            ),
          ] else
            Text(
              'All clear',
              style: TextStyle(
                fontSize: 14,
                color: OSColors.textMuted(dark),
              ),
            ),
        ],
      ),
    );
  }
}

class OSReminderStackWidget extends StatelessWidget {
  const OSReminderStackWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final snapshot =
        context.watch<GlobalSystemShellController>().workspaceSnapshot;
    final reminders = snapshot?.pendingReminders.take(3).toList() ?? const [];

    return _WidgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist_rounded, size: 16, color: OSColors.amber),
              const SizedBox(width: 6),
              Text(
                'Reminders',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: OSColors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (reminders.isEmpty)
            Text(
              'Nothing pending.',
              style: TextStyle(
                fontSize: 14,
                color: OSColors.textMuted(dark),
              ),
            )
          else
            for (final reminder in reminders) ...[
              Text(
                reminder.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: OSColors.text(dark),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                reminder.isSchoolWide ? 'School-wide' : 'Class linked',
                style: TextStyle(
                  fontSize: 10,
                  color: OSColors.textSecondary(dark),
                ),
              ),
              if (reminder != reminders.last) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class OSQuickLaunchWidget extends StatelessWidget {
  const OSQuickLaunchWidget({super.key});

  static const _actions = [
    _QuickAction(
      icon: Icons.draw_rounded,
      label: 'Whiteboard',
      route: AppRoutes.whiteboard,
      color: Color(0xFF7869F0),
    ),
    _QuickAction(
      icon: Icons.class_rounded,
      label: 'Classes',
      route: AppRoutes.classes,
      color: Color(0xFF58C78B),
    ),
    _QuickAction(
      icon: Icons.forum_rounded,
      label: 'Messages',
      route: AppRoutes.communication,
      color: Color(0xFF5C8AFF),
    ),
    _QuickAction(
      icon: Icons.cast_for_education_rounded,
      label: 'Teach',
      route: AppRoutes.osTeach,
      color: Color(0xFF5EC7E6),
    ),
    _QuickAction(
      icon: Icons.admin_panel_settings_rounded,
      label: 'Connected',
      route: AppRoutes.admin,
      color: Color(0xFF66758C),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return _WidgetCard(
      minHeight: 80,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Launch',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: OSColors.textSecondary(dark),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _actions
                .map(
                  (action) => _QuickActionButton(
                    action: action,
                    onTap: () => context.go(action.route),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class OSClassHealthWidget extends StatelessWidget {
  const OSClassHealthWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final snapshot =
        context.watch<GlobalSystemShellController>().workspaceSnapshot;
    final classService = context.watch<ClassService>();
    final activeClasses = snapshot?.activeClasses.isNotEmpty == true
        ? snapshot!.activeClasses
        : classService.activeClasses;
    final archivedCount = snapshot?.archivedClasses.length ?? 0;
    final totalStudents = snapshot?.totalStudents ?? 0;

    return _WidgetCard(
      onTap: () => context.go(AppRoutes.classes),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Class health',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: OSColors.textSecondary(dark),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.analytics_rounded,
                size: 16,
                color: OSColors.indigo,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            activeClasses.isEmpty
                ? 'No active classes yet'
                : '${activeClasses.length} live classes across your workspace',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: OSColors.text(dark),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _InlineMetric(
                label: 'Active',
                value: '${activeClasses.length}',
                accent: OSColors.green,
              ),
              const SizedBox(width: 10),
              _InlineMetric(
                label: 'Archived',
                value: '$archivedCount',
                accent: OSColors.indigo,
              ),
              const SizedBox(width: 10),
              _InlineMetric(
                label: 'Students',
                value: '$totalStudents',
                accent: OSColors.cyan,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class OSClassDeckWidget extends StatelessWidget {
  const OSClassDeckWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final classService = context.watch<ClassService>();
    final snapshot =
        context.watch<GlobalSystemShellController>().workspaceSnapshot;
    final classes = snapshot?.activeClasses.isNotEmpty == true
        ? snapshot!.activeClasses
        : classService.activeClasses;
    final visible = classes.take(3).toList();

    return _WidgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Class deck',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: OSColors.textSecondary(dark),
            ),
          ),
          const SizedBox(height: 10),
          if (visible.isEmpty)
            Text(
              'Create your first class to start using the OS workspace.',
              style: TextStyle(
                fontSize: 13,
                color: OSColors.textMuted(dark),
              ),
            )
          else
            for (final classItem in visible) ...[
              _ClassDeckTile(classItem: classItem),
              if (classItem != visible.last) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.route,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String route;
  final Color color;
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.action,
    required this.onTap,
  });

  final _QuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return OSTouchFeedback(
      onTap: onTap,
      borderRadius: OSRadius.lgBr,
      minSize: const Size(84, 54),
      child: Container(
        width: 88,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: dark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.02),
          borderRadius: OSRadius.lgBr,
          border: Border.all(color: OSColors.border(dark), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.14),
                borderRadius: OSRadius.mdBr,
              ),
              child: Icon(action.icon, size: 19, color: action.color),
            ),
            const SizedBox(height: 8),
            Text(
              action.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: OSColors.text(dark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  const _InlineMetric({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: OSRadius.mdBr,
          border: Border.all(color: accent.withValues(alpha: 0.18), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: OSColors.text(dark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassDeckTile extends StatelessWidget {
  const _ClassDeckTile({required this.classItem});

  final Class classItem;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return OSTouchFeedback(
      onTap: () => context.go('${AppRoutes.osClass}/${classItem.classId}'),
      borderRadius: OSRadius.lgBr,
      minSize: const Size(140, 56),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: dark
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.black.withValues(alpha: 0.02),
          borderRadius: OSRadius.lgBr,
          border: Border.all(color: OSColors.border(dark), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: OSColors.green.withValues(alpha: 0.14),
                borderRadius: OSRadius.mdBr,
              ),
              child: const Icon(
                Icons.class_rounded,
                color: OSColors.green,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    classItem.className,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: OSColors.text(dark),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    classItem.subject,
                    style: TextStyle(
                      fontSize: 11,
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
