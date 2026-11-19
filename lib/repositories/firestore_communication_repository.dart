import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gradeflow/models/communication_models.dart';
import 'package:gradeflow/models/user.dart';
import 'package:gradeflow/repositories/communication_repository.dart';
import 'package:uuid/uuid.dart';
import 'package:gradeflow/models/communication_access.dart';
import 'package:gradeflow/config/gradeflow_existing_project_preview.dart';

class FirestoreCommunicationRepository implements CommunicationRepository {
  FirestoreCommunicationRepository();

  static const Uuid _uuid = Uuid();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<CommunicationChannelRecord> createChannel({
    required User user,
    required String name,
    required String description,
    required CommunicationChannelKind kind,
  }) async {
    throw StateError(
      'Shared channels are provisioned by your school administrator.',
    );
  }

  @override
  Future<void> ensureDefaultChannels({required User user}) async {
    // Cloud startup must never seed sample channels or impersonated messages.
  }

  Future<CommunicationAccess> _access(User user) async {
    final doc = await _firestore
        .collection('communicationAccess')
        .doc(user.userId)
        .get(const GetOptions(source: Source.server));
    return CommunicationAccess.fromData(doc.data());
  }

  void _requireWrites() {
    if (GradeFlowExistingProjectPreview.enabled) {
      throw StateError('This review preview cannot send shared messages.');
    }
  }

  @override
  Future<Map<String, DateTime>> loadReadMarkers({required User user}) async {
    final access = await _access(user);
    final schoolKey = access.schoolKey;
    final snapshot = await _readMarkersCollection(
      user.userId,
    ).where('schoolKey', isEqualTo: schoolKey).get();
    return {
      for (final doc in snapshot.docs)
        (doc.data()['channelId'] as String? ?? doc.id):
            (doc.data()['readAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    };
  }

  @override
  Future<void> markChannelRead({
    required User user,
    required String channelId,
    required DateTime readAt,
  }) async {
    if (GradeFlowExistingProjectPreview.enabled) return;
    final access = await _access(user);
    access.requireChannel(channelId);
    final schoolKey = access.schoolKey;
    await _readMarkersCollection(
      user.userId,
    ).doc(_readMarkerDocId(schoolKey, channelId)).set({
      'channelId': channelId,
      'schoolKey': schoolKey,
      'readAt': Timestamp.fromDate(readAt),
      'updatedBy': user.userId,
    }, SetOptions(merge: true));
  }

  @override
  Future<List<CommunicationChannelRecord>> loadChannels({
    required User user,
  }) async {
    final access = await _access(user);
    final schoolKey = access.schoolKey;
    final channels = <CommunicationChannelRecord>[];
    // Query only administrator-granted document IDs; rules never filter a broad list.
    for (var offset = 0; offset < access.channelIds.length; offset += 10) {
      final ids = access.channelIds.skip(offset).take(10).toList();
      final snapshot = await _firestore
          .collection(_channelsPath(schoolKey))
          .where(FieldPath.documentId, whereIn: ids)
          .limit(10)
          .get(const GetOptions(source: Source.server));
      channels.addAll(
        snapshot.docs.map((doc) => _channelFromFirestore(doc.data())),
      );
    }
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
    final access = await _access(user);
    final schoolKey = access.schoolKey;
    access.requireChannel(channelId);
    if (limit < 1 || limit > 100)
      throw RangeError.range(limit, 1, 100, 'limit');
    final snapshot = await _messagesCollection(schoolKey, channelId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get(const GetOptions(source: Source.server));
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
    await _send(user: user, channelId: channel.channelId, text: text);
  }

  @override
  Future<void> postAdminAlert({
    required User user,
    required String text,
    required CommunicationAlertSeverity severity,
  }) async {
    await _send(
      user: user,
      channelId: 'admin-alerts',
      text: text,
      isAlert: true,
      severity: severity,
    );
  }

  Future<void> _send({
    required User user,
    required String channelId,
    required String text,
    bool isAlert = false,
    CommunicationAlertSeverity severity = CommunicationAlertSeverity.info,
  }) async {
    _requireWrites();
    final access = await _access(user);
    access.requireChannel(channelId);
    if (isAlert && access.role != CommunicationRole.admin) {
      throw StateError('Only a school administrator can publish admin alerts.');
    }
    final body = text.trim();
    if (body.isEmpty || body.length > 4000) {
      throw ArgumentError('Messages must contain 1 to 4000 characters.');
    }
    final message = CommunicationMessage(
      messageId: _uuid.v4(),
      channelId: channelId,
      schoolKey: access.schoolKey,
      authorId: user.userId,
      authorName: access.displayName,
      authorRole: access.role,
      text: body,
      createdAt: DateTime.now(),
      isAlert: isAlert,
      severity: severity,
    );
    final batch = _firestore.batch();
    batch.set(
      _messagesCollection(access.schoolKey, channelId).doc(message.messageId),
      {
        ..._messageToFirestore(message),
        'createdAt': FieldValue.serverTimestamp(),
      },
    );
    batch.update(_channelDoc(access.schoolKey, channelId), {
      'lastMessageId': message.messageId,
      'lastMessagePreview': body,
      'lastSenderName': access.displayName,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
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

  CollectionReference<Map<String, dynamic>> _readMarkersCollection(
    String userId,
  ) {
    return _firestore.collection('users/$userId/communicationReads');
  }

  String _readMarkerDocId(String schoolKey, String channelId) =>
      '${schoolKey}__$channelId';

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
