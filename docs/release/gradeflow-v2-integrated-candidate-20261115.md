# GradeFlow V2 integration candidate — 15 November 2026

## Goal
Deliver the approved Planner inside the existing teacher application, retaining production features and data.

## Source and changes
Production workflow pins 19c90232724224d7a2eeed624dd8f13c47ccc170, not main application HEAD.
Candidate starts from approved Planner #130 cfd33e2624c13382e3f60ebb48040df63c4d5204, including #129 3783f22.
Imports exact reviewed blobs from #126 94c855e, #127 97e5937, #128 930d328.
All modified paths were compared against production and Planner trees: no overlapping changes.
No dependencies, academic schemas, Firebase rules, deployment configuration or approved visual design changed.
New verification workflow analyzes, tests and builds lib/main.dart with live V2 enabled. It cannot deploy.

## Teacher behavior
Today/Week/Month/Agenda/Tasks use the actual PlannerSurface and existing shell.
Saved-weight Excel summaries use numeric snapshots.
Exam saves retain failed edits and wait for outstanding writes.
Real sign-in rejects cached-profile authorization without Firebase verification.
Classroom, room layouts, rosters, quick grading, compact Home and weather source are retained.

## Verification
Prior component checks are recorded in parent PRs and are not combined-candidate evidence.
New complete suite, analysis and actual application web build are pending CI.
Local checkout unavailable: Git DNS failed and local gh token is invalid; connected GitHub API used for exact tree integration.

## Release gates
- Complete actual-application browser preview and authenticated navigation.
- Surface 1280x900 and desktop 1440x1000 in light and dark.
- Home -> Planner -> confirmed Classroom -> Gradebook -> Home.
- Timetable import, cancel, reload, class ownership and linked lessons.
- Corrected original XLSX acceptance; available prior CSV is not a substitute.
- Saved grades/weights, exam retry, seats/room persistence and roster add.
- Authentication/session and emulator isolation checks.
- No production deployment, merge, new Firebase project or teacher data mutation authorized here.

## Risk and rollback
Draft integration includes academic and authentication fixes explicitly requested by Stuart.
No migration or automatic teacher-data changes. Revert candidate integration before release; never clear browser storage as rollback.
Human review of the complete integrated browser preview remains required before replacing live.
