import React, { useCallback, useEffect, useRef, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { Excalidraw, MainMenu, exportToBlob, loadFromBlob, serializeAsJSON } from '@excalidraw/excalidraw';
import '@excalidraw/excalidraw/index.css';
import './style.css';

type BoardAPI = Parameters<NonNullable<React.ComponentProps<typeof Excalidraw>['excalidrawAPI']>>[0];
type Mode = 'board' | 'pdf';

function download(blob: Blob, name: string) {
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a'); link.href = url; link.download = name;
  link.click(); setTimeout(() => URL.revokeObjectURL(url), 30000);
}

function TeachingTools() {
  const [seconds, setSeconds] = useState(300);
  const [duration, setDuration] = useState(300);
  const [running, setRunning] = useState(false);
  const deadline = useRef(0);
  const [signal, setSignal] = useState('Listen');
  const [dice, setDice] = useState(1);
  useEffect(() => {
    if (!running) return;
    const tick = () => {
      const remaining = Math.max(0, Math.ceil((deadline.current - Date.now()) / 1000));
      setSeconds(remaining); if (!remaining) setRunning(false);
    };
    const id = window.setInterval(tick, 200); tick();
    return () => clearInterval(id);
  }, [running]);
  return <aside className="teaching-tools" aria-label="Teaching tools">
    <span className="tool-label">ACTIVITY TIMER</span>
    <output className="clock" aria-label="Time remaining">{seconds ? `${Math.floor(seconds / 60).toString().padStart(2, '0')}:${(seconds % 60).toString().padStart(2, '0')}` : 'Time is up'}</output>
    <button onClick={() => { if (!running) deadline.current = Date.now() + seconds * 1000; setRunning(!running); }} disabled={!seconds}>{running ? 'Pause' : 'Start'}</button>
    <button onClick={() => { setRunning(false); setSeconds(duration); }}>Reset</button>
    <select aria-label="Timer duration" value={duration} onChange={e => { const value = Number(e.target.value); setDuration(value); setSeconds(value); setRunning(false); }}>
      {[1, 3, 5, 10, 15].map(n => <option value={n * 60} key={n}>{n} min</option>)}
    </select>
    <span className="divider" />
    {['Listen', 'Get ready', 'Discuss'].map((label, index) => <button key={label} className={`signal signal-${index}`} aria-pressed={signal === label} onClick={() => setSignal(label)}><i />{label}</button>)}
    <span className="divider" />
    <button onClick={() => { const values = crypto.getRandomValues(new Uint32Array(1)); setDice(values[0] % 6 + 1); }}>Roll dice <strong>{dice}</strong></button>
  </aside>;
}

function App() {
  const [mode, setMode] = useState<Mode>('board');
  const [dark, setDark] = useState(false);
  const [tools, setTools] = useState(true);
  const [focus, setFocus] = useState(false);
  const [controlsOpen, setControlsOpen] = useState(false);
  const [ready, setReady] = useState(false);
  const [status, setStatus] = useState('Session only — save your work before closing.');
  const [pdf, setPdf] = useState<{ url: string; name: string } | null>(null);
  const api = useRef<BoardAPI | null>(null);
  const boardInput = useRef<HTMLInputElement>(null);
  const pdfInput = useRef<HTMLInputElement>(null);
  const dirty = useRef(false);
  const sceneVersion = useRef('');
  const connect = useCallback((value: BoardAPI) => { api.current = value; setReady(true); }, []);
  useEffect(() => {
    const changed = () => { if (!document.fullscreenElement) { setFocus(false); setControlsOpen(false); } };
    const escape = (event: KeyboardEvent) => { if (event.key === 'Escape') { setFocus(false); setControlsOpen(false); } };
    document.addEventListener('fullscreenchange', changed);
    window.addEventListener('keydown', escape);
    return () => { document.removeEventListener('fullscreenchange', changed); window.removeEventListener('keydown', escape); };
  }, []);
  async function fullscreen() {
    if (document.fullscreenElement) { await document.exitFullscreen(); return; }
    setFocus(true); setControlsOpen(false);
    try { await document.documentElement.requestFullscreen(); }
    catch { setStatus('Browser full screen is unavailable. Focus mode is active; use F11 to hide browser controls.'); }
  }
  useEffect(() => {
    document.documentElement.dataset.theme = dark ? 'dark' : 'light';
  }, [dark]);
  useEffect(() => () => { if (pdf) URL.revokeObjectURL(pdf.url); }, [pdf]);
  useEffect(() => {
    const warn = (event: BeforeUnloadEvent) => {
      if (dirty.current || pdf) { event.preventDefault(); event.returnValue = ''; }
    };
    window.addEventListener('beforeunload', warn);
    return () => window.removeEventListener('beforeunload', warn);
  }, [pdf]);

  async function openBoard(file?: File) {
    if (!file || !api.current) return;
    if (file.size > 25 * 1024 * 1024) { setStatus('Choose a board file smaller than 25 MB.'); return; }
    if (dirty.current && !confirm('Save your current board before replacing it. Open this board anyway?')) return;
    try {
      const scene = await loadFromBlob(file, null, null);
      if (!api.current) return;
      api.current.resetScene();
      api.current.updateScene({ elements: scene.elements, appState: { ...scene.appState, theme: dark ? 'dark' : 'light' } });
      if (scene.files) api.current.addFiles(Object.values(scene.files));
      api.current.scrollToContent(); dirty.current = false;
      setStatus(`Opened ${file.name}. Save a board file to keep further edits.`);
    } catch { setStatus('Could not open this board. Use an Excalidraw board file; your current board was not replaced.'); }
  }
  function saveBoard() {
    if (!api.current) return;
    download(new Blob([serializeAsJSON(api.current.getSceneElements(), api.current.getAppState(), api.current.getFiles(), 'local')], { type: 'application/json' }), 'GradeFlow-lesson.excalidraw');
    dirty.current = false; setStatus('Editable board download started. Check your Downloads folder.');
  }
  async function savePng() {
    if (!api.current) return;
    try {
      const blob = await exportToBlob({ elements: api.current.getSceneElements(), appState: { ...api.current.getAppState(), exportBackground: true }, files: api.current.getFiles(), mimeType: 'image/png' });
      download(blob, 'GradeFlow-lesson.png'); setStatus('PNG download started. Save a board file too if you want to edit it later.');
    } catch { setStatus('Could not export an image. Add something to the board and try again.'); }
  }
  function openPdf(file?: File) {
    if (!file) return;
    if (!file.name.toLowerCase().endsWith('.pdf') || file.size > 50 * 1024 * 1024) { setStatus('Choose a PDF smaller than 50 MB. Save Word or PowerPoint documents as PDF first.'); return; }
    if (pdf && !confirm('Save your annotated PDF before opening another. Continue?')) return;
    setPdf({ name: file.name, url: URL.createObjectURL(file) }); setMode('pdf');
    setStatus('Use the PDF editor’s pen, highlighter and text tools. Download from its toolbar to save your annotated copy.');
  }
  return <div className={`studio ${focus ? 'focus-mode' : ''} ${controlsOpen ? 'controls-open' : ''}`}>
    <div id="studio-controls" className="studio-controls" ref={node => { node?.toggleAttribute('inert', focus && !controlsOpen); }}>
    <header className="studio-header">
      <div className="brand"><span className="brand-mark">G</span><div><h1>Teaching Studio</h1><p>GradeFlow · standalone review · no school records connected</p></div></div>
      <div className="header-actions">
        <button onClick={() => setTools(!tools)} aria-pressed={tools}>Teaching tools</button>
        <button onClick={() => setDark(!dark)}>{dark ? 'Light theme' : 'Dark theme'}</button>
        <button onClick={() => { setFocus(!focus); setControlsOpen(false); }}>{focus ? 'Leave focus mode' : 'Hide controls'}</button>
        <button onClick={() => { void fullscreen(); }}>Full screen</button>
      </div>
    </header>
    <div className="workspace-bar">
      <nav className="tabs" aria-label="Editor mode">
        <button aria-pressed={mode === 'board'} onClick={() => setMode('board')}>Whiteboard</button>
        <button aria-pressed={mode === 'pdf'} onClick={() => setMode('pdf')}>Annotate PDF</button>
      </nav>
      <div className="document-actions" hidden={mode !== 'board'}>
        <button disabled={!ready} onClick={() => boardInput.current?.click()}>Open board</button>
        <button disabled={!ready} onClick={saveBoard}>Save board</button>
        <button disabled={!ready} onClick={savePng}>Export PNG</button>
      </div>
      <div className="document-actions" hidden={mode !== 'pdf'}>
        <button className="primary" onClick={() => pdfInput.current?.click()}>Open PDF</button>
        <span className="filename" title={pdf?.name}>{pdf?.name ?? 'PDFs stay in your browser'}</span>
      </div>
    </div>
    <input ref={boardInput} data-testid="board-file" type="file" accept=".excalidraw,application/json" hidden onChange={e => { void openBoard(e.target.files?.[0]); e.target.value = ''; }} />
    <input ref={pdfInput} data-testid="pdf-file" type="file" accept="application/pdf,.pdf" hidden onChange={e => { openPdf(e.target.files?.[0]); e.target.value = ''; }} />
    <div hidden={!tools}><TeachingTools /></div>
    </div>
    {focus && <button className="controls-tab" aria-controls="studio-controls" aria-expanded={controlsOpen} onClick={() => setControlsOpen(!controlsOpen)}>{controlsOpen ? 'Hide controls ▴' : 'Show controls ▾'}</button>}
    <main className="editors">
      <section className={`editor-layer ${mode === 'board' ? '' : 'inactive'}`} aria-label="Whiteboard editor" aria-hidden={mode !== 'board'}>
        <Excalidraw excalidrawAPI={connect} theme={dark ? 'dark' : 'light'} name="GradeFlow lesson"
          initialData={{ appState: { penMode: true, currentItemRoughness: 0, currentItemFontFamily: 2, viewBackgroundColor: '#fffef8' } }}
          onChange={elements => { const version = elements.map(element => `${element.id}:${element.version}:${element.isDeleted}`).join('|'); if (version !== sceneVersion.current) { sceneVersion.current = version; dirty.current = true; } }}
          validateEmbeddable={() => false}>
          <MainMenu><MainMenu.DefaultItems.ClearCanvas /></MainMenu>
        </Excalidraw>
      </section>
      <section className={`editor-layer pdf-layer ${mode === 'pdf' ? '' : 'inactive'}`} aria-label="PDF editor" aria-hidden={mode !== 'pdf'}>
        {pdf ? <iframe key={pdf.url} title="PDF annotation editor" src={`/pdfjs/web/viewer.html?file=${encodeURIComponent(pdf.url)}`} allowFullScreen /> :
          <div className="empty-pdf"><span className="document-symbol">PDF</span><h2>Open a worksheet. Teach straight onto it.</h2><p>Write with your pen, highlight passages, add notes and save an annotated copy.</p><button className="primary" onClick={() => pdfInput.current?.click()}>Choose a PDF</button><small>For Word or PowerPoint, save as PDF first.</small></div>}
      </section>
    </main>
    <footer className="status" role="status" aria-label="Save and file status">{status}</footer>
  </div>;
}

createRoot(document.getElementById('root')!).render(<App />);
