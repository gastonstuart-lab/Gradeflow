import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import firebase from 'firebase/compat/app';
import 'firebase/compat/firestore';
import {setLogLevel} from 'firebase/firestore';
setLogLevel('silent');

const env = await initializeTestEnvironment({projectId:'demo-gradeflow-communication-security',
  firestore:{host:'127.0.0.1',port:8180,rules:readFileSync('firestore.rules','utf8')}});
const stamp=()=>firebase.firestore.FieldValue.serverTimestamp();
const now=firebase.firestore.Timestamp.fromMillis(Date.now());
const access=(role='teacher',schoolKey='school-a',channelIds=['staff','admin-alerts'])=>({active:true,schoolKey,role,displayName:role==='admin'?'Fictional Admin':'Fictional Teacher',channelIds});
const channel=(schoolKey,channelId,kind='staffRoom',readOnly=false)=>({schoolKey,channelId,name:'Fictional channel',description:'Synthetic security test',kind,readOnly,memberCount:2,sortOrder:0,createdBy:'Fictional Admin',createdAt:now,updatedAt:now,lastMessagePreview:null,lastSenderName:null,lastMessageAt:null});
const path=(school,id='staff')=>`schools/${school}/communicationChannels/${id}`;
let count=0;
async function passes(name,action){await action();count++;console.log('PASS',name);}
function send(db,{school='school-a',id='staff',uid='teacher-a',role='teacher',name='Fictional Teacher',isAlert=false,severity='info',text='Fictional test message',messageId='m-'+crypto.randomUUID(),mutate=()=>{},summaryMutate=()=>{},summary=true}={}){
 const d={messageId,channelId:id,schoolKey:school,authorId:uid,authorName:name,authorRole:role,text,createdAt:stamp(),isAlert,severity};mutate(d);
 const s={lastMessageId:messageId,lastMessagePreview:d.text ?? 'Fictional test message',lastSenderName:d.authorName,lastMessageAt:stamp(),updatedAt:stamp()};summaryMutate(s);
 const batch=db.batch();batch.set(db.doc(path(school,id)+'/messages/'+messageId),d);
 if(summary)batch.update(db.doc(path(school,id)),s);
 return batch.commit();
}
try{
 await env.withSecurityRulesDisabled(async ctx=>{
  const db=ctx.firestore();
  for(const [uid,a] of [['teacher-a',access()],['teacher-b',access('teacher','school-b')],['admin-a',access('admin')],['private-only',access('teacher','school-a',['private'])],['revoked',{...access(),active:false}]]) await db.doc('communicationAccess/'+uid).set(a);
  for(const school of ['school-a','school-b']){
   await db.doc(path(school)).set(channel(school,'staff'));
   await db.doc(path(school,'private')).set(channel(school,'private','direct'));
   await db.doc(path(school,'admin-alerts')).set(channel(school,'admin-alerts','adminAlerts',true));
  }
 });
 const a=env.authenticatedContext('teacher-a').firestore(),b=env.authenticatedContext('teacher-b').firestore();
 const admin=env.authenticatedContext('admin-a').firestore(),none=env.authenticatedContext('outsider').firestore();
 const anon=env.unauthenticatedContext().firestore(),revoked=env.authenticatedContext('revoked').firestore();
 await passes('anonymous, nonmember, other school and revoked reads denied',async()=>{
  for(const db of [anon,none,b,revoked])await assertFails(db.doc(path('school-a')).get());
 });
 await passes('authorized channel-ID query works; broad/mixed/private lists fail',async()=>{
  await assertSucceeds(a.collection('schools/school-a/communicationChannels').where(firebase.firestore.FieldPath.documentId(),'in',['staff','admin-alerts']).limit(10).get());
  await assertFails(a.collection('schools/school-a/communicationChannels').get());
  await assertFails(a.collection('schools/school-a/communicationChannels').where(firebase.firestore.FieldPath.documentId(),'in',['staff','private']).get());
  await assertFails(a.doc(path('school-a','private')).get());
 });
 await passes('membership cannot be self-created, promoted, reassigned or read by another user',async()=>{
  await assertFails(none.doc('communicationAccess/outsider').set(access('admin')));
  for(const change of [{role:'admin'},{active:true},{schoolKey:'school-b'},{channelIds:['private']}])await assertFails(a.doc('communicationAccess/teacher-a').update(change));
  await assertFails(a.doc('communicationAccess/teacher-b').get());
  await assertSucceeds(a.doc('communicationAccess/teacher-a').get());
  await assertFails(a.doc('communicationAccess/teacher-a').delete());
 });
 await passes('teachers and admins cannot provision channels or alter ACL metadata from clients',async()=>{
  for(const db of [a,admin]){
   await assertFails(db.doc(path('school-a','new')).set(channel('school-a','new')));
   for(const change of [{readOnly:false},{kind:'adminAlerts'},{memberCount:999},{name:'Forged'}])await assertFails(db.doc(path('school-a')).update(change));
   await assertFails(db.doc(path('school-a')).delete());
  }
 });
 await passes('valid atomic teacher message and bounded ordered query succeed',async()=>{
  await assertSucceeds(send(a,{messageId:'valid-message'}));
  const m=await assertSucceeds(a.doc(path('school-a')+'/messages/valid-message').get());
  assert.equal(m.data().authorId,'teacher-a');
  assert.equal(m.data().authorRole,'teacher');
  await assertSucceeds(a.collection(path('school-a')+'/messages').orderBy('createdAt','desc').limit(40).get());
  await assertFails(a.collection(path('school-a')+'/messages').get());
  await assertFails(a.collection(path('school-a')+'/messages').limit(101).get());
  await assertFails(a.collectionGroup('messages').limit(100).get());
 });
 await passes('nonmember/cross-school/private writes denied',async()=>{
  for(const db of [anon,none,b,revoked])await assertFails(send(db));
  await assertFails(send(a,{school:'school-b'}));await assertFails(send(a,{id:'private'}));
 });
 await passes('forged UID, role, name, school, channel and message ID denied',async()=>{
  for(const patch of [{authorId:'admin-a'},{authorRole:'admin'},{authorName:'School Principal'},{schoolKey:'school-b'},{channelId:'private'},{messageId:'different'}])await assertFails(send(a,{mutate:d=>Object.assign(d,patch)}));
 });
 await passes('self-written profile does not grant admin authority',async()=>{
  await assertSucceeds(a.doc('users/teacher-a/profile/self').set({role:'admin',schoolKey:'school-a'}));
  await assertFails(send(a,{id:'admin-alerts',isAlert:true,severity:'urgent',role:'admin'}));
 });
 await passes('only trusted admin in the channel can publish an alert',async()=>{
  await assertFails(send(a,{id:'admin-alerts',isAlert:true}));
  await assertSucceeds(send(admin,{uid:'admin-a',role:'admin',name:'Fictional Admin',id:'admin-alerts',isAlert:true,severity:'urgent'}));
  await assertFails(send(admin,{uid:'admin-a',role:'admin',name:'Fictional Admin',id:'private'}));
  await assertFails(send(a,{isAlert:true,severity:'urgent'}));
 });
 await passes('messages immutable; no update bypass, hijack or delete',async()=>{
  const m=a.doc(path('school-a')+'/messages/valid-message');
  for(const change of [{text:'Edited'},{authorId:'other'},{authorRole:'admin'},{createdAt:now},{extra:'injected'},{text:'x'.repeat(4001)}])await assertFails(m.update(change));
  await assertFails(m.delete());await assertFails(admin.doc(m.path).delete());
 });
 await passes('invalid types, missing/extra fields, empty/oversized body and timestamp manipulation denied',async()=>{
  for(const mutate of [d=>d.text='',d=>d.text='x'.repeat(4001),d=>d.text=45,d=>d.createdAt=now,d=>d.createdAt='today',d=>delete d.text,d=>d.extra='pollution',d=>d.isAlert='true',d=>d.severity='invalid'])await assertFails(send(a,{mutate}));
 });
 await passes('preview cannot be forged, replayed or committed without its new message',async()=>{
  await assertFails(send(a,{summary:false}));
  await assertFails(send(a,{summaryMutate:s=>s.lastMessagePreview='Forged preview'}));
  await assertFails(send(a,{summaryMutate:s=>s.lastSenderName='Principal'}));
  await assertFails(a.doc(path('school-a')).update({lastMessageId:'valid-message',lastMessagePreview:'Fictional test message',lastSenderName:'Fictional Teacher',lastMessageAt:stamp(),updatedAt:stamp()}));
 });
 await passes('orphan subcollections denied even to granted member',async()=>{
  await env.withSecurityRulesDisabled(ctx=>ctx.firestore().doc('communicationAccess/teacher-a').update({channelIds:['staff','ghost']}));
  await assertFails(a.doc(path('school-a','ghost')+'/messages/unknown').get());
  await assertFails(send(a,{id:'ghost'}));
 });
 await passes('revocation takes effect on future server reads and writes',async()=>{
  await env.withSecurityRulesDisabled(ctx=>ctx.firestore().doc('communicationAccess/teacher-a').update({active:false}));
  await assertFails(a.doc(path('school-a')).get());await assertFails(send(a));
 });
 await passes('academic ownership remains intact; no cross-user PII access',async()=>{
  await assertSucceeds(a.doc('users/teacher-a/classes/fictional').set({name:'Fictional class'}));
  await assertFails(b.doc('users/teacher-a/classes/fictional').get());
  await assertFails(b.doc('users/teacher-a/classes/fictional').update({name:'Hijacked'}));
 });
 console.log(`Communication security: ${count} attack/acceptance groups passed.`);
}finally{await env.cleanup();}
