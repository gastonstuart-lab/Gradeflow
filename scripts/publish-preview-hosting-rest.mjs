// Hosting-only, fixed-site preview publisher using ephemeral GitHub OIDC credentials.
// Never creates a live-channel release, Firebase project, backend or secret key.
// Official API: https://firebase.google.com/docs/hosting/api-deploy
import { readFileSync, readdirSync } from 'node:fs';
import { join, relative, sep } from 'node:path';
import { gzipSync } from 'node:zlib';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { appendFileSync } from 'node:fs';

const site = 'gradeflow-20260113';
const channel = 'classroom-v2';
const root = 'build/web';
const apiBase = 'https://firebasehosting.googleapis.com/v1beta1';
const configFile = JSON.parse(readFileSync('firebase.preview.json', 'utf8'));
const hosting = configFile.hosting;
if (!hosting || hosting.public !== root ||
    Object.keys(configFile).some((key) => key !== 'hosting') ||
    !hosting.rewrites?.some((r) => r.source === '**' && r.destination === '/index.html')) {
  throw new Error('Only the approved Hosting preview manifest is permitted');
}
if (!readFileSync(join(root, 'main.dart.js')).length) {
  throw new Error('Web preview build missing');
}

const token = execFileSync('gcloud', ['auth', 'print-access-token'], {
  encoding: 'utf8', stdio: ['ignore','pipe','pipe'],
}).trim();
if (!token) throw new Error('Workload Identity access token unavailable');

async function call(url, method = 'GET', body) {
  if (!url.startsWith(apiBase + '/') &&
      !url.startsWith('https://upload-firebasehosting.googleapis.com/upload/')) {
    throw new Error('Unexpected Hosting endpoint');
  }
  const headers = { Authorization: 'Bearer ' + token };
  if (body !== undefined) {
    headers['Content-Type'] = Buffer.isBuffer(body)
      ? 'application/octet-stream' : 'application/json';
  }
  const res = await fetch(url, {
    method, headers,
    body: body === undefined ? undefined :
      Buffer.isBuffer(body) ? body : JSON.stringify(body),
  });
  const content = await res.text();
  if (!res.ok) {
    throw new Error(method + ' Hosting API returned HTTP ' + res.status +
      ': ' + content.slice(0, 600));
  }
  return content && content.trim() ? JSON.parse(content) : {};
}

const files = [];
function walk(dir) {
  for (const name of readdirSync(dir, { withFileTypes: true })) {
    if (name.name.startsWith('.') || name.name === 'node_modules') continue;
    const path = join(dir, name.name);
    if (name.isDirectory()) walk(path);
    else if (name.isFile()) {
      const uri = '/' + relative(root, path).split(sep).join('/');
      const compressed = gzipSync(readFileSync(path));
      files.push({uri, hash: createHash('sha256').update(compressed).digest('hex'), compressed});
    }
  }
}
walk(root);
if (!files.length || !files.some((x) => x.uri === '/index.html')) {
  throw new Error('Missing preview assets');
}
console.log('Preparing read-only GradeFlow preview with ' + files.length + ' files');

const servingConfig = {
  rewrites: hosting.rewrites.map((r) => ({glob: r.source, path: r.destination})),
  headers: (hosting.headers || []).map((h) => ({
    glob: h.source,
    headers: Object.fromEntries(h.headers.map((v) => [v.key, v.value])),
  })),
};
const version = await call(apiBase + '/sites/' + site + '/versions', 'POST', {
  config: servingConfig,
});
if (!version.name?.startsWith('sites/' + site + '/versions/')) {
  throw new Error('Unexpected version resource');
}
const hashes = Object.fromEntries(files.map((f) => [f.uri, f.hash]));
let uploadRequiredHashes = new Set();
let uploadUrl;
for (let i = 0; i < files.length; i += 900) {
  const section = Object.fromEntries(files.slice(i, i+900).map((f) => [f.uri, f.hash]));
  const populated = await call(apiBase + '/' + version.name + ':populateFiles', 'POST', {
    files: section,
  });
  uploadUrl = populated.uploadUrl;
  for (const hash of populated.uploadRequiredHashes || []) uploadRequiredHashes.add(hash);
}
if (!uploadUrl?.startsWith('https://upload-firebasehosting.googleapis.com/upload/')) {
  throw new Error('Unexpected Hosting upload endpoint');
}
for (const file of files) {
  if (!uploadRequiredHashes.has(file.hash)) continue;
  await call(uploadUrl + '/' + file.hash, 'POST', file.compressed);
  uploadRequiredHashes.delete(file.hash);
}
if (uploadRequiredHashes.size) throw new Error('Some asset hashes were not uploaded');
const finalized = await call(
  apiBase + '/' + version.name + '?update_mask=status', 'PATCH',
  {status:'FINALIZED'},
);
if (finalized.status !== 'FINALIZED') throw new Error('Version not finalized');

// Never publish to sites/SITE/releases (the LIVE channel).
const previewParent = 'sites/' + site + '/channels/' + channel;
let current;
const url = apiBase + '/' + previewParent;
const lookup = await fetch(url, {headers: {Authorization: 'Bearer ' + token}});
if (lookup.status === 404) {
  current = await call(apiBase + '/sites/' + site + '/channels?channelId=' + channel,
    'POST', {ttl: '604800s'});
} else if (lookup.ok) {
  current = await lookup.json();
} else {
  throw new Error('Cannot verify preview channel: HTTP ' + lookup.status);
}
if (current.name !== previewParent ||
    !/^https:\/\/gradeflow-20260113--classroom-v2-[a-z0-9-]+\.web\.app\/?$/.test(current.url || '')) {
  throw new Error('Preview channel identity or URL failed validation');
}
const released = await call(apiBase + '/' + previewParent +
  '/releases?versionName=' + encodeURIComponent(version.name), 'POST', {});
if (!released.name?.startsWith(previewParent + '/releases/')) {
  throw new Error('Expected preview-channel release only');
}
console.log('Verified GradeFlow preview: ' + current.url);
if (process.env.GITHUB_STEP_SUMMARY) {
  appendFileSync(process.env.GITHUB_STEP_SUMMARY,
    '\n## GradeFlow PR #96 preview published\n' +
    'Live Firebase Hosting was not changed. This preview reads existing ' +
    'teacher data but blocks academic repository writes.\n\n' +
    current.url + '/os/home\n');
}
