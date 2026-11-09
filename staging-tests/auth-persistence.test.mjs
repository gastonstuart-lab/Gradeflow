import assert from 'node:assert/strict';
import { initializeApp, deleteApp } from 'firebase/app';
import {
  getAuth,
  connectAuthEmulator,
  createUserWithEmailAndPassword,
  signInWithEmailAndPassword,
  signOut,
} from 'firebase/auth';
import {
  getFirestore,
  connectFirestoreEmulator,
  doc,
  collection,
  setDoc,
  getDoc,
  getDocs,
  updateDoc,
} from 'firebase/firestore';

// The SDKs below use the *actual* Firebase Auth and Firestore clients,
// but only connect to local emulators on loopback. Never use production
// credentials, real teacher names or student records in this fixture.
const projectId = 'demo-gradeflow-v2-staging';
const appConfig = {
  apiKey: 'emulator-only-not-a-real-api-key',
  appId: '1:1234567890:web:local-emulator',
  authDomain: `${projectId}.firebaseapp.com`,
  projectId,
};
const appA = initializeApp(appConfig, 'gradeflow-teacher-a-test');
const appB = initializeApp(appConfig, 'gradeflow-teacher-b-test');
const authA = getAuth(appA);
const authB = getAuth(appB);
connectAuthEmulator(authA, 'http://127.0.0.1:9099', {
  disableWarnings: true,
});
connectAuthEmulator(authB, 'http://127.0.0.1:9099', {
  disableWarnings: true,
});
const dbA = getFirestore(appA);
const dbB = getFirestore(appB);
connectFirestoreEmulator(dbA, '127.0.0.1', 8180);
connectFirestoreEmulator(dbB, '127.0.0.1', 8180);

async function denied(action, label) {
  try {
    await action();
    assert.fail(`Unexpectedly authorized: ${label}`);
  } catch (error) {
    if (error?.code !== 'permission-denied') {
      throw new Error(`Expected permission-denied for ${label}; received ${String(error)}`);
    }
  }
}

try {
  const teacherA = await createUserWithEmailAndPassword(
    authA, 'fictional-a@example.invalid', 'FakePassword-A123!',
  );
  const teacherB = await createUserWithEmailAndPassword(
    authB, 'fictional-b@example.invalid', 'FakePassword-B123!',
  );
  const uidA = teacherA.user.uid;
  const uidB = teacherB.user.uid;
  assert.notEqual(uidA, uidB);

  const aClass = doc(dbA, 'users', uidA, 'classes', 'class-science');
  const aSeats = doc(dbA, 'users', uidA, 'classes', 'class-science',
    'seatingLayouts', 'room-v2');
  const aStudent = doc(dbA, 'users', uidA, 'classes', 'class-science',
    'students', 'fictional-student-1');
  const aGradeItem = doc(dbA, 'users', uidA, 'classes', 'class-science',
    'gradeItems', 'quiz-1');
  const aScore = doc(dbA, 'users', uidA, 'classes', 'class-science',
    'gradeItems', 'quiz-1', 'scores', 'fictional-student-1');
  const bClass = doc(dbB, 'users', uidB, 'classes', 'class-math');
  const aClassFromB = doc(dbB, 'users', uidA, 'classes', 'class-science');
  const aSeatFromB = doc(dbB, 'users', uidA, 'classes', 'class-science',
    'seatingLayouts', 'room-v2');
  const aScoreFromB = doc(dbB, 'users', uidA, 'classes', 'class-science',
    'gradeItems', 'quiz-1', 'scores', 'fictional-student-1');

  // Actual Firebase Authentication is used to save a complete fictional
  // class workflow including furniture geometry and grading.
  await setDoc(aClass, { classId: 'class-science', teacherId: uidA,
    className: 'Synthetic Science' });
  await setDoc(aSeats, {
    layoutId: 'room-v2',
    tables: [{ tableId: 'table-1', x: 320, y: 250, width: 160, height: 90 }],
    seats: [{ seatId: 'seat-1', tableId: 'table-1',
      studentId: 'fictional-student-1', x: 80, y: 48 }],
  });
  await setDoc(aStudent, { studentId: 'fictional-student-1',
    name: 'Fictional Pupil' });
  await setDoc(aGradeItem, { gradeItemId: 'quiz-1',
    name: 'Synthetic Quiz' });
  await setDoc(aScore, { studentId: 'fictional-student-1', score: 92 });
  await setDoc(bClass, { classId: 'class-math', teacherId: uidB,
    className: 'Synthetic Mathematics' });

  assert.equal((await getDoc(aClass)).data().className, 'Synthetic Science');
  assert.equal((await getDoc(aSeats)).data().tables[0].x, 320);
  assert.equal((await getDoc(aScore)).data().score, 92);
  const aClasses = await getDocs(collection(dbA, 'users', uidA, 'classes'));
  assert.equal(aClasses.size, 1);

  await denied(() => getDoc(aClassFromB), 'teacher B reads teacher A class');
  await denied(() => getDoc(aSeatFromB), 'teacher B reads teacher A seating');
  await denied(() => getDoc(aScoreFromB), 'teacher B reads teacher A grades');
  await denied(() => setDoc(aClassFromB, { className: 'Tampered' }),
    'teacher B overwrites teacher A class');
  await denied(() => getDoc(doc(dbA, 'schools', 'school-one',
    'communicationChannels', 'messages')),
    'teacher A reads school-wide communications');

  // Log out and confirm a cached document cannot be read while signed out,
  // then log in again to verify durable persistence across auth sessions.
  await signOut(authA);
  await denied(() => getDoc(aClass), 'signed-out teacher reads private class');
  await signInWithEmailAndPassword(authA,
    'fictional-a@example.invalid', 'FakePassword-A123!');
  assert.equal((await getDoc(aSeats)).data().seats[0].studentId,
    'fictional-student-1');
  assert.equal((await getDoc(aScore)).data().score, 92);
  await updateDoc(aSeats, { 'tables.0.x': 430 });
  const reopened = (await getDoc(aSeats)).data();
  assert.equal(reopened.seats[0].studentId, 'fictional-student-1');

  process.stdout.write(
    'PASS: emulator auth, isolated classes, seating, grades and session persistence\\n',
  );
} finally {
  await signOut(authA).catch(() => {});
  await signOut(authB).catch(() => {});
  await deleteApp(appA);
  await deleteApp(appB);
}
