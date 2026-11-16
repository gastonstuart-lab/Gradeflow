// Local emulator only. Reuse the existing app's test dependencies; no live data.
const {readFileSync}=require('node:fs');
const {resolve}=require('node:path');
const {createRequire}=require('node:module');
const assert=require('node:assert/strict');
const dependencies=process.env.GRADEFLOW_TEST_DEPENDENCIES;
if(!dependencies)throw Error('Set GRADEFLOW_TEST_DEPENDENCIES to the existing staging-tests directory');
const fixtureRequire=createRequire(resolve(dependencies,'package.json'));
const {initializeTestEnvironment,assertSucceeds,assertFails}=fixtureRequire('@firebase/rules-unit-testing');
(async()=>{
 const env=await initializeTestEnvironment({projectId:'demo-gradeflow-communication-containment',firestore:{host:'127.0.0.1',port:8180,rules:readFileSync('firestore.rules','utf8')}});
 try{
  const owner=env.authenticatedContext('teacher-a').firestore();
  const other=env.authenticatedContext('teacher-b').firestore();
  const admin=env.authenticatedContext('admin',{admin:true,role:'admin'}).firestore();
  const anonymous=env.unauthenticatedContext().firestore();
  const channel='schools/fictional-school/communicationChannels/staff';
  const message=channel+'/messages/fictional-message';
  await env.withSecurityRulesDisabled(async ctx=>{
   await ctx.firestore().doc(channel).set({schoolKey:'fictional-school',sortOrder:0});
   await ctx.firestore().doc(message).set({schoolKey:'fictional-school',text:'Fictional message'});
  });
  for(const db of [owner,other,admin,anonymous]){
   for(const path of [channel,message]){
    await assertFails(db.doc(path).get());
    await assertFails(db.doc(path).set({schoolKey:'fictional-school',text:'Forged'}));
    await assertFails(db.doc(path).update({text:'Forged'}));
    await assertFails(db.doc(path).delete());
   }
   await assertFails(db.collection('schools/fictional-school/communicationChannels').orderBy('sortOrder').get());
   await assertFails(db.collection(channel+'/messages').limit(40).get());
   await assertFails(db.collectionGroup('messages').limit(100).get());
  }
  console.log('PASS shared channel/message reads, queries and writes denied for anonymous/teachers/admin claims');
  const ownPaths=['users/teacher-a','users/teacher-a/classes/c',
   'users/teacher-a/classes/c/students/s','users/teacher-a/classes/c/categories/homework',
   'users/teacher-a/classes/c/gradeItems/quiz/scores/s','users/teacher-a/classes/c/exams/s',
   'users/teacher-a/classes/c/seatingLayouts/room','users/teacher-a/communicationReads/marker'];
  for(const path of ownPaths){
   await assertSucceeds(owner.doc(path).set({value:'Fictional academic record'}));
   await assertSucceeds(owner.doc(path).update({value:'Updated fictional record'}));
   const result=await assertSucceeds(owner.doc(path).get());assert.equal(result.data().value,'Updated fictional record');
   for(const db of [other,admin,anonymous]){
    await assertFails(db.doc(path).get());await assertFails(db.doc(path).set({value:'Hijack'}));
   }
   await assertSucceeds(owner.doc(path).delete());
  }
  console.log('PASS existing academic and private read-marker CRUD preserved; cross-user access denied');
  await assertSucceeds(owner.doc('users/teacher-a/profile/role').set({admin:true,role:'admin'}));
  await assertFails(owner.doc(message).get());
  await assertFails(owner.doc('communicationAccess/teacher-a').set({active:true,role:'admin'}));
  console.log('PASS profile edits/self-grants cannot reopen shared Messages');
  console.log('Containment rules: all acceptance groups passed. No production endpoints used.');
 }finally{await env.cleanup();}
})().catch(e=>{console.error(e.message);process.exitCode=1});
