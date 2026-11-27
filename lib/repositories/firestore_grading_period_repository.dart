import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/grading_period.dart';
import '../services/historical_grade_export_adapter.dart';
import 'grading_period_repository.dart';

/// Durable reference implementation restricted to a loopback demo emulator.
/// Never registered in RepositoryFactory; production configuration is rejected.
class FirestoreGradingPeriodRepository implements GradingPeriodRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  @override
  final String ownerId;

  FirestoreGradingPeriodRepository._(this._db, this._auth, this.ownerId);

  factory FirestoreGradingPeriodRepository.emulator({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    String host = '127.0.0.1',
    int port = 8085,
  }) {
    if (!firestore.app.options.projectId.startsWith('demo-') ||
        firestore.app.name != auth.app.name ||
        !['127.0.0.1', 'localhost', '::1'].contains(host) ||
        port < 1 ||
        port > 65535 ||
        auth.currentUser == null) {
      throw ArgumentError('A signed-in loopback demo emulator is required');
    }
    if (firestore.settings.host != '$host:$port') {
      firestore.settings = const Settings(persistenceEnabled: false);
      firestore.useFirestoreEmulator(host, port);
    }
    return FirestoreGradingPeriodRepository._(
        firestore, auth, auth.currentUser!.uid);
  }

  void _check() {
    if (_auth.currentUser?.uid != ownerId) throw StateError('Account changed');
  }

  DocumentReference<Map<String, dynamic>> _book(String classId) {
    _id(classId);
    return _db.doc('gradingPeriodBooks/$ownerId/classes/$classId');
  }

  @override
  Future<GradingPeriodBook?> load(String classId) async {
    _check();
    final ref = _book(classId);
    return _db.runTransaction((transaction) async {
      _check();
      return _read(transaction, ref);
    });
  }

  Future<GradingPeriodBook?> _read(
      Transaction tx, DocumentReference<Map<String, dynamic>> ref) async {
    final control = (await tx.get(ref)).data();
    if (control == null) return null;
    if (control['ownerId'] != ownerId ||
        control['classId'] != ref.id ||
        control['schemaVersion'] != 1) {
      throw StateError('Invalid stored grading scope/schema');
    }
    final ids = List<String>.from(control['periodIds'] as List);
    if (ids.length > 50)
      throw StateError('Period count exceeds bounded adapter');
    final periods = <GradingPeriod>[];
    for (final id in ids) {
      _id(id);
      final data = (await tx.get(ref.collection('periods').doc(id))).data();
      if (data == null ||
          data['ownerId'] != ownerId ||
          data['classId'] != ref.id ||
          data['periodId'] != id) {
        throw StateError('Missing or mis-scoped period');
      }
      periods.add(GradingPeriod.fromJson({
        ...data,
        'dataset': jsonDecode(data['datasetJson'] as String),
        'results': data['resultsJson'] == null
            ? null
            : jsonDecode(data['resultsJson'] as String),
      }));
    }
    return GradingPeriodBook(
        ownerId: ownerId,
        classId: ref.id,
        revision: control['revision'] as int,
        activePeriodId: control['activePeriodId'] as String,
        periods: periods);
  }

  @override
  Future<void> compareAndSet(GradingPeriodBook next,
      {required int? expectedRevision}) async {
    _check();
    if (next.ownerId != ownerId ||
        next.periods.length > 50 ||
        utf8.encode(jsonEncode(next.toJson())).length > 6000000) {
      throw ArgumentError('Invalid account or bounded storage size');
    }
    final ref = _book(next.classId);
    final encoded = {for (final p in next.periods) p.periodId: _encode(p)};
    final rejection = await _db.runTransaction<StateError?>((tx) async {
      GradingPeriodBook? old;
      final receipt = ref.collection('operations').doc('${next.revision}');
      try {
        _check();
        old = await _read(tx, ref);
        validateGradingPeriodTransition(ownerId, old, next, expectedRevision);
        if ((await tx.get(receipt)).exists) {
          return StateError('Operation already committed');
        }
        // All fallible domain validation precedes writes. Return rejections
        // across the web SDK bridge, which otherwise boxes Dart exceptions.
        for (final p in next.periods) {
          if (p.isSealed) HistoricalGradeExportAdapter().calculate(p);
        }
      } on StateError catch (error) {
        return error;
      }
      // No writes occur until the entire source and receipt have been read.
      tx.set(ref, {
        'schemaVersion': 1,
        'ownerId': ownerId,
        'classId': next.classId,
        'revision': next.revision,
        'activePeriodId': next.activePeriodId,
        'periodIds': next.periods.map((p) => p.periodId).toList(),
      });
      for (final p in next.periods) {
        final previous =
            old?.periods.where((v) => v.periodId == p.periodId).firstOrNull;
        if (previous == null ||
            jsonEncode(previous.toJson()) != jsonEncode(p.toJson())) {
          tx.set(
              ref.collection('periods').doc(p.periodId), encoded[p.periodId]!);
        }
      }
      tx.set(receipt, {
        'ownerId': ownerId,
        'classId': next.classId,
        'revision': next.revision,
        'fromPeriodId': old?.activePeriodId,
        'toPeriodId': next.activePeriodId,
      });
      return null;
    });
    if (rejection != null) throw rejection;
  }

  Map<String, dynamic> _encode(GradingPeriod period) {
    _id(period.periodId);
    final json = period.toJson();
    final data = {
      'schemaVersion': 1,
      'ownerId': ownerId,
      'classId': period.dataset.classId,
      'periodId': period.periodId,
      'label': period.label,
      'createdAt': json['createdAt'],
      'sealedAt': json['sealedAt'],
      'policyVersion': period.policyVersion,
      'datasetJson': jsonEncode(json['dataset']),
      'resultsJson':
          period.results == null ? null : jsonEncode(json['results']),
    };
    if (utf8.encode(jsonEncode(data)).length > 600000) {
      throw ArgumentError(
          'Period exceeds 600 KB; chunked storage is not supported');
    }
    return data;
  }

  static void _id(String id) {
    if (id.isEmpty ||
        id.contains('/') ||
        id == '.' ||
        id == '..' ||
        utf8.encode(id).length > 1000) {
      throw ArgumentError('Invalid document identity');
    }
  }
}
