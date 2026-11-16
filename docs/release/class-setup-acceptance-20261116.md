# Class setup acceptance — 16 November 2026

Application and test source: `f7807c750c94f41c756893b15257ce524177e5aa`.
This report is a subsequent documentation-only commit.

## Verified outcome

The authenticated Chromium journey passed against the local `demo-gradeflow-v2-staging` Firebase Auth and Firestore emulators at 1440 × 900. No live school records or production Firebase endpoints were used.

| Step | Result |
| --- | --- |
| Deny class writes while allowing reads | Failed save reaches the retained creation form; no phantom class exists in durable storage. |
| Retry class creation | Exactly one class is saved and appears after a full refresh. |
| Import pupils through the real clipboard and preview | Two fictional pupils are saved. |
| Add a missing pupil | The real Add student form saves a third pupil; all three survive refresh. |
| Arrange the target room | A real Add table action creates an existing arrangement to protect. |
| Deny only target room-metadata writes | The teacher receives a failed-share message; durable layout documents and the original active selection remain intact. |
| Retry sharing after writes are restored | The room operation completes and the target opens the copied physical room after refresh. |
| Check pupil isolation | The copied active room has no source pupil assignments; the target retains its own three pupils. |
| Endpoint guard | No browser requests reached live Firebase Auth or Firestore hosts. |

The browser also exposed a repository-contract distinction: Firestore save methods update documents rather than replacing collections. Recovery now explicitly deletes newly added room/template documents when compensating a failed application, and local template cleanup checks rejected writes.

## Checks

- Full Flutter suite: **357 passed, 2 existing original-file acceptance skips**.
- Full-project Dart analysis: clean, exit code 0.
- Release Flutter web build: passed, with the same pinned pubspec and lockfile as the base.
- Teaching Studio: its unchanged TypeScript/Vite build passed and its distribution was copied into both the isolated browser bundle and the local release-check bundle.
- New authenticated class-setup browser test: **1 passed**, 6.1 minutes.
- Creation-error and room-error screenshots were visually inspected for readable feedback within the viewport.

The final full test run used:
`flutter test --no-pub --reporter expanded --concurrency 2 --timeout 60s`.

The browser command, after building the guarded emulator-only debug app and including Studio, was:
```text
node staging-tests/node_modules/firebase-tools/lib/bin/firebase.js emulators:exec --project demo-gradeflow-v2-staging --config firebase.staging.json --only auth,firestore "node staging-tests/seed-browser-fixtures.mjs && node node_modules/@playwright/test/cli.js test --config=playwright.staging.config.ts --grep @class-setup"
```

The committed test installs temporary rules only in the hard-coded localhost demo emulator. It preserves signed-in owner reads, denies selected writes, and restores the original test rules in a finally block. No committed production rules or deployment workflows were changed.

## Boundaries

This is fictional-data acceptance, not real Google sign-in, real-school-file acceptance, hardware/pen acceptance, a cross-device transaction guarantee, or certification of every grade/export flow. Room compensation remains best-effort during an extended outage and reports when recovery cannot be confirmed. The older authenticated navigation/gradebook/Studio browser journey was not rerun in this session; it remains available in the same staging configuration.

The changes remain in draft PRs #140 and #141, stacked on the #137 application audit candidate. Nothing was merged or deployed. Existing release-control provenance, complete Studio-inclusive CI artifact checks, and explicit merge/release review still apply.
