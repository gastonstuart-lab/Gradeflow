import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/models/communication_models.dart';
import 'package:gradeflow/repositories/repository_factory.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/communication_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RepositoryFactory.useLocal();
  });

  test('unread counts persist per user and clear when a channel is opened',
      () async {
    final teacherAAuth = AuthService();
    final teacherBAuth = AuthService();

    expect(
      await teacherAAuth.register(
        'teacher.a@riverside.edu',
        'Teacher A',
        'Riverside High School',
      ),
      isTrue,
    );

    final teacherACommunication = await _loadCommunicationService(teacherAAuth);
    await teacherACommunication.selectChannel('teaching-team');
    expect(
      teacherACommunication.unreadCountForChannel('teaching-team'),
      equals(0),
    );

    await teacherACommunication.sendMessage(
      'Please review the updated intervention notes before period three.',
    );
    expect(
      teacherACommunication.unreadCountForChannel('teaching-team'),
      equals(0),
    );

    expect(
      await teacherBAuth.register(
        'teacher.b@riverside.edu',
        'Teacher B',
        'Riverside High School',
      ),
      isTrue,
    );

    final teacherBCommunication = await _loadCommunicationService(teacherBAuth);
    expect(
      teacherBCommunication.unreadCountForChannel('teaching-team'),
      greaterThan(0),
    );
    expect(teacherBCommunication.totalUnreadCount, greaterThan(0));

    await teacherBCommunication.selectChannel('teaching-team');
    expect(
      teacherBCommunication.unreadCountForChannel('teaching-team'),
      equals(0),
    );
    final totalUnreadAfterRead = teacherBCommunication.totalUnreadCount;

    final teacherBReloaded = await _loadCommunicationService(teacherBAuth);
    expect(
      teacherBReloaded.unreadCountForChannel('teaching-team'),
      equals(0),
    );
    expect(
      teacherBReloaded.totalUnreadCount,
      equals(totalUnreadAfterRead),
    );
  });

  test('custom staff groups are shared across teachers in the same school',
      () async {
    final teacherAAuth = AuthService();
    final teacherBAuth = AuthService();

    expect(
      await teacherAAuth.register(
        'teacher.a@riverside.edu',
        'Teacher A',
        'Riverside High School',
      ),
      isTrue,
    );
    final teacherACommunication = await _loadCommunicationService(teacherAAuth);

    final created = await teacherACommunication.createChannel(
      name: 'Student Support Team',
      description: 'Coordinate interventions and shared family follow-up.',
      kind: CommunicationChannelKind.gradeTeam,
    );
    expect(created, isTrue);
    expect(
      teacherACommunication.channels.any(
        (channel) => channel.name == 'Student Support Team',
      ),
      isTrue,
    );

    await teacherACommunication.sendMessage(
      'Please add fresh intervention updates before Friday.',
    );

    expect(
      await teacherBAuth.register(
        'teacher.b@riverside.edu',
        'Teacher B',
        'Riverside High School',
      ),
      isTrue,
    );
    final teacherBCommunication = await _loadCommunicationService(teacherBAuth);

    final sharedChannel = teacherBCommunication.channels.firstWhere(
      (channel) => channel.name == 'Student Support Team',
    );
    expect(sharedChannel.kind, CommunicationChannelKind.gradeTeam);
    expect(
      teacherBCommunication.unreadCountForChannel(sharedChannel.channelId),
      greaterThan(0),
    );
  });
}

Future<CommunicationService> _loadCommunicationService(AuthService auth) async {
  final service = CommunicationService();
  final ready = Completer<void>();

  void listener() {
    if (ready.isCompleted || service.isLoading) {
      return;
    }
    if (service.error != null) {
      ready.completeError(service.error!);
      return;
    }
    if (service.channels.isNotEmpty) {
      ready.complete();
    }
  }

  service.addListener(listener);
  service.syncAuth(auth);

  await Future<void>.delayed(Duration.zero);
  listener();
  await ready.future.timeout(const Duration(seconds: 2));
  service.removeListener(listener);
  return service;
}
