// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api

part of '../teacher_dashboard_screen.dart';

enum DashboardNotificationSeverity {
  urgent,
  attention,
  info,
}

class DashboardNotificationCenterData {
  final String headline;
  final String detail;
  final int totalCount;
  final int urgentCount;
  final int dismissedCount;
  final List<DashboardNotificationItemData> items;

  const DashboardNotificationCenterData({
    required this.headline,
    required this.detail,
    required this.totalCount,
    required this.urgentCount,
    required this.dismissedCount,
    required this.items,
  });
}

class DashboardNotificationItemData {
  final String id;
  final String category;
  final String title;
  final String detail;
  final String actionLabel;
  final String? badgeLabel;
  final IconData icon;
  final Color accent;
  final DashboardNotificationSeverity severity;
  final VoidCallback onTap;

  const DashboardNotificationItemData({
    required this.id,
    required this.category,
    required this.title,
    required this.detail,
    required this.actionLabel,
    required this.icon,
    required this.accent,
    required this.severity,
    required this.onTap,
    this.badgeLabel,
  });
}

class DashboardUtilityDockItemData {
  final String label;
  final IconData icon;
  final String? badge;
  final bool isActive;
  final Color accent;
  final VoidCallback onTap;

  const DashboardUtilityDockItemData({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.accent,
    required this.onTap,
    this.badge,
  });
}

extension TeacherDashboardSystemOverlays on _TeacherDashboardScreenState {
  void _toggleNotificationCenter() {
    setState(() => _notificationCenterOpen = !_notificationCenterOpen);
  }

  void _closeNotificationCenter() {
    if (!_notificationCenterOpen) {
      return;
    }
    setState(() => _notificationCenterOpen = false);
  }

  void _runDashboardUtilityAction(VoidCallback action) {
    _closeNotificationCenter();
    action();
  }

  Widget _buildDashboardOperatingSurface(
    BuildContext context, {
    required DateTime now,
    required double width,
    required Widget surface,
  }) {
    final notificationCenter = _dashboardNotificationCenterData(now);
    final useBottomSheet = width < TeacherDashboardShell._mobileBreakpoint;
    // The OS dock owns global navigation; avoid stacking a second dashboard dock.
    final showDashboardUtilityDock = widget.showDashboardUtilityDock &&
        width >= TeacherDashboardShell._mobileBreakpoint;
    final panelWidth = (useBottomSheet
            ? width - 24
            : (width < TeacherDashboardShell._desktopBreakpoint ? 360 : 390))
        .clamp(300.0, 420.0)
        .toDouble();
    final screenHeight = MediaQuery.sizeOf(context).height;
    final panelHeight = (useBottomSheet
            ? screenHeight * 0.72
            : screenHeight - (showDashboardUtilityDock ? 132 : 72))
        .clamp(320.0, 760.0)
        .toDouble();
    final dockItems = showDashboardUtilityDock
        ? _dashboardUtilityDockItems(
            now,
            notificationCenter: notificationCenter,
          )
        : const <DashboardUtilityDockItemData>[];

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: surface),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_notificationCenterOpen,
            child: AnimatedOpacity(
              opacity: _notificationCenterOpen ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeNotificationCenter,
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.24),
                ),
              ),
            ),
          ),
        ),
        if (useBottomSheet)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: panelWidth,
                  height: panelHeight,
                  child: AnimatedSlide(
                    offset: _notificationCenterOpen
                        ? Offset.zero
                        : const Offset(0, 0.12),
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      opacity: _notificationCenterOpen ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: IgnorePointer(
                        ignoring: !_notificationCenterOpen,
                        child: DashboardNotificationCenterPanel(
                          data: notificationCenter,
                          onDismiss: _closeNotificationCenter,
                          onRestoreDismissed:
                              notificationCenter.dismissedCount > 0
                                  ? () => context
                                      .read<GlobalSystemShellController>()
                                      .restoreDismissedNotifications()
                                  : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
        else
          Positioned(
            top: 18,
            right: 18,
            bottom: showDashboardUtilityDock ? 104 : 18,
            child: SafeArea(
              left: false,
              bottom: false,
              child: Align(
                alignment: Alignment.topRight,
                child: SizedBox(
                  width: panelWidth,
                  height: panelHeight,
                  child: AnimatedSlide(
                    offset: _notificationCenterOpen
                        ? Offset.zero
                        : const Offset(0.1, 0),
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      opacity: _notificationCenterOpen ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: IgnorePointer(
                        ignoring: !_notificationCenterOpen,
                        child: DashboardNotificationCenterPanel(
                          data: notificationCenter,
                          onDismiss: _closeNotificationCenter,
                          onRestoreDismissed:
                              notificationCenter.dismissedCount > 0
                                  ? () => context
                                      .read<GlobalSystemShellController>()
                                      .restoreDismissedNotifications()
                                  : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (showDashboardUtilityDock)
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: DashboardUtilityDock(
                  items: dockItems,
                  compact: width < TeacherDashboardShell._desktopBreakpoint,
                ),
              ),
            ),
          ),
      ],
    );
  }

  DashboardNotificationCenterData _dashboardNotificationCenterData(
    DateTime now,
  ) {
    final shellController = context.watch<GlobalSystemShellController>();
    final communication = _communicationWorkspaceSnapshot(now);
    final items = <DashboardNotificationItemData>[];
    final messageChannels = [...communication.channels]..sort((left, right) {
        final unread = right.unreadCount.compareTo(left.unreadCount);
        if (unread != 0) {
          return unread;
        }
        final rightStamp = right.lastMessageAt?.millisecondsSinceEpoch ?? 0;
        final leftStamp = left.lastMessageAt?.millisecondsSinceEpoch ?? 0;
        return rightStamp.compareTo(leftStamp);
      });
    final activeMessageChannels = messageChannels
        .where((channel) => channel.unreadCount > 0)
        .toList(growable: false);

    if (communication.totalUnread > 0) {
      final leadChannel = activeMessageChannels.isNotEmpty
          ? activeMessageChannels.first
          : (messageChannels.isNotEmpty ? messageChannels.first : null);
      final activeCount =
          activeMessageChannels.isEmpty ? 1 : activeMessageChannels.length;
      items.add(
        DashboardNotificationItemData(
          id: 'messages-summary',
          category: 'Messages',
          title:
              '${communication.totalUnread} unread across $activeCount channel${activeCount == 1 ? '' : 's'}',
          detail: leadChannel != null
              ? _dashboardCommunicationPreview(leadChannel)
              : 'Open communication to review staff updates.',
          actionLabel: 'Open inbox',
          badgeLabel: _compactBadgeCount(communication.totalUnread),
          icon: Icons.forum_outlined,
          accent: leadChannel != null
              ? _dashboardCommunicationAccent(leadChannel.kind)
              : _DashboardPalette.accent,
          severity: activeMessageChannels.any(
            (channel) => channel.kind == CommunicationChannelKind.adminAlerts,
          )
              ? DashboardNotificationSeverity.urgent
              : DashboardNotificationSeverity.attention,
          onTap: () => _runDashboardUtilityAction(
            () => context.go(AppRoutes.communication),
          ),
        ),
      );
    }

    for (final announcement in communication.announcements
        .where(
          (item) =>
              item.kind == CommunicationChannelKind.adminAlerts ||
              item.severity != CommunicationAlertSeverity.info,
        )
        .take(2)) {
      final isAdmin = announcement.kind == CommunicationChannelKind.adminAlerts;
      items.add(
        DashboardNotificationItemData(
          id: 'announcement-${announcement.title}',
          category: isAdmin ? 'Admin' : 'Notice',
          title: _headlineSafe(announcement.title, maxLength: 56),
          detail: _headlineSafe(announcement.subtitle, maxLength: 68),
          actionLabel: isAdmin ? 'Open admin' : 'Open comms',
          icon: _communicationAnnouncementIcon(
            announcement.kind,
            announcement.severity,
          ),
          accent: _communicationSeverityAccent(announcement.severity),
          severity: _notificationSeverityForCommunication(
            announcement.severity,
          ),
          onTap: () => _runDashboardUtilityAction(
            isAdmin
                ? () => context.go(AppRoutes.admin)
                : () => context.go(AppRoutes.communication),
          ),
        ),
      );
    }

    final classHealthItems = <DashboardNotificationItemData>[];
    for (final classBrief in _classes) {
      final health = _classHealthFor(classBrief, now);
      if (health.level == ClassHealthLevel.ready) {
        continue;
      }
      final action = _dashboardActionForHealth(
        context,
        classBrief,
        health.primaryAction,
      );
      classHealthItems.add(
        DashboardNotificationItemData(
          id: 'class-${classBrief.id}',
          category: 'Class health',
          title: classBrief.name,
          detail: _headlineSafe(health.primaryReason, maxLength: 68),
          actionLabel: action.label,
          badgeLabel: health.levelLabel,
          icon: _healthStatusIcon(health),
          accent: _classHealthAccent(health.level),
          severity: _notificationSeverityForClassHealth(health.level),
          onTap: () => _runDashboardUtilityAction(() {
            _focusClass(classBrief.id);
            action.onTap();
          }),
        ),
      );
    }
    classHealthItems.sort((left, right) {
      final severity = _notificationSeverityRank(right.severity)
          .compareTo(_notificationSeverityRank(left.severity));
      if (severity != 0) {
        return severity;
      }
      final leftFocused = left.id == 'class-${_selectedClassId ?? ''}' ? 1 : 0;
      final rightFocused =
          right.id == 'class-${_selectedClassId ?? ''}' ? 1 : 0;
      return rightFocused.compareTo(leftFocused);
    });
    items.addAll(classHealthItems.take(3));

    final reminderItems = <DashboardNotificationItemData>[];
    for (final reminder in _pendingReminders()) {
      final dueDate = DateTime(
        reminder.timestamp.year,
        reminder.timestamp.month,
        reminder.timestamp.day,
      );
      final today = DateTime(now.year, now.month, now.day);
      final daysUntil = dueDate.difference(today).inDays;
      if (daysUntil > 7) {
        continue;
      }
      final severity = daysUntil <= 1
          ? DashboardNotificationSeverity.urgent
          : DashboardNotificationSeverity.attention;
      reminderItems.add(
        DashboardNotificationItemData(
          id: 'reminder-${reminder.timestamp.millisecondsSinceEpoch}-${reminder.text}',
          category: 'Schedule',
          title: daysUntil < 0
              ? 'Reminder overdue'
              : daysUntil == 0
                  ? 'Reminder due today'
                  : 'Reminder due ${_shortMonthDay(reminder.timestamp)}',
          detail: _headlineSafe(reminder.text, maxLength: 68),
          actionLabel: 'Open schedule',
          badgeLabel: _isSchoolWideReminder(reminder) ? 'School' : 'Class',
          icon: daysUntil < 0
              ? Icons.error_outline_rounded
              : Icons.event_note_outlined,
          accent: severity == DashboardNotificationSeverity.urgent
              ? _DashboardPalette.coral
              : _DashboardPalette.amber,
          severity: severity,
          onTap: () => _runDashboardUtilityAction(
            () => unawaited(
              _openDashboardSection(
                DashboardWorkspaceSection.planning,
                focusKey: _planningSectionKey,
              ),
            ),
          ),
        ),
      );
    }
    items.addAll(reminderItems.take(2));

    items.sort((left, right) {
      final severity = _notificationSeverityRank(right.severity)
          .compareTo(_notificationSeverityRank(left.severity));
      if (severity != 0) {
        return severity;
      }
      return left.category.compareTo(right.category);
    });

    final visibleItems = shellController.visibleNotifications(
      items,
      (item) => item.id,
    );

    final urgentCount = visibleItems
        .where((item) => item.severity == DashboardNotificationSeverity.urgent)
        .length;
    final headline = visibleItems.isEmpty
        ? 'All clear'
        : urgentCount > 0
            ? '$urgentCount urgent'
            : '${visibleItems.length} to review';
    final detail = visibleItems.isEmpty
        ? 'Messages, class health, reminders, and notices are quiet.'
        : 'One place for messages, class health, reminders, and notices.';

    return DashboardNotificationCenterData(
      headline: headline,
      detail: detail,
      totalCount: visibleItems.length,
      urgentCount: urgentCount,
      dismissedCount:
          shellController.dismissedCountForIds(items.map((item) => item.id)),
      items: visibleItems,
    );
  }

  List<DashboardUtilityDockItemData> _dashboardUtilityDockItems(
    DateTime now, {
    required DashboardNotificationCenterData notificationCenter,
  }) {
    final communication = _communicationWorkspaceSnapshot(now);
    final classSignals = _classes.where((classBrief) {
      return _classHealthFor(classBrief, now).level != ClassHealthLevel.ready;
    }).length;
    final scheduleSignals = _pendingReminders().where((reminder) {
      final dueDate = DateTime(
        reminder.timestamp.year,
        reminder.timestamp.month,
        reminder.timestamp.day,
      );
      final today = DateTime(now.year, now.month, now.day);
      return dueDate.difference(today).inDays <= 7;
    }).length;

    return [
      DashboardUtilityDockItemData(
        label: 'Alerts',
        icon: Icons.notifications_active_outlined,
        badge: notificationCenter.totalCount > 0
            ? _compactBadgeCount(notificationCenter.totalCount)
            : null,
        isActive: _notificationCenterOpen,
        accent: _notificationCenterOpen
            ? _DashboardPalette.coral
            : _DashboardPalette.accent,
        onTap: _toggleNotificationCenter,
      ),
      DashboardUtilityDockItemData(
        label: 'Overview',
        icon: Icons.space_dashboard_outlined,
        badge: classSignals > 0 ? _compactBadgeCount(classSignals) : null,
        isActive: !_notificationCenterOpen &&
            _workspaceSection == DashboardWorkspaceSection.today,
        accent: _DashboardPalette.accent,
        onTap: () => _runDashboardUtilityAction(
          () => unawaited(
            _openDashboardSection(
              DashboardWorkspaceSection.today,
              focusKey: _classStatusSectionKey,
            ),
          ),
        ),
      ),
      DashboardUtilityDockItemData(
        label: 'Class tools',
        icon: Icons.widgets_outlined,
        isActive: !_notificationCenterOpen &&
            _workspaceSection == DashboardWorkspaceSection.classroom,
        accent: _DashboardPalette.amber,
        onTap: () => _runDashboardUtilityAction(
          () => unawaited(
            _openDashboardSection(
              DashboardWorkspaceSection.classroom,
              focusKey: _classToolsSectionKey,
            ),
          ),
        ),
      ),
      DashboardUtilityDockItemData(
        label: 'Schedule',
        icon: Icons.event_note_outlined,
        badge: scheduleSignals > 0 ? _compactBadgeCount(scheduleSignals) : null,
        isActive: !_notificationCenterOpen &&
            _workspaceSection == DashboardWorkspaceSection.planning,
        accent: _DashboardPalette.green,
        onTap: () => _runDashboardUtilityAction(
          () => unawaited(
            _openDashboardSection(
              DashboardWorkspaceSection.planning,
              focusKey: _planningSectionKey,
            ),
          ),
        ),
      ),
      DashboardUtilityDockItemData(
        label: 'Messages',
        icon: Icons.forum_outlined,
        badge: communication.totalUnread > 0
            ? _compactBadgeCount(communication.totalUnread)
            : null,
        isActive: false,
        accent: _DashboardPalette.cyan,
        onTap: () => _runDashboardUtilityAction(
          () => context.go(AppRoutes.communication),
        ),
      ),
    ];
  }

  DashboardNotificationSeverity _notificationSeverityForCommunication(
    CommunicationAlertSeverity severity,
  ) {
    switch (severity) {
      case CommunicationAlertSeverity.urgent:
        return DashboardNotificationSeverity.urgent;
      case CommunicationAlertSeverity.attention:
        return DashboardNotificationSeverity.attention;
      case CommunicationAlertSeverity.info:
        return DashboardNotificationSeverity.info;
    }
  }

  DashboardNotificationSeverity _notificationSeverityForClassHealth(
    ClassHealthLevel level,
  ) {
    switch (level) {
      case ClassHealthLevel.urgent:
        return DashboardNotificationSeverity.urgent;
      case ClassHealthLevel.attention:
        return DashboardNotificationSeverity.attention;
      case ClassHealthLevel.ready:
        return DashboardNotificationSeverity.info;
    }
  }

  int _notificationSeverityRank(DashboardNotificationSeverity severity) {
    switch (severity) {
      case DashboardNotificationSeverity.urgent:
        return 3;
      case DashboardNotificationSeverity.attention:
        return 2;
      case DashboardNotificationSeverity.info:
        return 1;
    }
  }

  Color _classHealthAccent(ClassHealthLevel level) {
    switch (level) {
      case ClassHealthLevel.ready:
        return _DashboardPalette.green;
      case ClassHealthLevel.attention:
        return _DashboardPalette.amber;
      case ClassHealthLevel.urgent:
        return _DashboardPalette.coral;
    }
  }

  String _compactBadgeCount(int count) {
    if (count <= 0) {
      return '';
    }
    if (count > 99) {
      return '99+';
    }
    return '$count';
  }
}

class _DashboardHeaderUtilityButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final String? badge;

  const _DashboardHeaderUtilityButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final showBadge = badge != null && badge!.isNotEmpty;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: label,
          onPressed: onPressed,
          icon: Icon(icon),
        ),
        if (showBadge)
          Positioned(
            top: -2,
            right: -2,
            child: _DashboardCountBadge(
              label: badge!,
              accent: _DashboardPalette.coral,
            ),
          ),
      ],
    );
  }
}

class _DashboardCountBadge extends StatelessWidget {
  final String label;
  final Color accent;
  final Color? foregroundColor;

  const _DashboardCountBadge({
    required this.label,
    required this.accent,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedForeground = foregroundColor ?? Colors.white;
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: accent,
        border: Border.all(
          color: accent.withValues(alpha: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: resolvedForeground,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class DashboardNotificationCenterPanel extends StatelessWidget {
  final DashboardNotificationCenterData data;
  final VoidCallback onDismiss;
  final VoidCallback? onRestoreDismissed;

  const DashboardNotificationCenterPanel({
    super.key,
    required this.data,
    required this.onDismiss,
    this.onRestoreDismissed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DashboardPanelCard(
        radius: 30,
        padding: const EdgeInsets.all(18),
        expandChild: true,
        gradientColors: [
          _DashboardPalette.panelElevated,
          _DashboardPalette.panel,
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _DashboardSectionTag(
                        label: 'Attention center',
                        icon: Icons.notifications_active_outlined,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        data.headline,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        data.detail,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _DashboardPalette.textSecondary,
                              height: 1.45,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (data.totalCount > 0)
                      _DashboardCountBadge(
                        label: '${data.totalCount}',
                        accent: data.urgentCount > 0
                            ? _DashboardPalette.coral
                            : _DashboardPalette.accent,
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: onDismiss,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DashboardSectionTag(
                  label: data.items.isEmpty
                      ? 'Quiet'
                      : '${data.items.length} live item${data.items.length == 1 ? '' : 's'}',
                  icon: Icons.radar_rounded,
                  foregroundColor: _DashboardPalette.accentSoft,
                  backgroundColor:
                      _DashboardPalette.accent.withValues(alpha: 0.10),
                  borderColor: _DashboardPalette.accent.withValues(alpha: 0.18),
                ),
                if (data.urgentCount > 0)
                  _DashboardSectionTag(
                    label: '${data.urgentCount} urgent',
                    icon: Icons.priority_high_rounded,
                    foregroundColor: _DashboardPalette.coral,
                    backgroundColor:
                        _DashboardPalette.coral.withValues(alpha: 0.10),
                    borderColor:
                        _DashboardPalette.coral.withValues(alpha: 0.18),
                  ),
                if (data.dismissedCount > 0)
                  ActionChip(
                    avatar: const Icon(Icons.history_rounded, size: 16),
                    label: Text('Restore ${data.dismissedCount}'),
                    onPressed: onRestoreDismissed,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: data.items.isEmpty
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: Colors.white.withValues(alpha: 0.03),
                          border: Border.all(
                            color: _DashboardPalette.border
                                .withValues(alpha: 0.74),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                color: _DashboardPalette.green
                                    .withValues(alpha: 0.14),
                                border: Border.all(
                                  color: _DashboardPalette.green
                                      .withValues(alpha: 0.22),
                                ),
                              ),
                              child: Icon(
                                Icons.check_circle_outline_rounded,
                                color: _DashboardPalette.green,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Nothing urgent right now.',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Unread communication, class-health issues, reminders, and notices will appear here.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: _DashboardPalette.textSecondary,
                                    height: 1.45,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          for (int index = 0;
                              index < data.items.length;
                              index++) ...[
                            _DashboardNotificationTile(item: data.items[index]),
                            if (index != data.items.length - 1)
                              const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardNotificationTile extends StatelessWidget {
  final DashboardNotificationItemData item;

  const _DashboardNotificationTile({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final shellController = context.read<GlobalSystemShellController>();
    final severityColor = switch (item.severity) {
      DashboardNotificationSeverity.urgent => _DashboardPalette.coral,
      DashboardNotificationSeverity.attention => _DashboardPalette.amber,
      DashboardNotificationSeverity.info => _DashboardPalette.accent,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: item.onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                item.accent.withValues(alpha: 0.12),
                Colors.white.withValues(alpha: 0.03),
              ],
            ),
            border: Border.all(
              color: item.accent.withValues(alpha: 0.22),
            ),
          ),
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
                      color: item.accent.withValues(alpha: 0.16),
                      border: Border.all(
                        color: item.accent.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Icon(
                      item.icon,
                      color: item.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _DashboardSectionTag(
                              label: item.category,
                              foregroundColor: _DashboardPalette.textSecondary,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.04),
                              borderColor: _DashboardPalette.border
                                  .withValues(alpha: 0.72),
                            ),
                            _DashboardSectionTag(
                              label: switch (item.severity) {
                                DashboardNotificationSeverity.urgent =>
                                  'Urgent',
                                DashboardNotificationSeverity.attention =>
                                  'Attention',
                                DashboardNotificationSeverity.info => 'Info',
                              },
                              foregroundColor: severityColor,
                              backgroundColor:
                                  severityColor.withValues(alpha: 0.12),
                              borderColor:
                                  severityColor.withValues(alpha: 0.18),
                            ),
                            if (item.badgeLabel != null &&
                                item.badgeLabel!.isNotEmpty)
                              _DashboardSectionTag(
                                label: item.badgeLabel!,
                                foregroundColor: item.accent,
                                backgroundColor:
                                    item.accent.withValues(alpha: 0.12),
                                borderColor:
                                    item.accent.withValues(alpha: 0.18),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.detail,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: _DashboardPalette.textSecondary,
                                    height: 1.45,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Dismiss',
                    onPressed: () =>
                        shellController.dismissNotification(item.id),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withValues(alpha: 0.04),
                  border: Border.all(
                    color: _DashboardPalette.border.withValues(alpha: 0.78),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.actionLabel,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: _DashboardPalette.textSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardUtilityDock extends StatelessWidget {
  final List<DashboardUtilityDockItemData> items;
  final bool compact;

  const DashboardUtilityDock({
    super.key,
    required this.items,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border:
            Border.all(color: _DashboardPalette.border.withValues(alpha: 0.9)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _DashboardPalette.panelElevated.withValues(alpha: 0.94),
            _DashboardPalette.panel.withValues(alpha: 0.88),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int index = 0; index < items.length; index++) ...[
            _DashboardDockButton(
              item: items[index],
              compact: compact,
            ),
            if (index != items.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _DashboardDockButton extends StatelessWidget {
  final DashboardUtilityDockItemData item;
  final bool compact;

  const _DashboardDockButton({
    required this.item,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final foreground =
        item.isActive ? Colors.white : _DashboardPalette.textSecondary;
    final iconColor = item.isActive ? Colors.white : item.accent;

    return Tooltip(
      message:
          item.badge == null ? item.label : '${item.label} (${item.badge})',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: item.onTap,
          child: Container(
            constraints: BoxConstraints(minWidth: compact ? 88 : 98),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: item.isActive
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        item.accent.withValues(alpha: 0.95),
                        item.accent.withValues(alpha: 0.72),
                      ],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.05),
                        Colors.white.withValues(alpha: 0.02),
                      ],
                    ),
              border: Border.all(
                color: item.isActive
                    ? item.accent.withValues(alpha: 0.28)
                    : _DashboardPalette.border.withValues(alpha: 0.82),
              ),
              boxShadow: item.isActive
                  ? [
                      BoxShadow(
                        color: item.accent.withValues(alpha: 0.22),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.icon, size: 18, color: iconColor),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: foreground,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
                if (item.badge != null && item.badge!.isNotEmpty)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: _DashboardCountBadge(
                      label: item.badge!,
                      accent: item.isActive ? Colors.white : item.accent,
                      foregroundColor: item.isActive ? item.accent : null,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
