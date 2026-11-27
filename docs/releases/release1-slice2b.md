# Release 1 — Slice 2B

Continues #183 at `7154ad1d15792094a111c743ab5b2b550b10066b`. Tested implementation: **`479887834d8bbdae33efbb408ca59fb6af3bb28e`**. Recoverable checkpoints `4b201a8` and `4798878` are pushed. Subsequent changes are documentation/evidence only.

The isolated Dart coordinator reads authoritative period data inside a Firestore transaction, validates scope/schema/size and historical calculations, then seals using the existing calculation/template code. Those pure helpers were extracted for reuse, without changing grading semantics. Clients supply intent only; emulator rules deny client seals, active-pointer rollover and rollover-receipt creation. The process verifies emulator Auth identity/project and class ownership. It requires the exact demo-project environment; all privileged connections are fixed to loopback. Production configuration and factory wiring remain unchanged.

Stable operation IDs and canonical SHA-256 request digests identify durable receipts. Equal retries recover the committed outcome, including after later rollovers; changed intent under the same ID fails. Commit, source seal, successor, pointer and receipt are atomic. The service delegates Firestore rollover to this coordinator; retain the exact intent, including timestamp, weights and operation ID, across uncertain outcomes. [Commands and API notes](../../test/emulator/README.md).

## Focused emulator tests

**13 passed** in `trusted_grading_coordinator_test.dart`: authoritative scores/weights, client snapshot injection and valid-looking seal bypass denial, lost acknowledgement/coordinator recreation, precommit interruption, concurrent identical/different intents, stale revisions, account/class isolation, receipt reuse/tampering, oversized source/successor and synthetic backup/restore. Recovery preserves complete book JSON, calculations, every decoded XLSX cell/metadata sheet and retry receipts. Backup checksums and restored counts/content were verified on synthetic records only.

## Existing regression tests

**42 passed** unchanged VM regressions, plus **10 passed** unchanged existing browser emulator checks. **1 additional browser test passed** for service-level recovery after a lost acknowledgement. Total: **66 passing tests** (52 preserved, 14 new). Captured output: [VM/emulator](release1-slice2b/vm-tests.txt), [browser](release1-slice2b/browser-tests.txt).

## Analysis

Targeted analysis of all 11 changed Dart files: **No issues found** ([output](release1-slice2b/analysis.txt)). Formatting and diff checks passed. Tests use real demo Auth/Firestore emulators and the trusted loopback process with test-only fault injection. The emulator GET transaction-byte decoder required transactional `batchGet`; the existing Windows CanvasKit runner workaround was reused and its SDK source restored. Full build/global suite not run.

## Readiness and production blockers

**Ready for Slice 3 against the emulator**: build active-period editing, read-only archive/export views and rollover confirmation using existing services; persist pending intent per owner/class until receipt recovery succeeds. No Home/Planner/Teaching Studio redesign needed.

Production remains disabled. Emulator Auth lookup/Admin bypass must be replaced by reviewed production authentication/IAM and trusted-service packaging; review/deploy real rules only with approval. Existing legacy-data adoption/old-client fences, operational backup/restore and size/capacity policy still require production validation. Limits remain 600 KB/period, 6 MB/book and 50 periods; larger books fail safely, with no chunking in this slice. No real data accessed, migrations, production rule changes, merges or deployments.
