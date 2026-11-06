# GradeFlow — Classroom preservation and usability acceptance contract
**Created:** 2026-11-06  
**Status:** Review contract; not visual approval or release approval  
**Target:** Draft PR #71, stacked on draft PR #69, in turn based on draft PR #68  
**Approved reference:** `72ad2d7` (premium teaching-preview experience)  
**Current integration:** `feat/premium-classroom-unified-20261106`  
**Owner's direction:** Preserve what worked in prior versions; do not fix non-problems, discard useful interactions or compromise ordinary teaching usability for a generic floor-plan editor.

## Core product principle
This is a **teacher's classroom workspace**, not a CAD-style room editor. Teach is the default, with the seating map stable and immediately legible. Arrange is an intentional edit mode. Present is a clear, privacy-conscious teaching display. All use the same real saved room model without copying fictional demo records.

Do not treat a newer implementation, passing tests, or premium-coloured legacy component as proof of improved user experience.

## Evidence and important nuance
- Approved preview: `lib/teaching_preview.dart`, `lib/components/teaching_preview_room.dart`, `lib/components/teaching_preview_room_builder.dart` at commit `72ad2d7`.
- PR #69 correction: `docs/gradebook-design-correction-20261105.md` and `docs/design-integration-hold-20261105.md`.
- PR #71 current sources: `lib/os/surfaces/classroom_surface.dart`, `lib/components/seating/seating_designer_view.dart`, `lib/components/seating/seating_canvas.dart`, `lib/components/seating/classroom_map_framing.dart`.
- The owner compared two local screenshots on November 6: the original preview at `127.0.0.1:8792` and integrated Classroom at `127.0.0.1:8791/os/class/demo-class-2/classroom`. These were **different synthetic classes and layouts**; they support an interaction/visual comparison, not a pixel-accurate A/B or evidence that a particular seat disappeared.
- Codex's latest local worktree reportedly moved student actions toward the right panel, fixed analysis issues and passed 31 tests before usage exhaustion. **Those unpushed edits are not evidenced by PR #71**. Reconcile local worktree without discarding it before any further implementation.

## Preservation matrix
Legend:
- **Protect** = working or expressly approved; do not remove or regress.
- **Restore appearance** = adapt approved design onto real records, not copy simulated state.
- **Reconcile** = inspect both implementations, test, preserve useful interaction before choosing final UI.
- **Unverified** = prototype-only, locally changed, or not yet production-evidenced; do not claim it works.

| Capability / behaviour | Approved preview | Current PR #71 GitHub state | Decision / test |
| --- | --- | --- | --- |
| Strong, immediately legible classroom composition | Premium full-width composition, furniture and seating visually integrated | Room displayed inside framed canvas with pan/zoom | **Restore appearance**; teaching mode should fit and feel stationary, without nested editor chrome |
| Furniture, chairs, student names | Distinct furniture depth, shaped chairs, name below seat | Premium materials on older `TableWidget`/`SeatWidget`; small name inside seat | **Restore appearance** without changing geometry, IDs, hit targets or student mapping |
| Real, irregular and saved room layouts | Fictional preview layout; builder changes demo seats | Real table types, saved coordinates and seat IDs | **Protect**; no synthetic six-table template imposed |
| Classroom teach/arrange separation | Teaching surface and room builder; some arrange actions inside preview | Explicit Arrange mode; PR #71 gates seat reassignment | **Protect**, verify no accidental writes in Teach |
| Teacher-friendly selection | Student/table pick shown on classroom map | Pick chooses saved occupied student/table and highlights actual map | **Protect**, check visibility and cycle fairness |
| Stable classroom viewport | First screenshot visually stationary/full-width | InteractiveViewer pan/zoom and new auto-fit/Fit room in PR #71 | **Reconcile**: disable unintended gestures in Teach, retain optional zoom and pan for Arrange, fit actual room within viewport |
| Contextual right panel | Preview has right slide panel **and** older bottom class tools tray | Current right sliding tools; seat tap opens legacy bottom sheet in GitHub branch | **Protect right panel**, migrate contextual seat actions after checking local unpushed Codex work; **do not restore** bottom tools tray |
| Quick student grading | Prototype score entry/quiz state | Real gradebook route and quick-entry dialog | **Protect** real save safety; review student-side panel integration |
| Homework/quiz progress | Visible mode banner and completion counts | Homework/Quiz actions exist but visible progress not equivalent | **Reconcile** with real assessments; no fabricated completion |
| Timer | Visible in original preview | Not surfaced in current Classroom | **Review** applicability/implementation, do not silently delete from product roadmap |
| Lesson focus | Visible in original preview | Not surfaced in current Classroom | **Review** actual teaching need and persistence before implementation |
| Attendance link/mode | Prototype has attendance action if configured | Not evident in current Classroom | **Review** linked school-system flow, don't claim production-ready |
| Groups and group labels | Prototype quick groups and on-map labels | Not evident in current Classroom | **Review** whether helpful; preserve design affordance but no fake saved groups |
| Undo seating changes | Original preview offers undo seat swap | Current Classroom undo not evident | **Reconcile**; only ship real reversible, acknowledged saved-layout operations |
| Lesson/class note and log | Prototype action and log | Not evident in current Classroom | **Review** before removing or reimplementing; assess data retention/privacy |
| Presentation | Cleaner teacher-led teaching view | Shared real map renderer, interactive:false | **Protect** identity and privacy; test typography/contrast, consistency and exits |
| Dock and class navigation | Distinct preview navigation | Newer Home/Planner/Classes dock on real routes | **Protect** valid routes and back paths; avoid legacy UI surprise |
| Substitute Handover | Approved feature requirement from school workflow | Not in bounded Classroom improvement | **Protect as future integration**; derive from canonical actual layout/roster, not screen scraping |

## Real teaching journeys that decide acceptance
1. **Open a class during a lesson:** From Home/Classes, classroom opens with a fitted, legible seating map. Student names and groups of desks are obvious. No accidental pan or assignment when tapping a student. No unnecessary setup step.
2. **Pick a student or table:** One action visibly highlights the actual saved seat or table. Clear/reset selection works. The map does not mutate.
3. **Mark homework or a quiz:** Select the right assessment, tap a student, enter/edit a grade, get explicit acknowledgement or actionable failure. Missing remains missing, no duplicate assessment or pretend progress.
4. **Arrange for the next lesson:** Explicitly enter Arrange; move or swap students and furniture, retain their IDs, check undo/recovery, leave and reload to verify the saved positions. Exit Arrange cleanly.
5. **Present:** Same classroom composition, same student positions, readable across projector, no private notes, scores, editing handles or accidental data exposure.
6. **Use a compact screen:** No clipped labels, unreachable panel controls or tiny default zoom. A stable map with deliberate navigation controls.
7. **Return to other work:** Gradebook, Classroom, Planner and Classes have clear, working paths; unfinished score edits are protected.

## Change-control policy (mandatory on PR #71 and descendants)
For EVERY proposed UI or behaviour change, document:
1. **Problem**: what fails in a real teacher task, with screenshot/test/reproduction.
2. **Existing good behaviour**: older and newer implementations, including where each works.
3. **Decision**: Preserve / Improve / Remove, with explicit evidence and owner agreement for changing approved interactions.
4. **Scope**: narrowest files/components; no unrelated features, data migrations, Firebase rules or grading policy changes.
5. **Acceptance evidence**: screenshot comparison at equal viewport, real/synthetic class with same layout, before/after flow, tests, contrast/name readability, responsive modes.
6. **Rollback**: identifiable source commit, review branch, no merge/deploy before owner approval.

**Never** silently replace an approved experience with a functional older screen, claim parity because colours match, default to a generic moving nested viewport, or invent a fictional arrangement to make a screenshot prettier.

## Existing defects and open questions to resolve before acceptance
- The currently committed Classroom still delegates seat taps to `_showSeatActions` modal bottom sheet; check the unpushed Codex right-panel work before making another overlapping change.
- New PR #71 `ClassroomMapFraming.fit`/Fit Room is unverified in the live Flutter UI. A mathematically fitted canvas is not necessarily a good default teaching experience. Do not force pan/zoom in Teach merely because the widget supports it.
- The PR #71 right panel currently contains broad class tools, not yet a fully contextual selected-student card. UI behaviour on compact widths needs visual validation.
- Confirm whether demo-only tools (lesson timer, attendance, groups, lesson log and undo) have real persisted equivalents. Prototype controls are preservation *candidates*, not evidence that production functionality is lost.
- Codex reported 31 passing tests **in an unpushed local worktree**. Current GitHub PR #71 has not independently been built/tested or visually approved in this chat.
- Real cloud saving/permissions, production imports and issue #62 still require separate verification; keep production operations out of this review.

## Minimum acceptance gate
- [ ] Verify actual local worktree and preserve unpushed edits without resetting/overwriting.
- [ ] Flutter analysis, all relevant tests and release build pass on the exact candidate commit.
- [ ] Same-class, same-viewport visual comparisons of approved design and corrected integrated UI, including compact and dark themes.
- [ ] Teaching uses legible premium seats, fit-to-room composition and stationary ordinary interactions.
- [ ] Arrange alone allows deliberate seating changes; restore actual saved positions after reload.
- [ ] One right panel handles contextual student actions and returns; no duplicate bottom Class tools tray.
- [ ] Quiz/homework and grades use real records and show reliable save/unsaved states.
- [ ] Present hides teacher-private data and uses the same saved room.
- [ ] Old good interactions have a documented retain/replace/defer decision, not silent omission.
- [ ] Owner visually approves; only then discuss merging the stacked PRs.

## Status
**HOLD FOR VISUAL/USABILITY REVIEW.** This document records design decisions and audit findings only. It does not certify PR #71, grant merge approval or authorise production operations.
