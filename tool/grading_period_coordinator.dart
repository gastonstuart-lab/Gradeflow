// Emulator-only trusted process. Never imported by the Flutter application.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:gradeflow/models/grading_period.dart';
import 'package:gradeflow/models/grading_rollover_request.dart';
import 'package:gradeflow/repositories/grading_period_repository.dart';
import 'package:gradeflow/repositories/grading_period_storage.dart';
import 'package:gradeflow/services/grading_period_calculation.dart';
import 'package:gradeflow/services/grading_period_template.dart';

const demoProject = 'demo-gradeflow-periods';
String digest(Object? value) =>
    sha256.convert(utf8.encode(jsonEncode(_canonical(value)))).toString();
Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final k in keys) k: _canonical(value[k])};
  }
  if (value is List) return value.map(_canonical).toList();
  return value;
}

class StoreFailure implements Exception {
  final int status;
  StoreFailure(this.status);
}

/// Small REST bridge permits use of the existing pure Dart models/calculator
/// in a trusted process. Admin-emulator bypass token never reaches the app.
class EmulatorStore {
  final http.Client client;
  final String root;
  EmulatorStore({http.Client? client, String project = demoProject})
      : client = client ?? http.Client(),
        root = 'projects/$project/databases/(default)/documents' {
    if (project != demoProject) throw ArgumentError('Demo emulator only');
  }
  Uri uri(String path, [Map<String, String>? query]) => Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: 8085,
      path: '/v1/$root$path',
      queryParameters: query);
  Future<Map<String, dynamic>> post(
      String action, Map<String, dynamic> body) async {
    final r = await client
        .post(uri(':$action'),
            headers: {
              'Authorization': 'Bearer owner',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw StoreFailure(r.statusCode);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<String> begin() async => (await post('beginTransaction', {
        'options': {'readWrite': <String, dynamic>{}},
      }))['transaction'] as String;
  Future<Map<String, dynamic>?> read(String path, {String? transaction}) async {
    final r = await client.get(
        uri(
            '/$path',
            transaction == null
                ? null
                : {
                    'transaction': transaction,
                  }),
        headers: {
          'Authorization': 'Bearer owner'
        }).timeout(const Duration(seconds: 15));
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200) throw StoreFailure(r.statusCode);
    return decodeFields(
        Map<String, dynamic>.from(jsonDecode(r.body)['fields'] as Map));
  }

  Map<String, dynamic> write(String path, Map<String, dynamic> data) => {
        'update': {'name': '$root/$path', 'fields': encodeFields(data)},
      };
  Future<void> commit(List<Map<String, dynamic>> writes,
      {String? transaction}) async {
    await post('commit', {
      'writes': writes,
      if (transaction != null) 'transaction': transaction
    });
  }

  Future<void> rollback(String transaction) async {
    try {
      await post('rollback', {'transaction': transaction});
    } catch (_) {/* may already be committed */}
  }

  Future<GradingPeriodBook> readBook(String path, String owner, String cid,
      {String? transaction}) async {
    final c = await read(path, transaction: transaction);
    if (c == null ||
        c['schemaVersion'] != 1 ||
        c['ownerId'] != owner ||
        c['classId'] != cid) {
      throw StateError('Unknown or mis-scoped class');
    }
    final ids = List<String>.from(c['periodIds'] as List);
    if (ids.length > 50) throw StateError('Oversized book');
    final periods = <GradingPeriod>[];
    for (final id in ids) {
      if (id.isEmpty || id.contains('/') || id == '.' || id == '..')
        throw StateError('Invalid stored identity');
      final raw = await read('$path/periods/$id', transaction: transaction);
      if (raw == null ||
          raw['ownerId'] != owner ||
          raw['classId'] != cid ||
          raw['periodId'] != id) {
        throw StateError('Missing or mis-scoped stored period');
      }
      periods.add(decodeStoredPeriod(raw));
    }
    final book = GradingPeriodBook(
        ownerId: owner,
        classId: cid,
        revision: c['revision'] as int,
        activePeriodId: c['activePeriodId'] as String,
        periods: periods);
    validateSize(book);
    return book;
  }
}

Map<String, dynamic> encodeFields(Map<String, dynamic> value) => {
      for (final e in value.entries) e.key: _encodeValue(e.value),
    };
Map<String, dynamic> _encodeValue(Object? v) {
  if (v == null) return {'nullValue': null};
  if (v is String) return {'stringValue': v};
  if (v is bool) return {'booleanValue': v};
  if (v is int) return {'integerValue': '$v'};
  if (v is double && v.isFinite) return {'doubleValue': v};
  if (v is List)
    return {
      'arrayValue': {'values': v.map(_encodeValue).toList()}
    };
  if (v is Map<String, dynamic>)
    return {
      'mapValue': {'fields': encodeFields(v)}
    };
  throw ArgumentError('Unsupported Firestore value');
}

Map<String, dynamic> decodeFields(Map<String, dynamic> fields) => {
      for (final e in fields.entries)
        e.key: _decodeValue(Map<String, dynamic>.from(e.value as Map)),
    };
Object? _decodeValue(Map<String, dynamic> v) {
  if (v.containsKey('nullValue')) return null;
  if (v.containsKey('integerValue'))
    return int.parse(v['integerValue'] as String);
  if (v.containsKey('doubleValue')) return (v['doubleValue'] as num).toDouble();
  if (v.containsKey('stringValue')) return v['stringValue'];
  if (v.containsKey('booleanValue')) return v['booleanValue'];
  if (v.containsKey('arrayValue'))
    return ((v['arrayValue']['values'] ?? []) as List)
        .map((e) => _decodeValue(Map<String, dynamic>.from(e as Map)))
        .toList();
  if (v.containsKey('mapValue'))
    return decodeFields(
        Map<String, dynamic>.from(v['mapValue']['fields'] ?? {}));
  throw StateError('Unsupported stored value');
}

void validateSize(GradingPeriodBook book) {
  if (book.periods.length > 50 ||
      utf8.encode(jsonEncode(book.toJson())).length > 6000000) {
    throw ArgumentError('Oversized book');
  }
  for (final p in book.periods) {
    encodeStoredPeriod(p);
  }
}

class TrustedSealingCoordinator {
  final EmulatorStore store;
  TrustedSealingCoordinator(this.store);

  Future<Map<String, dynamic>> rollover(
      String authenticatedOwner, GradingRolloverRequest request,
      {bool failBeforeCommit = false}) async {
    if (authenticatedOwner != request.ownerId)
      throw StateError('Account mismatch');
    final path =
        'gradingPeriodBooks/$authenticatedOwner/classes/${request.classId}';
    final receiptPath = '$path/rollovers/${digest(request.operationId)}';
    final requestDigest = digest(request.toJson());
    for (var attempt = 0; attempt < 5; attempt++) {
      final tx = await store.begin();
      var committed = false;
      try {
        // Receipt first: retries remain valid after later edits/rollovers.
        final committedReceipt = await store.read(receiptPath, transaction: tx);
        final old = await store.readBook(
            path, authenticatedOwner, request.classId,
            transaction: tx);
        if (committedReceipt != null) {
          if (committedReceipt['ownerId'] != authenticatedOwner ||
              committedReceipt['classId'] != request.classId ||
              committedReceipt['requestDigest'] != requestDigest ||
              committedReceipt['operationId'] != request.operationId ||
              !old.periods.any(
                  (p) => p.periodId == request.sourcePeriodId && p.isSealed)) {
            throw StateError(
                'Operation identity reused with a different intent');
          }
          final archive = old.periods
              .firstWhere((p) => p.periodId == request.sourcePeriodId);
          if (committedReceipt['fromPeriodId'] != request.sourcePeriodId ||
              committedReceipt['toPeriodId'] != request.nextPeriodId ||
              committedReceipt['revision'] != request.expectedRevision + 1 ||
              old.revision < request.expectedRevision + 1 ||
              !old.periods.any((p) => p.periodId == request.nextPeriodId) ||
              committedReceipt['archiveDigest'] != digest(archive.toJson())) {
            throw StateError('Incomplete or corrupt committed outcome');
          }
          GradingPeriodCalculation().calculate(archive);
          return {
            'book': old.toJson(),
            'receipt': committedReceipt,
            'replayed': true
          };
        }
        if (old.revision != request.expectedRevision ||
            old.activePeriodId != request.sourcePeriodId ||
            old.periods.any((p) => p.periodId == request.nextPeriodId)) {
          throw StateError('Stale rollover');
        }
        final calculation = GradingPeriodCalculation();
        for (final p in old.periods) {
          calculation.calculate(p);
        }
        final source = old.active;
        final sealed = source.seal(request.at, calculation.calculate(source));
        final next = GradingPeriodTemplate.create(
            context: source.dataset,
            periodId: request.nextPeriodId,
            label: request.label,
            at: request.at,
            weights: request.weights);
        final book = GradingPeriodBook(
            ownerId: authenticatedOwner,
            classId: request.classId,
            revision: old.revision + 1,
            activePeriodId: next.periodId,
            periods: [
              ...old.periods.where((p) => p.periodId != source.periodId),
              sealed,
              next
            ]);
        validateGradingPeriodTransition(
            authenticatedOwner, old, book, old.revision);
        validateSize(book);
        final receipt = <String, dynamic>{
          'ownerId': authenticatedOwner,
          'classId': request.classId,
          'operationId': request.operationId,
          'requestDigest': requestDigest,
          'revision': book.revision,
          'fromPeriodId': source.periodId,
          'toPeriodId': next.periodId,
          'sourceDigest': digest(source.toJson()),
          'archiveDigest': digest(sealed.toJson()),
        };
        // Test-only fault occurs before any writes. Transactional staging means
        // process death before commit leaves no partial archive or pointer.
        if (failBeforeCommit)
          throw StateError('Injected interruption before commit');
        await store.commit([
          store.write(path, {
            'schemaVersion': 1,
            'ownerId': authenticatedOwner,
            'classId': request.classId,
            'revision': book.revision,
            'activePeriodId': next.periodId,
            'periodIds': book.periods.map((p) => p.periodId).toList()
          }),
          store.write(
              '$path/periods/${source.periodId}', encodeStoredPeriod(sealed)),
          store.write(
              '$path/periods/${next.periodId}', encodeStoredPeriod(next)),
          store.write('$path/operations/${book.revision}', {
            'ownerId': authenticatedOwner,
            'classId': request.classId,
            'revision': book.revision,
            'fromPeriodId': source.periodId,
            'toPeriodId': next.periodId
          }),
          store.write(receiptPath, receipt),
        ], transaction: tx);
        committed = true;
        return {'book': book.toJson(), 'receipt': receipt, 'replayed': false};
      } on StoreFailure catch (e) {
        if (e.status != 409 || attempt == 4) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 40 * (attempt + 1)));
      } finally {
        if (!committed) await store.rollback(tx);
      }
    }
    throw StateError('Retry limit');
  }
}

Future<String> authenticate(String? authorization) async {
  if (authorization == null || !authorization.startsWith('Bearer '))
    throw StateError('Unauthenticated');
  final token = authorization.substring(7);
  final parts = token.split('.');
  if (parts.length != 3) throw StateError('Invalid token');
  final claims =
      jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))))
          as Map;
  if (claims['aud'] != demoProject ||
      claims['iss'] != 'https://securetoken.google.com/$demoProject' ||
      (claims['exp'] as num) * 1000 <= DateTime.now().millisecondsSinceEpoch)
    throw StateError('Wrong token project/expiry');
  final response = await http
      .post(
          Uri.parse(
              'http://127.0.0.1:9095/identitytoolkit.googleapis.com/v1/accounts:lookup?key=synthetic-emulator-key'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'idToken': token}))
      .timeout(const Duration(seconds: 10));
  if (response.statusCode != 200) throw StateError('Invalid identity');
  final users = jsonDecode(response.body)['users'] as List;
  if (users.length != 1 ||
      users.single['localId'] != claims['sub'] ||
      users.single['disabled'] == true) {
    throw StateError('Invalid identity');
  }
  final uid = users.single['localId'] as String;
  if (uid.isEmpty || uid.contains('/')) throw StateError('Invalid identity');
  return uid;
}

Future<void> main(List<String> args) async {
  if (Platform.environment['GRADEFLOW_COORDINATOR_PROJECT'] != demoProject) {
    throw StateError(
        'Set GRADEFLOW_COORDINATOR_PROJECT=$demoProject; production is disabled');
  }
  final allowFaults = args.contains('--test-faults');
  final coordinator = TrustedSealingCoordinator(EmulatorStore());
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8787);
  stdout.writeln('Trusted coordinator: demo emulator only, 127.0.0.1:8787');
  await for (final request in server) {
    unawaited(() async {
      final response = request.response;
      try {
        final origin = request.headers.value('origin');
        if (origin != null) {
          final parsed = Uri.tryParse(origin);
          if (parsed == null ||
              parsed.scheme != 'http' ||
              !['localhost', '127.0.0.1'].contains(parsed.host))
            throw StateError('Origin denied');
          response.headers.set('Access-Control-Allow-Origin', origin);
          response.headers.set('Vary', 'Origin');
        }
        response.headers.set('Access-Control-Allow-Headers',
            'Authorization, Content-Type, X-Test-Fault');
        response.headers.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
        if (request.method == 'OPTIONS') {
          response.statusCode = 204;
          return;
        }
        if (request.method != 'POST' || request.uri.path != '/rollover') {
          response.statusCode = 404;
          return;
        }
        String owner;
        try {
          owner = await authenticate(request.headers.value('authorization'));
        } catch (_) {
          response.statusCode = 401;
          return;
        }
        final bytes = <int>[];
        await for (final chunk in request) {
          bytes.addAll(chunk);
          if (bytes.length > 16000) {
            response.statusCode = 413;
            return;
          }
        }
        final intent = GradingRolloverRequest.fromJson(
            jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
        final fault =
            allowFaults ? request.headers.value('x-test-fault') : null;
        final result = await coordinator.rollover(owner, intent,
            failBeforeCommit: fault == 'before-commit');
        if (fault == 'after-commit') {
          response.statusCode = 503;
          return;
        }
        response.headers.contentType = ContentType.json;
        response.write(jsonEncode(result));
      } on StateError {
        response.statusCode = 409;
      } on StoreFailure {
        response.statusCode = 503;
      } on ArgumentError {
        response.statusCode = 422;
      } on FormatException {
        response.statusCode = 422;
      } on TypeError {
        response.statusCode = 422;
      } catch (_) {
        response.statusCode = 503; // outcome may be unknown: retry same intent
      } finally {
        await response.close();
      }
    }());
  }
}
