# GradeFlow Classroom Planner V2 — Release Review (2026-11-09)

## Protected source of truth

- **Owner-approved Classroom visual source:** `513bb31d7b5df57581270adc699641a73bcf88f8`, PR #89, including full-canvas furniture movement, corrected Fit to Screen, compact Present and zoom/pan.
- **Golden-master branch:** `golden/classroom-v2-approved-513bb31-20261109`. Do not change its appearance or replace it with older builds.
- **Owner-approved Ready synthetic preview:** `dpl_UqZwrQtr2H6hMaPeLM9AcoJSXEui`, https://gradeflow-classroom-zoom-review-hmc13sx9b.vercel.app/#/preview/classroom.
- **Approved visual source CI:** GitHub Actions run #42555675216 passed Flutter analysis, full tests and synthetic web build.
- **Integrated code review:** draft PR #91, `integration/approved-v2-auth-staging-candidate-20261109`, based on Home continuity draft #90 and the golden master, with isolated Firebase staging safeguards from drafts #85–#88.
- **Earlier review checkpoints:** `recovery/planner-v2-zoom-validated-20261109` and https://gradeflow-classroom-zoom-review-iuy35tk3s.vercel.app/#/preview/classroom are retained as historical fallbacks, not the owner-approved current target.
- **Do not merge** older independent experimental drafts piecemeal or overwrite production, the owner's approved Classroom checkpoint, or any existing preview links.

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

**HOLD FOR PRODUCTION.** The owner approved the appearance of PR #89; draft PR #91 now integrates the staging-only V2 route, signed-in teacher class selection, and fail-closed Firebase configuration. Automated builds and local emulator security tests are necessary but cannot substitute for an actual distinct Firebase staging project, authenticated multi-class browser tests, migration checks, and owner release approval. Do not promote the synthetic preview or deploy to the real school domain yet.
