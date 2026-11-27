# Release 1 — Slice 1: grading period contract and historical export

Implementation review: [draft PR #182](https://github.com/gastonstuart-lab/Gradeflow/pull/182). Unmerged; no deployment.

27 November 2026. Source under test: `5bd484d047513d59d8c37999f784ebcd4a19155a`. Authoritative baseline confirmed before editing and after testing: `origin/main` remains `5a49ec21077fc56c472fd69ce41cf29ba259dbcb`, with no drift. Read repository instructions and PRs [#180](https://github.com/gastonstuart-lab/Gradeflow/pull/180) and [#181](https://github.com/gastonstuart-lab/Gradeflow/pull/181). The user's Slice 1 instruction authorizes this domain implementation; production storage/rules/migration remain outside scope.

## Working implementation

* `lib/models/grading_period.dart`: immutable dataset, active/sealed period and owner/class aggregate. Exactly one active period, unique identities, class/category/item joins, versioned serialization, historical labels/weights/aggregation/maxima/raw scores/exams and frozen materialized results. Missing scores remain distinct from null. Unknown schemas fail closed. Existing immutable scalar models are reused; collections are detached and immutable.
* `lib/repositories/grading_period_repository.dart`: owner-bound repository contract with revision compare-and-set and archive preservation. The included in-memory adapter works independently; CAS is atomic within one instance/isolate only. It is not durable storage, authentication or a cloud transaction.
* `lib/services/grading_period_service.dart`: create/adopt an explicitly supplied snapshot, edit/add/soft-delete assessments, and seal/advance the active period in one aggregate CAS. Stale context/revision and archived writes fail. New defaults are exactly 2 quizzes and 6 each of classwork/homework/participation, with stable IDs from period/kind/ordinal. Every assessment is editable, extras allowed and deleted items are not reseeded. New periods copy roster/class labels but no prior scores/exams. Fresh weights are 25% each; callers can supply a complete weight map without normalization. Existing periods' weights are preserved. Legacy display names are not used to infer category roles.
* `lib/services/historical_grade_export_adapter.dart`: calculates and exports from self-contained snapshots using existing CalculationService/ExportService. Sealed results are verified against the policy before export. Class/student summary text cells, rounding, order, blanks and Unicode labels retain existing behavior. Combined summaries mirror the existing all-class layout using frozen class labels. A separate `Periods` sheet preserves class/period identity, labels, year/term and policy. Duplicate active category labels within a combined class snapshot fail explicitly rather than dropping data through a name map.
* `test/grading_period_test.dart`: 23 synthetic tests, including concurrent attempts against in-memory CAS, collection immutability, direct repository archive rewrite/removal rejection and serialization roundtrips.

No existing application files were modified. Nothing is registered in RepositoryFactory or UI providers. This is executable domain/service/export functionality, independently testable without enabling rollover in the teacher application.

## Integration contract

Build `GradebookDataset.fromLegacy` from an explicitly supplied class record, students, categories, assessments, scores and exams. It uses the existing class teacher ID, checked against the service repository owner. Include inactive records and former students' raw scores where available. Ambiguous/unknown item joins are rejected, never guessed or silently discarded. Existing missing/overwritten records cannot be reconstructed.

`GradingPeriodService(InMemoryGradingPeriodRepository(ownerId: ...))` can create a fresh first period or `adoptLegacy` a supplied snapshot. Adoption does not read or migrate legacy storage. Subsequent mutations require class, period and expected revision. Rollover seals the exact old dataset/results and leaves exactly one active successor. A repeated stale request is rejected; operation-ID retry/recovery belongs to the next slice. The export adapter requires sealed history and explicit owner/class scope; combined export requires an owner and allowed class IDs. It never consults live providers.

These checks prevent accidental context mixing; caller-supplied IDs and in-memory objects are not authentication. A persistent adapter must bind the authenticated owner and atomically enforce revision/immutability at storage. Never register this reference adapter as a production backend. Existing LocalRepository/FirestoreRepository schemas and behavior are unchanged. No migration flag, class archive flag, roster, seating/schedule/notes/settings key is changed.

## Verification

Windows PowerShell, Flutter 3.38.9 / Dart 3.10.8. Existing lockfile/dependencies reused. No Firebase initialization, real preferences access or school data access; legacy compatibility uses SharedPreferences mocks.

```powershell
flutter test --no-pub test/grading_period_test.dart test/grade_item_service_test.dart test/demo_data_service_test.dart test/seating_service_test.dart test/class_schedule_service_test.dart test/student_list_screen_test.dart --reporter expanded
```

**42 passed (23 new + 19 regression)**, exit 0. [Captured output](release1-slice1/tests.txt), workspace prefix removed. Covers creation/all defaults/every default edit/add/delete, historical calculation and class/student/combined Excel parity, exact weights and all aggregation methods, missing/null/non-100 maxima/inactive rows, archive protection, account/class collisions, JSON/version checks, snapshot isolation and legacy reads without source mutation.

```powershell
flutter analyze --no-pub lib/models/grading_period.dart lib/repositories/grading_period_repository.dart lib/services/grading_period_service.dart lib/services/historical_grade_export_adapter.dart test/grading_period_test.dart
```

**No issues found**, exit 0. [Captured output](release1-slice1/analysis.txt). New Dart files formatted; `git diff --check` passed. During development a test's Student identity comparison was corrected to compare values; an unnecessary null assertion was removed. Final focused suite and analysis passed after those corrections. Full suite/analyzer and web build were not run; no UI/plugin/deployment integration is introduced here.

## Risks, rollback and next slice

No persistent adapter, Firestore rules protection, old-client fence, trusted cloud coordinator, durable journal, cross-process locking, interrupted-operation recovery, backup/restore tooling or archive UI is implemented. Existing production rules/class deletion/legacy migration hazards in #181 remain. Future calculation changes must retain historical policy support; otherwise sealed-result verification fails rather than silently changing history. Materialized results are parity evidence, not cryptographic integrity. Checksummed manifests, history ledger, retention/corrections and operational recovery remain later work. In-memory concurrent tests do not prove multi-device safety.

Recommended Slice 2: emulator-only persistent repository/CAS tests, reviewed archive rules and legacy-write fences, class deletion protection, trusted sealing and resumable operation identity. Prove direct API archive denial, account isolation, failure/retry and backup/restore before any production connection or UI activation. Review model/security decisions before merge; separately approve any rules deployment/migration. No merge or deployment requested.

Rollback: revert this additive commit set. There are no persisted application data changes. Home, Planner, Teaching Studio, existing grading services, exports and storage remain unchanged. The programme tracking file carries forward PR #180's unmerged record so it can be reviewed here; reconcile the shared documentation when merging those PRs.
