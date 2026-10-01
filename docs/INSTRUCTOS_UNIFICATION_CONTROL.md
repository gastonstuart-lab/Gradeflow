# InstructOS Unification Control

Status: ACTIVE CONTROL DOCUMENT  
Created: 2026-10-01  
Active branch: `integration/instructos-unification`  
Base branch: `quality/seating-plan-classroom-control-surface`  
Main repository: `gastonstuart-lab/Gradeflow`

## 1. Purpose

Finish and unify the systems already built into one coherent teacher experience.

This is an integration, simplification, and consolidation project. It is not a new product build.

The active destination is **InstructOS**.

GradeFlow's mature grading/assessment functionality remains inside InstructOS.  
IED Hub remains a separate connected school/content platform.  
Science PowerPoint/courseware remains a separate content-production system.

## 2. Live Git findings — 2026-10-01

Current `main` base observed during audit:
- `3b0d930e3626aea8d2152275efe710bb315b8721`

Branch comparison against `main`:
- `quality/seating-plan-classroom-control-surface`: **5 commits ahead, 0 behind**.
- `feature/seating-classroom-map-redesign`: **0 ahead, 85 behind**.
- `feature/class-workspace-os-redesign`: **0 ahead, 87 behind**.
- `feature/instructos-os-home-simplification`: **0 ahead, 55 behind**.
- `quality/os-home-teacher-command-center`: **0 ahead, 7 behind**.

Decision:
- Use `quality/seating-plan-classroom-control-surface` as the base for unification.
- Treat the older redesign branches as historical references only unless a specific missing behavior is proven to exist there.
- Do not develop multiple competing classroom branches.

The quality seating branch changes only:
- `lib/components/seating/seating_canvas.dart`
- `lib/components/seating/seating_designer_view.dart`
- `lib/components/seating/seating_toolbar.dart`
- `lib/components/seating/student_list_panel.dart`
- `lib/screens/class_seating_screen.dart`
- `test/full_screen_seating_test.dart`

This makes it a controlled extension of current `main`, not a divergent rebuild.

## 3. Approved Classroom UX reference

The standalone Classroom Planner built on 1 October 2026 is the approved interaction reference.

Keep these principles:
- classroom/seating map is the primary surface;
- simple, fast teacher-first workflow;
- collapsible right-side tools drawer;
- seating expands when drawer closes;
- clean projector presentation mode;
- setup controls hidden during normal teaching;
- Today / Students / Class / Setup organization;
- random student animation;
- random table selection;
- attendance;
- student notes;
- class notes;
- dated lesson log;
- seat locking;
- real classroom layout;
- minimal clutter.

Do not turn Classroom into a dashboard of cards.

The HTML planner is a UX reference/prototype only. Do not make it a second permanent data system.

## 4. Existing InstructOS infrastructure to preserve

### Canonical identity/data
Keep:
- `ClassService`
- `StudentService`
- `Class` model
- `Student` model
- existing class IDs
- existing student IDs

Rule:
- one class identity;
- one student identity;
- all new classroom records reference those IDs.

### Seating engine
Keep:
- `SeatingService`
- `SeatingLayout`
- `SeatingTable`
- `SeatingSeat`
- `RoomSetup`
- repository-backed seating persistence;
- local repository support;
- Firestore repository support;
- active layout persistence;
- shared room setup persistence;
- class-specific student placements;
- table/seat drag and drop;
- seat swap/assignment;
- seat notes/reminders;
- seat locking;
- room templates;
- room reuse across classes.

Important:
The current seating engine already persists through `RepositoryFactory.instance`, with both local and Firestore implementations. Do not replace this with browser-local state from the HTML prototype.

### Existing academic functionality
Protect and connect rather than rebuild:
- Gradebook
- grading categories
- exams
- final results
- export
- student list/detail
- class imports
- roster imports
- existing GradeFlow calculations

### Existing planning/note functionality
Reuse where appropriate:
- `ClassScheduleService`
- `ClassNoteService`

Current limitation:
- `ClassNoteService` and `ClassScheduleService` currently use SharedPreferences/local storage.
- They can power early UI work, but should not be treated as the final cross-device/cloud data architecture without an explicit later migration.

## 5. Current Classroom branch strengths

The quality seating branch already adds:
- Teach Mode;
- Setup Room mode;
- Presentation Mode;
- cleaner classroom-map language;
- presentation-aware seat sizing;
- setup-only student panel/toolbar;
- room setup reuse;
- tests for presentation/setup/teach behavior.

Keep these ideas.

The key missing improvement is the **overall screen composition**:
- map should dominate;
- tools should live in a collapsible drawer;
- setup controls should not occupy normal teaching space;
- daily teacher actions should be grouped around the map;
- projector/public state should be clearly separated from private teacher state.

## 6. Gaps confirmed by current-code audit

### Attendance
Do not assume old documentation equals current canonical implementation.

No clean current `AttendanceService` or canonical attendance repository was found in the live `main` code search.

Decision:
- attendance is a later Phase 2 capability;
- implement it once, using class ID + student ID + date;
- do not revive a legacy external-link/tool implementation.

### Random student
Existing random-name picker logic exists in the legacy teacher dashboard and a seating picker already exists in `SeatingDesignerView`.

Decision:
- reuse the roster and existing picker behavior;
- redesign only the presentation/animation to match the approved Classroom UX.

### Random table
Not a canonical current service.

Decision:
- implement as a small Classroom action using the active `SeatingLayout`;
- choose only tables that contain eligible students when appropriate.

### Student notes
No canonical modern student-note repository was confirmed during the audit.

Decision:
- do not store student notes by display name;
- create/reference notes by `studentId`;
- scope notes to teacher/user as needed;
- add only after the first seating vertical slice is stable.

### Lesson log / today's lesson
Current schedule and class-note infrastructure can contribute, but the approved daily lesson log is not yet one canonical modern data model.

Decision:
- do not force it into seating data;
- design a small class/date lesson record when that phase begins;
- later connect completed lesson records to Planner.

## 7. Canonical Classroom migration plan

### First vertical slice — only this first

Goal:

**open real class → real roster appears → real seating works → tools drawer works → presentation mode works → seating saves**

Do not add attendance, AI, planner redesign, IED integration, gradebook redesign, or unrelated tools during this slice.

### Files to preserve as the engine
Use directly:
- `lib/services/class_service.dart`
- `lib/services/student_service.dart`
- `lib/services/seating_service.dart`
- `lib/models/student.dart`
- `lib/models/seating_layout.dart`
- `lib/models/room_setup.dart`
- `lib/repositories/data_repository.dart`
- `lib/repositories/local_repository.dart`
- `lib/repositories/firestore_repository.dart`

### Existing seating files to adapt, not rewrite
- `lib/components/seating/seating_canvas.dart`
- `lib/components/seating/seating_designer_view.dart`
- `lib/components/seating/seating_toolbar.dart`
- `lib/components/seating/student_list_panel.dart`
- `lib/screens/class_seating_screen.dart`

### Recommended new canonical surface
Create one classroom composition layer in the OS/class experience.

Preferred name:
- `lib/os/surfaces/classroom_surface.dart`

Purpose:
- load current class context;
- display the seating map as the dominant workspace;
- host the collapsible tools drawer;
- control normal/setup/presentation state;
- route to existing Student/Gradebook/Exam/Result/Export screens;
- keep private controls out of presentation mode.

Do not duplicate seating persistence or roster state inside this surface.

### Recommended drawer component
Create one focused drawer component, not a new dashboard framework.

Preferred path:
- `lib/components/classroom/classroom_tools_drawer.dart`

The drawer should:
- open/close without covering or clipping the map;
- cause the map area to reflow/resize;
- work well on Surface Pro touch;
- become an overlay only at narrow breakpoints;
- remember open/closed preference locally if appropriate;
- contain only real working controls.

During the first vertical slice, keep drawer content minimal and tied to real existing seating/class data. Add Today/Students/Class capabilities incrementally as their data layers become real.

### Setup mode
Reuse existing `SeatingToolbar` and room setup flows.

Do not display its long horizontal control strip during normal teaching.

Move/setup-access those controls inside the Setup area/drawer or a focused setup sheet.

### Presentation mode
Reuse branch presentation-aware rendering and improve composition to match the approved prototype:
- no private drawer;
- no setup controls;
- larger names/seats;
- clear class name/front marker;
- map uses full projector area;
- safe exit affordance;
- no student notes/attendance/private data shown.

## 8. Routing and workspace migration

Current ClassSurface owns tabs for:
- Overview
- Schedule
- Gradebook
- Exams
- Results
- Seating
- Students
- Export

Do not rewrite those academic tools.

Short-term:
- add/open the new Classroom surface beside the existing Seating route while proving parity.

After teacher approval:
- make Classroom the canonical live-class route;
- route the former Seating entry to Classroom;
- connect Student/Gradebook/Exam/Result/Export actions from Classroom;
- then assess whether TeachSurface and old seating route can be retired.

Never remove old routes before the replacement is proven in real use.

## 9. Frozen systems

Do not casually alter:
- grade calculations;
- grading categories logic;
- exam calculations;
- final results calculations;
- export generation;
- IED production/public site;
- IED staff/auth architecture;
- certified Science PowerPoint/courseware authority;
- Firebase architecture;
- Ask InstructOS architecture.

Change a frozen system only when a concrete Classroom integration requirement proves it necessary.

## 10. IED ownership

IED Hub remains separate.

It owns:
- public IED website;
- EEP;
- EEP Showcase;
- ESL subject hubs;
- Science web lessons;
- resources/content;
- teacher/admin publishing;
- public/student-facing material.

Private InstructOS student-management data must not be merged into IED.

Later connection should use stable resource IDs/links, not a repo merger.

## 11. Science courseware ownership

The private PowerPoint/courseware repository remains independent.

Do not rebuild certified PowerPoint/courseware work as part of Classroom unification.

InstructOS should later treat PowerPoints, IED lessons, PDFs, videos, Drive files, etc. as teaching resources that can be opened from a class/lesson context.

## 12. Design-system rule

Teacher-facing surfaces should feel like one product family even when implemented in different codebases.

Lock common principles for:
- typography;
- colors;
- spacing;
- radii;
- buttons;
- panels;
- drawers;
- tabs;
- student controls;
- touch targets;
- presentation mode;
- light/dark behavior;
- naming.

Flutter/InstructOS and React/IED may use different implementation code.

Public IED pages do not need to become identical to private InstructOS screens.

Teacher/admin IED surfaces should eventually align with the InstructOS design language.

## 13. Build order

1. Audit/control — this document.
2. Classroom first vertical slice.
3. Attendance.
4. Random student presentation.
5. Random table.
6. Student quick card.
7. Student notes.
8. Class notes.
9. Lesson log / today's lesson.
10. Lock/undo refinements.
11. Existing student/grade links.
12. Class workspace consolidation.
13. Home simplification.
14. Planner consolidation.
15. IED resource linking.
16. IED teacher/admin visual alignment.
17. Duplicate-route cleanup.
18. Ask InstructOS expansion last.

## 14. Acceptance standard for first vertical slice

Do not mark complete unless:
- a real existing InstructOS class opens;
- its real roster loads;
- existing seating layouts load;
- seat/table drag and drop still works;
- changes persist through the existing repository;
- room setup reuse still works;
- tools drawer opens/closes;
- map resizes/reflows rather than clipping;
- Surface Pro touch interaction remains usable;
- presentation mode hides private controls;
- projector view is readable;
- existing Gradebook/Exam/Result/Export behavior is untouched;
- relevant Flutter tests pass;
- visual output is reviewed against the 1 Oct 2026 Classroom Planner reference.

## 15. Retirement candidates — do not remove yet

Potential later retirement/merge targets:
- duplicate legacy class detail paths;
- old Seating route after Classroom replaces it;
- overlapping TeachSurface behavior after Classroom absorbs live-class functions;
- legacy dashboard classroom-tool surfaces after their useful behaviors are moved;
- old duplicate command-center/dashboard paths.

These are candidates only. Removal requires explicit parity confirmation.

## 16. Current milestone

**Milestone C1 — Classroom shell on real InstructOS data**

Only target:
- real class;
- real roster;
- real seating engine;
- approved classroom-first layout;
- collapsible tools drawer;
- setup mode;
- presentation mode;
- persistence;
- tests.

Everything else is deferred until C1 is approved.

## 17. Working rule

For each change:
1. inspect current code;
2. reuse existing service/model first;
3. change the smallest necessary area;
4. preserve unrelated behavior;
5. test;
6. visually review where relevant;
7. commit one clean checkpoint;
8. report what changed, what was reused, what remained untouched, and what comes next.

Final principle:

**preserve → connect → simplify → test → approve → retire duplicates**

Do not start again.  
Do not multiply systems.  
Do not drift.


## 18. C1 implementation checkpoint — 2026-10-01

Status: **IMPLEMENTED IN BRANCH, RUNTIME VERIFICATION STILL REQUIRED**

Branch:
- `integration/instructos-unification`

C1 implementation currently adds:
- `lib/os/surfaces/classroom_surface.dart`
- `lib/components/classroom/classroom_tools_drawer.dart`
- `test/classroom_surface_test.dart`

Existing files changed minimally:
- `lib/nav.dart` — additive Classroom route only;
- `lib/os/surfaces/class_surface.dart` — additive Classroom entry beside Seating;
- `lib/components/seating/seating_designer_view.dart` — adds a default-safe `interactive` option so the new public presentation can be read-only without changing old Seating behavior.

Current Classroom behavior:
- loads the real class through `ClassService`;
- loads the real roster through `StudentService`;
- loads/persists the real room map through `SeatingService`;
- uses the existing `SeatingDesignerView` and repository-backed seating engine;
- provides a collapsible right-side drawer;
- reflows the map when the drawer closes on normal/large widths;
- uses an overlay drawer at narrow widths;
- provides Today / Students / Class / Setup sections with only existing working links/data in C1;
- hides setup controls during normal teaching;
- enables the existing seating toolbar/student panel only in Setup Room mode;
- keeps full reusable-room management in the old Seating screen during C1;
- opens a separate read-only Presentation view with no private drawer or seat actions;
- leaves the old Seating route intact as a fallback.

Class workspace now exposes:
- Classroom — new C1 surface;
- Seating — existing full seating implementation, unchanged as a fallback.

Focused tests added for:
- drawer open/close behavior;
- map remaining present when drawer closes;
- setup controls hidden until Setup Room is enabled;
- presentation hiding teacher/private controls;
- presentation seats being read-only;
- narrow overlay drawer dismissal.

Verification limitation:
- no Flutter SDK is available in the current execution environment;
- no GitHub Actions run was attached to the latest branch commit at the time of this checkpoint;
- therefore C1 must not yet be labelled approved or production-ready.

Next required action:
1. run `flutter analyze`;
2. run `flutter test test/classroom_surface_test.dart test/full_screen_seating_test.dart test/seating_service_test.dart`;
3. run the web app on the Surface Pro / desktop;
4. visually compare Classroom against the approved 1 October Classroom Planner;
5. fix only C1 defects;
6. approve C1 before adding attendance or any later feature.


## 19. Whole-system integration blueprint — 2026-10-01

Authoritative whole-system audit:
- `docs/INSTRUCTOS_INTEGRATION_BLUEPRINT.md`

This blueprint maps:
- InstructOS / GradeFlow;
- IED public and IED Studio;
- Science lesson/courseware web system;
- native PowerPoint authority;
- Classroom;
- Firebase/auth boundaries;
- identity/data contracts;
- duplication/retirement candidates;
- shared teacher UX language;
- recommended implementation sequence.

Current next milestone:
- **Teacher Home Integration — Vertical Slice 1**

Do not begin that milestone until explicitly instructed to continue.


## 20. Teacher Home Integration — Vertical Slice 1 — 2026-10-01

Status: **IMPLEMENTED IN BRANCH, RUNTIME / VISUAL VALIDATION REQUIRED**

Branch:
- `integration/instructos-unification`

Purpose:
- make the existing InstructOS Home the clean front door into systems already built;
- do not create another dashboard or another backend.

Implementation:
- added `lib/components/home/teacher_home_integration_panel.dart`;
- kept the existing `HomeSurface` and replaced only its default empty/calm floor;
- desktop and stacked Home layouts both use the same integration panel;
- configured connected IED Studio and Science destinations in `GradeFlowProductConfig`;
- added focused Teacher Home route tests;
- updated the existing OS Home regression test.

Teacher Home now exposes:
- real current teaching context from the existing active class data;
- Classroom;
- Planner;
- Grades;
- Students;
- IED Studio;
- Science;
- existing pending reminder signal.

Data-safety corrections made during self-review:
- removed unsupported `Next class` wording because Home does not yet have a trustworthy timetable-derived next-class resolver;
- changed the language to `Teaching context`;
- no Science progress percentage / last-slide / continue state is displayed;
- persistent Science progress remains deferred;
- IED and Science remain separate connected systems;
- no cross-Firebase writes or identity assumptions were added.

Home simplification:
- the former default decorative/calm floor was retired;
- weather/audio were removed from the permanent priority utility rail;
- Planner reminders and Messages remain the persistent daily signals;
- duplicate class-chip listing was removed from the new integration panel;
- existing secondary mini-app code remains preserved.

Connected destinations:
- IED Studio: `https://ied-hub.web.app/admin`
- Science Lessons: `https://ied-hub.web.app/science-lessons.html`

Preserved and untouched:
- Classroom internals;
- Gradebook calculations;
- exams;
- results;
- export;
- Planner internals;
- student data models;
- repository/Firebase architecture;
- IED Firestore/security;
- Science lesson data;
- PowerPoint/courseware.

Verification completed in this environment:
- Git diff/scope audit;
- route/helper review;
- source-level delimiter/syntax-shape checks;
- confirmed no fake Science progress strings in the new panel;
- confirmed old `_HomeCalmWorkspaceFloor` is no longer referenced;
- confirmed desktop and stacked Home both mount the same integration panel.

Verification limitation:
- Flutter SDK is not installed in the current execution environment;
- Dart SDK is not installed;
- no GitHub Actions workflow run is available for this branch checkpoint;
- therefore `flutter analyze`, widget tests, browser render QA, and Surface Pro visual QA have not been executed here.

Required next gate:
1. run `flutter analyze`;
2. run `flutter test test/teacher_home_integration_panel_test.dart test/os_shell_surfaces_test.dart`;
3. run the web app;
4. inspect Home at desktop and Surface Pro widths;
5. verify Classroom / Planner / Grades / Students routes;
6. verify IED Studio and Science links;
7. fix only Home V1 defects;
8. approve Home V1 before moving to the connected-destinations contract.

Do not proceed to Science progress persistence, Firebase migration, IED redesign, Classroom feature work, or identity/SSO until this gate is passed.


## 21. Teacher Home V1 validation approval — 2026-10-01

Status: **HOME V1 APPROVED**

Validated branch:
- `integration/instructos-unification`

Primary successful validation run:
- GitHub Actions run `36874315912`
- validated commit `143413b67ad707641d9cae7e29ff53e0e5d85627`
- overall conclusion: `success`

Current branch may contain later validation-workflow-only changes; no later product-code change invalidates this approval.

### Proven working

- full repository `flutter analyze`: PASS;
- focused Home V1 analyze: PASS;
- required widget tests:
  - `test/teacher_home_integration_panel_test.dart`: PASS;
  - `test/os_shell_surfaces_test.dart`: PASS;
- Flutter release web build: PASS;
- Chromium Home validation: PASS;
- desktop 1440x900 Home: PASS;
- Surface-like 1180x720 Home: PASS;
- alternate light theme at Surface-like size: PASS;
- no horizontal overflow detected;
- Classroom route from Home: PASS;
- live IED Studio signed-out/protected route: PASS;
- live Science destination: PASS.

### Visual approval notes

The approved default Home now prioritizes:
- teaching context;
- reminder / attention state;
- Classroom;
- Planner;
- Grades;
- Students;
- IED Studio;
- Science.

The previous competing surfaces are preserved but demoted behind:
- `More Home tools`

They no longer surround the default Teacher Home.

Validated screenshots showed:
- clean desktop hierarchy;
- all six destinations visible at Surface-like landscape size;
- readable dark and light modes;
- bottom OS navigation preserved;
- touch-sized controls preserved.

### Data truth confirmed

Home does not claim:
- a verified next class;
- Science completion percentage;
- last Science slide;
- persistent Science progress;
- cross-project Firebase identity.

No strings for:
- `Continue last lesson`;
- `Last opened at slide`;
- `Next class`;
remain in the InstructOS codebase.

### External destination correction

The originally configured:
- `/science-lessons.html`

was proven not to be deployed on the current live IED host.

Home now uses the deployed Science Hub:
- `https://ied-hub.web.app/esl/science`

This is deliberately a safe live fallback.

The private Science Lessons workspace remains present in the IED codebase but must not be presented as a live production destination until it receives an approved deployment.

### IED authentication verification boundary

Production signed-out behavior was runtime-tested:
- `/admin` is reachable;
- unauthenticated users are redirected/protected correctly.

No production IED staff credential was used during this gate.

The production-ready IED code was inspected and confirms:
- `/admin` is wrapped in `ProtectedRoute`;
- authenticated staff users proceed into `ProtectedAppShell`;
- unauthenticated users redirect to `/login`;
- permission failures render access denied;
- forced password-change state redirects to `/admin/change-password`.

Therefore the InstructOS destination contract is valid, while credential-level signed-in production verification remains an IED operational check rather than a Home V1 defect.

### Drift check

Home V1 application changes were limited to:
- Home integration UI;
- Home composition/simplification;
- connected destination configuration;
- Home tests.

One out-of-scope source edit occurred during validation:
- `lib/os/surfaces/classroom_surface.dart`
- one unsupported icon constant was replaced with a supported Flutter icon solely to allow repository analysis to compile;
- no Classroom behavior, persistence, data, routing, or interaction logic changed.

Frozen systems remained otherwise untouched.

### Preserved

- Classroom behavior and seating persistence;
- Gradebook calculations;
- categories;
- exams;
- results;
- exports;
- Planner storage architecture;
- student data models;
- repository architecture;
- Gradeflow Firebase schema;
- IED Firebase/security rules;
- Science curriculum/lesson content;
- native PowerPoint/courseware.

### Next milestone

The next integration milestone is:

**Connected Destinations Contract**

Purpose:
- replace ad-hoc cross-system links with a small explicit connection contract;
- keep IED, Science, PowerPoint and InstructOS as separate owned systems;
- make stable destination/resource references possible without copying data;
- prepare later class-to-course and lesson-progress integration.

Do not begin this milestone until explicitly instructed to continue.
