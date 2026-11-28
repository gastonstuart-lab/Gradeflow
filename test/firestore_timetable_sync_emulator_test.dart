@TestOn('browser')
library;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_web/firebase_core_web.dart';
import 'package:firebase_auth_web/firebase_auth_web.dart';
import 'package:cloud_firestore_web/cloud_firestore_web.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/components/time_slot_timetable.dart';
import 'package:gradeflow/services/teacher_timetable_sync.dart';
import 'package:gradeflow/services/timetable_import_plan.dart';
import 'package:gradeflow/repositories/firestore_timetable_sync_repository.dart';

const options=FirebaseOptions(apiKey:'emulator-only-key',appId:'1:123:web:demo',
    messagingSenderId:'123',projectId:'demo-gradeflow-timetable-sync',
    authDomain:'demo-gradeflow-timetable-sync.firebaseapp.com');
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FirebaseAuth auth, freshAuth, otherAuth;
  late FirebaseFirestore db, freshDb, otherDb;
  late FirestoreTimetableSyncRepository first, fresh;
  final email='synthetic-${DateTime.now().microsecondsSinceEpoch}@example.invalid';
  const password='emulator-test-password';
  Future<(FirebaseAuth,FirebaseFirestore)> connect(String name,{bool create=false,bool other=false}) async {
    final app=await Firebase.initializeApp(name:name,options:options);
    final auth=FirebaseAuth.instanceFor(app:app);
    await auth.useAuthEmulator('127.0.0.1',9099);
    if(other) {await auth.signInAnonymously();}
    else if(create) {await auth.createUserWithEmailAndPassword(email:email,password:password);}
    else {await auth.signInWithEmailAndPassword(email:email,password:password);}
    return (auth,FirebaseFirestore.instanceFor(app:app));
  }
  setUpAll(()async{
    FirebaseCoreWeb.registerWith(webPluginRegistrar);
    FirebaseAuthWeb.registerWith(webPluginRegistrar);
    FirebaseFirestoreWeb.registerWith(webPluginRegistrar);
    (auth,db)=await connect('timetable-first',create:true);
    (freshAuth,freshDb)=await connect('timetable-second');
    (otherAuth,otherDb)=await connect('timetable-other',other:true);
    first=FirestoreTimetableSyncRepository.emulator(firestore:db,auth:auth,ownedClassIds:{'owned-class'});
    fresh=FirestoreTimetableSyncRepository.emulator(firestore:freshDb,auth:freshAuth,ownedClassIds:{'owned-class'});
    FirestoreTimetableSyncRepository.emulator(firestore:otherDb,auth:otherAuth,ownedClassIds:{'owned-class'});
  });
  TeacherTimetableSnapshot schedule(String name,{String? owner,String classId='owned-class'}) =>
      TeacherTimetableSnapshot(ownerId:owner??auth.currentUser!.uid,selectedId:'version',
        versions:[SyncedTimetableVersion(id:'version',name:name,uploadedAt:DateTime.utc(2026),
          lessons:[TimeSlotClass(title:'Fictional science',dayOfWeek:0,startMinutes:540,
            endMinutes:590,classId:classId,room:'Lab')])]);

  test('two authenticated devices share revisions, reject stale edits, recover exact retries and isolate other accounts',()async{
    expect(await first.load(),isNull);
    final original=schedule('Week A');
    final local=original.toDeviceVersions().map((v)=>{...v,'base64':'other-teacher-workbook','grid':[['private staff tab']]}).toList();
    final minimal=TeacherTimetableSnapshot.fromLocal(ownerId:original.ownerId,selectedId:'version',versions:local,ownedClassIds:{'owned-class'});
    expect(minimal.encode(),original.encode());
    expect(minimal.encode(),isNot(contains('private staff tab')));
    expect(minimal.encode(),isNot(contains('other-teacher-workbook')));
    expect(TimetableImportPlan.fromGrid((minimal.toDeviceVersions().single['grid'] as List<List<String>>)).lessons.single.classId,'owned-class');
    final a=await first.save(minimal,expectedRevision:null,operationId:'create');
    expect(a.revision,0);
    expect((await fresh.load())!.snapshot.encode(),original.encode());
    final b=await fresh.save(schedule('Week B'),expectedRevision:0,operationId:'second');
    expect(b.revision,1);
    await expectLater(first.save(schedule('Stale'),expectedRevision:0,operationId:'stale'),throwsA(isA<TimetableSyncConflict>()));
    expect((await first.save(minimal,expectedRevision:null,operationId:'create')).revision,1);
    await expectLater(first.save(schedule('Changed intent'),expectedRevision:null,operationId:'create'),throwsA(isA<TimetableSyncConflict>()));
    await expectLater(first.save(schedule('Bad scope',classId:'not-owned'),expectedRevision:1,operationId:'bad'),throwsStateError);
    expect((await first.load())!.snapshot.versions.single.name,'Week B');
    final denied=throwsA(isA<FirebaseException>().having((e)=>e.code,'code','permission-denied'));
    final victim=otherDb.doc('teacherTimetableSync/${original.ownerId}');
    await expectLater(victim.get(),denied);
    await expectLater(victim.set({'ownerId':otherAuth.currentUser!.uid}),denied);
    await expectLater(db.doc('teacherTimetableSync/${original.ownerId}').update({'revision':2}),denied);
    await expectLater(db.doc('teacherTimetableSync/${original.ownerId}/receipts/create').delete(),denied);
    expect((await fresh.load())!.revision,1);
  });
}
