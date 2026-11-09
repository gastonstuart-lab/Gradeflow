import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';

const PRODUCTION_PROJECT = 'gradeflow-20260113';
const DEMO_PROJECT = 'demo-gradeflow-v2-staging';

function get(config, name) {
  const value = String(config['GRADEFLOW_STAGING_FIREBASE_' + name] ?? '').trim();
  if (!value) throw new Error('Missing dedicated staging config: ' + name);
  return value;
}

// Validate build and deployment settings before any web build, login or CLI
// authentication. This must never read lib/firebase_options.dart or .firebaserc.
export function validateOnlineStaging(config, { requireServiceAccount = false } = {}) {
  if (config.GRADEFLOW_PLANNER_V2_STAGING !== 'true') {
    throw new Error('Staging guard must be enabled before deployment');
  }
  if (config.GRADEFLOW_V2_LOCAL_EMULATORS === 'true') {
    throw new Error('Local emulators are forbidden in an online staging deploy');
  }
  const id = get(config, 'PROJECT_ID');
  if (!/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(id) ||
      id === PRODUCTION_PROJECT || id === DEMO_PROJECT ||
      /^gradeflow-20260113(?:-|$)/.test(id)) {
    throw new Error('Project ID is invalid, production, or an emulator-only demo');
  }

  const apiKey = get(config, 'API_KEY');
  if (/emulator|fake|placeholder|not-a-real/i.test(apiKey)) {
    throw new Error('An emulator-only or placeholder web API key is forbidden');
  }
  const senderId = get(config, 'SENDER_ID');
  if (!/^\d+$/.test(senderId)) throw new Error('Sender ID must be numeric');
  const appId = get(config, 'APP_ID');
  if (!appId.startsWith('1:' + senderId + ':web:') ||
      !/^1:\d+:web:[A-Za-z0-9]+$/.test(appId)) {
    throw new Error('Web app ID does not match the staging sender ID');
  }
  if (get(config, 'AUTH_DOMAIN') !== id + '.firebaseapp.com') {
    throw new Error('Authentication domain must belong to the staging project');
  }
  const bucket = get(config, 'STORAGE_BUCKET');
  if (bucket !== id + '.firebasestorage.app' &&
      bucket !== id + '.appspot.com') {
    throw new Error('Storage bucket must belong to the staging project');
  }

  if (requireServiceAccount) {
    const raw = String(config.GRADEFLOW_STAGING_FIREBASE_SERVICE_ACCOUNT_JSON ?? '');
    if (!raw) throw new Error('Missing dedicated staging service-account secret');
    let account;
    try { account = JSON.parse(raw); }
    catch { throw new Error('Staging service-account secret is not valid JSON'); }
    if (account?.type !== 'service_account' ||
        account.project_id !== id ||
        typeof account.client_email !== 'string' ||
        !account.client_email.endsWith('@' + id + '.iam.gserviceaccount.com')) {
      throw new Error('Service account does not belong to the staging project');
    }
  }
  return { projectId: id };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const result = validateOnlineStaging(process.env, {
      requireServiceAccount: process.env.GRADEFLOW_REQUIRE_SERVICE_ACCOUNT === 'true',
    });
    process.stdout.write('Non-production GradeFlow staging guard passed: ' +
      result.projectId + '\n');
  } catch (error) {
    // Never print API keys or service-account JSON.
    process.stderr.write('GradeFlow staging blocked: ' + error.message + '\n');
    process.exitCode = 1;
  }
}
