// Standalone fictional SDK acceptance entrypoint. Never used by lib/main.dart.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:gradeflow/models/communication_models.dart';
import 'package:gradeflow/models/user.dart';
import 'package:gradeflow/repositories/firestore_communication_repository.dart';

final status =
    ValueNotifier<String>('Running fictional communication SDK acceptance');
void check(bool value, String message) {
  if (!value) throw StateError(message);
}

Future<void> denied(Future<dynamic> operation) async {
  try {
    await operation;
  } on StateError {
    return;
  }
  throw StateError('Expected unauthorized operation to fail');
}

Future<User> signIn(String role) async {
  await fb.FirebaseAuth.instance.signOut();
  final c = await fb.FirebaseAuth.instance.signInWithEmailAndPassword(
      email: 'communication-$role@example.invalid',
      password: 'Fictional-Communication123!');
  return User(
      userId: c.user!.uid,
      email: c.user!.email!,
      fullName: 'Forged Principal',
      schoolName: 'Forged school',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026));
}

Future<void> acceptance() async {
  try {
    await Firebase.initializeApp(
        options: const FirebaseOptions(
            apiKey: 'emulator-only-not-a-real-api-key',
            appId: '1:1234567890:web:local-emulator',
            messagingSenderId: '1234567890',
            projectId: 'demo-gradeflow-communication-security',
            authDomain:
                'demo-gradeflow-communication-security.firebaseapp.com'));
    await fb.FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8180);
    await fb.FirebaseAuth.instance.setPersistence(fb.Persistence.NONE);
    final teacher = await signIn('teacher');
    final repo = FirestoreCommunicationRepository();
    await repo.ensureDefaultChannels(user: teacher);
    final channels = await repo.loadChannels(user: teacher);
    check(
        channels.length == 2 &&
            channels.any((c) => c.channelId == 'staff') &&
            channels.any((c) => c.channelId == 'admin-alerts'),
        'Channel query must honor trusted grants');
    check((await repo.loadMessages(user: teacher, channelId: 'staff')).isEmpty,
        'Startup must not seed messages');
    await repo.sendMessage(
        user: teacher,
        channel: channels.singleWhere((c) => c.channelId == 'staff'),
        text: 'Fictional real SDK message',
        authorRole: CommunicationRole.admin);
    final message =
        (await repo.loadMessages(user: teacher, channelId: 'staff')).single;
    check(
        message.authorId == teacher.userId &&
            message.authorRole == CommunicationRole.teacher &&
            message.authorName == 'Verified teacher' &&
            message.schoolKey == 'web-school',
        'Profile/role hints must not become authority');
    final summary = await FirebaseFirestore.instance
        .doc('schools/web-school/communicationChannels/staff')
        .get(const GetOptions(source: Source.server));
    check(summary.data()!['lastMessageId'] == message.messageId,
        'Summary must bind actual message');
    await repo.markChannelRead(
        user: teacher, channelId: 'staff', readAt: DateTime.now());
    check((await repo.loadReadMarkers(user: teacher)).containsKey('staff'),
        'Read marker must work');
    await denied(repo.postAdminAlert(
        user: teacher,
        text: 'Forged alert',
        severity: CommunicationAlertSeverity.urgent));
    await denied(repo.loadMessages(user: teacher, channelId: 'private'));
    await denied(repo.createChannel(
        user: teacher,
        name: 'Forged',
        description: 'Fictional',
        kind: CommunicationChannelKind.staffRoom));
    final admin = await signIn('admin');
    await repo.postAdminAlert(
        user: admin,
        text: 'Fictional verified alert',
        severity: CommunicationAlertSeverity.urgent);
    final alert =
        (await repo.loadMessages(user: admin, channelId: 'admin-alerts'))
            .single;
    check(
        alert.authorName == 'Verified admin' &&
            alert.authorRole == CommunicationRole.admin &&
            alert.isAlert &&
            alert.severity == CommunicationAlertSeverity.urgent,
        'Trusted administrator alert must work');
    final unprovisioned = await signIn('unprovisioned');
    await denied(repo.loadChannels(user: unprovisioned));
    await denied(repo.loadMessages(user: unprovisioned, channelId: 'staff'));
    await fb.FirebaseAuth.instance.signOut();
    status.value = 'PASS all 3 communication SDK acceptance groups';
  } catch (e) {
    status.value = 'FAIL communication SDK acceptance: $e';
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  RendererBinding.instance.ensureSemantics();
  const enabled =
      bool.fromEnvironment('GRADEFLOW_COMMUNICATION_SECURITY_ACCEPTANCE');
  final allowed = enabled && ['127.0.0.1', 'localhost'].contains(Uri.base.host);
  if (!allowed) status.value = 'Blocked: loopback fictional acceptance only';
  runApp(MaterialApp(
      home: Scaffold(
          body: Center(
              child: ValueListenableBuilder<String>(
                  valueListenable: status,
                  builder: (context, value, _) => Text(value))))));
  if (allowed) unawaited(acceptance());
}
