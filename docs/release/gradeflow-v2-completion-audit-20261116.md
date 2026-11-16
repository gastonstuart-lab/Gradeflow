# GradeFlow V2 completion audit — 16 November 2026

## Release state
The successful live release is GitHub Actions run 43724962520 on release-control main commit fb487ab2ae7cea009c740b50cc6b05b29d718c90. Its exact application build source is 90906f2a35291012d0ac55b98e9cdfe29aafe03d; integration merge 61b6bedfd9c3be7064ee83c924951ca1eb960cfb contains the same application change. Main is not the current application source.

The approved Planner/Home/Classroom design is preserved. This audit does not read or modify live school records. All new tests use fictional local records or demo-project Firebase emulators.

## Confirmed first release blocker: roster import
Baseline run https://github.com/gastonstuart-lab/Gradeflow/actions/runs/43778090422 reproduced six failures before changes:
- Import into class A used class B's in-memory roster and saved IDs 102/201 instead of retaining class A's 101/102.
- A stale roster dropped student 102 added since the previous load.
- Duplicate IDs, mixed classes and empty IDs were accepted.
- Repository failures were swallowed and local state could announce a false success.
- A SharedPreferences false return was not treated as a failed roster save.

The fix validates a whole batch before writing, reads its destination roster, rejects existing/within-file duplicate IDs, persists before updating memory and propagates save failures. File/paste imports share a guarded preview with error/retry state, disabled repeated submission/cancel during save and no enabled import for invalid-only rows. Local rejected writes reload durable preferences.

This is additive import, not a roster replacement or identity/grade migration. Teachers must remove existing IDs from an import file; existing students are not silently updated or skipped. Import merge/update UX is a separate future decision.

## Workflow evidence and outstanding acceptance
| Workflow | Evidence now available | Still required |
| --- | --- | --- |
| Home / Planner / Classroom / Gradebook | Prior live-lineage emulator browser run 43724954930 passed authenticated navigation, five Planner views, class access, score save/reload and session restoration. New candidate extends this chain. | Physical Surface and teacher-session acceptance. |
| Roster file / paste import | New negative service tests reproduced actual failures. New service/dialog tests and actual emulator import/reload/duplicate rejection are required in this PR. | Corrected real school file acceptance without publishing student data. |
| Grading / exams / exports | Existing saved-weight projection, exam-save tests and prior actual gradebook save/reload checks passed. Candidate runs all Flutter tests and auth configurations. | A complete real-class enter/save/reload/export acceptance; no claim that every export browser flow is verified. |
| Teaching Studio | Existing eight browser workflows verify board save/open, simulated pen/palm, PNG, PDF ink/download/reparse and focus controls in two sizes/themes. Complete candidate must retain Studio assets. | Local recovery/autosave; physical Surface eraser and classroom comfort. Explicit downloads remain necessary. |
| Reports / Attendance / Files | Current class workspace correctly exposes Reports & export, Students and Class plan. Legacy app registry/Teach launcher aliases Attendance to students, Files to schedule and Reports to export. | Do not advertise these aliases as independent finished modules. Define attendance records and file-storage requirements before adding pages. |
| Timetable | Existing 8-group/24-period fixture and timetable reliability tests; original-file acceptance tests remain conditional. | Actual corrected original XLSX binary acceptance, including periods, double lessons and links. |
| Class setup / rooms | Existing roster-add and seating persistence tests; recovered layout controls retained. | A joined class-create/import/add-student/copy-room acceptance, including empty/new class state. |

New CI adds actual roster import to the signed-in emulator test, verifies that the existing student's saved score remains 96, then tests real Home → Studio at /teaching-studio/ and Studio navigation back to signed-in Home without closing Studio. No live Firebase endpoints are allowed in the primary emulator flow. CI result links and limitations are recorded in PR #137.

## Release discipline
The candidate is one complete application artifact, including /teaching-studio/. The existing general Flutter-only build must not be treated as a complete deployable replacement of the live site after Studio was added.
No production release workflow is changed by this PR. No merge or deployment is performed as part of the audit.
Future release source consolidation should be a separate scoped change with source/artifact provenance and rollback acceptance; do not merge main blindly into the application.

## Known limits
- A read-before-write preserves a stale client's omitted records but is not a cross-device transactional merge. Simultaneous independent devices/services can still race on edits; no backend transaction/schema change is claimed.
- StudentService update/delete and several other services still catch errors internally; audit each caller before broad changes. This PR fixes additive imports and local roster-write failure handling only.
- Studio remains session-only. Automatic local recovery must have clear restore/discard controls and a shared-device privacy policy.
- Real Google authentication and hardware input cannot be certified by emulator tests.
- An isolated passing test is not a complete product audit. Pages marked outstanding above remain outstanding.

## Next priorities
1. Review this roster safety candidate; run real timetable and joined class setup acceptance.
2. Complete the grade entry/export acceptance with an isolated copy of a class.
3. Add opt-in local Studio recovery with explicit save state and device/account boundaries; assess PDF recovery separately.
4. Scope actual Attendance/Files functionality rather than relabelling existing destinations.
5. Consolidate application source and release controls with a documented, repeatable release process.
