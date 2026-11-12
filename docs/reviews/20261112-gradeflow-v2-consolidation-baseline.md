# GradeFlow V2 — verified live-source baseline and integration plan

Status: **read-only repository audit, 12 November 2026**. This document does not authorise production changes or school-data mutations.

## Verified source of truth

- Live Firebase Hosting project: `gradeflow-20260113`. The GitHub Actions **GradeFlow V2 / deploy** run [#43142720874](https://github.com/gastonstuart-lab/Gradeflow/actions/runs/43142720874) completed **success** on 12 November. Its job passed the source guard, entire Flutter test suite, release web build, and **backed up current live Hosting before deploying Hosting files only**.
- The live-release workflow on `main` pins the application checkout to **`7d6f432d981c78352c923cd2f955e9217668ba96`**, the approved polished Home + Planner + weather source. The `main` branch primarily contains release/preview workflows and is **not a safe assumption for the current application code**.
- This branch `integration/v2-live-canonical-20261112` starts at **exactly** that live application source. Future changes must branch from this baseline or a tested descendant, never from an older draft PR by number.
- The separate Design Lab preview succeeded in [#43145633397](https://github.com/gastonstuart-lab/Gradeflow/actions/runs/43145633397) but is a **demo-only build**, not the school application. Its experimental scoring component should not be merged into production without a separate functional review.
- Earlier consolidated acceptance contract: [issue #72](https://github.com/gastonstuart-lab/Gradeflow/issues/72). It contains valuable constraints, but its 6 November claim that the live site was old is now historical and superseded by successful November 11/12 releases. Issue [#106](https://github.com/gastonstuart-lab/Gradeflow/issues/106) informed the deployed Home/Planner recovery; cross-device sync is still pending.

## Evidence-based feature matrix

| Feature / teacher journey | Repository evidence in exact live source | Next verification |
|---|---|---|
| Home, weather and calendar | `approved_teacher_home.dart`, `gradeflow_weather_chip.dart`, `home_planning_summary.dart`; separate preview and release builds green | Cross-device consistency and real class focus, on Surface and desktop |
| Class directory and import | `class_directory_surface.dart` links to `AppRoutes.classes`; `file_import_classes.dart` has CSV/XLSX parsers | Verify import dialog route, duplicate handling, class ownership and roster mapping using fixtures, then browser walkthrough |
| Shared room layouts | `SeatingService.saveRoomSetupFromLayout`, `applyRoomSetupToClass`, `refreshLinkedClassesFromRoomSetup`; Classroom has corresponding controls | Confirm two classes reuse furniture without replacing students, persist exact positions on reload and preserve Teach vs Arrange behavior |
| Classroom navigation / picks | `classroom_surface.dart`; existing widget tests for back to Home, seat/table pick, full-screen and drag | Verify saved real-layout persistence in an isolated authenticated browser/emulator; no demo/class data loss |
| Grade entry and weights | `native_gradebook_screen.dart` already implements quick +/−, editable weights, undo, paste, history warnings and save guards; `gradebook_workspace.dart` honors class weight and null vs zero | User-facing density review against approved interface **after** functional/export parity is established |
| XLSX grade export | `native_gradebook_screen.dart` lines ~724–777 | **P0 discrepancy**: exports hard-coded process 30/30/20/20 and final 40/60 formulas even when saved per-class category and coursework weights differ. Fix in isolated PR with regression tests; no stored marks touched |
| Planner / school events | `planner_surface.dart` reads/writes scoped `DashboardPreferencesService`; imported school events distinguished from tasks | Records are browser-local; design secure tenant/user-isolated sync plus migration/reimport/dedupe tests separately |
| Existing UI previews and old PRs | Current approved live SHA is explicit. PRs #96/#97/#99/#104/#107/#109/#112/#114, plus Design Lab #116, are historically stacked, **not** independent cherry-pick targets | Compare features individually; no blanket merges, resets or production replacement |

## Prioritised repair plan

1. **P0 — Correct XLSX export parity, in isolation.** Export saved GradebookWorkspace.process(), .exam(), .finalGrade() values from the same calculation used in-app, rather than a hardcoded Excel formula. Keep the existing column count/order and student mapping; remove misleading fixed percentage headings. Tests must cover modified class-level coursework split, category weights, missing scores vs actual zero, and preservation on reload. The spreadsheet becomes an exact snapshot; editing exported cells does not recompute the scores.
2. **P0 — Confirm the saved teacher journey with synthetic records.** Authenticate in an emulator and check class/roster import -> open class -> save shared room -> reopen/reuse room in second class -> select/assign student -> save score -> reload -> export. Assert no cross-teacher access, silent write failures, or deleted records.
3. **P1 — Gradebook usability without weakening saves.** Compare current live Gradebook and separate Design Lab fast-entry control; keep dense rows, keyboard navigation, one-grade-at-a-time feedback, weights, history and correct export. Add view/interaction tests before adoption.
4. **P1 — Planner persistence.** Specify server data model, deduplication, conflict/re-import behavior, security rules, backups, and non-destructive browser-local migration before writing any Firebase records.
5. **P2 — Cosmetic components and Widget Gallery.** Preserve approved visual design, live weather, no unsolicited zoom/pan, premium seating geometry, and responsive light/dark. New widgets are lower priority than functional parity.

## Release gates

- **Freeze:** no wholesale merge of draft PRs; no replacement of the live site until reviewed.
- **Protected data:** never alter existing scores or assign invented marks; never seed production synthetic records. Grade `0` is a real value, `null` is missing.
- **Validation:** Flutter analyze, full Flutter tests, targeted import/seating/grade/export tests, guarded web build, and safe authenticated browser/emulator journey. Verify dark/light and Surface-class viewport.
- **Review:** owner sees and approves the exact release candidate; prove its build hash matches the one to be published.
- **Deploy:** use existing `deploy-reviewed-gradeflow-v2.yml` with `check`, separate `deploy` + `REPLACE`, protected GitHub environment, dated backup-first Hosting clone, Hosting-only deployment and rollback.
- **Post-release:** open the live application, verify login, school calendar import, saved class/seating positions, grade calculations and XLSX export; rollback if any actual academic data path fails.

## Explicit limitations

Source inspection and green unit tests **do not** establish live end-to-end persistence. Real-device, authenticated, read/write checks need an isolated emulator or consented test workspace. In particular, the separate grading website mentioned in issue #72 has not been verified or migrated, and school records have not been examined or modified in this audit.
