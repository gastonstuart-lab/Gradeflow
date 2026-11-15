# GradeFlow V2 integrated candidate — 15 November 2026

## Result
Approved Planner #130 and timetable #129 integrated with reliability fixes #126–128. Design preserved. No production deployment or teacher-data mutation performed.

## Source
Production application base: 19c90232724224d7a2eeed624dd8f13c47ccc170.
Planner source: cfd33e2624c13382e3f60ebb48040df63c4d5204.
Fix parents: 94c855e2192ecb5a7f5d7a2072c937eb267e2a56, 97e593715561d972fe2017d8c253adce8e59256e, 930d32859f8efaa9e649fa2b9d7c4e4a4a94f69d.
No overlap in the fixes' 11 paths with Planner/timetable work.
Build source: b2a6dcd8c55231a2276e9819083c59a176b276d2.
Browser acceptance source: 241c5deb3107259374bdc0c51fe95599693b37f8.
Later changes are test/workflow/documentation only. Packaging checks application-file equivalence against build source.

## Teacher behavior
- Actual authenticated Planner retains Today/Week/Month/Agenda/Tasks and existing contextual class tools.
- Saved-weight exports use numeric snapshots matching Gradebook.
- Failed exam saves retain typed edits, serialize writes and wait before leaving.
- Cached profiles cannot authorize real accounts without Firebase verification.
- Classroom, room controls, roster management, quick grading, weather and compact Home retained.

## Evidence
https://github.com/gastonstuart-lab/Gradeflow/actions/runs/43712835336
Full analysis passed; 330 Flutter tests passed, two actual-file acceptance cases skipped.
Seven preview-auth and 14 live-V2 auth checks passed.
Actual lib/main.dart live-V2 release web build passed.
Planner widget checks passed at 1440x1000 and 1280x900 in both themes.

https://github.com/gastonstuart-lab/Gradeflow/actions/runs/43714479112
Actual Flutter browser against local Auth/Firestore emulators PASSED:
Firebase sign-in; five Planner views; class/Classroom access; quiz edit 94 -> 96; Saved acknowledgement; full reload restoring 96; Home refresh retaining session; Home action opening an owned class; no live Firebase Auth/Firestore requests.
Browser viewport: desktop 1440x900. This is not Google OAuth or physical Surface touch acceptance.
Planner ChoiceChip controls are exposed as checkboxes; tests now use observed accessibility roles. Home is verified by a functional class action rather than a decorative heading.

## Release package
Reuse validated build rather than rebuilding unchanged application source.
Windows deploy script checks existing Firebase access, requires REPLACE, backs up live Hosting first and publishes Hosting only to gradeflow-20260113. Includes rollback script.
Packaging itself cannot deploy.
Local session cannot publish: DNS resolution to www.googleapis.com fails. Normal Surface CLI execution is required.

## Remaining acceptance
- Complete user-facing integrated browser preview.
- Real school timetable import and corrected original XLSX binary acceptance. Located GradeFlow_V2_Timetable_Import.xlsx and read its extracted index-bearing 24-period/eight-group grid; that is not actual importer acceptance.
- Browser import/cancellation and linked-lesson flow; both-theme Surface/desktop browser checks and physical drag/touch.
- Actual Google provider sign-in.
No claim that these checks passed.

## Risk, preservation and rollback
No dependencies, lockfile, Firebase rules or academic schemas changed. No data migrations, grade fabrication or automatic room/roster rewrites.
Academic/authentication patches explicitly requested; keep integration PR draft for review.
If published, use included rollback script/Hosting backup for site rollback; never clear teacher browser storage.
