import {readFileSync} from 'node:fs';
import {initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {initializeApp,deleteApp} from 'firebase/app';
import {getAuth,connectAuthEmulator,createUserWithEmailAndPassword} from 'firebase/auth';
import firebase from 'firebase/compat/app';
import 'firebase/compat/firestore';
const projectId='demo-gradeflow-communication-security';
const env=await initializeTestEnvironment({projectId,firestore:{host:'127.0.0.1',port:8180,rules:readFileSync('firestore.rules','utf8')}});
const app=initializeApp({projectId,apiKey:'emulator-only-not-a-real-api-key',appId:'1:1234567890:web:local-emulator'},'communication-fixtures');
const auth=getAuth(app);connectAuthEmulator(auth,'http://127.0.0.1:9099',{disableWarnings:true});
try{
 for(const role of ['teacher','admin','unprovisioned']){
  const c=await createUserWithEmailAndPassword(auth,`communication-${role}@example.invalid`,'Fictional-Communication123!');
  if(role!=='unprovisioned')await env.withSecurityRulesDisabled(ctx=>ctx.firestore().doc('communicationAccess/'+c.user.uid).set({active:true,schoolKey:'web-school',role,displayName:`Verified ${role}`,channelIds:['staff','admin-alerts']}));
 }
 const now=firebase.firestore.Timestamp.now();
 await env.withSecurityRulesDisabled(async ctx=>{
  for(const id of ['staff','admin-alerts'])await ctx.firestore().doc(`schools/web-school/communicationChannels/${id}`).set({channelId:id,schoolKey:'web-school',name:id,description:'Fictional SDK acceptance',kind:id==='staff'?'staffRoom':'adminAlerts',readOnly:id!=='staff',memberCount:2,sortOrder:0,createdBy:'Verified admin',createdAt:now,updatedAt:now,lastMessagePreview:null,lastSenderName:null,lastMessageAt:null});
 });
 console.log('Fictional communication SDK fixtures ready on loopback emulators.');
}finally{await deleteApp(app);await env.cleanup();}
