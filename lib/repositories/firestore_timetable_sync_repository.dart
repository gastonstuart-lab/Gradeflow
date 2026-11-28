import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/teacher_timetable_sync.dart';

/// Emulator-only reference implementation. No production repository factory
/// or existing timetable preferences are altered. An account's confirmed
/// timetable can be retrieved by a fresh authenticated client.
class FirestoreTimetableSyncRepository {
  FirestoreTimetableSyncRepository._(this._db,this._auth,this.ownerId,this._ownedClassIds);
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final String ownerId;
  final Set<String> _ownedClassIds;
  static const demoProject = 'demo-gradeflow-timetable-sync';

  factory FirestoreTimetableSyncRepository.emulator({
    required FirebaseFirestore firestore,required FirebaseAuth auth,
    required Set<String> ownedClassIds,
  }) {
    if (firestore.app.options.projectId!=demoProject ||
        firestore.app.name!=auth.app.name || auth.currentUser==null) {
      throw ArgumentError('Signed-in timetable demo emulator required');
    }
    const host='127.0.0.1:8180';
    if (firestore.settings.host!=host) {
      firestore.settings=const Settings(persistenceEnabled:false);
      firestore.useFirestoreEmulator('127.0.0.1',8180);
    }
    return FirestoreTimetableSyncRepository._(firestore,auth,
        auth.currentUser!.uid,Set.unmodifiable(ownedClassIds));
  }
  void _check() {
    if (_auth.currentUser?.uid!=ownerId || _db.app.options.projectId!=demoProject ||
        _db.settings.host!='127.0.0.1:8180') {
      throw StateError('Account or emulator changed');
    }
  }
  DocumentReference<Map<String,dynamic>> get _ref=>_db.doc('teacherTimetableSync/$ownerId');

  TimetableSyncRevision? _read(Map<String,dynamic>? value) {
    if(value==null)return null;
    if(value['schemaVersion']!=1 || value['ownerId']!=ownerId ||
        value['revision'] is! int || (value['revision'] as int)<0 ||
        value['operationId'] is! String || (value['operationId'] as String).isEmpty) {
      throw StateError('Unexpected stored timetable identity');
    }
    final snapshot=TeacherTimetableSnapshot.decode(value['payloadJson'] as String);
    snapshot.checkScope(ownerId,_ownedClassIds);
    return TimetableSyncRevision(revision:value['revision'] as int,
        operationId:value['operationId'] as String,snapshot:snapshot);
  }
  Future<TimetableSyncRevision?> load() async {
    _check();
    final read=await _ref.get(const GetOptions(source:Source.server));
    _check();
    return _read(read.data());
  }

  Future<TimetableSyncRevision> save(TeacherTimetableSnapshot value,
      {required int? expectedRevision,required String operationId}) async {
    _check();
    value.checkScope(ownerId,_ownedClassIds);
    if(operationId.trim().isEmpty || operationId.length>128 || operationId.contains('/')) {
      throw ArgumentError('Stable operation ID required');
    }
    final encoded=value.encode();
    // Each operation receives a create-only receipt in the same transaction.
    // Retrying a lost acknowledgement after another device changed the
    // schedule returns the confirmed current state, not an old overwrite.
    final result=await _db.runTransaction<TimetableSyncRevision?>((tx) async {
      _check();
      final current=_read((await tx.get(_ref)).data());
      final receipt=_ref.collection('receipts').doc(operationId);
      final prior=(await tx.get(receipt)).data();
      if(prior!=null) {
        if(prior['ownerId']!=ownerId || prior['payloadJson']!=encoded ||
            prior['expectedRevision']!=expectedRevision || current==null ||
            (prior['revision'] as int)>current.revision) return null;
        return current;
      }
      if(current?.revision!=expectedRevision)return null;
      final revision=expectedRevision==null?0:expectedRevision+1;
      tx.set(_ref,{'schemaVersion':1,'ownerId':ownerId,'revision':revision,
        'operationId':operationId,'payloadJson':encoded});
      tx.set(receipt,{'ownerId':ownerId,'revision':revision,
        'expectedRevision':expectedRevision,'payloadJson':encoded});
      return TimetableSyncRevision(revision:revision,operationId:operationId,snapshot:value);
    });
    _check();
    if(result==null)throw const TimetableSyncConflict();
    return result;
  }
}
