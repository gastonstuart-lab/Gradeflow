# Release 1 design validation evidence

Date: 27 November 2026 (Asia/Taipei). Application source under test: `5a49ec21077fc56c472fd69ce41cf29ba259dbcb`. The evidence commit contains only docs/fixtures; its exact revision is available in this PR's commit list. This is a local synthetic characterization run, not a released feature or production sign-off.

## Baseline drift check

Before branch creation: `git rev-parse HEAD` returned `5a49ec21077fc56c472fd69ce41cf29ba259dbcb`; `git log --oneline 5a49ec21077fc56c472fd69ce41cf29ba259dbcb..origin/main` had no output. A subsequent `git fetch origin main`, `git rev-parse origin/main` and `git diff --stat 5a49ec21077fc56c472fd69ce41cf29ba259dbcb origin/main` confirmed the same SHA and an empty diff. There are no main-branch changes since the confirmed baseline. PR #180 and its discussion were read through the connected GitHub tools; its only discussion entry at investigation time was the Vercel bot's preview failure, not a changed engineering assignment.

## Environment check

Windows PowerShell; Flutter 3.38.9 stable (`67323de285`), Dart 3.10.8. `flutter pub get` succeeded using the existing dependency declarations/lockfile, with newer-package notices. No dependency or lockfile changes are included. No app launched, Firebase initialized or school account signed in. GitHub authentication was used only for repository work.

## Existing focused tests

```powershell
flutter test test/grade_item_service_test.dart test/demo_data_service_test.dart test/seating_service_test.dart test/class_schedule_service_test.dart test/student_list_screen_test.dart --reporter expanded
```

Exit 0, **19 passed**, 28 seconds reported by test runner. [Captured test output](fixtures/release1/existing-tests.txt) omits dependency-resolution chatter and replaces the workspace prefix with a repository-relative path.

Coverage: category-aware item seed naming, demo data behavior, seating/room preservation operations, user-scoped schedules and legacy adoption/clear, student sort UI. This is focused baseline evidence, not the full suite and not proof of rollover preservation.

## Synthetic calculation, Excel and repository checks

```powershell
dart format docs/fixtures/release1/preservation_test.dart
flutter test --no-pub docs/fixtures/release1/preservation_test.dart --reporter expanded
```

Exit 0, **9 passed**. [Captured output](fixtures/release1/fixture-tests.txt). Executable [fixture](fixtures/release1/preservation_test.dart) SHA-256 after formatting and analyzer annotation: `b1fd0c34fa618e174d762e1b4c0a819c1ff2df49759704c65ccd284ceea5d2e0`. The annotation changes no test behavior.

| Check | Observed result |
| --- | --- |
| Missing/null/maxima/weights | 10/20 and absent Quiz rows → 75%; null Homework row excluded, remaining 80%; weights 75/25 → process 76.25; exam 90 → final 84.5. Missing exam/empty category/all-null category remain null. Inactive item excluded. |
| Aggregation | Scores 20/60/100 → average 60, sum 180, best 2 average 80, drop lowest 1 average 80. |
| Frozen dataset / XLSX | JSON copy of two students, category, two assessments, two explicit score rows and one exam rehydrates to identical production calculations and decoded workbook cells after live roster/category/max/score/exam replacement. Expected example row: Quiz/process 50.00, exam 90.00, final 74.00; no-exam student final blank. Text cell type preserved. This tests dataset sufficiency, not an archive repository. |
| Proposed 20 defaults | Exactly 2 Quiz + 6 Classwork + 6 Homework + 6 Participation fixture items; all 20 edited through GradeItemService, reloaded with edited names and max 20. Existing app does not create this template yet. |
| Backup/restore | Mock-store JSON key/type/value backup, clear mock only, restore in fresh mock, exact map equality; null score, Chinese name and class term retained. Schedule/seating/settings sentinel values retained. No operational Firestore recovery claim. |
| Legacy precedence/isolation hazard | Canonical empty item list wins over legacy; global legacy score can be read for a different class with same item ID; resetting local factory does not isolate account data. These are observed baseline risks. |
| Default-fill hazard | `fillNulls: false` retains null; default call replaces it with 100. Adoption must not seed old scores. |
| Class-delete hazard | Local delete leaves legacy item/score globals readable by old class ID. A passing characterization assertion records the defect, not its correction. |
| Local volume | 1,000 synthetic students and 1,000 score rows roundtrip; no cloud limits or performance inference. |

All records are constructed in Dart with synthetic IDs/names and a fixed timestamp. SharedPreferences mocks isolate writes from real device data. No production persistence adapter is initialized. Synthetic assertions do not include a pretend rollover service or a fake rules engine; unimplemented acceptance gates remain explicit in the design matrix.

## Scope and review checks

`git diff --check` passed. `git status --short --branch` and final staged diff review restrict the PR to documentation, fixture source and captured logs. No application code, rules, Firebase config, models, migrations, dependencies or workflows are changed. Full `flutter analyze`, full `flutter test` and release web build were not run for this docs/fixture-only scope.

`flutter analyze --no-pub docs/fixtures/release1/preservation_test.dart` initially reported four visible-for-testing warnings because the executable fixture is deliberately outside `test/`. Added a documented file annotation for the test-only SharedPreferences mock API; rerun exited 0 with **No issues found** ([output](fixtures/release1/fixture-analysis.txt)). No production lint configuration changed.

## Outstanding verification

Firestore rules/transactions, direct API archive tampering, stale/old clients, multi-device concurrency, offline/reconnect, kill-and-resume journals, cloud/local adapter parity, real browser storage, all-class export UI and full restore rehearsal remain required implementation checks. No deployment receipt exists because nothing was deployed. No test result authorizes production adoption.
