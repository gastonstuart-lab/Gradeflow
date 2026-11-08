# GradeFlow Classroom recovery — draft review candidate

Issue: #72. Date: 8 November 2026. Risk: Amber. No merge or deployment.

## Result
The isolated candidate starts at PR #70 (`7d8c698bcf509aa1cd60210b1a0689d98df287c3`). It preserves the Surface contextual right panel and dimensional furniture, removes premium whole-room gestures and Fit Room, restores animated real-seat/table selection, and adds active presentation picking and timer controls. Teach and Arrange remain separate. Private note/reminder and pin indicators are hidden on the projector. Picker fairness history is shared when opening presentation. No academic, authentication, model/schema, Firebase, dependency, routing or deployment files changed.

## Preservation and authorization
Stuart confirmed the Surface is authoritative and expressly allowed proceeding with the other desktop computer unchecked. That desktop is NOT verified or represented as backed up.

Authoritative source: `C:\Users\Stuart\Documents\Codex\2026-11-06\continue-gradeflow-classroom-development-repository-gastonstuart\work\Gradeflow`, HEAD `140c07062ac914250ecc0db1445c4655394466e1`.

Before any checkout mutation, a private directory with restricted access was created at `work/private-preservation-20261108` in this recovery workspace. It contains:
- Verified complete Git bundle of all refs (no external prerequisite history), plus 764 hash-verified common Git metadata/object files including reflogs and worktree metadata.
- Original index, separate binary staged/unstaged patches, status and local-only commit inventory.
- 478 individually SHA-256 verified tracked/untracked source files, including the untracked contextual panel. No ignored source asset was identified in `assets`.
- Source and Git manifests. The staged patch is empty; four tracked files were modified and one source component was untracked.

After implementation all 478 original source hashes still match. The original checkout was not switched, reset, cleaned, stashed or edited. Recovery uses an independent clone from the verified bundle. Backups remain private and are not committed or uploaded.

## Requirements read
Read the source AGENTS.md, docs/ai-agents/README.md, product/design principles in docs/gradeflow_os_design_direction.md, PR #71 preservation contract, issue #72 and all three comments. The owner clarification removing zoom/Fit Room and restoring active presentation supersedes the contract's older optional zoom/pan language.

A separately titled product constitution could not be located in the inspected repository trees, local project candidates or connected GitHub code search. This is an outstanding documentation limitation; the available product rules and the explicit owner request govern this bounded candidate. It must not be represented as having read a missing document.

## Exact provenance and selective reconciliation
| Source | Use |
| --- | --- |
| #70 `7d8c698bcf509aa1cd60210b1a0689d98df287c3` | Foundation; Home, navigation, gradebook and unrelated functionality retained. Its `startInSetup` route option is preserved. |
| Surface HEAD `140c07062ac914250ecc0db1445c4655394466e1` plus verified local edits | classroom_surface, seating_designer_view, seating_canvas, classroom_map_framing, untracked classroom_seat_panel. Local contextual actions/material furniture retained. |
| #71 `532d650` | Read preservation contract and reviewed committed chair/Teach–Arrange changes. Local verified versions used where newer. No wholesale donor merge. |
| #73 `1222af97669755fbed5cfa7f54f2e109f545cdc0` | Selectively imported picker animator, presentation view and picker tests. Ported normal-view picker logic; improved real-roster eligibility, shared fairness history, reduced-motion transitions, timer rounding and presentation privacy. |
| Approved `72ad2d7f12bad3aab3c646f126afa7815186a149` | Inspected reference renderer and existing checkpoint captures. Used as visual reference, never as saved geometry or student data. |

## Change decisions
- Preserve the verified local contextual panel instead of the older seat bottom sheet. Ordinary seat taps in this Classroom open the right overlay without shrinking the map.
- Preserve the local approved-style oak/teal materials, chair backs and separate labels on the saved tables/seats. No fixed six-table preview imported.
- Remove premium pan/zoom gestures and visible Fit Room as explicitly requested. Internal framing is assigned before constructing the canvas, avoiding the old identity-transform first frame. Panel toggles and mode switches preserve the same transform.
- Improve picking with visible sequential highlights followed by a fair nonrepeating student outcome. Only real roster-backed saved assignments are eligible; picks never write layout data. Tables are independently random, not a nonrepeating cycle.
- Improve presentation with Pick student, Pick table, duration menu, pause/reset timer, clear selection and exit. No contextual grading/note tools or editor handles there.

## Verification
| Check | Result |
| --- | --- |
| flutter analyze --no-pub | PASS, no issues |
| Targeted Classroom/picker/canvas/adapter tests | PASS, 17 tests |
| flutter test --no-pub | PASS, 151 tests |
| flutter build web --release --no-wasm-dry-run --no-pub | PASS |
| Same-fixture baseline capture tests | PASS, 2 sizes |
| Original source preservation | PASS, 478 hashes unchanged |
| git diff --check | PASS |

Tests cover exact canvas transform and rendered occupied-seat rectangle across panel toggles, Teach/Arrange, contextual seat selection, picker, presentation exit and persisted reload; full layout JSON equality for non-edit actions; a deliberate table drag at a non-unit framing scale followed by reload with unchanged seats/assignments; student fairness, animation previews, cancellation and reduced motion; presentation timer progression and hidden synthetic private-note/reminder indicators. New tests use synthetic fixtures only. The full existing suite also exercises bundled repository import samples; no live service or real classroom storage was opened. Logs redact printed sample rows; unredacted originals remain in the private preservation folder.

## Visual evidence
See [comparison gallery](comparison.html). Captures are Flutter widget-render screenshots at 1440×960 (Surface-size review) and 1920×1080 (desktop-size review), DPR 1. They are not hardware/browser screenshots and do not measure current Windows scaling. Both comparison builds use byte-identical saved-fixture JSON:
`0c3e318e9143c2444e708c5780811fc72eddbb2600b097d0c63edb831b0430b1` (SHA-256).

The same irregular fixture has eight synthetic students, a desk, a round table and a rectangular table. Baseline #70 and candidate captures include Teach, right panel and fullscreen. A separately labeled historical approved-checkpoint image is included for appearance reference. That preview has different geometry and students: it is NOT a same-fixture A/B and does NOT establish pixel parity with `72ad2d7`.

## Remaining limitations and review holds
- Owner visual approval is pending. Exact same-fixture checkpoint-renderer comparison remains incomplete because the preview renderer generates its own fixed composition; it was not inserted into the application.
- No live browser/touch/projector test, browser reload/navigation smoke test, dark-theme screenshot set or actual desktop-machine test was performed. Widget/service reload and compact panel tests passed, but these do not replace those checks.
- Very long presentation labels can ellipsize; full names are available in tooltips. Projector legibility in a large/dense saved room needs review. Responsive/fullscreen viewport changes may refit the view; saved geometry is never changed by fitting.
- Presentation is an app fullscreen route, not a browser/OS fullscreen API change. Its timer is session-only and has no audio alarm. Existing contextual gradebook save behavior remains outside this change; #70's auth and grade-save release holds are not resolved.
- The missing separately titled constitution and unchecked desktop are explicitly recorded above. No production readiness claim.

## Rollback
The original Surface checkout and private backup remain the primary recovery points. To reject this candidate, leave the original untouched and close the draft PR. To undo the candidate on a future integration branch, revert its single recovery commit; do not reset the owner's Surface branch. For backup recovery, first clone `all-refs.bundle` to a NEW directory, restore the saved HEAD and source files, then restore the original index and apply the separate patches only as appropriate. Never apply recovery over a live checkout without comparison. No production rollback is needed because nothing was deployed.

## Human review required
Review the screenshot gallery, same-room teaching/Arrange flows and known limitations. Keep the PR draft. No merge, deployment or production-data action is authorized.
