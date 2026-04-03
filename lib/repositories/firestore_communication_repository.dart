import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gradeflow/models/communication_models.dart';
import 'package:gradeflow/models/user.dart';
import 'package:gradeflow/repositories/communication_repository.dart';
import 'package:uuid/uuid.dart';

class FirestoreCommunicationRepository implements CommunicationRepository {
  FirestoreCommunicationRepository();

  static const Uuid _uuid = Uuid();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<void> ensureDefaultChannels({
    required User user,
  }) async {
    final batch = _firestore.batch();
    final channels = buildDefaultCommunicationChannels(user);
    for (final channel in channels) {
      batch.set(
        _channelDoc(channel.schoolKey, channel.channelId),
        _channelToFirestore(channel),
        SetOptions(merge: true),
      );
    }
    await batch.commit();

    for (final message in buildDefaultCommunicationMessages(user)) {
      final messagesCollection =
          _messagesCollection(message.schoolKey, message.channelId);
      final existing = await messagesCollection.limit(1).get();
      if (existing.docs.isNotEmpty) {
        continue;
      }
      final doc = messagesCollection.doc(message.messageId);
      await doc.set(_messageToFirestore(message));
      await _channelDoc(message.schoolKey, message.channelId).set(
        {
          'lastMessagePreview': message.text,
          'lastSenderName': message.authorName,
          'lastMessageAt': Timestamp.fromDate(message.createdAt),
          'updatedAt': Timestamp.fromDate(message.createdAt),
        },
        SetOptions(merge: true),
      );
    }
  }

  @override
  Future<List<CommunicationChannelRecord>> loadChannels({
    required User user,
  }) async {
    final schoolKey = communicationSchoolKeyForUser(user);
    final snapshot = await _firestore
        .collection(_channelsPath(schoolKey))
        .orderBy('sortOrder')
        .get();
    final channels = snapshot.docs
        .map((doc) => _channelFromFirestore(doc.data()))
        .toList(growable: false);
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
    final schoolKey = communicationSchoolKeyForUser(user);
    final snapshot = await _messagesCollection(schoolKey, channelId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    final messages = snapshot.docs
        .map((doc) => _messageFromFirestore(doc.data()))
        .toList(growable: false)
        .reversed
        .toList(growable: false);
    return messages;
  }

  @override
  Future<void> sendMessage({
    required User user,
    required CommunicationChannelRecord channel,
    required String text,
    CommunicationRole authorRole = CommunicationRole.teacher,
  }) async {
    final schoolKey = communicationSchoolKeyForUser(user);
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

    await _messagesCollection(schoolKey, channel.channelId)
        .doc(message.messageId)
        .set(_messageToFirestore(message));
    await _channelDoc(schoolKey, channel.channelId).set(
      {
        'lastMessagePreview': message.text,
        'lastSenderName': message.authorName,
        'lastMessageAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> postAdminAlert({
    required User user,
    required String text,
    required CommunicationAlertSeverity severity,
  }) async {
    final schoolKey = communicationSchoolKeyForUser(user);
    final now = DateTime.now();
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

    await _messagesCollection(schoolKey, 'admin-alerts')
        .doc(message.messageId)
        .set(_messageToFirestore(message));
    await _channelDoc(schoolKey, 'admin-alerts').set(
      {
        'lastMessagePreview': message.text,
        'lastSenderName': message.authorName,
        'lastMessageAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      },
      SetOptions(merge: true),
    );
  }

  String _channelsPath(String schoolKey) =>
      'schools/$schoolKey/communicationChannels';

  DocumentReference<Map<String, dynamic>> _channelDoc(
    String schoolKey,
    String channelId,
  ) {
    return _firestore.collection(_channelsPath(schoolKey)).doc(channelId);
  }

  CollectionReference<Map<String, dynamic>> _messagesCollection(
    String schoolKey,
    String channelId,
  ) {
    return _channelDoc(schoolKey, channelId).collection('messages');
  }

  Map<String, dynamic> _channelToFirestore(CommunicationChannelRecord channel) {
    return {
      'channelId': channel.channelId,
      'schoolKey': channel.schoolKey,
      'name': channel.name,
      'description': channel.description,
      'kind': communicationChannelKindKey(channel.kind),
      'readOnly': channel.readOnly,
      'memberCount': channel.memberCount,
      'sortOrder': channel.sortOrder,
      'createdBy': channel.createdBy,
      'createdAt': Timestamp.fromDate(channel.createdAt),
      'updatedAt': Timestamp.fromDate(channel.updatedAt),
      'lastMessagePreview': channel.lastMessagePreview,
      'lastSenderName': channel.lastSenderName,
      'lastMessageAt': channel.lastMessageAt == null
          ? null
          : Timestamp.fromDate(channel.lastMessageAt!),
    };
  }

  CommunicationChannelRecord _channelFromFirestore(Map<String, dynamic> data) {
    return CommunicationChannelRecord(
      channelId: data['channelId'] as String,
      schoolKey: data['schoolKey'] as String,
      name: data['name'] as String,
      description: data['description'] as String? ?? '',
      kind: communicationChannelKindFromKey(data['kind'] as String?),
      readOnly: data['readOnly'] as bool? ?? false,
      memberCount: data['memberCount'] as int? ?? 0,
      sortOrder: data['sortOrder'] as int? ?? 0,
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessagePreview: data['lastMessagePreview'] as String?,
      lastSenderName: data['lastSenderName'] as String?,
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> _messageToFirestore(CommunicationMessage message) {
    return {
      'messageId': message.messageId,
      'channelId': message.channelId,
      'schoolKey': message.schoolKey,
      'authorId': message.authorId,
      'authorName': message.authorName,
      'authorRole': communicationRoleKey(message.authorRole),
      'text': message.text,
      'createdAt': Timestamp.fromDate(message.createdAt),
      'isAlert': message.isAlert,
      'severity': communicationAlertSeverityKey(message.severity),
    };
  }

  CommunicationMessage _messageFromFirestore(Map<String, dynamic> data) {
    return CommunicationMessage(
      messageId: data['messageId'] as String,
      channelId: data['channelId'] as String,
      schoolKey: data['schoolKey'] as String,
      authorId: data['authorId'] as String,
      authorName: data['authorName'] as String,
      authorRole: communicationRoleFromKey(data['authorRole'] as String?),
      text: data['text'] as String,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isAlert: data['isAlert'] as bool? ?? false,
      severity: communicationAlertSeverityFromKey(data['severity'] as String?),
    );
  }
}
