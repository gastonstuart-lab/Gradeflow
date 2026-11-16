import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp, mkdir, writeFile, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join, dirname, resolve} from 'node:path';
import {createServer} from 'node:http';
import {spawn} from 'node:child_process';

const files = ['main.dart.js', 'index.html', 'os/home', 'flutter_bootstrap.js', 'teaching-studio/', 'teaching-studio/index.html', 'teaching-studio/pdfjs/web/viewer.html', 'teaching-studio/pdfjs/web/gradeflow-pen.mjs', 'teaching-studio/pdfjs/web/gradeflow-pen.css', 'teaching-studio/pdfjs/build/pdf.worker.mjs'];
const expectedFile = path => path === 'os/home' ? 'index.html' : path === 'teaching-studio/' ? 'teaching-studio/index.html' : path;
const script = resolve('scripts/verify-hosting-release.sh');
async function verify(t, response) {
  const root = await mkdtemp(join(tmpdir(), 'gradeflow-verify-'));
  t.after(() => rm(root, {recursive:true, force:true}));
  for (const file of files) {
    const local = expectedFile(file);
    await mkdir(dirname(join(root, local)), {recursive:true});
    await writeFile(join(root, local), `verified ${local}`);
  }
  const requests = [];
  const server = createServer((req, res) => {
    const url = new URL(req.url, 'http://localhost');
    requests.push({path:url.pathname.slice(1), attempt:url.searchParams.get('attempt'), cache:req.headers['cache-control']});
    const answer = response(requests.at(-1));
    res.statusCode = answer.status ?? 200;
    res.end(answer.body ?? `verified ${expectedFile(url.pathname.slice(1))}`);
  });
  await new Promise(r => server.listen(0, '127.0.0.1', r));
  t.after(() => new Promise(r => server.close(r)));
  const child = spawn('bash', [script, root, `http://127.0.0.1:${server.address().port}`, 'review-123'], {env:{...process.env,GRADEFLOW_VERIFY_ATTEMPTS:'2',GRADEFLOW_VERIFY_DELAY_SECONDS:'0'}});
  let output = '';
  child.stdout.on('data', b => output += b);
  child.stderr.on('data', b => output += b);
  const code = await new Promise((r, reject) => {child.on('close', r);child.on('error', reject);});
  return {code, requests, output};
}
test('verifies every required Flutter and Studio file using actual HTTP bytes', async t => {
  const r = await verify(t, () => ({}));
  assert.equal(r.code, 0, r.output);
  assert.deepEqual(r.requests.map(x => x.path), files);
  assert.ok(r.requests.every(x => x.cache === 'no-cache'));
});
test('recovers from a stale viewer response rather than failing the publish receipt', async t => {
  const r = await verify(t, req => req.path.endsWith('viewer.html') && req.attempt === '1' ? {body:'old cached viewer'} : {});
  assert.equal(r.code, 0, r.output);
  assert.deepEqual(r.requests.filter(x => x.path.endsWith('viewer.html')).map(x => x.attempt), ['1','2']);
});
test('retries an HTTP error and still checks the returned bytes', async t => {
  const r = await verify(t, req => req.path === 'main.dart.js' && req.attempt === '1' ? {status:503,body:'unavailable'} : {});
  assert.equal(r.code, 0, r.output);
  assert.equal(r.requests.filter(x => x.path === 'main.dart.js').length, 2);
});
test('persistent wrong bytes exhaust the bound and fail verification', async t => {
  const r = await verify(t, () => ({body:'wrong build'}));
  assert.equal(r.code, 1, r.output);
  assert.equal(r.requests.length, 2);
  assert.match(r.output, /Published bytes do not match: main.dart.js/);
});
