import 'dart:convert';

import 'package:gradeflow/models/communication_models.dart';
import 'package:gradeflow/models/user.dart';
import 'package:gradeflow/repositories/communication_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class LocalCommunicationRepository implements CommunicationRepository {
  const LocalCommunicationRepository();

  static const Uuid _uuid = Uuid();

  @override
  Future<CommunicationChannelRecord> createChannel({
    required User user,
    required String name,
    required String description,
    required CommunicationChannelKind kind,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final schoolKey = communicationSchoolKeyForUser(user);
    final channels = await loadChannels(user: user);
    final now = DateTime.now();
    final channel = CommunicationChannelRecord(
      channelId: createCommunicationChannelId(
        name,
        channels.map((item) => item.channelId),
      ),
      schoolKey: schoolKey,
      name: name.trim(),
      description: description.trim(),
      kind: kind,
      readOnly: false,
      memberCount: _defaultMemberCountForKind(kind),
      sortOrder: channels.isEmpty
          ? 0
          : channels
                  .map((item) => item.sortOrder)
                  .reduce((a, b) => a > b ? a : b) +
              1,
      createdBy:
          user.fullName.trim().isEmpty ? user.email : user.fullName.trim(),
      createdAt: now,
      updatedAt: now,
    );

    final updatedChannels = [...channels, channel];
    await prefs.setString(
      _channelsKey(schoolKey),
      jsonEncode(updatedChannels.map((item) => item.toJson()).toList()),
    );
    return channel;
  }

  @override
  Future<void> ensureDefaultChannels({
    required User user,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final schoolKey = communicationSchoolKeyForUser(user);
    final channelsKey = _channelsKey(schoolKey);
    final existingChannels = await loadChannels(user: user);
    final mergedChannels = <CommunicationChannelRecord>[
      ...existingChannels,
    ];

    for (final channel in buildDefaultCommunicationChannels(user)) {
      final index = mergedChannels.indexWhere(
        (item) => item.channelId == channel.channelId,
      );
      if (index == -1) {
        mergedChannels.add(channel);
      }
    }

    await prefs.setString(
      channelsKey,
      jsonEncode(mergedChannels.map((channel) => channel.toJson()).toList()),
    );

    final welcomeMessages = buildDefaultCommunicationMessages(user);
    for (final message in welcomeMessages) {
      final messagesKey = _messagesKey(schoolKey, message.channelId);
      final raw = prefs.getString(messagesKey);
      if (raw != null) {
        final decoded = (jsonDecode(raw) as List)
            .cast<Map<String, dynamic>>()
            .toList(growable: false);
        if (decoded.isNotEmpty) {
          continue;
        }
      }

      await prefs.setString(messagesKey, jsonEncode([message.toJson()]));
      await _touchChannel(
        prefs,
        user: user,
        channelId: message.channelId,
        preview: message.text,
        senderName: message.authorName,
        createdAt: message.createdAt,
      );
    }
  }

  @override
  Future<Map<String, DateTime>> loadReadMarkers({
    required User user,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(
      _readMarkersKey(communicationSchoolKeyForUser(user), user.userId),
    );
    if (raw == null || raw.trim().isEmpty) {
      return {};
    }

    final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    return decoded.map(
      (key, value) => MapEntry(key, DateTime.parse(value as String)),
    );
  }

  @override
  Future<void> markChannelRead({
    required User user,
    required String channelId,
    required DateTime readAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadReadMarkers(user: user);
    current[channelId] = readAt;
    await prefs.setString(
      _readMarkersKey(communicationSchoolKeyForUser(user), user.userId),
      jsonEncode(
        current.map(
          (key, value) => MapEntry(key, value.toIso8601String()),
        ),
      ),
    );
  }

  @override
  Future<List<CommunicationChannelRecord>> loadChannels({
    required User user,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw =
        prefs.getString(_channelsKey(communicationSchoolKeyForUser(user)));
    if (raw == null || raw.trim().isEmpty) {
      return [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    final channels = decoded
        .map((item) => CommunicationChannelRecord.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
    channels.sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      if (order != 0) return order;
      final bTime = b.lastMessageAt ?? b.updatedAt;
      final aTime = a.lastMessageAt ?? a.updatedAt;
      return bTime.compareTo(aTime);
    });
    return channels;
  }

  @override
  Future<List<CommunicationMessage>> loadMessages({
    required User user,
    required String channelId,
    int limit = 40,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(
      _messagesKey(communicationSchoolKeyForUser(user), channelId),
    );
    if (raw == null || raw.trim().isEmpty) {
      return [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    final messages = decoded
        .map((item) => CommunicationMessage.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    if (messages.length <= limit) {
      return messages;
    }
    return messages.sublist(messages.length - limit);
  }

  @override
  Future<void> sendMessage({
    required User user,
    required CommunicationChannelRecord channel,
    required String text,
    CommunicationRole authorRole = CommunicationRole.teacher,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final schoolKey = communicationSchoolKeyForUser(user);
    final messages =
        await loadMessages(user: user, channelId: channel.channelId);
    final now = DateTime.now();
    final message = CommunicationMessage(
      messageId: _uuid.v4(),
      channelId: channel.channelId,
      schoolKey: schoolKey,
      authorId: user.userId,
      authorName: user.fullName.trim().isEmpty ? user.email : user.fullName,
      authorRole: authorRole,
      text: text.trim(),
      createdAt: now,
    );
    final updatedMessages = [...messages, message];
    await prefs.setString(
      _messagesKey(schoolKey, channel.channelId),
      jsonEncode(updatedMessages.map((item) => item.toJson()).toList()),
    );
    await _touchChannel(
      prefs,
      user: user,
      channelId: channel.channelId,
      preview: message.text,
      senderName: message.authorName,
      createdAt: now,
    );
  }

  @override
  Future<void> postAdminAlert({
    required User user,
    required String text,
    required CommunicationAlertSeverity severity,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final schoolKey = communicationSchoolKeyForUser(user);
    final now = DateTime.now();
    final messages = await loadMessages(user: user, channelId: 'admin-alerts');
    final message = CommunicationMessage(
      messageId: _uuid.v4(),
      channelId: 'admin-alerts',
      schoolKey: schoolKey,
      authorId: user.userId,
      authorName: user.fullName.trim().isEmpty ? 'School Admin' : user.fullName,
      authorRole: CommunicationRole.admin,
      text: text.trim(),
      createdAt: now,
      isAlert: true,
      severity: severity,
    );
    final updatedMessages = [...messages, message];
    await prefs.setString(
      _messagesKey(schoolKey, 'admin-alerts'),
      jsonEncode(updatedMessages.map((item) => item.toJson()).toList()),
    );
    await _touchChannel(
      prefs,
      user: user,
      channelId: 'admin-alerts',
      preview: message.text,
      senderName: message.authorName,
      createdAt: now,
    );
  }

  Future<void> _touchChannel(
    SharedPreferences prefs, {
    required User user,
    required String channelId,
    required String preview,
    required String senderName,
    required DateTime createdAt,
  }) async {
    final channels = await loadChannels(user: user);
    final index =
        channels.indexWhere((channel) => channel.channelId == channelId);
    if (index == -1) {
      return;
    }

    channels[index] = channels[index].copyWith(
      updatedAt: createdAt,
      lastMessageAt: createdAt,
      lastMessagePreview: preview,
      lastSenderName: senderName,
    );
    await prefs.setString(
      _channelsKey(communicationSchoolKeyForUser(user)),
      jsonEncode(channels.map((channel) => channel.toJson()).toList()),
    );
  }

  String _channelsKey(String schoolKey) =>
      'communication_channels_v1:$schoolKey';

  String _messagesKey(String schoolKey, String channelId) =>
      'communication_messages_v1:$schoolKey:$channelId';

  String _readMarkersKey(String schoolKey, String userId) =>
      'communication_reads_v1:$schoolKey:$userId';

  int _defaultMemberCountForKind(CommunicationChannelKind kind) {
    switch (kind) {
      case CommunicationChannelKind.adminAlerts:
        return 12;
      case CommunicationChannelKind.staffRoom:
        return 18;
      case CommunicationChannelKind.department:
        return 8;
      case CommunicationChannelKind.gradeTeam:
        return 6;
      case CommunicationChannelKind.direct:
        return 2;
      case CommunicationChannelKind.sharedFiles:
        return 5;
    }
  }
}
