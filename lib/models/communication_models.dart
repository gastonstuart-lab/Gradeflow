enum CommunicationRole {
  admin,
  departmentLead,
  teacher,
}

enum CommunicationChannelKind {
  adminAlerts,
  staffRoom,
  department,
  gradeTeam,
  direct,
  sharedFiles,
}

enum CommunicationAlertSeverity {
  info,
  attention,
  urgent,
}

String communicationRoleKey(CommunicationRole role) => role.name;

CommunicationRole communicationRoleFromKey(String? value) {
  return CommunicationRole.values.firstWhere(
    (role) => role.name == value,
    orElse: () => CommunicationRole.teacher,
  );
}

String communicationChannelKindKey(CommunicationChannelKind kind) => kind.name;

CommunicationChannelKind communicationChannelKindFromKey(String? value) {
  return CommunicationChannelKind.values.firstWhere(
    (kind) => kind.name == value,
    orElse: () => CommunicationChannelKind.staffRoom,
  );
}

String communicationAlertSeverityKey(CommunicationAlertSeverity severity) =>
    severity.name;

CommunicationAlertSeverity communicationAlertSeverityFromKey(String? value) {
  return CommunicationAlertSeverity.values.firstWhere(
    (severity) => severity.name == value,
    orElse: () => CommunicationAlertSeverity.info,
  );
}

class CommunicationAlertSeed {
  final String title;
  final DateTime timestamp;
  final String audienceLabel;
  final CommunicationAlertSeverity severity;
  final bool requiresAcknowledgement;

  const CommunicationAlertSeed({
    required this.title,
    required this.timestamp,
    required this.audienceLabel,
    required this.severity,
    this.requiresAcknowledgement = false,
  });
}

class CommunicationChannelPreview {
  final String channelId;
  final String name;
  final CommunicationChannelKind kind;
  final String description;
  final bool readOnly;
  final int unreadCount;
  final int memberCount;
  final String? lastMessagePreview;
  final String? lastSenderName;
  final DateTime? lastMessageAt;

  const CommunicationChannelPreview({
    required this.channelId,
    required this.name,
    required this.kind,
    required this.description,
    this.readOnly = false,
    this.unreadCount = 0,
    this.memberCount = 0,
    this.lastMessagePreview,
    this.lastSenderName,
    this.lastMessageAt,
  });
}

class CommunicationChannelRecord {
  final String channelId;
  final String schoolKey;
  final String name;
  final String description;
  final CommunicationChannelKind kind;
  final bool readOnly;
  final int memberCount;
  final int sortOrder;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastMessagePreview;
  final String? lastSenderName;
  final DateTime? lastMessageAt;

  const CommunicationChannelRecord({
    required this.channelId,
    required this.schoolKey,
    required this.name,
    required this.description,
    required this.kind,
    required this.readOnly,
    required this.memberCount,
    required this.sortOrder,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessagePreview,
    this.lastSenderName,
    this.lastMessageAt,
  });

  Map<String, dynamic> toJson() => {
        'channelId': channelId,
        'schoolKey': schoolKey,
        'name': name,
        'description': description,
        'kind': communicationChannelKindKey(kind),
        'readOnly': readOnly,
        'memberCount': memberCount,
        'sortOrder': sortOrder,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'lastMessagePreview': lastMessagePreview,
        'lastSenderName': lastSenderName,
        'lastMessageAt': lastMessageAt?.toIso8601String(),
      };

  factory CommunicationChannelRecord.fromJson(Map<String, dynamic> json) {
    return CommunicationChannelRecord(
      channelId: json['channelId'] as String,
      schoolKey: json['schoolKey'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      kind: communicationChannelKindFromKey(json['kind'] as String?),
      readOnly: json['readOnly'] as bool? ?? false,
      memberCount: json['memberCount'] as int? ?? 0,
      sortOrder: json['sortOrder'] as int? ?? 0,
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      lastMessagePreview: json['lastMessagePreview'] as String?,
      lastSenderName: json['lastSenderName'] as String?,
      lastMessageAt: json['lastMessageAt'] == null
          ? null
          : DateTime.parse(json['lastMessageAt'] as String),
    );
  }

  CommunicationChannelRecord copyWith({
    String? channelId,
    String? schoolKey,
    String? name,
    String? description,
    CommunicationChannelKind? kind,
    bool? readOnly,
    int? memberCount,
    int? sortOrder,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastMessagePreview,
    String? lastSenderName,
    DateTime? lastMessageAt,
  }) {
    return CommunicationChannelRecord(
      channelId: channelId ?? this.channelId,
      schoolKey: schoolKey ?? this.schoolKey,
      name: name ?? this.name,
      description: description ?? this.description,
      kind: kind ?? this.kind,
      readOnly: readOnly ?? this.readOnly,
      memberCount: memberCount ?? this.memberCount,
      sortOrder: sortOrder ?? this.sortOrder,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      lastSenderName: lastSenderName ?? this.lastSenderName,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    );
  }
}

class CommunicationMessage {
  final String messageId;
  final String channelId;
  final String schoolKey;
  final String authorId;
  final String authorName;
  final CommunicationRole authorRole;
  final String text;
  final DateTime createdAt;
  final bool isAlert;
  final CommunicationAlertSeverity severity;

  const CommunicationMessage({
    required this.messageId,
    required this.channelId,
    required this.schoolKey,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.text,
    required this.createdAt,
    this.isAlert = false,
    this.severity = CommunicationAlertSeverity.info,
  });

  Map<String, dynamic> toJson() => {
        'messageId': messageId,
        'channelId': channelId,
        'schoolKey': schoolKey,
        'authorId': authorId,
        'authorName': authorName,
        'authorRole': communicationRoleKey(authorRole),
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'isAlert': isAlert,
        'severity': communicationAlertSeverityKey(severity),
      };

  factory CommunicationMessage.fromJson(Map<String, dynamic> json) {
    return CommunicationMessage(
      messageId: json['messageId'] as String,
      channelId: json['channelId'] as String,
      schoolKey: json['schoolKey'] as String,
      authorId: json['authorId'] as String,
      authorName: json['authorName'] as String,
      authorRole: communicationRoleFromKey(json['authorRole'] as String?),
      text: json['text'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isAlert: json['isAlert'] as bool? ?? false,
      severity: communicationAlertSeverityFromKey(json['severity'] as String?),
    );
  }
}

class CommunicationDeskCard {
  final String overline;
  final String title;
  final String description;
  final CommunicationChannelKind kind;
  final int unreadCount;
  final List<String> chips;

  const CommunicationDeskCard({
    required this.overline,
    required this.title,
    required this.description,
    required this.kind,
    this.unreadCount = 0,
    this.chips = const [],
  });
}

class CommunicationAnnouncementPreview {
  final String title;
  final String subtitle;
  final CommunicationChannelKind kind;
  final CommunicationAlertSeverity severity;

  const CommunicationAnnouncementPreview({
    required this.title,
    required this.subtitle,
    required this.kind,
    this.severity = CommunicationAlertSeverity.info,
  });
}

class CommunicationWorkspaceContext {
  final String schoolName;
  final String teacherName;
  final String sourceOfTruthLabel;
  final String sourceOfTruthDescription;
  final bool cloudSyncEnabled;
  final int activeClassCount;
  final int totalStudents;
  final int pendingReminderCount;
  final String? focusedClassName;
  final String? focusedDepartmentName;
  final List<CommunicationAlertSeed> schoolAlerts;

  const CommunicationWorkspaceContext({
    required this.schoolName,
    required this.teacherName,
    required this.sourceOfTruthLabel,
    required this.sourceOfTruthDescription,
    required this.cloudSyncEnabled,
    required this.activeClassCount,
    required this.totalStudents,
    required this.pendingReminderCount,
    required this.schoolAlerts,
    this.focusedClassName,
    this.focusedDepartmentName,
  });
}

class CommunicationWorkspaceSnapshot {
  final String railTitle;
  final String railSubtitle;
  final String summaryLabel;
  final String summaryValue;
  final String summaryDetail;
  final int totalUnread;
  final List<CommunicationChannelPreview> channels;
  final List<CommunicationDeskCard> deskCards;
  final List<CommunicationAnnouncementPreview> announcements;

  const CommunicationWorkspaceSnapshot({
    required this.railTitle,
    required this.railSubtitle,
    required this.summaryLabel,
    required this.summaryValue,
    required this.summaryDetail,
    required this.totalUnread,
    required this.channels,
    required this.deskCards,
    required this.announcements,
  });
}
