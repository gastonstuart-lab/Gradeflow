# Release 1: isolated Firestore repository

Continues draft PR #182, based on `c4b689cb1be5f648bda27e3a7e5ac9e6858b17d6`. Main remains `5a49ec21077fc56c472fd69ce41cf29ba259dbcb`. Tested code: **`ed919a9245f2750362203994fc3e0850f224151d`**. Checkpoints: `0d212dd` repository/rules, `5e4ed5c` browser harness, `ed919a9` web rejection fix. No live data, production rules/configuration, factory registration, UI, migration, merge or deployment.

The existing repository contract now has an emulator-only Firestore adapter. It binds the signed-in owner, uses a separate `gradingPeriodBooks/{uid}/classes/{classId}` root, and reads consistent snapshots through transactions. Each period has its own bounded document. One transaction checks the revision and commits control, sealed source, successor and a create-only revision receipt. Shared transition validation protects archives in both adapters. Repeated/stale requests fail without duplicate periods; unknown-outcome retries are not transparently recovered.

## Emulator tests

**10 passed**, real FlutterFire web SDK against Auth/Firestore emulators at 127.0.0.1:9095/8085, project `demo-gradeflow-periods`. Tests cover fresh-client reload, rollover/20 defaults/calculation/export, concurrent and repeated requests, stale writes, account/class isolation, direct SDK archive/parent/receipt mutation denial, atomic rejection with no partial documents, legacy namespace separation and oversize rejection. [Run instructions](../../test/emulator/README.md).

Command: `./test/emulator/run-browser.ps1` after starting emulators as documented. A Flutter 3.38 Windows CanvasKit URL bug required the temporary source-runner workaround; its SDK file was restored byte-for-byte after testing. Explicit Firebase web registration uses three existing locked packages promoted to direct test dependencies, with no version upgrades. The emulator run initially exposed the SDK boxing Dart StateErrors; returning domain rejections across the bridge fixed the focused test.

## Regression tests

**42 passed**, unchanged Slice 1 suite: `flutter test --no-pub test/grading_period_test.dart test/grade_item_service_test.dart test/demo_data_service_test.dart test/seating_service_test.dart test/class_schedule_service_test.dart test/student_list_screen_test.dart --reporter expanded`.

## Analysis

`flutter analyze --no-pub lib/repositories/grading_period_repository.dart lib/repositories/firestore_grading_period_repository.dart test/firestore_grading_period_emulator_test.dart`: **No issues found**. `git diff --check` passed. Full build/suite not run. Captured final output is in `release1-firestore/` beside this record.

## Remaining boundary and next step

Rules are an emulator-only prototype. They protect ownership, pointer/seal atomicity and immutable sealed records/receipts, but cannot validate JSON snapshot internals or recompute grades. Privileged/Admin SDKs bypass rules. Limits are 600 KB/period, 6 MB/book and 50 periods; larger data fails before writes. No chunking, offline rollover or comprehensive recovery tooling is supplied. Production construction is deliberately rejected and existing production rules remain unchanged.

**Next:** implement an emulator-only trusted sealing coordinator that validates snapshot contents and supports receipt-aware retry after an unknown commit outcome. Keep production wiring disabled until that coordinator and rules receive security review. Rollback is reverting these additive changes; legacy data requires no recovery.
