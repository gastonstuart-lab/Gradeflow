/// GradeFlow OS — Notification Shade
///
/// [OSNotificationShade] slides down from the top of the screen when the
/// teacher pulls down or taps the shade trigger in the status bar.
///
/// It delegates notification data to the existing
/// [GlobalSystemShellController] so messages, admin alerts, and reminders
/// already handled by that controller continue to surface here.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/os/os_palette.dart';
import 'package:gradeflow/services/global_system_shell_service.dart';
import 'package:gradeflow/services/communication_service.dart';
import 'package:gradeflow/nav.dart';

class OSNotificationShade extends StatelessWidget {
  const OSNotificationShade({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final shellCtrl = context.watch<GlobalSystemShellController>();
    final communication = context.watch<CommunicationService>();

    final unread = communication.totalUnreadCount;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: OSColors.surface(dark),
        borderRadius: OSRadius.xlBr,
        border: Border.all(color: OSColors.border(dark), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.40 : 0.12),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          _ShadeHandle(dark: dark),

          // Quick actions row
          _ShadeQuickActions(dark: dark, onDismiss: onDismiss),

          const _ShadeDivider(),

          // Notification list
          _ShadeNotificationList(
            communication: communication,
            shellCtrl: shellCtrl,
            dark: dark,
            unread: unread,
            onDismiss: onDismiss,
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INTERNAL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _ShadeHandle extends StatelessWidget {
  const _ShadeHandle({required this.dark});
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: OSColors.border(dark),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _ShadeQuickActions extends StatelessWidget {
  const _ShadeQuickActions({required this.dark, required this.onDismiss});

  final bool dark;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Text(
            'Notifications',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: OSColors.text(dark),
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          _ShadeChip(
            icon: Icons.forum_rounded,
            label: 'Messages',
            onTap: () {
              onDismiss();
              context.go(AppRoutes.communication);
            },
          ),
          const SizedBox(width: 8),
          _ShadeChip(
            icon: Icons.class_rounded,
            label: 'Classes',
            onTap: () {
              onDismiss();
              context.go(AppRoutes.classes);
            },
          ),
        ],
      ),
    );
  }
}

class _ShadeChip extends StatelessWidget {
  const _ShadeChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: dark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: OSRadius.pillBr,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: OSColors.textSecondary(dark)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: OSColors.textSecondary(dark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShadeDivider extends StatelessWidget {
  const _ShadeDivider();

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: OSColors.border(dark),
    );
  }
}

class _ShadeNotificationList extends StatelessWidget {
  const _ShadeNotificationList({
    required this.communication,
    required this.shellCtrl,
    required this.dark,
    required this.unread,
    required this.onDismiss,
  });

  final CommunicationService communication;
  final GlobalSystemShellController shellCtrl;
  final bool dark;
  final int unread;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final snapshot = shellCtrl.workspaceSnapshot;
    final items = <Widget>[];

    // Messages unread
    if (unread > 0) {
      items.add(
        _ShadeNotificationTile(
          icon: Icons.forum_rounded,
          iconColor: OSColors.blue,
          title: '$unread unread message${unread == 1 ? '' : 's'}',
          subtitle: 'Tap to open your inbox',
          onTap: () {
            onDismiss();
            context.go(AppRoutes.communication);
          },
        ),
      );
    }

    // Admin alerts
    for (final alert in communication.adminAlertMessages.take(2)) {
      items.add(
        _ShadeNotificationTile(
          icon: Icons.campaign_outlined,
          iconColor: OSColors.attention,
          title: alert.text,
          subtitle: 'Admin',
          onTap: () {
            onDismiss();
            context.go(AppRoutes.admin);
          },
        ),
      );
    }

    // Reminders from workspace snapshot
    if (snapshot != null) {
      final today = DateTime.now();
      final upcoming = snapshot.pendingReminders.where((r) {
        final d =
            DateTime(r.timestamp.year, r.timestamp.month, r.timestamp.day);
        final t = DateTime(today.year, today.month, today.day);
        return d.difference(t).inDays <= 3;
      }).take(2);
      for (final r in upcoming) {
        items.add(
          _ShadeNotificationTile(
            icon: Icons.event_note_outlined,
            iconColor: OSColors.amber,
            title: r.text,
            subtitle: _relativeDay(r.timestamp),
            onTap: () {
              onDismiss();
              context.go(AppRoutes.osHome);
            },
          ),
        );
      }
    }

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 18,
              color: OSColors.success,
            ),
            const SizedBox(width: 10),
            Text(
              'All clear — no new notifications.',
              style: TextStyle(
                fontSize: 13,
                color: OSColors.textSecondary(dark),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: items,
    );
  }

  String _relativeDay(DateTime dt) {
    final today = DateTime.now();
    final d = DateTime(dt.year, dt.month, dt.day);
    final t = DateTime(today.year, today.month, today.day);
    final diff = d.difference(t).inDays;
    if (diff < 0) return 'Overdue';
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return 'In $diff days';
  }
}

class _ShadeNotificationTile extends StatelessWidget {
  const _ShadeNotificationTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: OSRadius.mdBr,
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: OSColors.text(dark),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
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
              size: 16,
              color: OSColors.textMuted(dark),
            ),
          ],
        ),
      ),
    );
  }
}
