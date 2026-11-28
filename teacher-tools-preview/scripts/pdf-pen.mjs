// Adapter for the pinned PDF.js 6.5.438 viewer. Keep native PDF annotations,
// download and undo; only change the lifetime of a handwriting stroke.
const app = window.PDFViewerApplication;
await app.initializedPromise;
const INK = 15;
const viewer = app.pdfViewer;
const manager = () => viewer._layerProperties.annotationEditorUIManager;
let writing = null;
let erasing = null;
let pendingStroke = false;
let finishTimer = null;
let quickErase = false;

function finishStroke() {
  const ui = manager();
  ui?.currentLayer?.endDrawingSession();
  ui?.unselectAll();
}

function finishPendingStroke() {
  clearTimeout(finishTimer);
  finishTimer = null;
  if (!pendingStroke) return;
  pendingStroke = false;
  if (viewer.annotationEditorMode === INK) finishStroke();
}

function isEraser(event) {
  // Pointer Events: inverted pen tip = button 5 / buttons bit 32.
  // A barrel button reporting right-click is intentionally left alone.
  return event.pointerType === 'pen' && (event.button === 5 || (event.buttons & 32) !== 0);
}

function eraseAt(x, y) {
  const page = document.elementFromPoint(x, y)?.closest('.page');
  if (!page) return;
  const ui = manager();
  const pageIndex = Number(page.dataset.pageNumber) - 1;
  for (const editor of [...ui.getEditors(pageIndex)]) {
    if (editor.editorType !== 'ink' || !editor.div?.isConnected) continue;
    const bounds = editor.div.getBoundingClientRect();
    const radius = 6;
    if (x < bounds.left - radius || x > bounds.right + radius ||
        y < bounds.top - radius || y > bounds.bottom + radius) continue;
    // Hit the actual curve, never the annotation's rectangular selection box.
    const curve = document.getElementById(`path_${editor._drawId}`);
    const matrix = curve?.getScreenCTM();
    if (!matrix) continue;
    const inverse = matrix.inverse();
    let hit = false;
    for (const [dx, dy] of [[0, 0], [-4, 0], [4, 0], [0, -4], [0, 4]]) {
      const point = new DOMPoint(x + dx, y + dy).matrixTransform(inverse);
      if (curve.isPointInStroke(point)) { hit = true; break; }
    }
    if (!hit) continue;
    // Use native editor removal/storage and its command history, without
    // selecting first: selection launches an async toolbar that may race with
    // immediate removal. Restore through the current layer on Undo.
    ui.addCommands({
      cmd: () => editor.remove(),
      undo: () => {
        const layer = ui.getLayer(editor.pageIndex);
        if (layer) layer.addOrRebuild(editor);
        else {
          ui.addEditor(editor);
          ui.addToAnnotationStorage(editor);
        }
      },
      mustExec: true,
    });
  }
}

function eraseTo(event) {
  const previous = erasing;
  const distance = Math.hypot(event.clientX - previous.x, event.clientY - previous.y);
  const steps = Math.max(1, Math.ceil(distance / 3));
  for (let i = 1; i <= steps; i++) {
    eraseAt(previous.x + (event.clientX - previous.x) * i / steps,
      previous.y + (event.clientY - previous.y) * i / steps);
  }
  erasing = { id: event.pointerId, x: event.clientX, y: event.clientY };
}

function interceptEraser(event) {
  if (viewer.annotationEditorMode !== INK || !manager()) return false;
  const activeButtons = isEraser(event) ? 32 : quickErase ? 1 : 0;
  if (!isEraser(event) && !quickErase && erasing?.id !== event.pointerId) return false;
  // Ignore hover and keep toolbar, scrolling and other annotation tools native.
  if (!erasing && (!(event.buttons & activeButtons) || !event.target.closest?.('.page'))) return false;
  event.preventDefault();
  event.stopImmediatePropagation();
  if (!erasing) {
    finishStroke();
    writing = null;
    erasing = { id: event.pointerId, x: event.clientX, y: event.clientY };
  }
  eraseTo(event);
  return true;
}

window.addEventListener('pointerdown', event => {
  // Also flush before the next stroke in case it arrives before our timer.
  finishPendingStroke();
  if (interceptEraser(event)) return;
  if (viewer.annotationEditorMode === INK && event.button === 0 &&
      event.target.closest?.('.annotationEditorLayer')) writing = event.pointerId;
}, { capture: true });

window.addEventListener('pointermove', event => {
  if (erasing?.id === event.pointerId && !(event.buttons & (quickErase ? 33 : 32))) {
    erasing = null;
    return;
  }
  interceptEraser(event);
}, { capture: true });

function endPointer(event) {
  if (erasing?.id === event.pointerId) {
    event.preventDefault();
    event.stopImmediatePropagation();
    erasing = null;
    return;
  }
  if (writing !== event.pointerId) return;
  writing = null;
  // Wait until every PDF.js pointerup listener has finalized the last point.
  // A microtask can run between native event listeners, so use a task instead.
  pendingStroke = true;
  finishTimer = setTimeout(finishPendingStroke, 0);
}
window.addEventListener('pointerup', endPointer);
window.addEventListener('pointercancel', endPointer);
window.addEventListener('blur', () => {
  finishPendingStroke();
  writing = null;
  erasing = null;
  if (viewer.annotationEditorMode === INK) finishStroke();
});


// A large, direct pen/eraser switch works with mouse, touch and Surface pen.
// The actual annotation and undo implementation remains native PDF.js.
const toolbar = document.createElement('div');
toolbar.className = 'gradeflow-ink-tools';
toolbar.setAttribute('role', 'group');
toolbar.setAttribute('aria-label', 'Quick PDF ink tools');
const inkButton = document.getElementById('editorInkButton');
function tool(label, title) {
  const button = document.createElement('button');
  button.type = 'button';
  button.textContent = label;
  button.title = title;
  button.setAttribute('aria-pressed', 'false');
  toolbar.append(button);
  return button;
}
const penTool = tool('Pen', 'Write with the PDF pen');
const eraseTool = tool('Eraser', 'Erase individual ink strokes (undo supported)');
const colourTool = tool('Colour & width', 'Open the native PDF pen colour and thickness controls');
function refreshQuickTools() {
  const inInk = viewer.annotationEditorMode === INK;
  if (!inInk) quickErase = false;
  penTool.setAttribute('aria-pressed', String(inInk && !quickErase));
  eraseTool.setAttribute('aria-pressed', String(inInk && quickErase));
  toolbar.classList.toggle('is-erasing', inInk && quickErase);
  toolbar.hidden = !app.pdfDocument;
  document.documentElement.classList.toggle('gradeflow-quick-erase', inInk && quickErase);
}
function enableInk(erase) {
  if (!inkButton || !app.pdfDocument) return;
  finishPendingStroke();
  if (viewer.annotationEditorMode === INK) finishStroke();
  else inkButton.click();
  quickErase = erase;
  // Native mode switches may complete asynchronously; the next mode event
  // also updates pressed state and clears erasing if another tool is chosen.
  if (viewer.annotationEditorMode === INK) refreshQuickTools();
}
penTool.addEventListener('click', () => enableInk(false));
eraseTool.addEventListener('click', () => enableInk(true));
colourTool.addEventListener('click', () => {
  enableInk(false);
  const show = () => {
    const popup = document.getElementById('editorInkParamsToolbar');
    const colour = document.getElementById('editorInkColor');
    // PDF.js owns the settings and values. Never recreate annotation params.
    if (popup?.classList.contains('hidden') && inkButton) inkButton.click();
    if (colour && !colour.closest('.hidden')) colour.focus();
  };
  requestAnimationFrame(show);
});
if (inkButton) {
  document.body.append(toolbar);
  toolbar.hidden = true;
  app.eventBus.on('documentloaded', refreshQuickTools);
  app.eventBus.on('annotationeditormodechanged', refreshQuickTools);
  app.eventBus.on('pagesloaded', refreshQuickTools);
  refreshQuickTools();
}
