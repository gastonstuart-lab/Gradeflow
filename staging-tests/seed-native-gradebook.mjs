// Fictional loopback-only extension of the existing browser fixture.
import './seed-browser-fixtures.mjs';
import { initializeApp, deleteApp } from 'firebase/app';
import { getAuth, connectAuthEmulator, signInWithEmailAndPassword } from 'firebase/auth';
import { getFirestore, connectFirestoreEmulator, doc, setDoc, updateDoc } from 'firebase/firestore';
const app = initializeApp({ apiKey: 'emulator-only-not-a-real-api-key', projectId: 'demo-gradeflow-v2-staging' }, 'core-workflow');
const auth = getAuth(app); connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
const db = getFirestore(app); connectFirestoreEmulator(db, '127.0.0.1', 8180);
try {
  const { user } = await signInWithEmailAndPassword(auth, 'browser-teacher@example.invalid', 'FakePassword-Teacher123!');
  const path = ['users', user.uid, 'classes', 'class-science-browser'];
  const now = new Date().toISOString();
  await updateDoc(doc(db, ...path), { courseworkWeightPercent: 40 });
  // Second fictional pupil exercises whole-column updates without touching school data.
  await setDoc(doc(db, ...path, 'students', 'synthetic-student-two'), {
    studentId: 'synthetic-student-two', classId: 'class-science-browser',
    chineseName: '虛構學生', englishFirstName: 'Supplemental',
    englishLastName: 'Pupil', seatNo: '2', createdAt: now, updatedAt: now,
  });

  await updateDoc(doc(db, ...path, 'categories', 'fictional-quizzes'), { weightPercent: 25 });
  for (const [id, name, score] of [['homework', 'Homework', 100], ['classwork', 'Classwork', 90], ['participation', 'Participation', 80]]) {
    await setDoc(doc(db, ...path, 'categories', id), { categoryId: id, classId: 'class-science-browser', name, weightPercent: 25, aggregationMethod: 'average', aggregationParam: null, isActive: true, createdAt: now, updatedAt: now });
    await setDoc(doc(db, ...path, 'gradeItems', id), { gradeItemId: id, categoryId: id, classId: 'class-science-browser', name: 'Fictional ' + name, maxScore: 100, isActive: true, createdAt: now, updatedAt: now });
    await setDoc(doc(db, ...path, 'gradeItems', id, 'scores', 'synthetic-student-one'), { studentId: 'synthetic-student-one', gradeItemId: id, score, createdAt: now, updatedAt: now });
  }
} finally { await deleteApp(app); }
