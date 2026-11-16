import { createHash } from 'node:crypto';
import { cp, mkdir, writeFile, readFile, access, rm } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

const version = '6.5.438';
const expected = '55138aa33b5f1f6f68809895338b947f395f344eb6381d424b2420d6daa6a844';
const root = resolve('public');
await mkdir(root, { recursive: true });
let installed = false;
try {
  installed = (await readFile(join(root, 'pdfjs-version.txt'), 'utf8')).trim() === `${version} ${expected}`;
  await access(join(root, 'pdfjs/web/viewer.html'));
} catch { installed = false; }
if (!installed) {
  const response = await fetch(`https://github.com/mozilla/pdf.js/releases/download/v${version}/pdfjs-${version}-legacy-dist.zip`);
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
// Reapply the adapter on every build, including a cached vendor extraction.
// Do not modify the upstream PDF.js bundle or its source map.
await cp('scripts/pdf-pen.mjs', join(root, 'pdfjs/web/gradeflow-pen.mjs'));
await cp('scripts/pdf-pen.css', join(root, 'pdfjs/web/gradeflow-pen.css'));
const viewerPath = join(root, 'pdfjs/web/viewer.html');
let viewer = await readFile(viewerPath, 'utf8');
if (!viewer.includes('src="gradeflow-pen.mjs"')) {
  if (!viewer.includes('</head>')) throw Error('PDF.js viewer head missing');
  viewer = viewer.replace('</head>', '<script type="module" src="gradeflow-pen.mjs"></script>\n<link rel="stylesheet" href="gradeflow-pen.css">\n</head>');
  await writeFile(viewerPath, viewer);
}
if (!viewer.includes('href="gradeflow-pen.css"')) {
  viewer = viewer.replace('</head>', '<link rel="stylesheet" href="gradeflow-pen.css">\n</head>');
  await writeFile(viewerPath, viewer);
}
console.log(`Self-hosted PDF.js ${version} (checksum verified) and Excalidraw fonts. No CDN needed at runtime.`);

