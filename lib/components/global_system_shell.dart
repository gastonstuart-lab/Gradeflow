import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gradeflow/components/workspace_shell.dart';
import 'package:gradeflow/models/communication_models.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/communication_service.dart';
import 'package:gradeflow/services/global_system_shell_service.dart';
import 'package:provider/provider.dart';

class GlobalSystemShellFrame extends StatefulWidget {
  final String location;
  final Widget child;
  final bool focusMode;
  final bool showNavigationChrome;

  const GlobalSystemShellFrame({
    super.key,
    required this.location,
    required this.child,
    this.focusMode = false,
    this.showNavigationChrome = true,
  });

  @override
  State<GlobalSystemShellFrame> createState() => _GlobalSystemShellFrameState();
}

class _GlobalSystemShellFrameState extends State<GlobalSystemShellFrame> {
  static const double _desktopDockBreakpoint = 980;
  static const double _dockReservation = 96;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncShellState();
  }

  @override
  void didUpdateWidget(covariant GlobalSystemShellFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location ||
        oldWidget.focusMode != widget.focusMode) {
      _syncShellState();
    }
  }

  void _syncShellState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context
          .read<GlobalSystemShellController>()
          .updateLocation(widget.location);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!auth.isAuthenticated) {
      return widget.child;
    }
    if (!widget.showNavigationChrome && !widget.focusMode) {
      return widget.child;
    }

    final controller = context.watch<GlobalSystemShellController>();
    final communication = context.watch<CommunicationService>();
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final dashboardManaged = widget.location == AppRoutes.dashboard;
    final showDock = widget.showNavigationChrome &&
        !dashboardManaged &&
        !widget.focusMode &&
        width >= _desktopDockBreakpoint;
    final showAttentionFab = widget.showNavigationChrome &&
        !dashboardManaged &&
        !widget.focusMode &&
        width < _desktopDockBreakpoint;
    final shellNotifications =
        _buildNotifications(context, controller, communication);
    final focusTopInset = widget.focusMode ? 82.0 : 0.0;
    final adjustedMediaQuery = showDock
        ? mediaQuery.copyWith(
            padding: mediaQuery.padding.copyWith(
              bottom: mediaQuery.padding.bottom + _dockReservation,
            ),
          )
        : mediaQuery;

    return MediaQuery(
      data: adjustedMediaQuery,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: focusTopInset),
              child: widget.child,
            ),
          ),
          if (controller.attentionOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: controller.closeAttentionCenter,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  color: Colors.black.withValues(alpha: 0.24),
                ),
              ),
            ),
          if (controller.attentionOpen)
            _GlobalAttentionCenterSheet(
              focusMode: widget.focusMode,
              notifications: shellNotifications,
            ),
          if (showDock)
            Positioned(
              left: 0,
              right: 0,
              bottom: 14,
              child: SafeArea(
                top: false,
                child: Center(
                  child: _GlobalUtilityDock(
                    items: _dockItems(
                      context,
                      controller: controller,
                      notifications: shellNotifications,
                    ),
                  ),
                ),
              ),
            ),
          if (showAttentionFab)
            Positioned(
              right: 16,
              bottom: 18,
              child: SafeArea(
                top: false,
                left: false,
                child: _ShellFloatingAttentionButton(
                  count: shellNotifications.visibleCount,
                  active: controller.attentionOpen,
                  onTap: controller.toggleAttentionCenter,
                ),
              ),
            ),
          if (widget.focusMode)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: SafeArea(
                bottom: false,
                child: _GlobalFocusBar(
                  notificationCount: shellNotifications.visibleCount,
                  hasAttentionOpen: controller.attentionOpen,
                  onAttentionTap: controller.toggleAttentionCenter,
                  onReturn: () => _handleStudioTap(context, controller),
                  canReturn: controller.lastNonStudioLocation != null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  _ShellNotificationBundle _buildNotifications(
    BuildContext context,
    GlobalSystemShellController controller,
    CommunicationService communication,
  ) {
    final theme = Theme.of(context);
    final items = <_ShellNotificationItem>[];
    final channels = [...communication.channels]..sort((left, right) {
        final unread = communication
            .unreadCountForChannel(right.channelId)
            .compareTo(communication.unreadCountForChannel(left.channelId));
        if (unread != 0) {
          return unread;
        }
        final rightStamp = right.lastMessageAt?.millisecondsSinceEpoch ?? 0;
        final leftStamp = left.lastMessageAt?.millisecondsSinceEpoch ?? 0;
        return rightStamp.compareTo(leftStamp);
      });
    final leadChannel = channels.isNotEmpty ? channels.first : null;
    final totalUnread = communication.totalUnreadCount;

    if (totalUnread > 0) {
      final latestStamp =
          leadChannel?.lastMessageAt?.millisecondsSinceEpoch ?? 0;
      items.add(
        _ShellNotificationItem(
          id: 'messages:$totalUnread:$latestStamp',
          category: 'Messages',
          title: '$totalUnread unread right now',
          detail: leadChannel == null
              ? 'Open communication to review staff updates.'
              : '${leadChannel.name} is the busiest thread.',
          actionLabel: 'Open inbox',
          icon: Icons.forum_outlined,
          severity: _ShellNotificationSeverity.attention,
          accent: theme.colorScheme.primary,
          onTap: () {
            controller.closeAttentionCenter();
            context.go(AppRoutes.communication);
          },
        ),
      );
    }

    for (final alert in communication.adminAlertMessages.reversed.take(2)) {
      items.add(
        _ShellNotificationItem(
          id: 'admin:${alert.createdAt.millisecondsSinceEpoch}:${alert.text}',
          category: 'Admin',
          title: alert.text,
          detail: _shellTimeLabel(alert.createdAt),
          actionLabel: 'Open admin',
          icon: _severityIcon(alert.severity),
          severity: switch (alert.severity) {
            CommunicationAlertSeverity.urgent =>
              _ShellNotificationSeverity.urgent,
            CommunicationAlertSeverity.attention =>
              _ShellNotificationSeverity.attention,
            CommunicationAlertSeverity.info => _ShellNotificationSeverity.info,
          },
          accent: _severityColor(theme, alert.severity),
          onTap: () {
            controller.closeAttentionCenter();
            context.go(AppRoutes.admin);
          },
        ),
      );
    }

    final snapshot = controller.workspaceSnapshot;
    if (snapshot != null) {
      final reminders = snapshot.pendingReminders.where((reminder) {
        final today = DateTime.now();
        final start = DateTime(today.year, today.month, today.day);
        final dueDate = DateTime(
          reminder.timestamp.year,
          reminder.timestamp.month,
          reminder.timestamp.day,
        );
        return dueDate.difference(start).inDays <= 7;
      }).take(2);

      for (final reminder in reminders) {
        final now = DateTime.now();
        final daysUntil = DateTime(
          reminder.timestamp.year,
          reminder.timestamp.month,
          reminder.timestamp.day,
        ).difference(DateTime(now.year, now.month, now.day)).inDays;
        final severity = daysUntil <= 1
            ? _ShellNotificationSeverity.urgent
            : _ShellNotificationSeverity.attention;
        items.add(
          _ShellNotificationItem(
            id: 'reminder:${reminder.timestamp.millisecondsSinceEpoch}:${reminder.text}',
            category: 'Schedule',
            title: daysUntil < 0
                ? 'Reminder overdue'
                : daysUntil == 0
                    ? 'Reminder due today'
                    : 'Reminder due ${_monthDay(reminder.timestamp)}',
            detail: reminder.text,
            actionLabel: 'Open dashboard',
            icon: Icons.event_note_outlined,
            severity: severity,
            accent: severity == _ShellNotificationSeverity.urgent
                ? theme.colorScheme.error
                : const Color(0xFFE3A23B),
            onTap: () {
              controller.closeAttentionCenter();
              context.go(AppRoutes.dashboard);
            },
          ),
        );
      }

      if (snapshot.activeClasses.isEmpty) {
        items.add(
          _ShellNotificationItem(
            id: 'classes-empty',
            category: 'Classes',
            title: 'No live classes yet',
            detail:
                'Create your first class space to bring the teacher shell online.',
            actionLabel: 'Open classes',
            icon: Icons.class_outlined,
            severity: _ShellNotificationSeverity.attention,
            accent: theme.colorScheme.tertiary,
            onTap: () {
              controller.closeAttentionCenter();
              context.go(AppRoutes.classes);
            },
          ),
        );
      }
    }

    final visibleItems = controller.visibleNotifications(
      items,
      (item) => item.id,
    );

    return _ShellNotificationBundle(
      items: visibleItems,
      dismissedCount:
          controller.dismissedCountForIds(items.map((item) => item.id)),
      loadingWorkspace: controller.isWorkspaceLoading && snapshot == null,
    );
  }

  List<_GlobalDockItemData> _dockItems(
    BuildContext context, {
    required GlobalSystemShellController controller,
    required _ShellNotificationBundle notifications,
  }) {
    final currentUtility = controller.activeUtility;
    final communication = context.watch<CommunicationService>();

    return [
      _GlobalDockItemData(
        label: 'Alerts',
        icon: Icons.notifications_active_outlined,
        badge: notifications.visibleCount > 0
            ? '${notifications.visibleCount}'
            : null,
        isActive: controller.attentionOpen,
        onTap: controller.toggleAttentionCenter,
      ),
      _GlobalDockItemData(
        label: 'Dashboard',
        icon: Icons.space_dashboard_outlined,
        isActive: currentUtility == GlobalSystemUtility.dashboard,
        onTap: () {
          controller.closeAttentionCenter();
          context.go(AppRoutes.dashboard);
        },
      ),
      _GlobalDockItemData(
        label: 'Classes',
        icon: Icons.class_rounded,
        isActive: currentUtility == GlobalSystemUtility.classes,
        onTap: () {
          controller.closeAttentionCenter();
          context.go(AppRoutes.classes);
        },
      ),
      _GlobalDockItemData(
        label: 'Studio',
        icon: Icons.draw_rounded,
        isActive: currentUtility == GlobalSystemUtility.studio,
        onTap: () => _handleStudioTap(context, controller),
      ),
      _GlobalDockItemData(
        label: 'Messages',
        icon: Icons.forum_outlined,
        badge: communication.totalUnreadCount > 0
            ? '${communication.totalUnreadCount}'
            : null,
        isActive: currentUtility == GlobalSystemUtility.messages,
        onTap: () {
          controller.closeAttentionCenter();
          context.go(AppRoutes.communication);
        },
      ),
      _GlobalDockItemData(
        label: 'Admin',
        icon: Icons.admin_panel_settings_outlined,
        isActive: currentUtility == GlobalSystemUtility.admin,
        onTap: () {
          controller.closeAttentionCenter();
          context.go(AppRoutes.admin);
        },
      ),
    ];
  }

  void _handleStudioTap(
    BuildContext context,
    GlobalSystemShellController controller,
  ) {
    controller.closeAttentionCenter();
    if (widget.location == AppRoutes.whiteboard) {
      context.go(controller.lastNonStudioLocation ?? AppRoutes.dashboard);
      return;
    }
    context.push(AppRoutes.whiteboard);
  }

  IconData _severityIcon(CommunicationAlertSeverity severity) {
    switch (severity) {
      case CommunicationAlertSeverity.urgent:
        return Icons.priority_high_rounded;
      case CommunicationAlertSeverity.attention:
        return Icons.notification_important_outlined;
      case CommunicationAlertSeverity.info:
        return Icons.campaign_outlined;
    }
  }

  Color _severityColor(ThemeData theme, CommunicationAlertSeverity severity) {
    switch (severity) {
      case CommunicationAlertSeverity.urgent:
        return theme.colorScheme.error;
      case CommunicationAlertSeverity.attention:
        return const Color(0xFFE3A23B);
      case CommunicationAlertSeverity.info:
        return theme.colorScheme.primary;
    }
  }

  String _shellTimeLabel(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inMinutes < 1) {
      return 'Just now';
    }
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }
    return _monthDay(timestamp);
  }

  String _monthDay(DateTime timestamp) {
    return '${timestamp.month}/${timestamp.day}';
  }
}

enum _ShellNotificationSeverity {
  urgent,
  attention,
  info,
}

class _ShellNotificationBundle {
  final List<_ShellNotificationItem> items;
  final int dismissedCount;
  final bool loadingWorkspace;

  const _ShellNotificationBundle({
    required this.items,
    required this.dismissedCount,
    required this.loadingWorkspace,
  });

  int get visibleCount => items.length;
}

class _ShellNotificationItem {
  final String id;
  final String category;
  final String title;
  final String detail;
  final String actionLabel;
  final IconData icon;
  final Color accent;
  final _ShellNotificationSeverity severity;
  final VoidCallback onTap;

  const _ShellNotificationItem({
    required this.id,
    required this.category,
    required this.title,
    required this.detail,
    required this.actionLabel,
    required this.icon,
    required this.accent,
    required this.severity,
    required this.onTap,
  });
}

class _GlobalDockItemData {
  final String label;
  final IconData icon;
  final bool isActive;
  final String? badge;
  final VoidCallback onTap;

  const _GlobalDockItemData({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
    this.badge,
  });
}

class _GlobalAttentionCenterSheet extends StatelessWidget {
  final _ShellNotificationBundle notifications;
  final bool focusMode;

  const _GlobalAttentionCenterSheet({
    required this.notifications,
    required this.focusMode,
  });

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GlobalSystemShellController>();
    final width = MediaQuery.sizeOf(context).width;
    final useBottomSheet = width < 860 || focusMode;
    final panelWidth = useBottomSheet ? width - 24 : 400.0;

    return Positioned(
      top: useBottomSheet ? null : 18,
      right: useBottomSheet ? 12 : 18,
      left: useBottomSheet ? 12 : null,
      bottom: useBottomSheet ? 12 : 18,
      child: SafeArea(
        top: !useBottomSheet,
        bottom: true,
        left: useBottomSheet,
        right: true,
        child: Align(
          alignment:
              useBottomSheet ? Alignment.bottomCenter : Alignment.topRight,
          child: SizedBox(
            width: panelWidth,
            height: useBottomSheet ? null : 620,
            child: WorkspaceSurfaceCard(
              padding: const EdgeInsets.all(18),
              radius: 28,
              child: Column(
                mainAxisSize:
                    useBottomSheet ? MainAxisSize.min : MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Attention center',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              notifications.visibleCount == 0
                                  ? 'Messages, admin alerts, and due-soon reminders are quiet.'
                                  : 'A manageable system queue for real teacher signals.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    height: 1.45,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: controller.closeAttentionCenter,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ShellMetaChip(
                        label: notifications.visibleCount == 0
                            ? 'Quiet'
                            : '${notifications.visibleCount} live',
                        icon: Icons.radar_rounded,
                      ),
                      if (notifications.dismissedCount > 0)
                        ActionChip(
                          avatar: const Icon(Icons.history_rounded, size: 16),
                          label: Text(
                            'Restore ${notifications.dismissedCount}',
                          ),
                          onPressed: controller.restoreDismissedNotifications,
                        ),
                      if (notifications.loadingWorkspace)
                        const _ShellMetaChip(
                          label: 'Syncing workspace',
                          icon: Icons.sync_rounded,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (notifications.items.isEmpty)
                    _ShellQuietState(
                      loadingWorkspace: notifications.loadingWorkspace,
                    )
                  else if (useBottomSheet)
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            for (int index = 0;
                                index < notifications.items.length;
                                index++) ...[
                              _ShellNotificationTile(
                                item: notifications.items[index],
                              ),
                              if (index != notifications.items.length - 1)
                                const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            for (int index = 0;
                                index < notifications.items.length;
                                index++) ...[
                              _ShellNotificationTile(
                                item: notifications.items[index],
                              ),
                              if (index != notifications.items.length - 1)
                                const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellNotificationTile extends StatelessWidget {
  final _ShellNotificationItem item;

  const _ShellNotificationTile({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final controller = context.read<GlobalSystemShellController>();
    final theme = Theme.of(context);
    final severityColor = switch (item.severity) {
      _ShellNotificationSeverity.urgent => theme.colorScheme.error,
      _ShellNotificationSeverity.attention => const Color(0xFFE3A23B),
      _ShellNotificationSeverity.info => theme.colorScheme.primary,
    };

    return WorkspaceSurfaceCard(
      padding: const EdgeInsets.all(14),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: item.accent.withValues(alpha: 0.14),
                ),
                child: Icon(item.icon, color: item.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ShellMetaChip(label: item.category),
                        _ShellMetaChip(
                          label: switch (item.severity) {
                            _ShellNotificationSeverity.urgent => 'Urgent',
                            _ShellNotificationSeverity.attention => 'Attention',
                            _ShellNotificationSeverity.info => 'Info',
                          },
                          foreground: severityColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Dismiss',
                onPressed: () => controller.dismissNotification(item.id),
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: item.onTap,
            icon: const Icon(Icons.arrow_outward_rounded, size: 18),
            label: Text(item.actionLabel),
          ),
        ],
      ),
    );
  }
}

class _GlobalUtilityDock extends StatelessWidget {
  final List<_GlobalDockItemData> items;

  const _GlobalUtilityDock({
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return WorkspaceSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 26,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int index = 0; index < items.length; index++) ...[
            _GlobalUtilityDockButton(item: items[index]),
            if (index != items.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _GlobalUtilityDockButton extends StatelessWidget {
  final _GlobalDockItemData item;

  const _GlobalUtilityDockButton({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: item.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: item.isActive
                ? accent.withValues(alpha: 0.18)
                : theme.colorScheme.surface.withValues(alpha: 0.18),
            border: Border.all(
              color: item.isActive
                  ? accent.withValues(alpha: 0.34)
                  : theme.colorScheme.outline.withValues(alpha: 0.32),
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.icon,
                    size: 18,
                    color: item.isActive
                        ? accent
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (item.badge != null && item.badge!.isNotEmpty)
                Positioned(
                  top: -8,
                  right: -10,
                  child: _ShellDockBadge(label: item.badge!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShellFloatingAttentionButton extends StatelessWidget {
  final int count;
  final bool active;
  final VoidCallback onTap;

  const _ShellFloatingAttentionButton({
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onTap,
      backgroundColor: active
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      foregroundColor:
          active ? Colors.white : Theme.of(context).colorScheme.onSurface,
      icon: const Icon(Icons.notifications_active_outlined),
      label: Text(count > 0 ? 'Alerts $count' : 'Alerts'),
    );
  }
}

class _GlobalFocusBar extends StatelessWidget {
  final int notificationCount;
  final bool hasAttentionOpen;
  final VoidCallback onAttentionTap;
  final VoidCallback onReturn;
  final bool canReturn;

  const _GlobalFocusBar({
    required this.notificationCount,
    required this.hasAttentionOpen,
    required this.onAttentionTap,
    required this.onReturn,
    required this.canReturn,
  });

  @override
  Widget build(BuildContext context) {
    return WorkspaceSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 22,
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: canReturn ? onReturn : null,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to workspace'),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onAttentionTap,
            icon: const Icon(Icons.notifications_active_outlined),
            label: Text(
              notificationCount > 0 ? 'Alerts $notificationCount' : 'Alerts',
            ),
          ),
          if (hasAttentionOpen) ...[
            const SizedBox(width: 8),
            const Icon(Icons.remove_red_eye_outlined, size: 18),
          ],
        ],
      ),
    );
  }
}

class _ShellDockBadge extends StatelessWidget {
  final String label;

  const _ShellDockBadge({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.primary,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _ShellMetaChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? foreground;

  const _ShellMetaChip({
    required this.label,
    this.icon,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedForeground =
        foreground ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.24),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: resolvedForeground),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: resolvedForeground,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _ShellQuietState extends StatelessWidget {
  final bool loadingWorkspace;

  const _ShellQuietState({
    required this.loadingWorkspace,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.14),
              ),
              child: Icon(
                loadingWorkspace
                    ? Icons.sync_rounded
                    : Icons.check_circle_outline_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              loadingWorkspace
                  ? 'Syncing teacher workspace'
                  : 'Nothing urgent right now',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              loadingWorkspace
                  ? 'Messages are already live. Class and reminder context will join this queue as soon as the shared workspace snapshot is ready.'
                  : 'Unread communication, admin notices, and due-soon reminders will surface here automatically.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
