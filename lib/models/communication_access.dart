import 'package:gradeflow/models/communication_models.dart';

/// Trusted administrator-provisioned access; never derived from profile/email.
class CommunicationAccess {
  const CommunicationAccess({
    required this.schoolKey,
    required this.role,
    required this.displayName,
    required this.channelIds,
  });
  final String schoolKey;
  final CommunicationRole role;
  final String displayName;
  final List<String> channelIds;

  factory CommunicationAccess.fromData(Map<String, dynamic>? data) {
    Never denied() => throw StateError(
      'Shared Messages access has not been provisioned by your school administrator.',
    );
    if (data == null || data['active'] != true) denied();
    final school = data['schoolKey'], name = data['displayName'];
    final role = data['role'], channels = data['channelIds'];
    if (school is! String ||
        !RegExp(r'^[a-zA-Z0-9_-]{1,200}$').hasMatch(school) ||
        name is! String ||
        name.trim().isEmpty ||
        name.length > 100 ||
        role is! String ||
        !CommunicationRole.values.any((r) => r.name == role) ||
        channels is! List ||
        channels.length > 100 ||
        channels.any(
          (c) => c is! String || !RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(c),
        )) {
      denied();
    }
    return CommunicationAccess(
      schoolKey: school,
      role: CommunicationRole.values.byName(role),
      displayName: name,
      channelIds: List.unmodifiable(channels.cast<String>().toSet()),
    );
  }

  void requireChannel(String id) {
    if (!channelIds.contains(id)) {
      throw StateError('You are not a member of this shared channel.');
    }
  }
}
