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


## 22. Connected Destinations Contract — 2026-10-01

Status: **APPROVED**

Branch:
- `integration/instructos-unification`

Primary validation run:
- GitHub Actions run `36876311163`
- validated commit `4ded33e2e7d5c7ebdb6614b4e9fc4f3b9f96f096`
- overall job conclusion: `success`

### Purpose

Replace ad-hoc cross-system URL coupling with one small typed reference contract.

The contract does not merge applications, Firebase projects, identities, or content stores.

Implementation:
- added `lib/integrations/connected_destinations.dart`;
- Home now resolves IED/Science through the registry;
- `GradeFlowProductConfig` no longer owns IED/Science URLs;
- external launching is handled through `ConnectedDestinationLauncher`;
- launcher failures are converted to safe result states instead of throwing through Home;
- unavailable destinations cannot be launched.

### Canonical destination identities

#### `ied-studio`
Owner:
- IED

Production URL:
- `https://ied-hub.web.app/admin`

Status:
- production

Authentication:
- expected / protected by IED

Purpose:
- department/hub publishing and IED Studio administration.

#### `ied-science-hub`
Owner:
- IED

Production URL:
- `https://ied-hub.web.app/esl/science`

Status:
- production

Authentication:
- public destination

Purpose:
- current deployed Science Hub and shared Science content.

#### `science-lessons`
Owner:
- Science teacher/courseware layer

Production URL:
- none

Status:
- deferred / not deployed

Purpose:
- reserved stable identity for the private Science Lessons teacher workspace that already exists in the IED codebase.

Rule:
- it must not appear as a normal production Home destination until an approved deployment exists.

### Launch contract

`ConnectedDestinationLauncher` returns:
- `opened`
- `unavailable`
- `invalid`
- `failed`

Rules:
- deferred destinations are rejected before any browser launch;
- invalid/non-http(s) destinations are rejected;
- browser launch failures do not throw through the teacher UI;
- Home remains in InstructOS and shows a small error message when a live external destination cannot open.

### Security boundary

Production destination URLs:
- contain no class ID;
- contain no student ID;
- contain no teacher ID;
- contain no grade data;
- contain no private query payload.

This milestone:
- did not merge Firebase projects;
- did not create cross-project writes;
- did not assume shared Firebase UIDs;
- did not transmit private InstructOS academic data to IED.

### Resource-reference audit

Existing systems already have useful resource identities:

InstructOS:
- class schedule items preserve a generic `Link` detail;
- existing Drive integrations remain separate.

Science:
- stable lesson ID;
- unit ID;
- `LessonResource.id`;
- resource type;
- format;
- href;
- Drive file ID;
- source ID;
- teacher-only flag;
- `LessonSourceReference`.

IED:
- `ContentItem.id`;
- section ID;
- link URL;
- content/resource type;
- publication state.

PowerPoint:
- protected artifact/file identity and authority remain in the native PowerPoint system.

Decision:
- **do not create a new generic InstructOS resource-reference model yet**.

Reason:
- there is no current consumer requiring a fourth representation;
- adding one now would duplicate existing Science/IED resource metadata without solving a live workflow.

Future rule:
- when class/course/lesson integration needs a resource reference, create the smallest reference-only adapter using stable IDs/locators;
- never copy resource bodies into InstructOS.

### Naming cleanup

Removed misleading production coupling:
- `GradeFlowProductConfig.iedStudioUrl`
- `GradeFlowProductConfig.scienceLessonsUrl`

Home now uses:
- `ConnectedDestinations.iedStudio`
- `ConnectedDestinations.iedScienceHub`

The live Science Hub is no longer represented internally as “Science Lessons.”

### Validation

PASS:
- full repository analyze baseline;
- focused touched-code analyze;
- `test/connected_destinations_test.dart`;
- `test/teacher_home_integration_panel_test.dart`;
- `test/os_shell_surfaces_test.dart`;
- release web build;
- Chromium Home regression;
- desktop Home;
- Surface-like Home;
- live IED Studio protected-route check;
- live deployed Science Hub check.

Contract tests prove:
- approved production URLs;
- stable destination IDs;
- owner identities;
- deferred `science-lessons` has no production URL;
- deferred destination cannot launch;
- invalid URL cannot launch;
- failed browser launch is reported safely;
- launch exceptions are contained;
- production destination URLs contain no private class/student/grade context.

### Drift check

Changes in this milestone were limited to:
- destination contract;
- Home connection wiring only;
- removal of duplicate URL config;
- focused tests;
- validation workflow.

No Home visual redesign occurred.

### Preserved

Untouched:
- approved Home composition;
- Classroom behavior;
- seating persistence;
- Planner behavior/storage;
- Gradebook calculations;
- categories;
- exams;
- results;
- exports;
- student models;
- Firebase schemas;
- IED Firebase/security;
- IED public design;
- Science curriculum content;
- PowerPoint/courseware.

### Next decision

The Integration Blueprint previously suggested:
- Science Class Mapping + Real Lesson Progress.

That is now **one step too early**.

Reason:
- the private Science Lessons teacher workspace exists in source;
- it has stable lesson/resource identities;
- but it is not deployed on the production IED host;
- current Home Science therefore correctly opens the public Science Hub.

Next milestone:
- **Science Teacher Workspace Production Readiness**

Goal:
- establish one approved, secure, deployable teacher Science workspace destination first;
- preserve IED security/auth;
- reconcile the relevant Science branch with the production-ready IED platform;
- validate the teacher workspace route;
- only after that create InstructOS class → Science course/lesson mapping and durable progress.

Do not begin that milestone until explicitly instructed to continue.


## 23. Whole-System Capability Inventory — 2026-10-02

Status: **COMPLETED — REVIEW REQUIRED BEFORE SHELL SIMPLIFICATION**

Supporting inventory:
- `docs/INSTRUCTOS_CAPABILITY_INVENTORY.md`

Purpose:
- reconstruct the capabilities already built across InstructOS / GradeFlow, Classroom, Planner, IED, Science web, and native Science PowerPoint;
- identify duplicate implementations and hidden/forgotten capabilities;
- classify capabilities provisionally as KEEP / MERGE / MOVE / DUPLICATE / RETIRE CANDIDATE / UNCERTAIN;
- prevent useful functionality from being lost during visual simplification.

Key finding:
- the system is primarily suffering from **overlap and competing presentation layers**, not from a lack of functionality.
- current Home visibly combines several generations of navigation/dashboard concepts.
- Classroom, Teach Surface, and the legacy Teacher Dashboard each contain meaningful live-teaching capabilities.
- Planner, dashboard timetable/reminders, class schedules, and class notes overlap but are not identical.
- IED production security/admin, bilingual lifecycle work, and Science courseware remain separate subsystem authority streams.
- Science web presentation has multiple generations; native PowerPoint remains an independent authority.
- Ask InstructOS is a real callable/server implementation, but a small grounding branch remains diverged and requires later review.

No-change rule:
- this milestone changed documentation only;
- no application behavior, routes, Firebase data, IED behavior, Science content, Classroom behavior, Planner behavior, grade logic, or PowerPoint artifacts were modified.

Next decision:
- Stuart reviews the capability map by teacher job.
- only after that review should the product hierarchy and Shell/Home simplification be defined.
- do not begin shell redesign automatically.


## 24. Teacher-job review and shell hierarchy — 2026-10-02

Status: **DECISION LOCKED — SHELL SIMPLIFICATION MAY PROCEED IN SMALL SLICES**

The capability inventory was reviewed by teacher job rather than by code ownership.

### Canonical teacher jobs

1. **Start / continue the day** — Home
   - teaching context;
   - reminders / attention;
   - compact communication signal;
   - direct launch into the current working area.

2. **Plan** — Planner
   - teacher-wide reminders, timetable, calendar import;
   - class-specific schedules remain attached to class context until a later durable lesson-history model exists.

3. **Teach** — Classroom inside a selected class
   - Classroom is the canonical live-teaching surface;
   - seating/map is the primary composition;
   - useful tools from Teach Surface and the legacy Teacher Dashboard are migration sources, not separate future destinations.

4. **Manage / review a class** — Classes / Class workspace
   - roster;
   - schedule;
   - Classroom;
   - students;
   - assessment;
   - results;
   - export.

5. **Assess** — class context
   - Gradebook, categories, exams, results and export stay mature, protected subsystems;
   - they are not global top-level apps.

6. **Review a student** — Student Profile from class/student context
   - no new duplicate student identity is introduced.

7. **Publish / share school content** — connected IED / Science systems
   - IED Studio, public hubs, Science web and native PowerPoint keep their existing ownership boundaries;
   - InstructOS connects to them rather than absorbing them.

8. **Utilities / operations** — secondary tools
   - Messages;
   - School Data Inbox / Knowledge Hub;
   - Whiteboard;
   - Ask InstructOS;
   - Connected/admin entry while its final placement remains under review.

### Global navigation decision

Keep the existing dock hierarchy:
- Home;
- Planner;
- Classes;
- All Apps.

Do not redesign the approved Home during this slice.

The global launcher is now a curated list of standalone/cross-class tools only:
- Classes;
- Planner;
- Whiteboard;
- Messages;
- Knowledge Hub / School Data Inbox;
- Assistant;
- Connected.

The following remain registered and reachable through contextual workflows, but are no longer advertised as competing top-level apps:
- Teach;
- Seating;
- Gradebook;
- Export;
- Attendance;
- Files;
- Reports.

Reason:
- Gradebook/Seating/Export/etc. require class context and already belong in the class workspace;
- Attendance does not yet have a canonical modern service;
- Files/Reports currently map onto other class tools rather than independent mature destinations;
- Teach is a legacy live-teaching environment whose useful capabilities must be merged into Classroom before retirement.

### Preservation rule

This is visibility simplification, not feature retirement.

No routes, services, data models, repositories, grading logic, Classroom behavior, Planner behavior, IED behavior, Science content, Firebase schema, or PowerPoint authority are deleted or rewritten by this decision.

Legacy surfaces remain available until parity is proven.

### Shell Simplification S1

First implementation slice:
- curate the global launcher only;
- add a regression test proving class-context apps remain registered but are not globally promoted;
- make no Home visual redesign;
- make no dock redesign;
- make no route deletion.

Next gate after S1 validation:
- inspect the remaining Home secondary/legacy navigation surfaces and remove only duplicated presentation, not capability;
- then begin controlled migration of live-teaching utilities into Classroom.


### Shell Simplification S1 validation — 2026-10-02

Status: **APPROVED**

Validated workflow:
- GitHub Actions run `36969485735`;
- exact shell code head: `b45e7a263e0255b4634e3fa86c88a6b0d92dd37d`.

PASS:
- full Flutter analyze;
- shell hierarchy regression test;
- Flutter release web build;
- GitHub Pages artifact/deployment.

Validated behavior:
- the global launcher now promotes only standalone/cross-class tools;
- class-context and legacy live-teaching apps remain registered for existing routes;
- no route, service, model, repository, grading logic, Classroom behavior, Planner behavior, IED behavior, Science content, Firebase schema, or PowerPoint authority was removed.

Post-validation review:
- legacy Home tools are already gated behind `More Home tools`;
- no further Home deletion is justified yet because those preserved surfaces still contain capabilities awaiting migration.

Next controlled slice:
- migrate **Random Student** into the canonical Classroom surface using the existing seating-based `StudentPickerSheet`;
- do not add Random Table, participation, groups, timer, poll, QR, or whiteboard in the same slice.


## 25. Classroom consolidation slice C2 — Random Student — 2026-10-02

Status: **APPROVED**

Purpose:
- begin moving proven live-teaching utilities into the canonical Classroom surface one capability at a time;
- reuse existing behavior instead of rebuilding the legacy Teacher Dashboard or Teach Surface.

Implementation:
- Classroom Today now exposes `Random student`;
- the action reuses the existing `StudentPickerSheet`;
- the picker uses the real current class roster;
- students with active seat assignments receive the existing ordered-seat label;
- unseated students remain eligible and are shown as not currently seated;
- existing picker animation, avoid-repeats behavior, and reset-round behavior are preserved;
- no new random-selection persistence or parallel service was created.

Privacy / presentation:
- the action lives in the private Classroom tools drawer;
- Presentation mode continues to hide the teacher drawer and Random Student action.

Validation:
- GitHub Actions run `36969995531`;
- validated head: `d97895e222a1c6a1a39a79b21c89270701520264`;
- full Flutter analyze: PASS;
- shell hierarchy regression: PASS;
- Classroom widget regression suite: PASS;
- release web build: PASS;
- GitHub Pages deployment: PASS.

Validation note:
- the first run correctly caught an over-specific test assertion because the reused picker shows a seat label in both its selected card and roster row;
- product behavior was correct;
- the assertion was fixed to reflect the existing picker UI and the full gate then passed.

Preserved:
- legacy Teacher Dashboard picker remains untouched;
- Teach Surface remains untouched;
- seating persistence and room setup remain untouched;
- no Random Table, groups, participation, timer, poll, QR, whiteboard, attendance, notes, Planner, Gradebook, IED, Science, Firebase, or PowerPoint behavior changed.

Next candidate:
- **Random Table** is the next small approved Classroom utility because it is tied directly to the active seating layout and has no durable data requirement.
- implement it only from occupied/eligible classroom tables and keep it private to teacher mode.
