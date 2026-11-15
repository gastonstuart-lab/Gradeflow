import { test, expect } from '@playwright/test';
import { readFile } from 'node:fs/promises';

function worksheet() {
  const objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 2 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 5 0 R >> >> /Contents 6 0 R >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 5 0 R >> >> /Contents 7 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    ...[1, 2].map(n => { const stream = `BT /F1 22 Tf 55 770 Td (Fictional worksheet page ${n}) Tj ET\n`; return `<< /Length ${Buffer.byteLength(stream)} >>\nstream\n${stream}endstream`; }),
  ];
  let pdf = '%PDF-1.7\n'; const offsets = [0];
  objects.forEach((object, index) => { offsets.push(Buffer.byteLength(pdf)); pdf += `${index + 1} 0 obj\n${object}\nendobj\n`; });
  const xref = Buffer.byteLength(pdf);
  pdf += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
  pdf += offsets.slice(1).map(offset => `${String(offset).padStart(10, '0')} 00000 n \n`).join('');
  pdf += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
  return Buffer.from(pdf);
}

async function ready(page, testInfo) {
  const outside = [];
  page.on('request', request => { const url = new URL(request.url());
    if (url.protocol.startsWith('http') && url.hostname !== '127.0.0.1') outside.push(url.origin);
  });
  await page.goto('/');
  await expect(page.getByRole('button', { name: 'Save board', exact: true })).toBeEnabled();
  if (testInfo.project.name.endsWith('dark')) await page.getByRole('button', { name: 'Dark theme', exact: true }).click();
  return outside;
}

async function saveScene(page) {
  const [download] = await Promise.all([page.waitForEvent('download'), page.getByRole('button', { name: 'Save board', exact: true }).click()]);
  return JSON.parse(await readFile(await download.path(), 'utf8'));
}

test('pen drawing, editable save/open, invalid-file preservation and image export', async ({ page }, testInfo) => {
  const outside = await ready(page, testInfo);
  const canvas = page.locator('canvas.interactive');
  await expect(canvas).toBeVisible();
  const box = await canvas.boundingBox();
  const x = box.x + box.width * .45, y = box.y + box.height * .5;
  await page.mouse.click(x, y); await page.keyboard.press('p');
  const pen = await page.context().newCDPSession(page);
  await pen.send('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', buttons: 1, pointerType: 'pen', force: .2 });
  for (let i = 1; i <= 25; i++) await pen.send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: x + i * 5, y: y + Math.sin(i / 5) * 35, button: 'left', buttons: 1, pointerType: 'pen', force: .2 + i / 40 });
  await pen.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: x + 125, y: y + Math.sin(5) * 35, button: 'left', buttons: 0, pointerType: 'pen', force: 0 });
  const scene = await saveScene(page);
  expect(scene.type).toBe('excalidraw');
  const strokes = scene.elements.filter(e => e.type === 'freedraw' && !e.isDeleted);
  expect(strokes.length).toBeGreaterThan(0);
  expect(strokes[0].points.length).toBeGreaterThan(5);
  expect(strokes[0].pressures.length).toBeGreaterThan(0);
  if (testInfo.project.name.startsWith('surface')) {
    await pen.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: x + 150, y: y + 60, radiusX: 30, radiusY: 20 }] });
    await pen.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: x + 180, y: y + 90, radiusX: 30, radiusY: 20 }] });
    await pen.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    const afterPalm = await saveScene(page);
    expect(afterPalm.elements.filter(e => e.type === 'freedraw' && !e.isDeleted)).toHaveLength(strokes.length);
  }
  await page.getByTestId('board-file').setInputFiles({ name: 'bad.excalidraw', mimeType: 'application/json', buffer: Buffer.from('{}') });
  await expect(page.getByRole('status')).toContainText('Could not open');
  const preserved = await saveScene(page);
  expect(preserved.elements.filter(e => !e.isDeleted).map(e => e.id)).toEqual(scene.elements.filter(e => !e.isDeleted).map(e => e.id));
  await page.getByTestId('board-file').setInputFiles({ name: 'lesson.excalidraw', mimeType: 'application/json', buffer: Buffer.from(JSON.stringify(scene)) });
  await expect(page.getByRole('status')).toContainText('Opened lesson.excalidraw');
  const [png] = await Promise.all([page.waitForEvent('download'), page.getByRole('button', { name: 'Export PNG', exact: true }).click()]);
  const bytes = await readFile(await png.path());
  expect(bytes.subarray(1, 4).toString()).toBe('PNG');
  await page.getByRole('button', { name: 'Start', exact: true }).click();
  await expect(page.getByLabel('Time remaining')).not.toHaveText('05:00');
  await page.getByRole('button', { name: 'Pause', exact: true }).click();
  await page.screenshot({ path: testInfo.outputPath('whiteboard.png') });
  expect(outside).toEqual([]);
});

test('real PDF editor writes ink and saves a two-page annotated copy', async ({ page }, testInfo) => {
  const outside = await ready(page, testInfo);
  await page.getByRole('button', { name: 'Annotate PDF', exact: true }).click();
  await page.getByTestId('pdf-file').setInputFiles({ name: 'fictional-worksheet.pdf', mimeType: 'application/pdf', buffer: worksheet() });
  const frame = page.frameLocator('iframe[title="PDF annotation editor"]');
  await expect(frame.locator('#numPages')).toContainText('2');
  await expect(frame.locator('#editorInkButton')).toBeVisible();
  await frame.locator('#editorInkButton').click();
  const paper = frame.locator('.page[data-page-number="1"]');
  await expect(paper.locator('canvas')).toBeVisible();
  const bounds = await paper.boundingBox();
  await page.mouse.move(bounds.x + bounds.width * .25, bounds.y + bounds.height * .25);
  await page.mouse.down();
  for (let i = 1; i <= 20; i++) await page.mouse.move(bounds.x + bounds.width * (.25 + i * .01), bounds.y + bounds.height * .25 + Math.sin(i / 3) * 15);
  await page.mouse.up();
  await frame.locator('#editorInkButton').click();
  await expect(paper.locator('.inkEditor')).toHaveCount(1);
  const [download] = await Promise.all([page.waitForEvent('download'), frame.locator('#downloadButton').click()]);
  const saved = await readFile(await download.path());
  expect(saved.subarray(0, 5).toString()).toBe('%PDF-');
  const info = await frame.locator('body').evaluate(async (_, data) => {
    const pdfjs = await import('/pdfjs/build/pdf.mjs');
    const doc = await pdfjs.getDocument({ data: new Uint8Array(data), isEvalSupported: false }).promise;
    try {
      const page = await doc.getPage(1);
      const annotations = await page.getAnnotations();
      const text = await page.getTextContent();
      return { pages: doc.numPages, ink: annotations.filter(a => a.annotationType === 15).length, text: text.items.map(item => item.str || '').join(' ') };
    } finally { await doc.destroy(); }
  }, Array.from(saved));
  expect(info.pages).toBe(2); expect(info.ink).toBeGreaterThan(0);
  expect(info.text).toContain('Fictional worksheet page 1');
  await page.screenshot({ path: testInfo.outputPath('pdf-annotation.png') });
  expect(outside).toEqual([]);
});
