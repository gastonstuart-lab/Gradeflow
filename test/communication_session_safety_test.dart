import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/models/user.dart';
import 'package:gradeflow/models/communication_models.dart';
import 'package:gradeflow/repositories/local_communication_repository.dart';
import 'package:gradeflow/repositories/repository_factory.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/communication_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAuth extends AuthService {
  User? user;
  @override
  User? get currentUser => user;
}

class DeferredCommunication extends LocalCommunicationRepository {
  DeferredCommunication();
  final gate = Completer<void>();
  final started = Completer<void>();
  bool fail = false;
  @override
  Future<void> ensureDefaultChannels({required User user}) async {}
  @override
  Future<List<CommunicationChannelRecord>> loadChannels(
      {required User user}) async {
    if (user.userId == 'a') {
      if (!started.isCompleted) started.complete();
      await gate.future;
    }
    if (fail) throw StateError('Synthetic access revoked');
    return [
      CommunicationChannelRecord(
          channelId: user.userId,
          schoolKey: 'fictional',
          name: user.userId,
          description: 'Synthetic',
          kind: CommunicationChannelKind.staffRoom,
          readOnly: false,
          memberCount: 1,
          sortOrder: 0,
          createdBy: 'Fictional',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026))
    ];
  }

  @override
  Future<Map<String, DateTime>> loadReadMarkers({required User user}) async =>
      {};
  @override
  Future<List<CommunicationMessage>> loadMessages(
          {required User user,
          required String channelId,
          int limit = 40}) async =>
      [];
  @override
  Future<void> markChannelRead(
      {required User user,
      required String channelId,
      required DateTime readAt}) async {}
}

User user(String id) => User(
    userId: id,
    email: '$id@example.invalid',
    fullName: 'Fictional $id',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026));
Future<void> settled(CommunicationService service) async {
  for (var i = 0; i < 50; i++) {
    await Future<void>.delayed(Duration.zero);
    if (!service.isLoading && service.channels.isNotEmpty) return;
  }
  fail('Communication load did not settle');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RepositoryFactory.useLocal();
  });
  test('an old account response cannot populate the next account workspace',
      () async {
    final repo = DeferredCommunication();
    final auth = FakeAuth()..user = user('a');
    final service = CommunicationService(repositoryFactory: (_) => repo);
    service.syncAuth(auth);
    await repo.started.future;
    auth.user = user('b');
    service.syncAuth(auth);
    await settled(service);
    expect(service.channels.single.channelId, 'b');
    repo.gate.complete();
    await Future<void>.delayed(Duration.zero);
    expect(service.channels.single.channelId, 'b');
    expect(service.selectedChannel!.channelId, 'b');
    service.dispose();
    auth.dispose();
  });
  test('sign out and dispose suppress pending account responses', () async {
    final repo = DeferredCommunication();
    final auth = FakeAuth()..user = user('a');
    final service = CommunicationService(repositoryFactory: (_) => repo);
    service.syncAuth(auth);
    await repo.started.future;
    auth.user = null;
    service.syncAuth(auth);
    service.dispose();
    repo.gate.complete();
    await Future<void>.delayed(Duration.zero);
    expect(service.channels, isEmpty);
    auth.dispose();
  });
  test('a rejected reload clears previously displayed shared data', () async {
    final repo = DeferredCommunication();
    final auth = FakeAuth()..user = user('b');
    final service = CommunicationService(repositoryFactory: (_) => repo);
    service.syncAuth(auth);
    await settled(service);
    expect(service.channels, isNotEmpty);
    repo.fail = true;
    await service.load();
    expect(service.channels, isEmpty);
    expect(service.error, contains('revoked'));
    service.dispose();
    auth.dispose();
  });
}
