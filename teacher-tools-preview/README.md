# GradeFlow Teaching Studio — isolated review

Two ready-made editors in a small teacher shell:
- @excalidraw/excalidraw 0.18.1 (MIT) for editable boards and PNG snapshots.
- Complete PDF.js 6.5.438 viewer/editor (Apache-2.0), from the official release archive, verified against its published SHA-256 digest.
- Session timer, classroom status indicators and dice.

Run npm ci, npm run build, npm run preview from this directory.
Build assets and fonts are self-hosted; no runtime CDN, Firebase, school APIs, student records, AI upload or separate service account.
The board is session-only: Save board downloads an editable .excalidraw file. PDF annotations are saved using the native PDF editor's download button. Source files are not overwritten. Browser refresh/close warns while work may be unsaved.
Opening a replacement PDF asks the teacher to save first. Board parsing occurs before resetting existing work.
Word/PowerPoint files must be exported as PDF first.

Tests exercise simulated pen pressure, pen-mode palm rejection, board round-trip, invalid-file preservation, PNG export and real PDF ink/save/reparse at 1280x900 and 1440x1000 in light/dark.
Physical Surface Pen/eraser acceptance is still required; simulated input is not hardware certification.
This is a preview only. No Flutter production files, authentication, gradebook, seating, Planner, Firebase rules or deployment target changed.

Upstream sources:
https://www.npmjs.com/package/@excalidraw/excalidraw
https://github.com/excalidraw/excalidraw/blob/v0.18.1/LICENSE
https://github.com/mozilla/pdf.js/releases/tag/v6.5.438

Licences are retained in the built static assets. Collaboration/hosted-account services are not part of this integration.
