import { initializeApp, deleteApp } from 'firebase/app';
import { getAuth, connectAuthEmulator, createUserWithEmailAndPassword,
  signOut } from 'firebase/auth';
import { getFirestore, connectFirestoreEmulator, doc, setDoc } from 'firebase/firestore';

const projectId = 'demo-gradeflow-v2-staging';
const app = initializeApp({
  apiKey: 'emulator-only-not-a-real-api-key',
  appId: '1:1234567890:web:local-emulator',
  authDomain: projectId + '.firebaseapp.com',
  projectId,
}, 'gradeflow-browser-fixture');
const auth = getAuth(app);
connectAuthEmulator(auth, 'http://127.0.0.1:9099', {
  disableWarnings: true,
});
const db = getFirestore(app);
connectFirestoreEmulator(db, '127.0.0.1', 8180);

try {
  const credential = await createUserWithEmailAndPassword(
    auth, 'browser-teacher@example.invalid', 'FakePassword-Teacher123!');
  const uid = credential.user.uid;
  const now = new Date().toISOString();
  const classes = [
    { classId: 'class-science-browser', className: 'Synthetic Science 2B',
      subject: 'Science', schoolYear: '2026-2027', term: 'Fall',
      teacherId: uid, createdAt: now, updatedAt: now, isArchived: false },
    { classId: 'class-english-browser', className: 'Synthetic English 1A',
      subject: 'English', schoolYear: '2026-2027', term: 'Fall',
      teacherId: uid, createdAt: now, updatedAt: now, isArchived: false },
  ];
  for (const cls of classes) {
    await setDoc(doc(db, 'users', uid, 'classes', cls.classId), cls);
  }
  const classPath = ['users', uid, 'classes', 'class-science-browser'];
  await setDoc(doc(db, ...classPath, 'students', 'synthetic-student-one'), {
    studentId: 'synthetic-student-one',
    classId: 'class-science-browser',
    chineseName: '測試學生', englishFirstName: 'Fictional',
    englishLastName: 'Pupil', seatNo: '1',
    createdAt: now, updatedAt: now,
  });
  await setDoc(doc(db, ...classPath, 'seatingLayouts', 'synthetic-layout'), {
    layoutId: 'synthetic-layout', classId: 'class-science-browser',
    name: 'Synthetic Room',
    canvasWidth: 1600, canvasHeight: 1200,
    tables: [{ tableId: 'table-one', type: 'rectangular',
      label: 'Science table', x: 450, y: 400,
      seatCount: 1, width: 190, height: 90 }],
    seats: [{ seatId: 'seat-one', tableId: 'table-one', x: 100, y: 50,
      studentId: 'synthetic-student-one', statusColor: 'none',
      locked: false, note: '', reminder: false }],
    createdAt: now, updatedAt: now,
  });
  await setDoc(doc(db, ...classPath, 'gradeItems', 'fictional-quiz'), {
    gradeItemId: 'fictional-quiz', title: 'Fictional Quiz',
    classId: 'class-science-browser',
  });
  await setDoc(doc(db, ...classPath, 'gradeItems', 'fictional-quiz',
    'scores', 'synthetic-student-one'), {
      studentId: 'synthetic-student-one', score: 94,
  });
  process.stdout.write('Browser test fixtures created for local emulator only\\n');
} finally {
  await signOut(auth).catch(() => {});
  await deleteApp(app);
}
