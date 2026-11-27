# Classroom Experience V2

## Phase 0 · 27 November 2026

GitHub authenticated repository access confirmed. Default development branch is `main` at `5a49ec21077fc56c472fd69ce41cf29ba259dbcb` (PR #179). The 27 November daily release report recorded live source `11c214ed090aa4fcfbb1bb4131779ce3b1a5c190` after matching served JavaScript to the live review manifest SHA-256. This review did not independently retrieve the live manifest or Firebase Hosting release history. The protected publication workflow packages that SHA from draft PR #178. Reconcile its changes with main before starting any timetable-dependent work. Preserve the existing Firebase project and approved Planner V2 and Teaching Studio designs.

## Requirements and evidence

| Release | Workstream | Existing code and open checks |
| --- | --- | --- |
| 1 | Archive gradebooks by period, historical Excel, fresh editable 2 quiz + 6 classwork + 6 homework + 6 participation columns | Gradebook screen, grade item/category/score services and XLSX export. Firestore nests scores under class grade items and LocalRepository has class-scoped keys and legacy fallback. Confirm term/exam dependencies and class-delete cascade. |
| 2 | Chair behaviour and lesson participation | SeatingDesignerView and SeatingCanvas provide an integration point. Use an event ledger with operation identity, undo/corrections and a teacher-private UI. Start at 100, apply repeatable default −10 events, clamp at zero. Bind to a stable class/period/lesson occurrence and allow participation entries beyond six. |
| 2 | Timetable teaching card | HomeSurface contains a TODO to reconnect Now/Next. Verify #178 import path and storage/account/origin on Chrome and installed app. Current, upcoming, break, finished, no classes and missing timetable need distinct states and manual override. |
| 3 | PDF ink | PdfWebViewerWeb is an embedded viewer wrapper. Identify the actual annotation engine from the active route. Validate page-local coordinates, per-stroke erase, pen preferences, persistence/recovery and fullscreen with Edge and Surface Pen. |
| 3 | Whiteboard toolbar | TeacherWhiteboardWorkspace and its controller/painter provide existing ink controls. Inventory the live left toolbar from the active route. Add collapse, optional auto-collapse and pinning with full-canvas edge access. |
| 3 | Presentation timer | ClassSeatingScreen and fullscreen seating are entry points. Trace existing timer owner before reuse. Keep elapsed time across views with a shared deadline and offer fullscreen, editable durations, controls, presets, warnings, sound and styles. |
| 4 | Ambient display and media | OSController owns idle timeout; GradeFlowOSShell mounts OSIdleScreen, which already has clock/date/class presentation. Add activity suppression and teacher preferences. For whiteboard media evaluate filtering, attribution, licensing and controlled costs before integration. Never send student data to media providers. |

Behaviour categories are talking after being asked to stop, eating, sleeping, walking around without permission, incomplete work, late at start, late after break, more than one toilet break, other-subject homework, and bad language. Make categories and deductions configurable. Track student, class, period, lesson date, event time, reason and deduction with private per-student history and overrides.

## Delivery record

Phase 0 is documentation only. Releases 1–4 are pending. No code test, release, or signed-in production behavior was verified as part of Phase 0. The daily report has prior deployment evidence. Track each PR's exact revision, test commands and results, merge state, deployment receipt, and deployed checks here. Track remaining gaps for signed-in verification, the timetable branch reconciliation, active PDF/whiteboard/timer routes, and archive migration and rollback. Keep one implementation branch active per scoped task. Production releases require explicit approval.

## Release 1 — Implementation Slice 1 · 27 November 2026

Implementation: [draft PR #182](https://github.com/gastonstuart-lab/Gradeflow/pull/182), branch `classroom-experience-v2/release-1-slice-1`. Tested code revision is recorded below; later commits update documentation only. Merge state: unmerged. Deployment: none.

The design in [draft PR #181](https://github.com/gastonstuart-lab/Gradeflow/pull/181) was accepted as the working engineering proposal. Slice 1 now has an isolated domain/service/export implementation: immutable historical datasets and materialized calculations; exactly one active period per owner/class; 20 editable defaults (2/6/6/6); revision-checked assessment edits and sealing; legacy snapshot compatibility; and class/student/combined historical XLSX adapters. Implementation remains draft, unmerged and undeployed. Persistent storage, rules, live adoption and UI activation remain pending; the Phase 0 evidence above is unchanged.

Tested source revision: `5bd484d047513d59d8c37999f784ebcd4a19155a`. Baseline rechecked: main remains `5a49ec21077fc56c472fd69ce41cf29ba259dbcb` with no drift. **42 tests passed (23 new, 19 regression)**; targeted analysis passed with no issues. Commands, captured output, integration contract and unresolved risks are in [Slice 1 evidence](releases/release1-slice1.md). No live records accessed, no migrations/rules changes, no production writes, merges or deployments. No deployment receipt or deployed verification exists.

Recommended next slice: emulator-backed persistent repository, archive rules/legacy-write fences, class deletion protection, trusted sealing and resumable operation identity. Verify recovery/account isolation before any production connection. Release 1 as a whole remains pending. No changes to approved Home, Planner or Teaching Studio designs.

## First Codex assignment · Release 1 data protection design (completed in #181)

Start from `main` at `5a49ec21077fc56c472fd69ce41cf29ba259dbcb`. Before branching, compare current main and record any drift with its effect on grading. Read AGENTS.md and docs/ai-agents/README.md. Use a scoped docs/fixture-only draft PR. Review GradebookScreen, GradeItemService, StudentScoreService, GradingCategoryService, GradingTemplateService, RepositoryFactory, both repositories, exam and class-deletion paths, rules and ExportService. Inventory canonical and legacy storage keys/paths, weights, score identity, repository selection, offline/cache semantics and all grade writes including auto-seeding and bulk edits. Trace actual XLSX callers.

Propose an additive period model with a single active period, immutable historical snapshots of assessments, scores, weights and historical labels, and new-period templates of 2 quizzes and 6 each of classwork, homework and participation. Keep live rosters, seating, schedules and settings tied to the existing class. Compare lazy legacy adoption with migration and recommend one based on actual paths. Define write ordering, idempotency, stale clients, concurrent rollover, interrupted operations, cross-account isolation, archive protection during class deletion, large-class limits, and local/Firestore parity. Define backup/export scope, restore rehearsal, validation counts, rollback triggers and old-client compatibility. Flag any need for data model, rules or migration approval before implementation. Do not access live school data or apply schema/rules changes.

Use synthetic fixtures and an isolated emulator/local environment. Run existing focused grading, XLSX and repository tests where available, recording commands and outcomes. Specify implementation acceptance checks for historical calculation and XLSX parity, 20 editable default assessments, roster/settings preservation, repeat/concurrent rollover, interruption and retry, archived writes/deletes, account isolation, offline/reconnect and restore. Deliver a draft PR with storage inventory, recommended design, alternatives, backup/restore runbook, evidence and test matrix, and the smallest follow-on implementation assignment. No production writes or deployment.
