import 'dart:math' as math;

import 'package:gradeflow/models/communication_models.dart';

class CommunicationWorkspaceService {
  const CommunicationWorkspaceService();

  CommunicationWorkspaceSnapshot buildSnapshot(
    CommunicationWorkspaceContext context,
  ) {
    final departmentName = _departmentName(context);
    final adminAlertCount = context.schoolAlerts.length;
    final teamUnread = context.cloudSyncEnabled
        ? math.min(math.max(context.activeClassCount - 1, 1), 4)
        : 0;
    final directUnread =
        context.cloudSyncEnabled && context.pendingReminderCount > 0 ? 1 : 0;
    final totalUnread = adminAlertCount + teamUnread + directUnread;

    final channels = <CommunicationChannelPreview>[
      CommunicationChannelPreview(
        channelId: 'admin-alerts',
        name: 'Admin alerts',
        kind: CommunicationChannelKind.adminAlerts,
        description:
            'School-wide announcements and urgent operational notices.',
        readOnly: true,
        unreadCount: adminAlertCount,
        memberCount: 6,
      ),
      CommunicationChannelPreview(
        channelId: 'all-staff',
        name: 'All staff',
        kind: CommunicationChannelKind.staffRoom,
        description: 'Daily coordination for staff, cover, and quick updates.',
        unreadCount: teamUnread,
        memberCount: math.max(context.activeClassCount * 3, 12),
      ),
      CommunicationChannelPreview(
        channelId: 'teaching-team',
        name: '$departmentName team',
        kind: CommunicationChannelKind.department,
        description:
            'Department planning, interventions, and shared teaching notes.',
        unreadCount: context.cloudSyncEnabled
            ? math.min(context.activeClassCount, 3)
            : 0,
        memberCount: math.max(context.activeClassCount + 4, 8),
      ),
      CommunicationChannelPreview(
        channelId: 'shared-files',
        name: 'Shared files',
        kind: CommunicationChannelKind.sharedFiles,
        description: 'Pinned resources, follow-ups, and department documents.',
        unreadCount: context.cloudSyncEnabled ? directUnread : 0,
        memberCount: math.max(context.totalStudents > 0 ? 3 : 2, 2),
      ),
    ];

    final deskCards = <CommunicationDeskCard>[
      CommunicationDeskCard(
        overline: 'Admin Broadcasts',
        title: context.schoolAlerts.isNotEmpty
            ? context.schoolAlerts.first.title
            : 'No urgent admin broadcasts',
        description: context.schoolAlerts.isNotEmpty
            ? '$adminAlertCount active alert${adminAlertCount == 1 ? '' : 's'} for staff, cover, deadlines, and school-wide direction.'
            : 'School leaders can use this surface for schedule changes, compliance reminders, and urgent notices.',
        kind: CommunicationChannelKind.adminAlerts,
        unreadCount: adminAlertCount,
        chips: [
          context.schoolName,
          if (context.schoolAlerts
              .any((alert) => alert.requiresAcknowledgement))
            'Ack needed',
          if (context.schoolAlerts.isEmpty) 'Broadcast ready',
        ],
      ),
      CommunicationDeskCard(
        overline: 'Teacher Groups',
        title: context.cloudSyncEnabled
            ? '$departmentName, all-staff, and team channels can stay live.'
            : '$departmentName and staff groups are ready for cloud rollout.',
        description: context.cloudSyncEnabled
            ? 'Keep cover questions, quick planning, and department decisions inside shared staff channels instead of scattered messages.'
            : 'The layout is ready, but real teacher chat should remain cloud-only so unread state and permissions stay reliable.',
        kind: CommunicationChannelKind.department,
        unreadCount: teamUnread,
        chips: [
          '$departmentName team',
          'All staff',
          if (context.focusedClassName != null) context.focusedClassName!,
        ],
      ),
      CommunicationDeskCard(
        overline: 'Shared Resources',
        title: context.cloudSyncEnabled
            ? 'Files, pinned notes, and meeting follow-ups can live with chat.'
            : 'Shared files and pinned resources should activate with the cloud-first communication layer.',
        description: context.cloudSyncEnabled
            ? 'Tie resources to alerts, channels, and direct threads so departments stop losing documents in email chains.'
            : 'Keep academic data hybrid, but make communication documents cloud-first so every teacher sees the same source of truth.',
        kind: CommunicationChannelKind.sharedFiles,
        unreadCount: directUnread,
        chips: [
          context.sourceOfTruthLabel,
          '${context.activeClassCount} classes',
          '${context.totalStudents} students',
        ],
      ),
    ];

    final announcements = <CommunicationAnnouncementPreview>[
      for (final alert in context.schoolAlerts.take(3))
        CommunicationAnnouncementPreview(
          title: alert.title,
          subtitle: '${alert.audienceLabel} - ${_timeLabel(alert.timestamp)}',
          kind: CommunicationChannelKind.adminAlerts,
          severity: alert.severity,
        ),
      CommunicationAnnouncementPreview(
        title: context.cloudSyncEnabled
            ? 'Communication can graduate to live staff channels'
            : 'Cloud sync is required before teacher chat becomes real',
        subtitle: context.sourceOfTruthDescription,
        kind: CommunicationChannelKind.staffRoom,
        severity: context.cloudSyncEnabled
            ? CommunicationAlertSeverity.info
            : CommunicationAlertSeverity.attention,
      ),
      if (context.focusedClassName != null)
        CommunicationAnnouncementPreview(
          title: 'Focused class ready for shared discussion',
          subtitle:
              '${context.focusedClassName} can anchor a department thread, quick staff note, or pinned intervention update.',
          kind: CommunicationChannelKind.department,
        ),
    ];

    final summaryValue = context.schoolAlerts.isNotEmpty
        ? context.schoolAlerts.first.title
        : context.cloudSyncEnabled
            ? '$departmentName channels ready'
            : 'Communication rail ready';

    final summaryDetail = context.schoolAlerts.isNotEmpty
        ? '${context.schoolAlerts.length} admin alert${context.schoolAlerts.length == 1 ? '' : 's'} waiting across staff channels'
        : context.cloudSyncEnabled
            ? '${channels.where((channel) => channel.unreadCount > 0).length} active communication lane${channels.where((channel) => channel.unreadCount > 0).length == 1 ? '' : 's'} for ${context.teacherName}'
            : 'Cloud sync required for real-time groups, direct messages, and file sharing';

    return CommunicationWorkspaceSnapshot(
      railTitle: 'Communication Hub',
      railSubtitle:
          'Admin alerts, staff rooms, and shared school updates stay visible without taking over the teaching workflow.',
      summaryLabel: 'Team Pulse',
      summaryValue: summaryValue,
      summaryDetail: summaryDetail,
      totalUnread: totalUnread,
      channels: channels,
      deskCards: deskCards,
      announcements: announcements.take(4).toList(),
    );
  }

  String _departmentName(CommunicationWorkspaceContext context) {
    final candidate = context.focusedDepartmentName?.trim();
    if (candidate != null && candidate.isNotEmpty) {
      return candidate;
    }
    return 'Teaching';
  }

  String _timeLabel(DateTime timestamp) {
    final date = '${timestamp.month}/${timestamp.day}';
    final hour = timestamp.hour == 0
        ? 12
        : (timestamp.hour > 12 ? timestamp.hour - 12 : timestamp.hour);
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = timestamp.hour >= 12 ? 'PM' : 'AM';
    return '$date at $hour:$minute $period';
  }
}
