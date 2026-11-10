import test from 'node:test';
import assert from 'node:assert/strict';
import { validateOnlineStaging } from './online-project-guard.mjs';

const id = 'gradeflow-staging-2026';
const config = {
  GRADEFLOW_PLANNER_V2_STAGING: 'true',
  GRADEFLOW_V2_LOCAL_EMULATORS: 'false',
  GRADEFLOW_STAGING_FIREBASE_PROJECT_ID: id,
  GRADEFLOW_STAGING_FIREBASE_API_KEY: 'AIza-FICTIONAL-STAGING-TEST-KEY',
  GRADEFLOW_STAGING_FIREBASE_APP_ID: '1:123456789:web:abc123',
  GRADEFLOW_STAGING_FIREBASE_SENDER_ID: '123456789',
  GRADEFLOW_STAGING_FIREBASE_AUTH_DOMAIN: id + '.firebaseapp.com',
  GRADEFLOW_STAGING_FIREBASE_STORAGE_BUCKET: id + '.firebasestorage.app',
  GRADEFLOW_STAGING_FIREBASE_SERVICE_ACCOUNT_JSON: JSON.stringify({
    type: 'service_account', project_id: id,
    client_email: 'staging-deployer@' + id + '.iam.gserviceaccount.com',
  }),
};
const check = (overrides, requireServiceAccount = false) =>
  validateOnlineStaging({ ...config, ...overrides }, { requireServiceAccount });
const rejects = (overrides, reason, requireServiceAccount = false) =>
  assert.throws(() => check(overrides, requireServiceAccount), reason);

test('accepts dedicated fictional staging options and matching deploy account', () => {
  assert.equal(check({}, true).projectId, id);
});

test('blocks production, synthetic-emulator and production-derived projects', () => {
  for (const project of ['gradeflow-20260113', 'demo-gradeflow-v2-staging',
    'gradeflow-20260113-staging']) {
    rejects({ GRADEFLOW_STAGING_FIREBASE_PROJECT_ID: project }, /project ID/i);
  }
});

test('requires staging flag and blocks any local-emulator deployment', () => {
  rejects({ GRADEFLOW_PLANNER_V2_STAGING: 'false' }, /staging guard/i);
  rejects({ GRADEFLOW_V2_LOCAL_EMULATORS: 'true' }, /emulators/i);
});

test('refuses missing, fake and cross-project Firebase options', () => {
  rejects({ GRADEFLOW_STAGING_FIREBASE_API_KEY: '' }, /missing/i);
  rejects({ GRADEFLOW_STAGING_FIREBASE_API_KEY: 'emulator-only-not-a-real-api-key' }, /placeholder/i);
  rejects({ GRADEFLOW_STAGING_FIREBASE_APP_ID: '1:00000000:web:abc123' }, /app ID/i);
  rejects({ GRADEFLOW_STAGING_FIREBASE_SENDER_ID: 'not-numeric' }, /sender ID/i);
  rejects({ GRADEFLOW_STAGING_FIREBASE_AUTH_DOMAIN: 'gradeflow-20260113.firebaseapp.com' }, /domain/i);
  rejects({ GRADEFLOW_STAGING_FIREBASE_STORAGE_BUCKET: 'gradeflow-20260113.appspot.com' }, /bucket/i);
});

test('does not accept missing, malformed, production or foreign deploy credentials', () => {
  rejects({ GRADEFLOW_STAGING_FIREBASE_SERVICE_ACCOUNT_JSON: '' }, /missing/i, true);
  rejects({ GRADEFLOW_STAGING_FIREBASE_SERVICE_ACCOUNT_JSON: '{' }, /valid JSON/i, true);
  rejects({ GRADEFLOW_STAGING_FIREBASE_SERVICE_ACCOUNT_JSON: JSON.stringify({
    type: 'service_account', project_id: 'gradeflow-20260113',
    client_email: 'firebase-adminsdk@gradeflow-20260113.iam.gserviceaccount.com',
  }) }, /does not belong/i, true);
  rejects({ GRADEFLOW_STAGING_FIREBASE_SERVICE_ACCOUNT_JSON: JSON.stringify({
    type: 'service_account', project_id: id,
    client_email: 'deployer@gradeflow-20260113.iam.gserviceaccount.com',
  }) }, /does not belong/i, true);
});
