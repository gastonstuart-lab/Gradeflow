import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';

const projectId = 'demo-gradeflow-v2-staging';
const env = await initializeTestEnvironment({
  projectId,
  firestore: {
    host: '127.0.0.1',
    port: 8180,
    rules: readFileSync('firestore.staging.rules', 'utf8'),
  },
});
try {
  const teacherA = env.authenticatedContext('teacher-a').firestore();
  const teacherB = env.authenticatedContext('teacher-b').firestore();
  const anonymous = env.unauthenticatedContext().firestore();
  const aClass = 'users/teacher-a/classes/science';
  const aSeats = 'users/teacher-a/classes/science/seatingLayouts/main';
  const aStudent = 'users/teacher-a/classes/science/students/student-one';
  const aGrade = 'users/teacher-a/classes/science/gradeItems/quiz-one';
  const aScore = 'users/teacher-a/classes/science/gradeItems/quiz-one/scores/student-one';
  const bClass = 'users/teacher-b/classes/math';
  const shared = 'schools/school-one/communicationChannels/class-news';

  // Own school-data namespace works, including nested seating plans.
  await assertSucceeds(teacherA.doc(aClass).set({ name: 'Synthetic Science' }));
  await assertSucceeds(teacherA.doc(aSeats).set({ tables: [], seats: [] }));
  await assertSucceeds(teacherA.doc(aStudent).set({ name: 'Fictional student' }));
  await assertSucceeds(teacherA.doc(aGrade).set({ title: 'Synthetic quiz' }));
  await assertSucceeds(teacherA.doc(aScore).set({ score: 92 }));
  await assertSucceeds(teacherA.doc(aClass).get());
  await assertSucceeds(teacherA.doc(aSeats).get());
  await assertSucceeds(teacherA.doc(aScore).get());
  await assertSucceeds(
    teacherA.collection('users/teacher-a/classes/science/students').get(),
  );

  // Changing the class ID must not cross the authenticated teacher boundary.
  await assertFails(teacherB.doc(aClass).get());
  await assertFails(teacherB.doc(aSeats).get());
  await assertFails(teacherB.doc(aStudent).get());
  await assertFails(teacherB.doc(aGrade).get());
  await assertFails(teacherB.doc(aScore).get());
  await assertFails(teacherB.doc(aScore).set({ score: 0 }));
  await assertFails(
    teacherB.collection('users/teacher-a/classes/science/students').get(),
  );
  await assertFails(teacherB.doc(aClass).set({ name: 'Tampered' }));
  await assertFails(teacherA.doc(bClass).set({ name: 'Tampered' }));

  // No unauthenticated access or insecure shared-school access.
  await assertFails(anonymous.doc(aClass).get());
  await assertFails(anonymous.doc(aClass).set({ name: 'Anonymous' }));
  await assertFails(teacherA.doc(shared).get());
  await assertFails(teacherA.doc(shared).set({
    schoolKey: 'school-one', body: 'Synthetic',
  }));

  // A user's own documents stay available after another user's denied write.
  const result = await teacherA.doc(aClass).get();
  assert.equal(result.data()?.name, 'Synthetic Science');
  process.stdout.write('Staging Firestore isolation: all checks passed.\\n');
} finally {
  await env.cleanup();
}
