# Isolated grading-period Firestore tests

Requires Java 21, Firebase CLI, Flutter and Chrome. Uses only a loopback demo project; no credentials or real data. Production firebase.json/rules and RepositoryFactory are unchanged.

```powershell
firebase emulators:start --only 'firestore,auth' --project demo-gradeflow-periods --config test/emulator/firebase.json
# In another terminal (fault injection is enabled only for automated tests):
$env:GRADEFLOW_COORDINATOR_PROJECT='demo-gradeflow-periods'
dart run tool/grading_period_coordinator.dart --test-faults
# In a third terminal:
flutter test --platform chrome --no-pub test/firestore_grading_period_emulator_test.dart --reporter expanded
# Windows Flutter 3.38 CanvasKit URL workaround (restores SDK source afterward):
./test/emulator/run-browser.ps1
# Focused trusted coordinator tests, including synthetic backup/restore:
flutter test --no-pub test/trusted_grading_coordinator_test.dart --reporter expanded
```

The repository persists controls, one bounded document per period and create-only revision receipts under `gradingPeriodBooks/{uid}/classes/{classId}`. Rollover uses the loopback trusted process; it reads and validates stored snapshots, recomputes grades with the existing pure Dart calculator, and atomically commits seal, successor, pointer and a request-digest receipt. Retain the exact `GradingRolloverRequest` (including operation ID, timestamp and weights) when the outcome is uncertain; resubmitting it recovers the receipt even after later edits/rollovers. Reusing its ID for changed intent fails. `GradingPeriodService.rollover` routes the Firestore backend through this coordinator while preserving the in-memory contract.

Limits remain 600 KB per period, 6 MB aggregate, 50 periods; oversize sources/successors fail without writes. No production wiring, UI or migration. For interface development, omit `--test-faults`; fault headers are then ignored. The server requires the exact demo project environment and all its network endpoints are fixed to loopback emulators.

Rules are an emulator-only prototype: clients can create/edit active data but cannot seal, advance pointers, forge rollover receipts, alter archived data or delete books. Snapshot validation/calculation belongs to the trusted coordinator. Emulator Auth token lookup/Admin bypass are not production authentication or IAM; review and replace that boundary before production activation. Production rules/configuration remain untouched.

The browser test explicitly registers Firebase web plugins; three existing locked packages are direct test dependencies, with no version upgrades. Do not run other source-based Flutter tool commands while the Windows workaround temporarily patches its test asset handler. Keep the emulator running for either test command above.
