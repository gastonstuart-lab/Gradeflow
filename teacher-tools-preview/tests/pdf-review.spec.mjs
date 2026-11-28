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


async function openPdf(page) {
  const outside = [];
  const url = process.env.GRADEFLOW_STUDIO_URL || '/?classId=fictional-class';
  const origin = new URL(url, 'http://127.0.0.1:4173').origin;
  page.context().on('request', request => {
    const u = new URL(request.url());
    if (u.protocol.startsWith('http') && u.origin !== origin) outside.push(u.origin);
  });
  await page.goto(url);
  await page.getByRole('button',{name:'Annotate PDF',exact:true}).click();
  await page.getByTestId('pdf-file').setInputFiles({name:'fictional-worksheet.pdf',mimeType:'application/pdf',buffer:worksheet()});
  const frame = page.frameLocator('iframe[title="PDF annotation editor"]');
  await expect(frame.locator('#numPages')).toContainText('2');
  await expect(frame.locator('#editorInkButton')).toBeEnabled();
  await frame.locator('#editorInkButton').click();
  return {frame, outside};
}
async function preset(frame, name) {
  const panel = frame.locator('#editorInkParamsToolbar');
  if (!(await panel.isVisible())) await frame.locator('#gradeflowInkSettings').click();
  await frame.getByRole('button',{name,exact:true}).click();
  await expect(panel).toBeHidden();
  await expect(frame.locator('#editorInkButton')).toHaveClass(/toggled/);
}
async function stroke(page, frame, number, offset = 0) {
  const paper = frame.locator('.page[data-page-number="'+number+'"]');
  await paper.scrollIntoViewIfNeeded();
  await expect(paper.locator('canvas')).toBeVisible();
  const b = await paper.boundingBox();
  const f = await page.locator('iframe[title="PDF annotation editor"]').boundingBox();
  const x = Math.max(b.x+30,f.x+30), y = Math.max(b.y+100,f.y+130)+offset;
  expect(x+90).toBeLessThan(Math.min(b.x+b.width,f.x+f.width));
  expect(y+20).toBeLessThan(Math.min(b.y+b.height,f.y+f.height));
  await page.mouse.move(x,y); await page.mouse.down();
  await page.mouse.move(x+85,y+15,{steps:12}); await page.mouse.up();
  await expect(paper.locator('.inkEditor')).not.toHaveCount(0);
}
async function download(page,frame,trigger=()=>frame.locator('#downloadButton').click()) {
  const [file] = await Promise.all([page.waitForEvent('download'),trigger()]);
  expect(file.suggestedFilename()).toBe('fictional-worksheet-annotated.pdf');
  expect(await file.failure()).toBeNull();
  return readFile(await file.path());
}
async function parse(frame,bytes) {
  return frame.locator('body').evaluate(async (_,data) => {
    const pdfjs = await import(new URL('../build/pdf.mjs',location.href).href);
    const task = pdfjs.getDocument({data:new Uint8Array(data),isEvalSupported:false});
    const doc = await task.promise;
    try {
      const pages=[];
      for(let n=1;n<=doc.numPages;n++) {
        const p=await doc.getPage(n);
        pages.push({view:p.view, text:(await p.getTextContent()).items.map(x=>x.str||'').join(' '),
          ink:(await p.getAnnotations()).filter(x=>x.annotationType===15).map(x=>({color:Array.from(x.color||[]).slice(0,3),rect:x.rect,width:x.borderStyle?.width,paths:x.inkLists?.map(path=>Array.from(path))}))});
      }
      return pages;
    } finally { await task.destroy(); }
  },Array.from(bytes));
}
test('one-tap pen presets keep Draw active; two-page export preserves original and ink',async({page},testInfo)=>{
  const {frame,outside}=await openPdf(page);
  await preset(frame,'Black'); await stroke(page,frame,1);
  await preset(frame,'Red'); await stroke(page,frame,1,35);
  await preset(frame,'Blue'); await stroke(page,frame,2);
  await preset(frame,'Black'); await stroke(page,frame,2,35);
  await page.screenshot({path:testInfo.outputPath('preset-and-ink.png')});
  const firstBytes=await download(page,frame);
  await testInfo.attach('first-annotated.pdf',{body:firstBytes,contentType:'application/pdf'});
  const first=await parse(frame,firstBytes);
  expect(first).toHaveLength(2);
  for(let i=0;i<2;i++) {
    expect(first[i].view).toEqual([0,0,595,842]);
    expect(first[i].text).toContain('Fictional worksheet page '+(i+1));
    expect(first[i].ink).toHaveLength(2);
  }
  expect(first[0].ink.map(x=>x.color)).toEqual(expect.arrayContaining([[0,0,0],[255,0,0]]));
  expect(first[1].ink.map(x=>x.color)).toEqual(expect.arrayContaining([[0,0,255],[0,0,0]]));
  await preset(frame,'Green'); await stroke(page,frame,2,70);
  const secondBytes=await download(page,frame);
  await testInfo.attach('second-annotated.pdf',{body:secondBytes,contentType:'application/pdf'});
  const second=await parse(frame,secondBytes);
  expect(second[1].ink).toHaveLength(3);
  expect(second[1].ink.map(x=>x.color)).toContainEqual([0,128,0]);
  expect(second[0].ink).toEqual(first[0].ink);
  expect(second[1].ink).toEqual(expect.arrayContaining(first[1].ink));
  for(const p of second) for(const ink of p.ink){
    expect(ink.rect[2]).toBeGreaterThan(ink.rect[0]);
    expect(ink.rect[3]).toBeGreaterThan(ink.rect[1]);
    expect(ink.paths?.length).toBeGreaterThan(0);
    expect(ink.width).toBeGreaterThan(0);
  }
  expect(outside).toEqual([]);
});
test('serialization failure is visible and does not download the unannotated source',async({page})=>{
  const {frame,outside}=await openPdf(page);
  await preset(frame,'Red'); await stroke(page,frame,1);
  await frame.locator('body').evaluate(()=>{
    const doc=window.PDFViewerApplication.pdfDocument;
    const original=doc.saveDocument;
    window.restoreGradeFlowSave=()=>{doc.saveDocument=original;};
    doc.saveDocument=async()=>{throw new Error('Fictional injected export failure');};
  });
  const downloads=[]; page.on('download', d=>downloads.push(d));
  await frame.locator('#downloadButton').click();
  await expect(frame.locator('#gradeflowPdfExportStatus')).toContainText('Could not export');
  await expect(frame.locator('#downloadButton')).not.toHaveAttribute('aria-busy','true');
  expect(downloads).toHaveLength(0);
  await frame.locator('body').evaluate(()=>window.restoreGradeFlowSave());
  const result=await parse(frame,await download(page,frame));
  expect(result[0].ink.map(x=>x.color)).toContainEqual([255,0,0]);
  expect(outside).toEqual([]);
});
test('custom colour commits without disabling Draw and keyboard export saves it',async({page})=>{
  const {frame,outside}=await openPdf(page);
  await preset(frame,'Black'); await stroke(page,frame,1);
  await frame.locator('#gradeflowInkSettings').click();
  await frame.locator('#editorInkColor').evaluate(el=>{
    el.focus(); el.value='#aa00aa';
    el.dispatchEvent(new Event('input',{bubbles:true}));
    el.dispatchEvent(new Event('change',{bubbles:true}));
  });
  await expect(frame.locator('#editorInkParamsToolbar')).toBeHidden();
  await expect(frame.locator('#editorInkButton')).toHaveClass(/toggled/);
  await stroke(page,frame,1,35);
  await frame.locator('#gradeflowInkSettings').focus();
  const bytes=await download(page,frame,()=>page.keyboard.press('Control+s'));
  const result=await parse(frame,bytes);
  expect(result[0].ink.map(x=>x.color)).toEqual(expect.arrayContaining([[0,0,0],[170,0,170]]));
  expect(outside).toEqual([]);
});

test('hosted PDF ink remains after real fullscreen exit and downloads correctly',async({page},testInfo)=>{
  const {frame,outside}=await openPdf(page);
  await preset(frame,'Red'); await stroke(page,frame,1);
  await page.getByRole('button',{name:'Full screen',exact:true}).click();
  await expect.poll(()=>page.evaluate(()=>document.fullscreenElement===document.documentElement)).toBe(true);
  await page.getByRole('button',{name:'Show controls ▾',exact:true}).click();
  await expect(page.getByRole('button',{name:'Exit full screen',exact:true})).toBeVisible();
  await page.getByRole('button',{name:'Leave focus mode',exact:true}).click();
  await expect.poll(()=>page.evaluate(()=>document.fullscreenElement===null)).toBe(true);
  await expect(page.getByRole('button',{name:'Full screen',exact:true})).toBeVisible();
  const bytes=await download(page,frame);
  const result=await parse(frame,bytes);
  expect(result).toHaveLength(2);
  expect(result[0].ink.map(x=>x.color)).toContainEqual([255,0,0]);
  await page.screenshot({path:testInfo.outputPath('fullscreen-exit-pdf.png')});
  expect(outside).toEqual([]);
});
test('hosted fullscreen denial keeps an accessible explanation',async({page})=>{
  const {outside}=await openPdf(page);
  await page.evaluate(()=>{
    document.documentElement.requestFullscreen=()=>Promise.reject(new DOMException('Denied','NotAllowedError'));
  });
  await page.getByRole('button',{name:'Full screen',exact:true}).click();
  const status=page.getByRole('status',{name:'Save and file status'});
  await expect(status).toBeVisible();
  await expect(status).toContainText('Browser full screen is unavailable');
  await page.getByRole('button',{name:'Hide controls',exact:true}).click();
  await expect(page.getByRole('button',{name:'Show controls ▾',exact:true})).toBeVisible();
  expect(await page.evaluate(()=>document.fullscreenElement)).toBeNull();
  expect(outside).toEqual([]);
});
