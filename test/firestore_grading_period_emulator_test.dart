@TestOn('browser')
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_web/firebase_core_web.dart';
import 'package:firebase_auth_web/firebase_auth_web.dart';
import 'package:cloud_firestore_web/cloud_firestore_web.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/models/grading_period.dart';
import 'package:gradeflow/models/grading_rollover_request.dart';
import 'package:gradeflow/repositories/firestore_grading_period_repository.dart';
import 'package:gradeflow/services/grading_period_service.dart';
import 'package:gradeflow/services/historical_grade_export_adapter.dart';
import 'grading_period_test.dart' as fixture;

const options = FirebaseOptions(
    apiKey: 'synthetic-emulator-key',
    appId: '1:123:web:synthetic',
    messagingSenderId: '123',
    projectId: 'demo-gradeflow-periods',
    authDomain: 'demo-gradeflow-periods.firebaseapp.com');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FirebaseAuth auth;
  late FirebaseFirestore db;
  late FirebaseAuth otherAuth;
  late FirebaseFirestore otherDb;
  late FirestoreGradingPeriodRepository repo;
  late GradingPeriodService service;
  late String cid;
  final email =
      'synthetic-${DateTime.now().microsecondsSinceEpoch}@example.invalid';
  const password = 'synthetic-emulator-password';
  var sequence = 0;

  setUpAll(() async {
    FirebaseCoreWeb.registerWith(webPluginRegistrar);
    FirebaseAuthWeb.registerWith(webPluginRegistrar);
    FirebaseFirestoreWeb.registerWith(webPluginRegistrar);
    final app = await Firebase.initializeApp(options: options);
    auth = FirebaseAuth.instanceFor(app: app);
    await auth.useAuthEmulator('127.0.0.1', 9095);
    await auth.createUserWithEmailAndPassword(email: email, password: password);
    db = FirebaseFirestore.instanceFor(app: app);
    repo = FirestoreGradingPeriodRepository.emulator(firestore: db, auth: auth);
    final otherApp =
        await Firebase.initializeApp(name: 'synthetic-other', options: options);
    otherAuth = FirebaseAuth.instanceFor(app: otherApp);
    await otherAuth.useAuthEmulator('127.0.0.1', 9095);
    await otherAuth.signInAnonymously();
    otherDb = FirebaseFirestore.instanceFor(app: otherApp);
    FirestoreGradingPeriodRepository.emulator(
        firestore: otherDb, auth: otherAuth);
  });
  setUp(() {
    cid = 'synthetic-${DateTime.now().microsecondsSinceEpoch}-${sequence++}';
    service = GradingPeriodService(repo);
  });
  GradebookDataset data({String? owner, String? classId}) {
    final json = fixture.legacy().toJson();
    json['ownerId'] = owner ?? repo.ownerId;
    json['classId'] = classId ?? cid;
    for (final key in ['students', 'categories', 'assessments']) {
      for (final row in json[key] as List) {
        row['classId'] = json['classId'];
      }
    }
    return GradebookDataset.fromJson(json);
  }

  DocumentReference<
      Map<String,
          dynamic>> control([String? owner, String? classId]) => db.doc(
      'gradingPeriodBooks/${owner ?? repo.ownerId}/classes/${classId ?? cid}');
  Future<GradingPeriodBook> create() => service.adoptLegacy(
      dataset: data(), periodId: 'old', label: 'Old', at: fixture.at);
  Future<GradingPeriodBook> rollover(
          {String target = 'next', int revision = 0, String source = 'old'}) =>
      service.rollover(
          classId: cid,
          periodId: source,
          expectedRevision: revision,
          nextPeriodId: target,
          label: 'New',
          at: fixture.at.add(const Duration(days: 1)));
  final denied = throwsA(isA<FirebaseException>()
      .having((e) => e.code, 'code', 'permission-denied'));

  test(
      'persists legacy data and reloads through a fresh authenticated SDK client',
      () async {
    final initial = await create();
    final app = await Firebase.initializeApp(
        name: 'synthetic-reload', options: options);
    final freshAuth = FirebaseAuth.instanceFor(app: app);
    await freshAuth.useAuthEmulator('127.0.0.1', 9095);
    await freshAuth.signInWithEmailAndPassword(
        email: email, password: password);
    final fresh = FirestoreGradingPeriodRepository.emulator(
        firestore: FirebaseFirestore.instanceFor(app: app), auth: freshAuth);
    expect((await fresh.load(cid))!.toJson(), initial.toJson());
    expect((await control().collection('operations').get()).docs.length, 1);
  });

  test(
      'atomic rollover seals old data, saves 20 defaults and persists one pointer',
      () async {
    final initial = await create();
    final result = await rollover();
    final loaded = (await repo.load(cid))!;
    expect(loaded.toJson(), result.toJson());
    expect(
        loaded.periods.first.dataset.toJson(), initial.active.dataset.toJson());
    expect(loaded.active.dataset.assessments.length, 20);
    expect(loaded.periods.where((p) => !p.isSealed).length, 1);
    expect(loaded.periods.first.results!['one']!['finalGrade'], 84.5);
    expect(
        HistoricalGradeExportAdapter().generateXlsx(loaded.periods.first,
            ownerId: repo.ownerId, classId: cid),
        isNotEmpty);
    expect((await control().collection('operations').get()).docs.length, 2);
  });

  test(
      'simultaneous rollover requests commit once and repeated stale requests cannot duplicate',
      () async {
    await create();
    var success = 0;
    var failure = 0;
    await Future.wait(
        ['next-a', 'next-b'].map((id) => rollover(target: id).then((_) {
              success++;
            }, onError: (_) {
              failure++;
            })));
    expect([success, failure], [1, 1]);
    await expectLater(rollover(), throwsStateError);
    final book = (await repo.load(cid))!;
    expect(book.revision, 1);
    expect(book.periods.length, 2);
    expect((await control().collection('operations').get()).docs.length, 2);
    await expectLater(
        service.rollover(
            classId: cid,
            periodId: book.activePeriodId,
            expectedRevision: 1,
            nextPeriodId: 'old',
            label: 'Duplicate',
            at: fixture.at),
        throwsStateError);
  });

  test(
      'assessment edit persists; stale compare-and-set leaves server state unchanged',
      () async {
    final initial = await create();
    final edited = await service.putAssessment(
        classId: cid,
        periodId: 'old',
        expectedRevision: 0,
        assessment:
            initial.active.dataset.assessments.first.copyWith(name: 'Edited'));
    expect((await repo.load(cid))!.toJson(), edited.toJson());
    await expectLater(
        repo.compareAndSet(edited, expectedRevision: 0), throwsStateError);
    expect((await repo.load(cid))!.revision, 1);
  });

  test(
      'SDK rules deny cross-account reads, writes and deletes even with colliding IDs',
      () async {
    await create();
    final victim = otherDb.doc(control().path);
    await expectLater(victim.get(), denied);
    await expectLater(victim.set((await control().get()).data()!), denied);
    await expectLater(victim.delete(), denied);
    await expectLater(
        otherDb.doc('${control().path}/periods/old').get(), denied);
    final otherRepo = FirestoreGradingPeriodRepository.emulator(
        firestore: otherDb, auth: otherAuth);
    await GradingPeriodService(otherRepo).adoptLegacy(
        dataset: data(owner: otherRepo.ownerId),
        periodId: 'old',
        label: 'Other',
        at: fixture.at);
    expect((await repo.load(cid))!.ownerId, repo.ownerId);
    expect((await otherRepo.load(cid))!.ownerId, otherRepo.ownerId);
  });

  test(
      'class scope is isolated; orphan period creation and pointer-only rollover denied',
      () async {
    final initial = await create();
    expect(await repo.load('$cid-other'), isNull);
    final periodData =
        (await control().collection('periods').doc('old').get()).data()!;
    await expectLater(
        control(null, '$cid-other')
            .collection('periods')
            .doc('old')
            .set(periodData),
        denied);
    await expectLater(
        control().update({
          'activePeriodId': 'phantom',
          'periodIds': ['old', 'phantom'],
          'revision': 1
        }),
        denied);
    expect((await repo.load(cid))!.toJson(), initial.toJson());
  });

  test(
      'sealed records, parent and operation receipts cannot be changed/deleted directly',
      () async {
    await create();
    final book = await rollover();
    final archived = control().collection('periods').doc('old');
    for (final change in [
      {'label': 'Changed'},
      {'datasetJson': '{}'},
      {'resultsJson': '{}'},
      {'sealedAt': null},
      {'ownerId': otherAuth.currentUser!.uid}
    ]) {
      await expectLater(archived.update(change), denied);
    }
    await expectLater(archived.delete(), denied);
    await expectLater(control().delete(), denied);
    final receipt = control().collection('operations').doc('1');
    await expectLater(receipt.update({'toPeriodId': 'again'}), denied);
    await expectLater(receipt.delete(), denied);
    expect((await repo.load(cid))!.toJson(), book.toJson());
  });

  test(
      'rejected transaction rolls back pointer, successor and receipt together',
      () async {
    final initial = await create();
    final batch = db.batch();
    final original =
        (await control().collection('periods').doc('old').get()).data()!;
    batch.update(control(), {
      'revision': 1,
      'activePeriodId': 'new',
      'periodIds': ['old', 'new']
    });
    batch.update(control().collection('periods').doc('old'), {
      'sealedAt': fixture.at.toIso8601String(),
      'resultsJson': '{}',
      'datasetJson': '{}'
    });
    batch.set(control().collection('periods').doc('new'),
        {...original, 'periodId': 'new'});
    batch.set(control().collection('operations').doc('1'), {
      'ownerId': repo.ownerId,
      'classId': cid,
      'revision': 1,
      'fromPeriodId': 'old',
      'toPeriodId': 'new'
    });
    await expectLater(batch.commit(), denied);
    expect((await repo.load(cid))!.toJson(), initial.toJson());
    expect((await control().collection('periods').doc('new').get()).exists,
        isFalse);
    expect((await control().collection('operations').doc('1').get()).exists,
        isFalse);
  });

  test(
      'legacy grading namespace remains untouched and unsupported environments rejected',
      () async {
    await create();
    await rollover();
    // Separate root has no permissive owner wildcard; direct legacy writes denied.
    await expectLater(
        db.doc('users/${repo.ownerId}/classes/$cid').set({'synthetic': true}),
        denied);
    expect(
        () => FirestoreGradingPeriodRepository.emulator(
            firestore: db, auth: auth, host: 'production.example'),
        throwsArgumentError);
    await expectLater(repo.load('../bad'), throwsArgumentError);
  });

  test(
      'service recovers a lost acknowledgement and retries the same intent idempotently',
      () async {
    await create();
    final intent = GradingRolloverRequest(
        ownerId: repo.ownerId,
        classId: cid,
        sourcePeriodId: 'old',
        expectedRevision: 0,
        nextPeriodId: 'next',
        label: 'New',
        at: fixture.at.add(const Duration(days: 1)));
    final token = await auth.currentUser!.getIdToken();
    final lost = await http.post(Uri.parse('http://127.0.0.1:8787/rollover'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'X-Test-Fault': 'after-commit'
        },
        body: jsonEncode(intent.toJson()));
    expect(lost.statusCode, 503);
    final recovered = await rollover();
    final replayed = await rollover();
    expect(recovered.revision, 1);
    expect(replayed.toJson(), recovered.toJson());
    expect(recovered.periods.first.results!['one']!['finalGrade'], 84.5);
    expect((await control().collection('operations').get()).docs.length, 2);
  });

  test('oversized periods fail before any control or operation is written',
      () async {
    final json = data().toJson()..['subject'] = List.filled(600001, 'x').join();
    await expectLater(
        service.adoptLegacy(
            dataset: GradebookDataset.fromJson(json),
            periodId: 'large',
            label: 'Large',
            at: fixture.at),
        throwsArgumentError);
    expect(await repo.load(cid), isNull);
    expect((await control().collection('operations').get()).docs, isEmpty);
  });
}
