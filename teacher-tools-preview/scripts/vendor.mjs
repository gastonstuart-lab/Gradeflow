import { createHash } from 'node:crypto';
import { cp, mkdir, writeFile, readFile, access, rm } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

const version = '6.5.438';
const expected = 'fcbe9ba21d9911843e3502adc178a7f549a524a4055f887bedc942e5490c6ba1';
const root = resolve('public');
await mkdir(root, { recursive: true });
let installed = false;
try {
  installed = (await readFile(join(root, 'pdfjs-version.txt'), 'utf8')).trim() === `${version} ${expected}`;
  await access(join(root, 'pdfjs/web/viewer.html'));
} catch { installed = false; }
if (!installed) {
  const response = await fetch(`https://github.com/mozilla/pdf.js/releases/download/v${version}/pdfjs-${version}-dist.zip`);
  if (!response.ok) throw Error(`PDF.js download failed: ${response.status}`);
  const bytes = Buffer.from(await response.arrayBuffer());
  if (createHash('sha256').update(bytes).digest('hex') !== expected) throw Error('PDF.js archive checksum mismatch');
  const zip = join(tmpdir(), `gradeflow-pdfjs-${process.pid}.zip`);
  await writeFile(zip, bytes);
  try { execFileSync('unzip', ['-q', '-o', zip, '-d', join(root, 'pdfjs')]); }
  finally { await rm(zip, { force: true }); }
  await writeFile(join(root, 'pdfjs-version.txt'), `${version} ${expected}\n`);
}
await mkdir(join(root, 'excalidraw'), { recursive: true });
await cp('node_modules/@excalidraw/excalidraw/dist/prod/fonts', join(root, 'excalidraw/fonts'), { recursive: true });
await cp('node_modules/@excalidraw/excalidraw/LICENSE', join(root, 'excalidraw/LICENSE')).catch(async () => {
  const response = await fetch('https://raw.githubusercontent.com/excalidraw/excalidraw/v0.18.1/LICENSE');
  if (!response.ok) throw Error('Excalidraw licence unavailable');
  await writeFile(join(root, 'excalidraw/LICENSE'), await response.text());
});
console.log(`Self-hosted PDF.js ${version} (checksum verified) and Excalidraw fonts. No CDN needed at runtime.`);
