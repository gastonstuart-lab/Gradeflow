# GradeFlow recovery audit — 11 November 2026

## Safety and baseline
- **Current live release:** `595bdc3aa83dfda60da56cbef442e8b93ca64ca3`, published by Actions run `42951239747`.
- **Previous live Hosting backup:** `before-v2-20261111031617` (created before that release). Never silently switch to an old interface.
- **Recovery candidate:** `recovery/calendar-classroom-imports-20261111`. Not deployed and must pass all CI and the owner's practical review.
- Source `2026-F Calendar.xlsx` was inspected in the conversation and **not** committed to the repository. It is a school calendar, *not* a class roster or grades workbook.

## Confirmed regressions in live source

| Capability | Problem / root cause | Recovery action |
| --- | --- | --- |
| School calendar | Weekly Excel has 63 date/event notes; importer treated a single `Date: Event` column as both a date and a title, with no multi-day model | Specialized weekly-grid parser, inclusive end dates, 2027 rollover, preview before import, duplicate checks |
| Repeat calendar import | Previously appended every parsed event without checking existing saved items | Deduplicate by event start + title, preserve completed and manually edited saved items |
| Classroom student swaps | Live Classroom had `allowSeatReassignment: setupMode` so dragging seated students during Teach mode was disabled | Allow Teach-mode seat assignment drags, retain physical seat/table movement in Arrange |
| New-class seating | Classroom forcibly passed `showStudentPanel: false`, hiding draggable unseated roster | Display StudentListPanel while students are unassigned; toggle it and avoid overlap with right contextual drawer |
| Navigation | Back icon used `context.go(AppRoutes.osClasses)` | Route Classroom Back to `AppRoutes.osHome` |
| Import discoverability | Classes directory hid imports behind a settings icon routing to ClassListScreen | Prominent `Import classes / rosters` entry on Classes directory; preserve actual importer |
| Arrange access | Horizontal tools can push critical `Arrange room` offscreen | Put Arrange/Finish button in a consistently visible row separate from optional tools |

## Functional contract — before a live recovery release
1. Load the exact 2026-F school calendar. Preview should show the number of events and sample dates, including multiple notes in each cell, week/date ranges, and January–February 2027. No date guessing for unparseable notes.
2. Press Cancel: existing Planner data unchanged. Import: add only new events. Reimport: add zero duplicates and preserve checked/finished reminders. Multi-day entries appear on all relevant Planner calendar dates.
3. Open a class with students but no seating assignments: show an **Unseated students** list. Drag a student onto a chair, then another. Selecting or moving a physical chair must not randomly allocate students.
4. In Teach mode, drag an occupied student's assignment to another occupied seat and verify swap; click a seat to open existing student tools. In Arrange mode, move a physical seat or table deliberately and save coordinates; confirm reload persistence.
5. The **Arrange room** action must be visible without sideways scrolling; the right-hand slide-in tools panel, classroom viewport and student name labels stay intact.
6. Classroom Back must return to Home. The Classes directory offers a clearly labelled import/manage path. Check both Surface Pro touch and Windows mouse, desktop widths, light/dark and narrow windows.

## Other previously approved or discussed functions — audit before claiming complete

| Feature | Current evidence | Verification still needed |
| --- | --- | --- |
| Premium stable classroom map, shaped chairs/name labels | Historical recovery reference and current V2 Flutter source | Real desktop/touch comparison without unwanted pan/zoom |
| Quick student grades, grading category weights, dense gradebook | PR #96 stack included in V2 source | User workflow and saved values on current production |
| Reuse one physical classroom setup across different classes | PR #97 stack included in release | Verify unique student placements per class and no duplicate room rebuild |
| Student/table picker, full-page timer and presentation | Automated V2 tests cover some behaviours | Check actual classroom and privacy in presentation |
| Undo/redo physical geometry | Planner V2 service has tests | Verify under real account and save failures |
| Contextual student grading/status/notes/reminders panel | Existing right panel code | Check no duplicate bottom tray and grade saves |
| Attendance, lesson log, groups, seating locks | Historical product requirements, mixed prototype states | Treat as unverified backlog; don't claim completed |
| Substitute handover | Previously approved printout concept | Integration and A4 export not confirmed live |
| Class roster import and class creation | Existing `ClassListScreen` and `StudentListScreen` controls | Confirm correct destinations, mapping and duplicate protection |
| Home visual theme, class rail, calendar, reminders and floating dock | Current V2 release | Preserve while correcting feature regressions |

## Release rules
- Never merge old prototype UI blindly.
- Academic records and Firebase configuration remain untouched by this recovery's source edits.
- Use isolated CI, then a preview/UI check, then the existing manual **backup-first Hosting-only** deployment workflow pinned to the tested commit.
- If a live smoke test fails, use the exact backed-up Hosting channel from the corresponding deployment log to restore the previous published version; do not delete or overwrite student data.
