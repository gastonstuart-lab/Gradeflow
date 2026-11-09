# GradeFlow Classroom Planner V2 — Release Review (2026-11-09)

## Protected source of truth

- **Verified latest review commit:** `a44a066a0603559080dfc3f5e2d2433ab11b38c0` from draft PR #84 (`engineering/planner-v2-seat-drag-20261109`).
- **Immutable recovery branch:** `recovery/planner-v2-zoom-validated-20261109`.
- **Review staging branch:** `release/classroom-v2-integration-review-20261109`.
- **Verified Ready Vercel deployment:** `dpl_4eMCDjBrx9S71bxEXNrYtmBDak7o`, at https://gradeflow-classroom-zoom-review-iuy35tk3s.vercel.app/#/preview/classroom.
- **Passing source CI:** GitHub Actions run #42541830670, including `flutter analyze`, the focused V2 geometry/seating/widget tests, full Flutter tests (reported 189), and the isolated synthetic web release build.
- **Separate older Ready deployment:** full canvas `dpl_EbrmDjmuHaZJJTRVQZtjk6eAvY7N`; tools/timer `dpl_3G7n5Xn5MBTtNWsagQDRtTX1FqaS`.
- **Do not merge** older independent drafts #68–#83 piecemeal; latest PR #84 contains the newer combined V2 evolution. Do not overwrite the approved Classroom checkpoint, local Surface checkout, or existing immutable review links.

## Verified implementation from source

1. The synthetic Classroom route passes `cleanCanvas: true, plannerV2: true`.
2. The V2 seat and table pointer logic, inverse view transform, geometry save, and undo/redo are present in the latest source.
3. Teacher action bar has random seating, Fit to screen, Zoom in/out, full-page timer, student and table picker, Arrange, and Present.
4. Fullscreen presentation receives the same V2 layout with classroom edit mode disabled; picker is included.
5. The synthetic preview builds routes for Home, Classroom, Grades and Students and adds its own bottom navigation.
6. The synthetic preview uses `RepositoryFactory.useLocal()` and fabricated students, not production authentication or Firebase school data.

## Release gates — **not yet all passed**

### A. Integrated authenticated Classroom (not the synthetic entrypoint)

- **Implemented in release review branch, not deployed:** the real authenticated `osClassroom` route now passes V2 and clean-canvas options when built with `--dart-define=GRADEFLOW_PLANNER_V2_STAGING=true`. Default builds keep the legacy Classroom because this flag is false. This wiring still requires staging auth/browser tests before it is release-ready.
- Confirm teacher account can navigate premium Teacher Home → class → Classroom → gradebook → student records → Home with a real class ID, rather than fixed `_classId` or temporary redirects.
- Confirm selected teacher/class and gradebook return path; verify no old routes or dead toolbar controls.
- Verify role enforcement, class isolation, Firebase security rules, and persistence with permitted test accounts, before using any real student data.
- Confirm the preview-only Home placeholders (IED, Science resources, Assistant, Attention, Planner) are not accidentally presented as live features in production.

### B. Classroom UX acceptance in real browser

- Full canvas hit areas at 1920 and 2880 wide, laptop, Surface touch, compact desktop and high DPI.
- Move each table to each visible edge; drag every chair, including chairs far from their parent table, across the entire permitted room.
- Verify dragging never moves the underlying table when seat is selected, and never changes a student assignment.
- Resize tables with corner handle and exact dimension fields; check chair positions, name labels, table shapes, and room bounds.
- Zoom in/out at multiple scales, Fit to screen, save/reopen after refresh, Undo/Redo interleaving chair and table moves.
- Random seating preserves locked seats and room geometry, preserves teacher choices, and requires confirmation.
- Student and table picker non-repeating rules, animation and selected highlights work.
- Right sliding panel supports seat profile, grades, notes/reminders, seat selection and dismissal without blocking drag targets.
- Full-page timer: select duration, start/pause/reset, close and return; check foreground/background behaviour.
- Present mode: fullscreen (including projector view), no private grades/notes, no edit controls; back returns to same room and bottom navigation.
- Verify production-quality fonts and Traditional Chinese names, and no recurrence of invisible text.

### C. Reliability, security, migration and approval

- Build the **actual integrated app** in both modes (production-default flag off, staging flag on), plus the synthetic review target, and run full test suites. The release-review CI now includes all three web builds; only treat this gate as passed once the GitHub run succeeds.
- Explicitly test load/save failures and recovery, same-class reload, switching between classes, and legacy room layouts migrated into V2 geometry without data loss.
- Validate undo/redo scope for non-geometry actions; existing V2 history is only promised for geometry.
- Capture desktop and Surface screenshots and browser interaction traces, not just successful builds.
- Use a separate staging domain with test accounts and explicit Firebase environment; avoid production credentials in Vercel synthetic builds.
- Owner must inspect and explicitly approve the final candidate before merging into live main or publishing to `https://gradeflow-20260113.web.app/os/home`.

## Decision at this checkpoint

**HOLD FOR PRODUCTION.** The latest synthetic-only Planner V2 is a Ready review deployment and the protected baseline. There is no evidence yet in this audit of the complete authenticated Teacher Home/Classroom integration or of end-to-end production-route validation. Proceed with a separate integrated staging candidate. Do not promote this synthetic entrypoint as the real school system.
