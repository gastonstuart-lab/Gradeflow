# Isolated grading-period Firestore tests

Requires Java 21, Firebase CLI, Flutter and Chrome. Uses only a loopback demo project; no credentials or real data. Production firebase.json/rules and RepositoryFactory are unchanged.

```powershell
firebase emulators:start --only 'firestore,auth' --project demo-gradeflow-periods --config test/emulator/firebase.json
# In another terminal:
flutter test --platform chrome --no-pub test/firestore_grading_period_emulator_test.dart --reporter expanded
# Windows Flutter 3.38 CanvasKit URL workaround (restores SDK source afterward):
./test/emulator/run-browser.ps1
```

The repository persists controls, one bounded document per period and create-only operation receipts under `gradingPeriodBooks/{uid}/classes/{classId}`. Transactions reject stale revisions; receipt identity is the new aggregate revision. Duplicate/stale rollover requests fail without adding a period; transparent recovery of an unknown commit outcome is not implemented. Limits: 600 KB per period, 6 MB aggregate, 50 periods; larger books fail before writing and require chunked storage later. No production wiring, UI or migration.

Rules are an emulator-only prototype: owner isolation, atomic pointer/seal transitions, immutable sealed documents and receipts, no deletes. They cannot verify serialized JSON contents or recompute grades; trusted sealing and security review remain required before any production activation. They are intentionally not production rules.

The browser test explicitly registers Firebase web plugins; three existing locked packages are direct test dependencies, with no version upgrades. Do not run other source-based Flutter tool commands while the Windows workaround temporarily patches its test asset handler. Keep the emulator running for either test command above.
