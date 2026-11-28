// GradeFlow adapter for the pinned PDF.js 6.5.438 viewer.
// Keep the native editor, annotation storage and toolbar actions; separate
// ink settings from the active tool and make ordinary PDF export fail closed.
import { AnnotationEditorParamsType } from '../build/pdf.mjs';
const app = window.PDFViewerApplication;
await app.initializedPromise;
const INK = 15;
const viewer = app.pdfViewer;
const ui = () => viewer._layerProperties.annotationEditorUIManager;
const draw = document.getElementById('editorInkButton');
const panel = document.getElementById('editorInkParamsToolbar');
const nativeColor = document.getElementById('editorInkColor');
const save = document.getElementById('downloadButton');
if (!draw || !panel || !nativeColor || !save) {
  throw new Error('GradeFlow: pinned PDF.js toolbar controls missing');
}
const settings = document.createElement('button');
settings.type = 'button';
settings.id = 'gradeflowInkSettings';
settings.textContent = '⚙';
settings.title = 'Pen settings';
settings.setAttribute('aria-label', 'Pen settings');
settings.setAttribute('aria-controls', panel.id);
settings.setAttribute('aria-expanded', 'false');
settings.hidden = true;
// Keep the settings control beside the fixed-square Draw wrapper.
const inkWrapper = draw.closest('#editorInk');
if (!inkWrapper) throw new Error('GradeFlow: PDF.js Draw wrapper missing');
inkWrapper.after(settings);
function setPanel(open) {
  panel.classList.toggle('hidden', !open);
  settings.setAttribute('aria-expanded', String(open));
  draw.setAttribute('aria-expanded', String(open));
}
function syncMode() {
  const active = viewer.annotationEditorMode === INK;
  settings.hidden = !active;
  settings.setAttribute('aria-expanded', String(active && !panel.classList.contains('hidden')));
}
new MutationObserver(syncMode).observe(draw, { attributes: true, attributeFilter: ['class', 'disabled', 'aria-expanded'] });
settings.addEventListener('click', () => {
  if (viewer.annotationEditorMode === INK) setPanel(panel.classList.contains('hidden'));
});
const presets = document.createElement('div');
presets.className = 'gradeflowInkPresets';
presets.setAttribute('role', 'group');
presets.setAttribute('aria-label', 'Preset pen colours');
function finishInk() {
  ui()?.endCurrentEditing();
  ui()?.unselectAll();
}
for (const [name, color] of [['Black','#000000'], ['Red','#ff0000'], ['Blue','#0000ff'], ['Green','#008000']]) {
  const button = document.createElement('button');
  button.type = 'button';
  button.dataset.inkColor = color;
  button.setAttribute('aria-label', name);
  button.title = name;
  button.style.setProperty('--swatch', color);
  button.addEventListener('click', () => {
    if (viewer.annotationEditorMode !== INK || !ui()) return;
    finishInk();
    app.eventBus.dispatch('switchannotationeditorparams', {
      source: button, type: AnnotationEditorParamsType.INK_COLOR, value: color,
    });
    app.eventBus.dispatch('annotationeditorparamschanged', {
      source: button, details: [[AnnotationEditorParamsType.INK_COLOR, color]],
    });
    setPanel(false);
    settings.focus({ preventScroll: true });
  });
  presets.append(button);
}
const colorRow = nativeColor.closest('.editorParamsSetter');
colorRow.before(presets);
const label = colorRow.querySelector('label');
label.removeAttribute('data-l10n-id');
label.textContent = 'More colours';
nativeColor.addEventListener('focus', finishInk);
nativeColor.addEventListener('pointerdown', finishInk, { capture: true });
nativeColor.addEventListener('change', () => {
  if (viewer.annotationEditorMode === INK) {
    setPanel(false);
    settings.focus({ preventScroll: true });
  }
});
panel.addEventListener('keydown', event => {
  if (event.key === 'Escape') {
    event.preventDefault(); event.stopPropagation(); setPanel(false); settings.focus({ preventScroll: true });
  }
});
syncMode();

const status = document.createElement('div');
status.id = 'gradeflowPdfExportStatus';
status.setAttribute('role', 'status');
status.setAttribute('aria-live', 'polite');
status.hidden = true;
document.body.append(status);
let busy = false;
let statusTimer;
function report(message, temporary = false) {
  clearTimeout(statusTimer);
  status.textContent = message;
  status.hidden = false;
  if (temporary) statusTimer = setTimeout(() => { status.hidden = true; }, 6000);
}
function downloadBytes(bytes, filename) {
  if (!(bytes instanceof Uint8Array) || bytes.length < 5 || new TextDecoder().decode(bytes.subarray(0, 5)) !== '%PDF-') {
    throw new Error('PDF serialization did not return a PDF');
  }
  const url = URL.createObjectURL(new Blob([bytes], { type: 'application/pdf' }));
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.append(a);
  try { a.click(); }
  finally { a.remove(); setTimeout(() => URL.revokeObjectURL(url), 60000); }
}
async function exportPdf() {
  if (busy) return;
  const doc = app.pdfDocument;
  if (!doc) { report('Open a PDF before saving.'); return; }
  busy = true;
  for (const control of saveControls) control.setAttribute('aria-busy', 'true');
  report('Preparing PDF…');
  try {
    finishInk();
    await app.pdfScriptingManager.dispatchWillSave();
    // Never silently download the unannotated source after serialization fails.
    const bytes = await doc.saveDocument(app.externalServices.printToPDF);
    if (doc !== app.pdfDocument) throw new Error('The open PDF changed during export');
    const supplied = new URLSearchParams(location.search).get('gradeflowFilename');
    const original = (supplied || app._docFilename || 'worksheet.pdf').replace(/[\\/:*?"<>|\x00-\x1f]/g, '_');
    downloadBytes(bytes, original.replace(/\.pdf$/i, '') + '-annotated.pdf');
    report('PDF download requested. Check Downloads before closing.', true);
  } catch (error) {
    console.error('GradeFlow PDF export failed:', error);
    report('Could not export the annotated PDF. Your work remains open; try Save again.');
  } finally {
    try {
      if (doc === app.pdfDocument) await app.pdfScriptingManager.dispatchDidSave();
    } catch (error) { console.error('GradeFlow PDF post-save hook failed:', error); }
    finally {
      busy = false;
      for (const control of saveControls) control.removeAttribute('aria-busy');
    }
  }
}
// Structural page changes retain the upstream save-pages path.
const saveControls = [save, document.getElementById('secondaryDownload')].filter(Boolean);
for (const control of saveControls) {
  control.addEventListener('click', event => {
    if (app.pdfThumbnailViewer?.hasStructuralChanges()) return;
    event.preventDefault(); event.stopImmediatePropagation();
    if (control !== save) app.secondaryToolbar?.close();
    void exportPdf();
  }, { capture: true });
}
window.addEventListener('keydown', event => {
  if (!((event.ctrlKey || event.metaKey) && !event.altKey && !event.shiftKey &&
        event.key.toLowerCase() === 's') || app.pdfThumbnailViewer?.hasStructuralChanges()) return;
  if (!app.pdfDocument || event.defaultPrevented) return;
  event.preventDefault();
  event.stopImmediatePropagation();
  if (!event.repeat) void exportPdf();
}, { capture: true });
