import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:gradeflow/models/grading_period.dart';
import 'package:gradeflow/models/grading_rollover_request.dart';
import 'package:gradeflow/repositories/grading_period_storage.dart';
import 'package:gradeflow/services/grading_period_calculation.dart';
import 'package:gradeflow/services/grading_period_template.dart';
import 'package:gradeflow/services/historical_grade_export_adapter.dart';
import '../tool/grading_period_coordinator.dart' as backend;
import 'grading_period_test.dart' as fixture;

// Requires demo emulators and the isolated coordinator (--test-faults).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null; // Actual loopback emulator I/O, never production.
  final store = backend.EmulatorStore();
  late String owner, token, otherOwner, otherToken, cid, path;
  late GradingPeriodBook initial;
  late GradingRolloverRequest intent;
  var sequence = 0;
  Future<(String, String)> account() async {
    final response = await http.post(
        Uri.parse(
            'http://127.0.0.1:9095/identitytoolkit.googleapis.com/v1/accounts:signUp?key=synthetic-emulator-key'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'returnSecureToken': true}));
    expect(response.statusCode, 200);
    final json = jsonDecode(response.body);
    return (json['localId'] as String, json['idToken'] as String);
  }

  setUpAll(() async {
    (owner, token) = await account();
    (otherOwner, otherToken) = await account();
  });
  Future<void> seed(GradingPeriodBook book) => store.commit([
        store.write(path, {
          'schemaVersion': 1,
          'ownerId': owner,
          'classId': cid,
          'revision': book.revision,
          'activePeriodId': book.activePeriodId,
          'periodIds': book.periods.map((p) => p.periodId).toList()
        }),
        for (final p in book.periods)
          store.write('$path/periods/${p.periodId}', encodeStoredPeriod(p)),
        store.write('$path/operations/0', {
          'ownerId': owner,
          'classId': cid,
          'revision': 0,
          'fromPeriodId': null,
          'toPeriodId': 'old'
        }),
      ]);
  setUp(() async {
    cid =
        'trusted-synthetic-${DateTime.now().microsecondsSinceEpoch}-${sequence++}';
    path = 'gradingPeriodBooks/$owner/classes/$cid';
    final json = fixture.legacy().toJson()..['ownerId'] = owner;
    json['classId'] = cid;
    for (final key in ['students', 'categories', 'assessments']) {
      for (final row in json[key] as List) {
        row['classId'] = cid;
      }
    }
    final data = GradebookDataset.fromJson(json);
    initial = GradingPeriodBook(
        ownerId: owner,
        classId: cid,
        revision: 0,
        activePeriodId: 'old',
        periods: [fixture.period(data)]);
    intent = GradingRolloverRequest(
        ownerId: owner,
        classId: cid,
        sourcePeriodId: 'old',
        expectedRevision: 0,
        nextPeriodId: 'next',
        label: 'Synthetic next',
        at: fixture.at.add(const Duration(days: 1)),
        operationId: 'operation-one');
    await seed(initial);
  });
  Future<http.Response> call(
          {Map<String, dynamic>? json, String? auth, String? fault}) =>
      http
          .post(Uri.parse('http://127.0.0.1:8787/rollover'),
              headers: {
                'Authorization': 'Bearer ${auth ?? token}',
                'Content-Type': 'application/json',
                if (fault != null) 'X-Test-Fault': fault,
              },
              body: jsonEncode(json ?? intent.toJson()))
          .timeout(const Duration(seconds: 40));
  Future<GradingPeriodBook> load() => store.readBook(path, owner, cid);
  String receiptPath() =>
      '$path/rollovers/${backend.digest(intent.operationId)}';
  GradingPeriodBook responseBook(http.Response r) => GradingPeriodBook.fromJson(
      Map<String, dynamic>.from(jsonDecode(r.body)['book'] as Map));

  test(
      'trusted seal uses authoritative stored scores, weights and labels, not client snapshots',
      () async {
    final source = initial.active;
    final json = source.dataset.toJson();
    (json['scores'] as List).first['score'] = 20.0;
    final authoritative = GradingPeriod(
        periodId: source.periodId,
        label: source.label,
        createdAt: source.createdAt,
        dataset: GradebookDataset.fromJson(json));
    await store.commit(
        [store.write('$path/periods/old', encodeStoredPeriod(authoritative))]);
    final result = await call();
    expect(result.statusCode, 200, reason: result.body);
    final book = responseBook(result);
    expect(book.periods.first.dataset.toJson(), authoritative.dataset.toJson());
    expect(book.periods.first.results!['one']!['finalGrade'], 92);
    expect(book.periods.first.dataset.categories.map((c) => c.weightPercent),
        [75, 25]);
    expect(book.active.dataset.assessments.length, 20);
    expect((await store.read(receiptPath()))!['sourceDigest'],
        backend.digest(authoritative.toJson()));
  });

  test('client-provided archive/results injection is rejected before writes',
      () async {
    final forged = intent.toJson()..['snapshot'] = initial.active.toJson();
    expect((await call(json: forged)).statusCode, 422);
    expect((await load()).toJson(), initial.toJson());
    expect(await store.read(receiptPath()), isNull);
  });

  test(
      'valid-looking direct client archive transaction and forged receipt are denied by rules',
      () async {
    final source = initial.active;
    final sealed =
        source.seal(intent.at, GradingPeriodCalculation().calculate(source));
    final next = GradingPeriodTemplate.create(
        context: source.dataset,
        periodId: 'next',
        label: intent.label,
        at: intent.at);
    final writes = [
      store.write(path, {
        'schemaVersion': 1,
        'ownerId': owner,
        'classId': cid,
        'revision': 1,
        'activePeriodId': 'next',
        'periodIds': ['old', 'next']
      }),
      store.write('$path/periods/old', encodeStoredPeriod(sealed)),
      store.write('$path/periods/next', encodeStoredPeriod(next)),
      store.write('$path/operations/1', {
        'ownerId': owner,
        'classId': cid,
        'revision': 1,
        'fromPeriodId': 'old',
        'toPeriodId': 'next'
      }),
    ];
    final response = await http.post(store.uri(':commit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'writes': writes}));
    expect(response.statusCode, 403, reason: response.body);
    final receipt = await http.post(store.uri(':commit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'writes': [
            store.write(receiptPath(), {'ownerId': owner})
          ]
        }));
    expect(receipt.statusCode, 403);
    expect((await load()).toJson(), initial.toJson());
  });

  test(
      'lost acknowledgement recovers from durable receipt after coordinator recreation',
      () async {
    expect((await call(fault: 'after-commit')).statusCode, 503);
    final recovery =
        await backend.TrustedSealingCoordinator(backend.EmulatorStore())
            .rollover(owner, intent);
    expect(recovery['replayed'], isTrue);
    expect(GradingPeriodBook.fromJson(recovery['book']).revision, 1);
    expect((await call()).statusCode, 200);
    expect((await load()).periods.length, 2);
    expect(await store.read('$path/operations/2'), isNull);
  });

  test(
      'interruption before commit preserves old grades and the same intent can retry',
      () async {
    expect((await call(fault: 'before-commit')).statusCode, 409);
    expect((await load()).toJson(), initial.toJson());
    expect(await store.read('$path/periods/next'), isNull);
    expect(await store.read(receiptPath()), isNull);
    expect((await call()).statusCode, 200);
  });

  test('concurrent identical intents return one committed outcome', () async {
    final responses = await Future.wait([call(), call()]);
    expect(responses.map((r) => r.statusCode), [200, 200]);
    expect(responses.map((r) => responseBook(r).revision), [1, 1]);
    expect(
        responses.where((r) => jsonDecode(r.body)['replayed'] == false).length,
        1);
    expect((await load()).periods.length, 2);
  });

  test(
      'concurrent different operations and stale clients cannot create extra successors',
      () async {
    final other = intent.toJson()..['operationId'] = 'different-operation';
    other['nextPeriodId'] = 'different-next';
    final results = await Future.wait([call(), call(json: other)]);
    expect(results.map((r) => r.statusCode).toList()..sort(), [200, 409]);
    final before = (await load()).toJson();
    final stale = intent.toJson()..['operationId'] = 'stale';
    expect((await call(json: stale)).statusCode, 409);
    expect((await load()).toJson(), before);
  });

  test(
      'operation ID reuse with changed intent is rejected, including after later rollover',
      () async {
    expect((await call()).statusCode, 200);
    final changed = intent.toJson()..['label'] = 'Changed intent';
    expect((await call(json: changed)).statusCode, 409);
    final later = GradingRolloverRequest(
        ownerId: owner,
        classId: cid,
        sourcePeriodId: 'next',
        expectedRevision: 1,
        nextPeriodId: 'third',
        label: 'Third',
        at: fixture.at.add(const Duration(days: 2)),
        operationId: 'second-operation');
    expect((await call(json: later.toJson())).statusCode, 200);
    final replay = await call();
    expect(replay.statusCode, 200);
    expect(responseBook(replay).activePeriodId, 'third');
    expect(jsonDecode(replay.body)['receipt']['revision'], 1);
    expect(jsonDecode(replay.body)['replayed'], isTrue);
  });

  test(
      'unauthenticated, cross-account, cross-class and wrong-project requests fail closed',
      () async {
    expect((await call(auth: 'invalid')).statusCode, 401);
    expect((await call(auth: otherToken)).statusCode, 409);
    final cross = intent.toJson()..['ownerId'] = otherOwner;
    expect((await call(auth: otherToken, json: cross)).statusCode, 409);
    final missing = intent.toJson()..['classId'] = '$cid-missing';
    expect((await call(json: missing)).statusCode, 409);
    expect(() => backend.EmulatorStore(project: 'production'),
        throwsArgumentError);
    expect((await load()).toJson(), initial.toJson());
  });

  test(
      'invalid authoritative snapshot and oversize source fail without data loss',
      () async {
    final raw = encodeStoredPeriod(initial.active);
    final corrupt = initial.active.dataset.toJson();
    (corrupt['assessments'] as List).first['maxScore'] = 0.0;
    await store.commit([
      store.write(
          '$path/periods/old', {...raw, 'datasetJson': jsonEncode(corrupt)})
    ]);
    expect((await call()).statusCode, 409);
    expect((await store.read(path))!['revision'], 0);
    final oversized = initial.active.dataset.toJson()
      ..['subject'] = List.filled(600001, 'x').join();
    final huge = {...raw, 'datasetJson': jsonEncode(oversized)};
    await store.commit([store.write('$path/periods/old', huge)]);
    expect((await call()).statusCode, 422);
    expect(await store.read('$path/periods/old'), huge);
    expect((await store.read(path))!['activePeriodId'], 'old');
    expect(await store.read(receiptPath()), isNull);
  });

  test('stale source revision never seals a later teacher edit', () async {
    final control = (await store.read(path))!;
    await store.commit([
      store.write(path, {...control, 'revision': 1})
    ]);
    expect((await call()).statusCode, 409);
    expect((await store.read('$path/periods/old'))!['sealedAt'], isNull);
    expect(await store.read(receiptPath()), isNull);
  });

  test(
      'synthetic backup/restore preserves calculations, all XLSX cells and retry receipts',
      () async {
    final result = await call();
    expect(result.statusCode, 200);
    final before = responseBook(result);
    final adapter = HistoricalGradeExportAdapter();
    List<Object?> cells(List<int> bytes) => Excel.decodeBytes(bytes)
        .tables
        .entries
        .map((e) => [
              e.key,
              e.value.rows
                  .map((r) => r.map((c) => c?.value?.toString()).toList())
                  .toList()
            ])
        .toList();
    final excel = cells(adapter.generateXlsx(before.periods.first,
        ownerId: owner, classId: cid));
    final tx = await store.begin();
    final paths = [
      path,
      for (final p in before.periods) '$path/periods/${p.periodId}',
      '$path/operations/0',
      '$path/operations/1',
      receiptPath()
    ];
    final backup = <String, dynamic>{};
    for (final key in paths) {
      backup[key] = await store.read(key, transaction: tx);
    }
    await store.rollback(tx);
    final encoded = jsonEncode(backup);
    final checksum = backend.digest(backup);
    final restored = jsonDecode(encoded) as Map<String, dynamic>;
    expect(backend.digest(restored), checksum);
    // Rehearsal deletes/restores only this test's synthetic paths in a demo emulator.
    await store.commit([
      for (final key in paths) {'delete': '${store.root}/$key'}
    ]);
    expect(await store.read(path), isNull);
    await store.commit([
      for (final e in restored.entries)
        store.write(e.key, Map<String, dynamic>.from(e.value as Map))
    ]);
    final recovered = await load();
    expect(recovered.toJson(), before.toJson());
    expect(adapter.calculate(recovered.periods.first),
        before.periods.first.results);
    expect(
        cells(adapter.generateXlsx(recovered.periods.first,
            ownerId: owner, classId: cid)),
        excel);
    final retry = await call();
    expect(jsonDecode(retry.body)['replayed'], isTrue);
    expect((await load()).revision, 1);
    final tampered = (await store.read(receiptPath()))!
      ..['archiveDigest'] = 'bad';
    await store.commit([store.write(receiptPath(), tampered)]);
    expect((await call()).statusCode, 409);
    expect((await load()).toJson(), recovered.toJson());
  });
}
