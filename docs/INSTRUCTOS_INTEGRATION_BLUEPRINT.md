# InstructOS Integration Blueprint

Status: AUTHORITATIVE AUDIT / BLUEPRINT  
Date: 2026-10-01  
Primary control: `docs/INSTRUCTOS_UNIFICATION_CONTROL.md`  
Active InstructOS branch: `integration/instructos-unification`

## 0. Executive conclusion

The project does not need another product, another backend, or another wholesale rebuild.

Most of the required capability already exists across four working systems:

1. InstructOS / GradeFlow
2. IED Learning Hub + IED Studio
3. Science Lessons / Science courseware web workspace
4. Native PowerPoint courseware
5. Approved 1 October Classroom UX as the live-teaching interaction reference

The remaining problem is integration.

The systems currently use different codebases, navigation patterns, authentication boundaries, naming, and visual languages. The goal is to make them behave as one teacher product without forcing them into one codebase.

The future operating principle is:

**one teacher experience, clear ownership, stable IDs, explicit links, no duplicate job owners.**

---

## 1. Current system map

### 1.1 InstructOS / GradeFlow

Repository:
- `gastonstuart-lab/Gradeflow`

Primary integration branch:
- `integration/instructos-unification`

Default branch:
- `main`

Role:
- private teacher operating system;
- class and student operations;
- grading and assessment;
- classroom context;
- planning/reminders;
- teacher utilities;
- future cross-system front door.

Current strong areas:
- classes;
- class archive/restore;
- per-class student rosters;
- grading categories;
- grade items;
- scores;
- score history/undo;
- exams;
- final results;
- exports;
- seating layouts;
- room setups;
- student detail;
- existing Home/OS shell;
- Planner;
- Google Drive read access;
- Ask InstructOS architecture.

Current hybrid/local areas:
- Planner reminders;
- Planner timetables;
- class notes;
- class schedules;
- some dashboard preferences;
- wallpaper/theme/personalization;
- some legacy classroom tools.

Current overlapping surfaces:
- Home;
- legacy Teacher Dashboard;
- ClassSurface;
- TeachSurface;
- Seating;
- new Classroom proof shell;
- legacy class-detail routes.

Conclusion:
- InstructOS is the correct private operational system of record.
- GradeFlow is not a future separate product.
- GradeFlow grading functionality remains inside InstructOS.

### 1.2 IED Learning Hub / IED Studio

Repository:
- `gastonstuart-lab/eep-student-showcase`

Default branch:
- `design/final-premium-assets`

Important descendant authorities:
- `codex/production-ready-ied-hub`
- `feature/bilingual-content-layout-scheduling-v2`
- `science-courseware-production`

Role:
- public IED website;
- EEP;
- EEP Showcase;
- ESL subject hubs;
- content publishing;
- department/subject management;
- staff permissions;
- public/student-facing content;
- content/resource library.

Core public routes proven in production-ready branch:
- `/` and `/ied`
- `/eep`
- `/eep/showcase`
- `/eep/showcase/submit`
- `/submit`
- `/esl`
- `/esl/science`
- `/esl/language-arts`
- `/esl/performance-arts`
- `/esl/social-studies`
- `/projects/:id`
- `/about`
- `/login`

Protected teacher routes:
- `/admin`
- `/admin/pending`
- `/admin/approved`
- `/admin/hubs`
- `/admin/hubs/:sectionId`
- `/admin/users`
- audit/activity support in the workspace model.

Core Firestore collections:
- `projects`
- `contentItems`
- `hubPages`
- `adminUsers`
- `staffUsernames`
- `auditLogs`

Conclusion:
- IED remains the shared/public content platform.
- It must not become the private grade/attendance/student-note database.

### 1.3 Science Lessons web workspace

Repository:
- currently implemented inside `eep-student-showcase`

Strong current implementation branch:
- `science-courseware-production`

Important relationship:
- `science-courseware-production` is 160 commits ahead of `codex/production-ready-ied-hub` and 0 behind it.
- therefore it contains the production-ready IED core and adds Science work.
- however other IED feature branches contain improvements not merged into this Science branch.

Current architecture:
- multi-page Vite build;
- normal IED application uses `index.html`;
- Science Lessons uses separate `science-lessons.html`;
- Science Hub can link to `/science-lessons.html`.

Current Science model includes:
- stable lesson `id`;
- `unitId`;
- year;
- semester;
- chapter;
- lesson order;
- duration;
- status;
- source references;
- slides;
- resources;
- resource IDs;
- Drive IDs;
- URLs;
- presentation resources;
- source-slide traceability.

Current Science workspace supports:
- J1/J2 selection;
- semester selection;
- unit/lesson library;
- lesson viewer;
- presentation;
- teacher notes/resources;
- bilingual/Traditional Chinese support;
- source references;
- courseware experiments.

Critical audit finding:
- displayed progress such as “Continue last lesson”, “42%”, and “Last opened at slide…” is not proven to be persisted teacher progress.
- the Science product blueprint explicitly postpones Firebase persistence.
- do not treat current visual progress state as a production data source.

Conclusion:
- Science provides a strong course/lesson/resource identity model.
- persistent teacher lesson progress is still a gap.

### 1.4 Native Science PowerPoint/courseware

Repository:
- `gastonstuart-lab/science-courseware-ppt-private`

Branch:
- `audit-snapshot-2026-09-17`

Role:
- native editable PowerPoint production system;
- locked curriculum content;
- accepted shell/state architecture;
- separate image/asset pipeline;
- deterministic QA.

Current authority rules are already strong and explicit.

Important current checkpoints:
- J2 C1 S1: `J2-C1-S1-RETURN-TO-FIXED-SHELL.pptx`
- J2 C1 S2: certified `J2-C1-S2-empty-visual-shell-v6.pptx`

The private audit explicitly states:
- React/Firebase IED web material does not belong in the active native PowerPoint production system;
- PowerPoint authorities must stay protected;
- web lesson players are not native-PowerPoint authority.

Conclusion:
- keep this system separate;
- expose PowerPoint outputs to InstructOS/Science as resources;
- never rebuild native PowerPoint inside InstructOS.

### 1.5 Classroom

Authority:
- approved 1 October 2026 Classroom Planner interaction.

Role:
- live teaching;
- classroom/seating-first interaction;
- fast teacher actions;
- projector-safe presentation;
- touch-friendly Surface Pro workflow.

Current InstructOS branch contains a C1 proof shell showing that real ClassService, StudentService and SeatingService data can power a new Classroom surface.

Important:
- that C1 shell is not the final approved Classroom visual implementation;
- the approved 1 October interaction remains the UX authority;
- stop further Classroom feature work during this integration phase.

---

## 2. Authoritative branch/component map

There is no single branch that is authoritative for every IED subsystem.

Authority must be tracked by responsibility.

| Subsystem | Current authority / strongest reference | Decision |
|---|---|---|
| InstructOS integration | `integration/instructos-unification` | active integration branch |
| InstructOS production core | current `main` inherited into integration branch | preserve |
| Classroom backend/data | ClassService + StudentService + SeatingService + repository layer | preserve |
| Classroom UX | approved 1 Oct 2026 Classroom Planner | visual/interaction authority |
| IED public premium base | `design/final-premium-assets` as historical base, included by descendants | preserve through descendant branch |
| IED security/auth/admin core | `codex/production-ready-ied-hub` | core authority |
| IED bilingual/content-layout/lifecycle work | `feature/bilingual-content-layout-scheduling-v2` | feature authority; reconcile later |
| Science web lessons/courseware | `science-courseware-production` | strongest Science authority |
| Science experimental variants | gold/ppt/quality branches | reference until specific feature promoted |
| Native PowerPoint | `science-courseware-ppt-private@audit-snapshot-2026-09-17` authority documents | protect |

Do not promote a whole IED branch merely because it has more commits.

Future IED consolidation should start from the production-ready security/admin base and deliberately reconcile:
- bilingual content lifecycle/layout work;
- Science lesson/courseware work;
- any later approved visual fixes.

---

## 3. Ownership map

### KEEP — InstructOS owns

- Teacher Home / Desktop
- Classes
- operational class context
- Students
- Gradebook
- Categories
- Exams
- Results
- Export
- private classroom state
- seating assignments
- room setups
- future attendance
- private student notes
- class notes
- reminders
- Planner
- teacher workflow
- teacher-facing cross-system launcher
- Ask InstructOS later

### KEEP — IED owns

- public IED website
- EEP
- EEP Showcase
- ESL subject hubs
- department/subject pages
- public content
- student-publication workflows
- teacher/admin content publishing
- content lifecycle
- staff content permissions
- public resource library
- hub configuration

### KEEP — Science layer owns

- Science course structure
- unit IDs
- lesson IDs
- source references
- Science resource references
- Science teaching sequence
- lesson presentation metadata
- Science-specific bilingual teaching support
- Science lesson/resource library

### PROTECT — native PowerPoint owns

- native PowerPoint source/shell authority
- PowerPoint production
- PowerPoint QA
- interaction-state architecture
- asset insertion
- native deck output

### CONNECT

- InstructOS class → Science course
- InstructOS class → current Science lesson
- Science lesson → PowerPoint resource
- Science lesson → web lesson
- InstructOS Home → IED Studio
- InstructOS Home → Science course
- IED Science Hub → Science Lessons
- Classroom → same InstructOS class/student/grade context
- Planner → completed/current lesson context
- InstructOS → IED resource link

### MERGE LATER

- TeachSurface live-class tools into the canonical Classroom experience
- old Seating route into Classroom after approved parity
- overlapping dashboard tools into their canonical destinations
- class workspace routing/navigation duplication

### RETIRE LATER

Only after parity:
- legacy Teacher Dashboard as primary destination
- duplicate Seating screen as normal teaching route
- duplicate Teach/Seating live-class entrypoints
- old class-detail aliases/duplicate navigation
- duplicate dashboard copies of Planner/Classroom actions

### PROTECT / DO NOT TOUCH

- grade calculations
- category calculations
- exam calculations
- final result calculations
- export generation
- current IED Firestore security rules
- IED staff provisioning backend
- native PowerPoint authorities
- certified Science PPT checkpoints

### UNCERTAIN / REQUIRES LATER IMPLEMENTATION

- canonical attendance repository
- canonical student-note repository
- durable lesson-progress repository
- cross-project teacher identity bridge
- teacher-wide student identity across classes
- structured InstructOS resource-reference model

---

## 4. Data / identity map

### 4.1 Teacher

InstructOS:
- canonical operational ID = Firebase Auth UID when cloud-backed;
- `Class.teacherId` uses this user ID;
- Firestore root = `users/{userId}`.

IED:
- separate Firebase project;
- separate Firebase Auth UID;
- `adminUsers/{uid}`;
- username/hidden-auth-email model;
- section and permission model.

Important:
- the same person does not currently have the same Firebase UID across the two projects.

Future rule:
- do not fake UID equality.
- create an explicit application-level identity link later.

Recommended future bridge concept:
- InstructOS user UID remains private operational teacher key;
- IED admin record may later carry a linked InstructOS teacher key or a dedicated shared `teacherKey`;
- cross-project linkage is explicit, auditable, and optional.

No identity migration is part of this audit.

### 4.2 Class

Current InstructOS canonical:
- `classId`
- teacher-scoped;
- class fields include subject, school year, term, group number.

IED:
- public project records currently contain `className` text;
- hub content is section-based, not class-ID based.

Future rule:
- InstructOS remains class system of record.
- IED public content should not invent private class records.
- when private InstructOS needs to reference IED content, use resource IDs/URLs, not duplicated classes.

### 4.3 Student

Current InstructOS:
- student is stored beneath a class;
- model contains `studentId` and `classId`;
- Firestore path is `users/{teacherUid}/classes/{classId}/students/{studentId}`.

Critical limitation:
- code does not guarantee one global teacher-wide student record across multiple classes.

Current safe identity:
- `classId + studentId`

Future goal:
- if cross-class student history becomes required, introduce an explicit canonical student mapping.
- do not silently assume two same-named students are the same person.
- do not use display name as an identity.

### 4.4 Department / Hub

IED has strong stable IDs:
- `ied`
- `eep`
- `esl`
- `esl-science`
- `esl-language-arts`
- `esl-performance-arts`
- `esl-social-studies`

These should remain canonical IED section IDs.

### 4.5 Course / Unit / Lesson

Science currently has:
- year;
- semester;
- `unitId`;
- stable lesson `id`;
- lesson order;
- source references.

Recommendation:
- Science lesson ID becomes the canonical cross-system lesson reference for existing Science content.
- create a simple course key later, e.g. a stable identifier for J1 Science / J2 Science rather than matching free-text subject names.
- do not infer course identity solely from display strings.

### 4.6 Resource

Existing IDs:
- IED `ContentItem.id`
- Science `LessonResource.id`
- Science `LessonSourceReference.id`
- Drive file IDs
- external URLs
- PowerPoint file identity/authority manifests

Gap:
- InstructOS does not have one structured resource-reference model.

Recommended future contract:
a resource reference should minimally carry:
- resource ID
- source system
- external/source ID
- type
- title
- URL or Drive/file locator
- course/lesson association
- teacher-only/public flag where relevant

This should link; it should not copy the resource body into multiple systems.

### 4.7 Assessment

Canonical assessment data remains in InstructOS grading/exam models.

IED content can link to assessment resources but must not duplicate grades.

### 4.8 Attendance

No clean current canonical modern AttendanceService/repository was confirmed.

Future key:
- teacher/class context
- date/session
- student ID
- status

Do not revive legacy attendance URL behavior as the new attendance data model.

### 4.9 Lesson progress

Science currently shows progress UI but durable persistence is not established.

Future progress record should reference:
- teacher
- class
- Science lesson ID
- last completed teaching state/source slide
- updated timestamp
- optional completed flag

This belongs in the private teacher system, not public IED content.

---

## 5. Firebase / backend map

### 5.1 InstructOS Firebase

Project:
- `gradeflow-20260113`

Auth:
- Firebase Auth where available;
- Google sign-in;
- email/password support;
- local/offline account fallback.

Firestore hierarchy:
- `users/{userId}/classes`
- class students
- grade items
- scores
- score history
- exams
- categories
- seating layouts
- seating metadata
- user templates
- user room setups

Repository abstraction:
- `DataRepository`
- `FirestoreRepository`
- `LocalRepository`
- `RepositoryFactory`

Strength:
- core academic data already has a proper local/cloud abstraction.

Hybrid limitation:
- Planner reminders/timetables;
- class notes;
- class schedules;
- several preferences;
remain SharedPreferences/local.

### 5.2 IED Firebase

Project:
- `eep-student-showcase`

This is deliberately separate from Gradeflow.

Auth:
- closed staff model;
- username mapped to hidden Firebase Auth email;
- protected owner support;
- Cloud Functions for staff management;
- explicit permissions and section access.

Firestore:
- public content/project collections;
- private staff/access/audit collections.

Security:
- public reads restricted by published/approved state;
- staff permissions enforced in UI, Functions, and Firestore rules.

### 5.3 Cross-project rule

Do not merge the Firebase projects merely for convenience.

Do not allow IED public content code to access private Gradeflow academic collections.

First-stage integration:
- browser routes/URLs;
- stable IDs;
- explicit resource references;
- explicit linked teacher identity later.

Future optional SSO/identity linking must be designed deliberately and security-reviewed.

---

## 6. Shared UX / design language

The existing systems are already visually closer than they appear.

InstructOS teacher palette:
- dark navy backgrounds;
- light neutral canvases;
- blue primary;
- cyan teaching accent;
- amber attention;
- green success;
- rounded panels;
- 4/8/16/24/32/48 spacing scale.

IED Studio:
- navy sidebar;
- light neutral canvas;
- blue primary;
- white panels;
- similar compact radii;
- clear workspace navigation.

Science:
- navy shell;
- cyan Science accent;
- white/light content surfaces;
- system sans typography;
- pill navigation.

Recommended shared teacher design system:

### Core shell

Use common semantic roles:
- app background
- workspace background
- panel
- elevated panel
- border
- primary text
- secondary text
- muted text
- primary action
- success
- attention
- danger
- teaching/presentation accent

Do not force public IED marketing pages to look identical to private teacher screens.

### Shared teacher-facing palette

Use the InstructOS semantic palette as the shell reference.

Allow section accents:
- Science = cyan
- EEP = green
- Performance Arts = amber
- Social Studies = warm/coral
- general IED = blue

Section accent changes highlights, not navigation behavior.

### Typography

Use one teacher-facing system sans stack with:
- strong 800/900 page/title hierarchy;
- 700 action labels;
- 400/500 body;
- restrained uppercase eyebrow labels only for context.

Avoid a mixture of decorative fonts in operational teacher surfaces.

### Spacing

Canonical scale:
- 4
- 8
- 16
- 24
- 32
- 48

### Radius

Canonical teacher-facing scale:
- small 8–10
- medium 14
- large 20
- extra-large 28
- pill 999

### Touch

Teacher operational controls:
- minimum practical touch target around 44 px;
- primary live-teaching actions should be larger where space permits;
- no tiny text-only controls for essential classroom actions.

### Presentation

Public/projector mode:
- no grades;
- no private notes;
- no admin messages;
- no staff-only controls;
- no hidden private drawer state exposed;
- clear exit;
- large readable content;
- state preserved on return where practical.

---

## 7. Canonical naming proposal

Teacher-facing names:

| Current variants | Canonical teacher-facing term |
|---|---|
| GradeFlow / Gradeflow OS | InstructOS |
| Teach / Teach Mode / Classroom tools | Classroom |
| Seating / Classroom Map | Classroom Setup when editing room; Classroom in normal use |
| Dashboard / OS Home | Home |
| Schedule / timetable planning | Planner |
| Gradebook | Grades when top-level; Gradebook inside a class is acceptable |
| Hub admin / admin workspace | IED Studio |
| Hub / section | Department or Subject Hub depending context |
| Science Lessons / courseware web | Science |
| Presentation / PPTX / web lesson | Resource when listed generically; keep exact type when opening |
| Student Detail | Student Profile |
| Results / Final Results | Results |
| Export | Export |
| Ask AI / assistant | Ask InstructOS |

Internal code names do not need broad renaming if they are stable.

---

## 8. Navigation hierarchy

Avoid one enormous permanent sidebar.

### Teacher entry

**Home**

Home is the front door and decision surface.

Primary directions:
- Classroom
- Planner
- Grades
- Students
- Departments
- Courses / Science
- Resources

These can appear as context-aware launch areas rather than one giant menu.

### Class context

When a class is active:
- Classroom
- Grades
- Students
- Planner / lesson context
- Results
- Exams
- Export

Avoid exposing Classroom and Seating as equal long-term destinations.

### IED context

From Home:
- Departments → IED Studio
- choose department/subject context
- Create Content
- Content Library
- Submissions where permitted
- Staff Access for administrators

### Science context

From Home or a Science class:
- Science course
- current unit/lesson
- resume current teaching point
- open lesson resources
- open native PowerPoint or web lesson
- return to same class context

---

## 9. Teacher Desktop / Home functional specification

Do not implement in this audit.

Purpose:
answer “what should I do now?”

### Primary region

**Next class / current class**
- class name
- subject
- time
- room if known
- Open Classroom
- Open lesson/resource

Can be partially powered now by:
- InstructOS classes
- Planner timetable data
- class schedules

Gap:
- timetable/reminders are local;
- class-to-course/lesson mapping is not yet structured.

### Today

Show:
- today's class sequence
- current/next class
- relevant reminders
- upcoming assessment items when data can be trusted

Existing support:
- Planner
- ClassScheduleService
- reminders
- grade/exam data

### Continue

Show:
- last active class
- last lesson/resource
- lesson progress

Gap:
- durable Science lesson progress does not yet exist.

### Attention

Show only actionable items:
- overdue reminder
- upcoming assessment
- incomplete setup
- unresolved class task

Do not recreate the legacy giant dashboard.

### Destinations

Provide clear launch points for:
- Classroom
- Planner
- Grades
- Students
- IED Studio
- Science
- Resources

### Existing Home capability to reuse

Current Home already has:
- active classes;
- primary class selection logic;
- reminders;
- student counts;
- unread communication signal;
- OS launcher/dock;
- theme/personalization.

Therefore:
- simplify and connect existing Home;
- do not create Home 2.

---

## 10. Science integration map

### Keep

Science stable data model:
- lesson IDs
- unit IDs
- source references
- resource IDs
- resource types/formats
- lesson order
- year/semester
- bilingual support metadata

### Do not rely on yet

- visual “last opened” progress text
- 42% progress bar
- persistent progress implied by prototype UI

### Future connection

InstructOS class:
- gets an explicit Science course key;
- references a current Science lesson ID;
- stores teacher/class progress privately.

Science lesson:
- continues to own science content structure;
- exposes resources;
- can open web presentation;
- can point to native PowerPoint.

### Native PPT connection

Do not import PPT content into InstructOS.

Resource link:
- Science lesson ID
- resource ID
- type `Presentation`
- format `PPTX`
- Drive/file locator or approved launch URL
- authority/version metadata where useful

### IED Science Hub

Public Science Hub:
- public updates/resources/student work.

Science teacher workspace:
- private teacher course/lesson flow.

These are related but not the same job.

---

## 11. IED integration map

### Public IED

Remain public/school facing.

Do not force InstructOS dark OS styling onto public marketing/student pages.

### IED Studio

Teacher/admin operational experience should align with InstructOS:
- same spacing logic;
- same control density;
- same action hierarchy;
- same drawer/modal behavior;
- same terminology;
- same status language;
- same touch expectations.

Current IED Studio already has:
- Overview
- context switcher
- Create Content
- Content Library
- Submissions
- Staff Access
- Manage Hubs
- Audit & Activity
- responsive mobile navigation

This is valuable and should be preserved.

### IED branch reconciliation requirement

The future IED consolidation must preserve both:
- production-ready auth/security/admin;
- bilingual content layout/lifecycle/scheduling features;
- Science lesson/courseware entrypoint.

Do not replace one with another by branch reset.

---

## 12. Resource / PowerPoint integration model

### Resource ownership

IED content item:
- public/shared content resource.

Science resource:
- lesson-linked science teaching resource.

Native PowerPoint:
- authoritative teaching artifact.

InstructOS:
- launch/context owner for the teacher.

### Recommended reference-only contract

InstructOS should later store references, not copies.

Example conceptual fields:

- `resourceId`
- `sourceSystem`
- `externalId`
- `kind`
- `format`
- `title`
- `url` or Drive locator
- `courseKey`
- `lessonId`
- `teacherOnly`

### Existing bridge opportunities

ClassScheduleService already understands a generic Link field.

Science LessonResource already understands:
- ID
- type
- format
- href
- driveFileId
- teacherOnly

IED ContentItem already understands:
- ID
- sectionId
- linkUrl
- media/resource type
- publication state

These are compatible enough to create a lightweight connection layer later without moving content between databases.

---

## 13. Duplication / retirement map

### Teacher Dashboard vs Home

Current:
- legacy TeacherDashboard contains reminders, timetable, news/weather, class tools, participation, schedule, timer, QR, whiteboard, links and many utilities.
- HomeSurface is the newer OS destination.

Decision:
- Home becomes canonical.
- migrate only genuinely useful signals/actions.
- legacy Dashboard retires later.

### TeachSurface vs Classroom

Current:
- TeachSurface owns whiteboard/timer/groups/seating/poll.
- Classroom is intended to own live class context.

Decision:
- Classroom becomes canonical live-teaching destination.
- useful TeachSurface tools become contextual Classroom tools later.
- TeachSurface retires only after parity.

### Seating vs Classroom

Current:
- existing full seating screen
- C1 Classroom proof
- approved 1 Oct Classroom UX

Decision:
- approved Classroom UX becomes normal experience.
- seating engine is reused.
- old Seating remains setup/fallback until approval.
- later retire duplicate normal-use route.

### ClassSurface vs class-detail routes

Current:
- canonical OS class route
- schedule/class-detail route
- compatibility aliases.

Decision:
- keep ClassSurface as class context.
- reduce duplicate route concepts after parity.

### Planner vs dashboard timetable/reminders

Current:
- Planner has current reminder/timetable UI.
- legacy dashboard retains overlapping local data/tools.

Decision:
- Planner becomes canonical planning destination.
- Home consumes Planner signals.

### IED Studio vs InstructOS

Not duplicates.

IED Studio:
- content publishing/admin.

InstructOS:
- operational teacher/student/class data.

They need visual alignment and navigation connection, not merger.

### Science workspace vs native PowerPoint

Not duplicates.

Science workspace:
- lesson/course/resource organization and optional web presentation.

PowerPoint:
- native classroom presentation artifact.

Link them; do not replace one with the other.

---

## 14. Frozen systems

Until a specific integration milestone requires change, do not modify:

### InstructOS
- grade calculations
- score history behavior
- category calculations
- exam calculations
- final results
- export generation
- repository architecture

### IED
- staff provisioning security
- protected owner rules
- Firestore security boundary
- public publication controls
- existing production routes

### Science
- source-fidelity rules
- approved content authorities
- approved lesson IDs without deliberate migration

### PowerPoint
- source PPTX
- benchmark authorities
- accepted shells
- certified checkpoints
- authority hashes

### Classroom
- approved 1 October UX principles

---

## 15. Risks

### Risk 1 — branch authority confusion

IED contains multiple descendants of the same production-ready base.

Mitigation:
- authority by subsystem;
- reconcile deliberately;
- never reset one branch over another.

### Risk 2 — two Firebase projects

Teacher auth IDs differ.

Mitigation:
- explicit future identity bridge;
- no assumed UID equality;
- no immediate Firebase merger.

### Risk 3 — hybrid/local InstructOS data

Planner, notes and schedules are not fully cloud-backed.

Mitigation:
- do not claim cross-device reliability for these until migrated;
- use them for current UX where appropriate;
- migrate only in a dedicated later milestone.

### Risk 4 — student identity is class-scoped

A global student identity is not guaranteed.

Mitigation:
- current safe key = classId + studentId;
- introduce global mapping only if cross-class history is required.

### Risk 5 — fake Science progress

Prototype progress UI may look persistent when it is not.

Mitigation:
- create a real private progress record before exposing progress on Home.

### Risk 6 — navigation overload

Combining all systems could recreate a giant dashboard.

Mitigation:
- Home answers “what now?”;
- context-sensitive navigation;
- destinations grouped by teacher job.

### Risk 7 — visual unification becomes redesign mania

Mitigation:
- create semantic shared tokens;
- align teacher-facing shells;
- do not restyle every public IED page.

### Risk 8 — resource duplication

Copying PPT/IED/Drive content into InstructOS would create drift.

Mitigation:
- reference resources by stable ID/URL/Drive ID.

---

## 16. Exact recommended implementation sequence

### Phase A — Teacher Home integration

Goal:
- use existing Home as the unified front door;
- do not create Home 2.

First vertical slice:
- next/current class;
- today's classes;
- reminders;
- clear launch to Classroom;
- clear launch to Planner;
- clear launch to Grades;
- clear launch to Students;
- clear launch to IED Studio;
- clear launch to Science.

Use existing data only.

Do not invent persistent lesson progress yet.

### Phase B — connected destinations contract

Add the smallest stable connection model/config needed for:
- IED Studio URL;
- Science workspace URL;
- Science course/lesson IDs;
- resource references.

No cross-database copying.

### Phase C — Science class mapping + real progress

Create:
- class → Science course mapping;
- class → current lesson ID;
- private durable lesson progress.

Then Home can show:
- continue Science lesson;
- last taught point;
- next resource.

### Phase D — Planner / lesson history

Connect:
- current lesson;
- completed lesson;
- next lesson;
- reminders;
- class schedule.

Decide deliberately which local planning records must become cloud-backed.

### Phase E — IED Studio teacher UX alignment

Preserve IED functionality.

Align:
- shell tokens;
- terminology;
- interaction patterns;
- navigation behavior;
- touch targets;
- status language.

Reconcile:
- production-ready security/admin;
- bilingual content lifecycle/layout branch;
- Science lesson branch.

### Phase F — Classroom completion

Return to Classroom only after the wider integration path exists.

Use approved 1 October interaction as visual authority.

Connect:
- attendance
- random student/table
- student quick card
- notes
- lesson log
- Gradebook/Profile links

### Phase G — identity hardening

Only if needed:
- explicit teacher identity link between Firebase projects;
- global student identity mapping for cross-class history.

Do not do this casually.

### Phase H — retirement

After parity:
- legacy Dashboard
- duplicate Teach path
- duplicate Seating normal-use route
- duplicate class routes
- stale dashboard tools

### Phase I — Ask InstructOS

Last.

Only after:
- class context is coherent;
- resource references are coherent;
- lesson progress is real;
- planning data is reliable.

---

## 17. End-of-phase evaluation

### PASS

Sufficiently understood and locked:
- InstructOS is private operational system of record.
- IED is shared/public content and publishing system.
- Science has stable lesson/resource identity but not yet durable progress.
- PowerPoint remains independent authority/resource production.
- Classroom UX is approved and should not dominate current integration work.
- Gradeflow and IED use separate Firebase projects and separate auth identities.
- InstructOS core academic data is repository-backed.
- Planner/class notes/class schedule remain hybrid/local.
- IED branch authority must be by subsystem.
- resource integration should use stable references, not copied data.
- Home should be the unified front door.

### UNCERTAIN

Still requires future implementation/validation:
- exact cross-project teacher identity mechanism;
- whether a teacher-wide global student registry is required;
- exact durable lesson-progress schema;
- exact resource-reference persistence location;
- which bilingual/content lifecycle commits are finally promoted during IED branch reconciliation;
- C1 Classroom runtime/visual approval.

### DRIFT CHECK

No application feature work was performed during this audit.

No:
- Classroom redesign;
- attendance build;
- Home rewrite;
- Planner rewrite;
- Gradebook change;
- exam/results change;
- Firebase migration;
- IED public redesign;
- PowerPoint modification;
- OpenAI API work;
- legacy-screen deletion.

### PRESERVED

Untouched:
- Gradebook
- categories
- exams
- results
- export
- current Firestore architecture
- IED security/admin logic
- IED public production routes
- Science lesson content
- native PowerPoint authorities
- certified PowerPoint checkpoints

### NEXT DECISION

The next implementation milestone should be:

**Teacher Home Integration — Vertical Slice 1**

Reason:
- the architecture is now mapped;
- Home already exists and already reads classes/reminders/student counts;
- it is the correct front door;
- it can connect the existing systems without inventing new backends;
- it will make the separate systems begin to feel like one product immediately.

Scope must stay small:
- simplify/connect current Home;
- use existing data;
- add clean destinations to Classroom, Planner, Grades, Students, IED Studio and Science;
- do not fake Science progress;
- do not migrate Firebase;
- do not redesign IED or Classroom.
