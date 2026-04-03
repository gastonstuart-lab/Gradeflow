import 'package:gradeflow/models/communication_models.dart';
import 'package:gradeflow/models/user.dart';

abstract class CommunicationRepository {
  Future<List<CommunicationChannelRecord>> loadChannels({
    required User user,
  });

  Future<List<CommunicationMessage>> loadMessages({
    required User user,
    required String channelId,
    int limit = 40,
  });

  Future<void> ensureDefaultChannels({
    required User user,
  });

  Future<Map<String, DateTime>> loadReadMarkers({
    required User user,
  });

  Future<void> markChannelRead({
    required User user,
    required String channelId,
    required DateTime readAt,
  });

  Future<CommunicationChannelRecord> createChannel({
    required User user,
    required String name,
    required String description,
    required CommunicationChannelKind kind,
  });

  Future<void> sendMessage({
    required User user,
    required CommunicationChannelRecord channel,
    required String text,
    CommunicationRole authorRole,
  });

  Future<void> postAdminAlert({
    required User user,
    required String text,
    required CommunicationAlertSeverity severity,
  });
}

String createCommunicationChannelId(
  String name,
  Iterable<String> existingIds,
) {
  final normalized = _slug(name);
  final base = normalized.isEmpty ? 'staff-group' : normalized;
  final existing = existingIds.toSet();
  var candidate = base;
  var suffix = 2;
  while (existing.contains(candidate)) {
    candidate = '$base-$suffix';
    suffix += 1;
  }
  return candidate;
}

String communicationSchoolKeyForUser(User user) {
  final schoolName = user.schoolName?.trim();
  if (schoolName != null && schoolName.isNotEmpty) {
    return _slug('school-$schoolName');
  }

  final email = user.email.trim().toLowerCase();
  final atIndex = email.indexOf('@');
  if (atIndex != -1) {
    final domain = email.substring(atIndex + 1);
    const personalDomains = {
      'gmail.com',
      'hotmail.com',
      'outlook.com',
      'yahoo.com',
      'icloud.com',
      'live.com',
      'msn.com',
    };
    if (domain.isNotEmpty && !personalDomains.contains(domain)) {
      return _slug('domain-$domain');
    }
  }

  return _slug('user-${user.userId}');
}

List<CommunicationChannelRecord> buildDefaultCommunicationChannels(User user) {
  final now = DateTime.now();
  final schoolKey = communicationSchoolKeyForUser(user);
  final teacherName =
      user.fullName.trim().isEmpty ? 'Teacher' : user.fullName.trim();

  return [
    CommunicationChannelRecord(
      channelId: 'admin-alerts',
      schoolKey: schoolKey,
      name: 'Admin alerts',
      description: 'School-wide announcements and urgent operational notices.',
      kind: CommunicationChannelKind.adminAlerts,
      readOnly: true,
      memberCount: 12,
      sortOrder: 0,
      createdBy: teacherName,
      createdAt: now,
      updatedAt: now,
    ),
    CommunicationChannelRecord(
      channelId: 'all-staff',
      schoolKey: schoolKey,
      name: 'All staff',
      description: 'Daily coordination for staff, cover, and quick updates.',
      kind: CommunicationChannelKind.staffRoom,
      readOnly: false,
      memberCount: 24,
      sortOrder: 1,
      createdBy: teacherName,
      createdAt: now,
      updatedAt: now,
    ),
    CommunicationChannelRecord(
      channelId: 'teaching-team',
      schoolKey: schoolKey,
      name: 'Teaching team',
      description:
          'Department planning, interventions, and shared teaching notes.',
      kind: CommunicationChannelKind.department,
      readOnly: false,
      memberCount: 10,
      sortOrder: 2,
      createdBy: teacherName,
      createdAt: now,
      updatedAt: now,
    ),
    CommunicationChannelRecord(
      channelId: 'shared-files',
      schoolKey: schoolKey,
      name: 'Shared files',
      description: 'Pinned resources, follow-ups, and department documents.',
      kind: CommunicationChannelKind.sharedFiles,
      readOnly: false,
      memberCount: 8,
      sortOrder: 3,
      createdBy: teacherName,
      createdAt: now,
      updatedAt: now,
    ),
  ];
}

List<CommunicationMessage> buildDefaultCommunicationMessages(User user) {
  final schoolKey = communicationSchoolKeyForUser(user);
  final now = DateTime.now();

  CommunicationMessage message({
    required String channelId,
    required String authorName,
    required CommunicationRole role,
    required String text,
    required int minutesAgo,
    bool isAlert = false,
    CommunicationAlertSeverity severity = CommunicationAlertSeverity.info,
  }) {
    final createdAt = now.subtract(Duration(minutes: minutesAgo));
    return CommunicationMessage(
      messageId: '$channelId-$minutesAgo',
      channelId: channelId,
      schoolKey: schoolKey,
      authorId: role == CommunicationRole.admin ? 'admin' : 'system',
      authorName: authorName,
      authorRole: role,
      text: text,
      createdAt: createdAt,
      isAlert: isAlert,
      severity: severity,
    );
  }

  return [
    message(
      channelId: 'admin-alerts',
      authorName: 'School Admin',
      role: CommunicationRole.admin,
      text:
          'Welcome to the shared staff communication space. Use Admin alerts for schedule changes, cover requests, and school-wide notices.',
      minutesAgo: 180,
      isAlert: true,
      severity: CommunicationAlertSeverity.info,
    ),
    message(
      channelId: 'all-staff',
      authorName: 'IEP Team',
      role: CommunicationRole.admin,
      text:
          'All-staff is ready for quick questions, coverage notes, and short daily coordination.',
      minutesAgo: 150,
    ),
    message(
      channelId: 'teaching-team',
      authorName: 'IEP Team',
      role: CommunicationRole.departmentLead,
      text:
          'Teaching team can hold department planning, intervention follow-up, and shared support notes.',
      minutesAgo: 120,
    ),
    message(
      channelId: 'shared-files',
      authorName: 'IEP Team',
      role: CommunicationRole.admin,
      text:
          'Shared files is the right place for pinned resources and follow-up documents once attachments are connected.',
      minutesAgo: 90,
    ),
  ];
}

String _slug(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}
