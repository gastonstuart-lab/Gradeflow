// Adapter for the pinned PDF.js 6.5.438 viewer. Keep native PDF annotations,
// download and undo; only change the lifetime of a handwriting stroke.
const app = window.PDFViewerApplication;
await app.initializedPromise;
const INK = 15;
const viewer = app.pdfViewer;
const manager = () => viewer._layerProperties.annotationEditorUIManager;
let writing = null;
let erasing = null;

function finishStroke() {
  const ui = manager();
  ui?.currentLayer?.endDrawingSession();
  ui?.unselectAll();
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
    // Use PDF.js deletion so an erased stroke is recoverable with Undo and
    // remains deleted in downloaded PDFs, including reopened annotations.
    ui.setSelected(editor);
    ui.delete();
    ui.unselectAll();
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
  if (!isEraser(event) && erasing?.id !== event.pointerId) return false;
  // Ignore hover and keep toolbar, scrolling and other annotation tools native.
  if (!erasing && (!(event.buttons & 32) || !event.target.closest?.('.page'))) return false;
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
  if (interceptEraser(event)) return;
  if (viewer.annotationEditorMode === INK && event.button === 0 &&
      event.target.closest?.('.annotationEditorLayer')) writing = event.pointerId;
}, { capture: true });

window.addEventListener('pointermove', event => {
  if (erasing?.id === event.pointerId && !(event.buttons & 32)) {
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
  // PDF.js must receive pointerup first to finalize the curve's last point.
  // Commit synchronously after dispatch, before the next pointerdown can group.
  queueMicrotask(() => {
    if (viewer.annotationEditorMode === INK) finishStroke();
  });
}
window.addEventListener('pointerup', endPointer);
window.addEventListener('pointercancel', endPointer);
window.addEventListener('blur', () => {
  writing = null;
  erasing = null;
  if (viewer.annotationEditorMode === INK) finishStroke();
});
