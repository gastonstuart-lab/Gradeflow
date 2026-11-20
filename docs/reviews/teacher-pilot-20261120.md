# Combined teacher pilot review — 20 November 2026

## Candidate scope

Start from application integration `b59fa04c278782c350b62e28155499ae8bb8e36a` and preserve the complete histories of:

- #170, head `c41b80d85a1ee751f89daa9774a38c77b3930ebb`: visible Home ambient backgrounds, keeping solid cards.
- #171, head `f027ab57c319bed43ad9894b42c29146686f6352`: dock launcher and gap hit protection.
- #172, head `0c8379cc21b9181f423885fe483402b969b049ac`: consistent per-class Excel summary/detail snapshots and export busy state.

This branch is an isolated review candidate. No source PR has been merged into integration by creating it, and no production publication is included. Exact combined source and tree are recorded in the PR and CI package manifest.

## Integration review

The three source branches merged cleanly. Their shared authenticated-browser test retains both the real Classes dock click before Planner navigation and the Home/Planner dark/light appearance screenshots. The dock pointer guard covers the compact pill, not the whole screen. Gradebook export is isolated from Home/dock code. Independent source review found no blocking integration issue.

Preserve saved records, grading formulas, application navigation, Studio, dependencies, Firebase rules/auth and existing release controls. Messages remains subject to existing containment. A per-class loaded export snapshot is not a database-wide transaction or cross-device lock.

## Automated gates

Run the existing exact-head application, native Gradebook/actual Excel, Studio, authenticated class/room recovery, and appearance checks on this combined branch. Individual PR results do not certify the combination. Record final runs and any failures in the PR before recommending integration or release.

## Local fictional review

Use the existing debug-only local-emulator configuration for `demo-gradeflow-v2-staging`, with Auth on 127.0.0.1:9099, Firestore on 127.0.0.1:8180 and the complete app server on 127.0.0.1:7357. Keep the Studio subdirectory present. Never point the fictional fixture seed at production. The compiled preview must use all existing emulator/staging flags; the production-mode review artifact is not a substitute for this local-emulator build.

The fixture login is `browser-teacher@example.invalid`, password `FakePassword-Teacher123!`; these are fictional local-only credentials. The native fixture adds custom grading weights and marks to Synthetic Science 2B. Restarting emulators without export discards the fictional records.

## Surface acceptance — approximately 15 minutes

Use Edge on the Surface. Test only fictional records in the review preview.

1. **Dock, mouse and touch:** click/tap the top edge and centre of Classes. Classes must open, with no Science Hub activation. Tap gaps/padding inside the dock pill; remain on Home. Check the other dock destinations.
2. **Backgrounds:** compare Home and Planner in light/dark with Aurora, Soft dots and Neon boxes, at default and maximum intensity. Patterns should be visible; text and solid cards remain readable. Background-less Home should keep its approved appearance.
3. **Settings:** change appearance, close the modal and reload. The setting persists; no unexpected navigation occurs.
4. **Grading/export:** open Synthetic Science 2B. Enter a quiz mark, exam zero and a cleared mark; save and reopen. Change to a valid custom weighting and export. Summary/detail agree, blank marks remain blank and zero remains numeric. Repeated export clicks do not overlap operations. Controls re-enable after completion or a visible failure.
5. **Teaching tools:** open Studio. Check pen/eraser, undo, whiteboard save/reopen and PDF download/reopen on fictional content. Physical pen feel and palm rejection require your judgement.

Record each check as pass/fail, with browser, theme, source version and reproduction steps. Prior Chromium screenshots cover Neon boxes; they do not certify Edge, Aurora, Soft dots or physical Surface touch.

## Decision and rollback

Keep draft until combined CI and the bounded visual/device review are complete. A later release must use a pinned complete package, the existing protected Hosting process, a rollback backup and public-byte verification. Do not close original PRs as unused: the candidate retains their histories. Do not restore permissive Messages rules or clear teacher browser storage as rollback.
