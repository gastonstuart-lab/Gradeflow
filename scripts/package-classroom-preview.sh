#!/usr/bin/env bash
# Package the actual InstructOS main.dart preview plus its existing Teaching Studio.
# No credentials, hosting deployment, or database operations.
set -euo pipefail
test -s build/web/main.dart.js
test -s build/web/index.html
npm --prefix teacher-tools-preview ci --ignore-scripts --no-audit --no-fund
npm --prefix teacher-tools-preview run build
mkdir -p build/web/teaching-studio
cp -a teacher-tools-preview/dist/. build/web/teaching-studio/
python3 - <<'PY'
import hashlib, json, os, subprocess
from pathlib import Path
root = Path('build/web')
for rel in ('index.html','main.dart.js','flutter_bootstrap.js',
            'teaching-studio/index.html',
            'teaching-studio/pdfjs/web/gradeflow-pen.mjs',
            'teaching-studio/pdfjs/web/gradeflow-pen.css',
            'teaching-studio/pdfjs/build/pdf.worker.mjs'):
    assert (root/rel).is_file() and (root/rel).stat().st_size, rel
config = json.loads(Path('firebase.preview.json').read_text())
assert set(config) == {'hosting'}
assert config['hosting']['public'] == 'build/web'
assert any(r.get('source') == '**' and r.get('destination') == '/index.html'
           for r in config['hosting']['rewrites'])
manifest = {
    'commit': subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
    'tree': subprocess.check_output(['git','rev-parse','HEAD^{tree}'],text=True).strip(),
    'run': os.environ.get('GITHUB_RUN_ID','local'),
    'mode': 'GRADEFLOW_EXISTING_PROJECT_PREVIEW',
    'files': {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
              for p in sorted(root.rglob('*')) if p.is_file()
              and p.name != 'review-manifest.json'
              and not any(part.startswith('.') for part in p.relative_to(root).parts)}
}
(root/'review-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Packaged complete preview:',manifest['commit'],len(manifest['files']),'files')
PY
