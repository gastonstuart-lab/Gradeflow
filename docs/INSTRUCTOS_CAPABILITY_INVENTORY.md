# InstructOS Whole-System Capability Inventory

Status: SUPPORTING INVENTORY — subordinate to `docs/INSTRUCTOS_UNIFICATION_CONTROL.md`  
Audit date: 2026-10-02  
Primary integration branch: `integration/instructos-unification`

## 1. Purpose

This document reconstructs the capabilities that already exist across InstructOS / GradeFlow, Classroom, Planner, IED, Science web courseware, and native Science PowerPoint production.

It is intentionally an **inventory, not a redesign plan**.

Nothing in this document authorizes deletion, retirement, migration, or UI replacement. Classifications are provisional so Stuart can review what is useful, duplicated, misplaced, obsolete, or still uncertain before the unified product hierarchy is changed.

## 2. Systems inspected

### InstructOS / GradeFlow
Repository: `gastonstuart-lab/Gradeflow`

Primary current branch:
- `integration/instructos-unification`

Historical / subsystem branches inspected or compared:
- `main`
- `integration/gradeflow-os-home-verified`
- `quality/os-home-teacher-command-center`
- `feature/instructos-os-home-simplification`
- `feature/class-workspace-os-redesign`
- `feature/gradebook-rapid-score-entry`
- `feature/gf-047-data-inbox-premium-redesign`
- `quality/seating-plan-classroom-control-surface`
- `feature/seating-classroom-map-redesign`
- `feature/navigation-confidence`
- Ask InstructOS feature/quality branches

Important branch finding:
- most major historical redesign branches are fully behind the current integration branch and therefore their merged work is already represented in the current history;
- `feature/ask-instructos-ai-grounding` is a small diverged exception with three commits not fully absorbed by the current integration branch and must remain an explicit review item.

### IED / Science web
Repository: `gastonstuart-lab/eep-student-showcase`

Subsystem authorities inspected:
- `codex/production-ready-ied-hub`
- `feature/bilingual-content-layout-scheduling-v2`
- `science-courseware-production`
- `codex/science-courseware-final-production`

Important branch finding:
- there is no single IED branch that contains every strongest subsystem;
- production-ready auth/admin, bilingual lifecycle work, and Science courseware must be treated as separate authority streams until deliberately reconciled.

### Native Science PowerPoint
Repository: `gastonstuart-lab/science-courseware-ppt-private`

Inspected:
- `audit-snapshot-2026-09-17`
- `AUDIT/CURRENT-AUTHORITY-2026-09-17.md`

This repository remains a separate native PowerPoint production and QA system.

---

# 3. Human-readable capability map

## Home / teacher desktop
- InstructOS Home
- teaching context
- active class selection
- reminders / attention
- unread communication signal
- class launchers
- legacy Command Center
- legacy Daily Signals
- legacy pinned apps / quick tools
- Ask InstructOS entry
- theme / personalization

## Live teaching
- Classroom
- seating map
- room setup
- presentation mode
- old Teach surface
- whiteboard
- timer
- group maker
- random name picker
- quick poll
- participation counter
- QR tool
- schedule viewer/importer
- class-tool presentation mode

## Planning
- Planner
- reminders
- timetable
- calendar import
- class schedules
- class notes
- dated reminders
- local dashboard timetable/reminder variants

## Classes
- class list
- class workspace
- class overview
- schedule
- gradebook
- exams
- results
- Classroom
- Seating
- students
- exports
- archive / restore

## Students
- class roster
- student profile
- student photo
- seat / class context
- grade summary
- deleted-student recovery
- student import

## Assessment
- grading categories
- grade items
- rapid score entry
- score persistence / pending-write protection
- final exam entry
- exam imports
- final-results calculation
- per-student calculated results
- score history / repository-backed academic data

## Imports
- local CSV/XLSX
- Google Drive import
- Drive link import
- Drive browser
- roster/class/exam/calendar ingestion
- School Data Inbox / import staging flow

## Exports / reporting
- per-student
- per-class
- class details
- all classes
- CSV
- XLSX
- PDF
- substitute / printable report flows

## Communication
- Communication Hub
- message/conversation repositories
- unread-message signal
- Home message widgets / signals
- communication workspace service

## IED
- public IED home
- EEP hub
- EEP student website showcase
- public student submission
- ESL hub
- Science / Language Arts / Performance Arts / Social Studies hubs
- bilingual public presentation
- teacher login
- IED Studio
- Create Content
- Content Library
- submissions review
- hub management
- staff access
- audit/activity
- section-based permissions
- content lifecycle / scheduling branch
- content layout/placement controls

## Science web
- Science teacher lesson workspace source
- J1/J2 navigation
- semester/unit/lesson organization
- lesson library
- resource metadata
- source references
- web lesson players
- enhanced opening lessons
- courseware app
- presentation-v2 prototype
- visual QA workflows
- Science public hub

## Science PowerPoint
- immutable source decks
- accepted shell authority
- state-slide interaction architecture
- asset manifests
- structural QA
- native-click QA
- content/source fidelity
- certified output checkpoints
- authority-chain documentation

## AI
- Ask InstructOS UI
- Firebase callable
- server-side OpenAI call
- conversation payload
- context mode
- current limited grounding
- separate diverged grounding branch requiring review

---

# 4. Detailed capability inventory

Legend:
- **KEEP** = clearly useful and already has an appropriate home
- **MERGE** = overlapping implementations should eventually become one
- **MOVE** = useful capability currently lives in the wrong surface
- **DUPLICATE** = multiple competing implementations exist
- **RETIRE CANDIDATE** = likely obsolete after parity is proven
- **UNCERTAIN** = purpose, authority, persistence, or final use still needs review

## 4.1 Home / shell / navigation

| Capability | Current location | Status | Data reality | Provisional classification |
|---|---|---|---|---|
| InstructOS Home | `lib/os/surfaces/home_surface.dart` | Working | Mixed real + local signals | KEEP |
| Teacher Home integration panel | `lib/components/home/teacher_home_integration_panel.dart` | Working / previewed | Real current class + Planner reminder + destination contract | KEEP |
| Teaching context | Home integration panel | Working | Current class context; not true next-class resolution | KEEP |
| Destination links | Home integration panel + `connected_destinations.dart` | Working | Explicit URL contract | KEEP |
| Legacy Command Center | older Home composition still preserved behind Home tools | Working / cluttered | Mixed | DUPLICATE |
| Daily Signals / Agenda / Messages rail | legacy Home tools | Working / secondary | Mixed | MOVE |
| Pinned Apps / Teacher launchpad | legacy Home tools | Working / secondary | Navigation only | DUPLICATE |
| Class workspace list on Home | legacy Home tools | Working | Real class list | MOVE |
| Bottom OS dock | OS shell | Working | Navigation | KEEP but hierarchy must be reviewed |
| More Home tools | current Home | Working | Exposes preserved older features | KEEP temporarily as preservation gate |
| Theme / dark-light controls | shell / Home | Working | Local preference | KEEP |
| Old Teacher Dashboard | `teacher_dashboard_screen.dart` + parts | Working legacy | Mixed local/service data | RETIRE CANDIDATE only after feature migration |

Observation: Home is currently the largest visible duplication family. The preview demonstrated that the new front door and preserved legacy command-center components are simultaneously visible, producing multiple competing navigation hierarchies.

## 4.2 Classroom / live teaching

| Capability | Current location | Status | Data reality | Classification |
|---|---|---|---|---|
| Classroom live-class surface | `lib/os/surfaces/classroom_surface.dart` | Working / approved direction | Real class, roster, seating services | KEEP |
| Seating map in Classroom | Classroom + `SeatingDesignerView` | Working | Repository-backed local/Firestore | KEEP |
| Setup Room mode | Classroom | Working | Repository-backed seating | KEEP |
| Read-only presentation mode | Classroom | Working | Uses active seating layout | KEEP |
| Collapsible tools drawer | `classroom_tools_drawer.dart` | Working | Navigation + seating context | KEEP |
| Full legacy Seating screen | `class_seating_screen.dart` | Working | Repository-backed seating | MERGE |
| Teach Surface | `lib/os/surfaces/teach_surface.dart` | Working | Real class/roster + local tool state | DUPLICATE |
| Whiteboard | Teach + dedicated whiteboard screen/component + legacy dashboard | Working | Mostly transient presentation state | MERGE |
| Countdown timer | Teach + legacy dashboard | Working | Session/local state | MERGE |
| Groups | Teach + legacy dashboard | Working | Real roster; generated transiently | MERGE |
| Quick poll | Teach + legacy dashboard | Working | Session/transient | MERGE |
| Seating entry in Teach | Teach | Working | Routes to seating | DUPLICATE |
| Random name picker | legacy Teacher Dashboard | Working | Real roster; transient pick | MOVE to Classroom |
| Participation counter | legacy Teacher Dashboard | Working | Per-dashboard/session/local behavior; persistence not established as canonical | UNCERTAIN / MOVE |
| QR tool | legacy Teacher Dashboard | Working | Generated utility | MOVE if still useful |
| Class schedule teaching tool | legacy Teacher Dashboard | Working | ClassScheduleService/local schedule data | MERGE |
| Tool full-screen/presentation mode | legacy Teacher Dashboard | Working | Session state | MERGE |

Important: the old Teacher Dashboard class tools are not decorative leftovers. They contain real teaching capabilities that are not all present in the current Classroom drawer.

## 4.3 Seating / room management

| Capability | Current location | Status | Data reality | Classification |
|---|---|---|---|---|
| Seating layouts | `SeatingService`, models, repository | Working | Local + Firestore repository support | KEEP |
| Room setups/templates | seating service/models | Working | Repository-backed | KEEP |
| Active layout | seating service | Working | Persistent | KEEP |
| Table/seat drag-drop | seating components | Working | Persistent via layout save | KEEP |
| Student assignment / swap | seating components | Working | Persistent | KEEP |
| Seat locking | seating engine | Working | Persistent | KEEP |
| Seat notes/reminders | seating model/engine | Working | Persistent in seating data | KEEP |
| Full-screen seating view | `full_screen_seating_view.dart` | Working | Real layout | MERGE with Classroom presentation |
| Printable / assignment views | seating components | Working | Derived from seating data | KEEP |
| Legacy Seating route | class workspace | Working | Real data | RETIRE CANDIDATE after Classroom parity |

## 4.4 Planner / scheduling / notes

| Capability | Current location | Status | Data reality | Classification |
|---|---|---|---|---|
| Planner surface | `planner_surface.dart` | Working | SharedPreferences/user-scoped local storage | KEEP |
| Reminders | Planner | Working | Local-only SharedPreferences | KEEP, future data decision needed |
| Reminder complete/delete | Planner | Working | Local-only | KEEP |
| Timetables | Planner | Working | Local-only SharedPreferences | KEEP |
| Selected timetable | Planner | Working | Local-only | KEEP |
| Calendar import | Planner | Working | CSV/XLSX parsed into reminders | KEEP |
| Teacher-wide planning | Planner | Working | Mixed local + class data | KEEP |
| Dashboard reminders | legacy Dashboard | Working | Same/legacy local preference family | MERGE |
| Dashboard timetable | legacy Dashboard | Working | Same/legacy local preference family | MERGE |
| Class schedule | `ClassScheduleService` + class detail/dashboard | Working | SharedPreferences/local | KEEP |
| Schedule CSV/XLSX import | class detail / legacy dashboard | Working | Local class schedule | KEEP |
| Google Drive schedule import | legacy dashboard/class tooling | Working | External Drive + local stored parsed schedule | KEEP |
| Class notes | `ClassNoteService` + class detail | Working | SharedPreferences/local | KEEP |
| Class note reminder dates | class detail | Working | Local | KEEP |
| Canonical lesson log | not established | Missing/fragmented | No durable canonical model | UNCERTAIN |

## 4.5 Classes

| Capability | Current location | Status | Data reality | Classification |
|---|---|---|---|---|
| Class list | `class_list_screen.dart` | Working | Repository-backed | KEEP |
| Create/edit class | class service/screens | Working | Repository-backed | KEEP |
| Archive/restore classes | deleted classes + trash service | Working | Repository-backed/soft delete | KEEP |
| Class workspace | `class_surface.dart` | Working | Real class/roster context | KEEP |
| Class overview | class surface | Working | Real class/roster | KEEP |
| Class tool tabs | class surface | Working | Navigation to real systems | KEEP |
| Legacy class-detail route | `class_detail_screen.dart` | Working and feature-rich | Mixed real academic + local schedule/notes | MERGE |
| Demo workspace/class seeding | demo service | Working | Demo only | KEEP as demo/test capability |

ClassSurface currently exposes Overview, Schedule, Gradebook, Exams, Results, Classroom, Seating, Students, Export.

## 4.6 Students

| Capability | Current location | Status | Data reality | Classification |
|---|---|---|---|---|
| Student roster | `student_list_screen.dart` | Working | Repository-backed | KEEP |
| Student profile | `student_detail_screen.dart` | Working | Repository-backed + calculated grades | KEEP |
| Student photo | student detail | Working | Stored in student model (base64 path observed) | KEEP |
| Student ID / seat / class context | student detail | Working | Real data | KEEP |
| Per-student grade summary | student detail | Working | Calculated from grade/exam services | KEEP |
| Deleted student recovery | deleted students + trash service | Working | Soft-delete flow | KEEP |
| Roster import | import services | Working | Imported into repository-backed student data | KEEP |
| Global cross-class student identity | not established | Missing | Current safe identity is classId + studentId | UNCERTAIN |
| Canonical student notes | not established as a modern repository | Missing/fragmented | Do not assume seating note = student history | UNCERTAIN |

## 4.7 Grades / assessment

| Capability | Current location | Status | Data reality | Classification |
|---|---|---|---|---|
| Gradebook | `gradebook_screen.dart` | Working | Repository-backed | KEEP |
| Grading categories | category screen/service/model | Working | Repository-backed | KEEP |
| Grade items | gradebook/service | Working | Repository-backed | KEEP |
| Add/edit/delete grade item | gradebook | Working | Repository-backed | KEEP |
| Rapid score entry | gradebook | Working; dedicated historical branch merged | Repository-backed | KEEP |
| Pending-write protection | gradebook/student score service | Working | Real async save state | KEEP |
| Score history | repository/model support | Working | Repository-backed | KEEP |
| Final exam entry | `exam_input_screen.dart` | Working | Repository-backed | KEEP |
| Manual exam score editing | exam input | Working | Repository-backed | KEEP |
| Debounced exam saves | exam input | Working | Repository-backed | KEEP |
| Exam CSV/XLSX import | exam input | Working | Imports to repository | KEEP |
| Exam Drive-link import | exam input | Working | External Drive + repository save | KEEP |
| Exam Drive browser | exam input | Working | Google auth/Drive + repository save | KEEP |
| Final results | `final_results_screen.dart` | Working | Calculated from process/exam data | KEEP |
| Process 40% / Exam 60% result composition | final results | Working | CalculationService authority | KEEP |
| Grade calculations | CalculationService | Working / frozen | Repository-backed inputs | KEEP |

This area is mature and should not be redesigned as part of shell unification.

## 4.8 Imports / School Data Inbox

| Capability | Current location | Status | Data reality | Classification |
|---|---|---|---|---|
| Generic file import | `file_import_service.dart` + file_import modules | Working | Parses files; destination varies | KEEP |
| CSV import | import services | Working | Input mechanism | KEEP |
| XLSX import | import services | Working | Input mechanism | KEEP |
| Google Drive file picker | drive picker/service | Working | External service | KEEP |
| Drive direct/link import | drive import service | Working | External service | KEEP |
| School Data Inbox | `school_data_inbox_screen.dart` | Working / newer subsystem | Depends on import staging state | KEEP, placement review |
| Data Inbox Home shortcut | historical feature branch merged | Working where exposed | Navigation | MOVE if Home is simplified |

## 4.9 Export / reporting

| Capability | Current location | Status | Data reality | Classification |
|---|---|---|---|---|
| Per-student export | `export_screen.dart` | Working | Derived from academic data | KEEP |
| Per-class export | export screen/service | Working | Derived | KEEP |
| Class-details export | export screen/service | Working | Derived | KEEP |
| All-classes export | export screen/service | Working | Derived | KEEP |
| CSV | export | Working | Generated | KEEP |
| XLSX | export | Working | Generated | KEEP |
| PDF | export | Working | Generated | KEEP |
| PDF preview/printing | PDF viewer + printing | Working | Generated | KEEP |
| Data validation warnings before export | export screen | Working | Derived | KEEP |

## 4.10 Communication

| Capability | Current location | Status | Data reality | Classification |
|---|---|---|---|---|
| Communication Hub | `communication_hub_screen.dart` | Working | Repository abstraction exists | KEEP |
| CommunicationService | services | Working | Local/Firestore implementations exist | KEEP |
| Conversation/message models | models | Working | Repository-backed depending mode | KEEP |
| Unread count on Home | Home/dashboard | Working | Communication service signal | KEEP |
| Messages panel / command-center messages | legacy/new Home widgets | Working | Same underlying concept | MERGE |
| Message-related Home clutter | multiple Home regions | Working but duplicated | Same signal repeated | DUPLICATE |

## 4.11 IED public platform

| Capability | Current location | Status | Data reality | Classification |
|---|---|---|---|---|
| IED public home | `codex/production-ready-ied-hub` | Production-ready / deployed architecture | IED Firebase/public config | KEEP |
| EEP Hub | IED | Working | IED content | KEEP |
| EEP Showcase | IED | Working | `projects` collection | KEEP |
| Public project submission | IED | Working | Creates validated pending project | KEEP |
| ESL Hub | IED | Working | IED content | KEEP |
| Science Hub | IED | Working/live destination | public content | KEEP |
| Language Arts Hub | IED | Working | public content | KEEP |
| Performance Arts Hub | IED | Working | public content | KEEP |
| Social Studies Hub | IED | Working | public content | KEEP |
| Project detail pages | IED | Working | approved project data | KEEP |
| Traditional Chinese / bilingual modes | IED production + bilingual branches | Working but branch authority split | UI/content metadata | KEEP |
| Public content cards/layouts/heroes | IED | Working | presentation layer | KEEP |

## 4.12 IED Studio / admin

| Capability | Current location | Status | Data reality | Classification |
|---|---|---|---|---|
| Protected teacher login | production-ready IED | Working | IED Firebase Auth | KEEP |
| ProtectedAppShell | IED Studio | Working | Auth/permissions | KEEP |
| Overview | IED Studio | Working | IED data | KEEP |
| Context / hub switching | workspace model | Working | section IDs | KEEP |
| Create Content wizard | IED Studio | Working | contentItems | KEEP |
| Content Library | HubContentLibrary | Working | contentItems | KEEP |
| Submission review | admin routes | Working | projects | KEEP |
| Manage Hubs | admin routes | Working | hubPages/settings | KEEP |
| Staff Access | AccessWizard | Working | adminUsers/staffUsernames + Functions | KEEP |
| Roles | IED auth/admin | Working | superAdmin/admin/editor | KEEP |
| Granular permissions | IED auth/admin | Working | persisted staff record | KEEP |
| Section access | IED auth/admin | Working | allowedSectionIds | KEEP |
| Audit log | IED | Working | immutable trusted audit entries | KEEP |
| Protected owner | IED auth model | Working | fixed owner protections | KEEP |
| Forced password change | IED staff flow | Working | Auth + staff record | KEEP |
| Archive/disable staff | IED admin | Working | Auth + staff record | KEEP |
| Content lifecycle | bilingual branch | Working branch feature, not fully reconciled | content metadata | KEEP / MERGE |
| Scheduled/live/expired/hidden/archived states | bilingual branch | Working branch feature | content metadata | KEEP |
| Placement controls (hero/announcement/featured/main/sidebar) | bilingual branch | Working branch feature | content metadata | KEEP |
| Bilingual content fields | bilingual branch | Working branch feature | persisted content metadata | KEEP |
| Content design controls | bilingual branch | Working branch feature | content metadata/presentation | KEEP |

Important: IED Studio and InstructOS are not duplicates. IED owns publishing/content administration; InstructOS owns private teacher/class/student operations.

## 4.13 Science web teacher/courseware system

| Capability | Current location | Status | Data reality | Classification |
|---|---|---|---|---|
| Science lesson workspace source | `science-courseware-production` | Built but not established as protected production destination | Mostly static/code-defined curriculum/resources | KEEP, production-readiness pending |
| J1/J2 organization | ScienceLessonsApp | Working source | static/code-defined | KEEP |
| Semester/unit organization | Science lesson data/curriculum | Working | static/code-defined | KEEP |
| Stable lesson IDs | `types/lesson.ts` | Working contract | code-defined | KEEP |
| Stable unit IDs | lesson model/data | Working | code-defined | KEEP |
| Lesson order/duration/status/objectives | lesson model | Working | code-defined | KEEP |
| Lesson resources | LessonResource | Working contract | links/Drive IDs/metadata | KEEP |
| Source references | LessonSourceReference | Working contract | source metadata | KEEP |
| teacherOnly resource flag | LessonResource | Working contract | metadata | KEEP |
| Lesson library UI | ScienceLessonsApp | Working source | static/code-defined | KEEP |
| J1 opening enhanced player | Science branch | Working/prototype-quality varies by asset | code/assets | KEEP / review |
| J2 opening player | Science branch | Working/prototype-quality varies | code/assets | KEEP / review |
| Aquatic enhanced slide | Science branch | Working/prototype | code/assets | KEEP / review |
| CoursewareApp | Science courseware folder | Working source | code/assets | KEEP |
| Courseware manifests/source pages | Science courseware | Working | code-defined | KEEP |
| Presentation-v2 shell | Science presentation-v2 | Prototype | code/assets | UNCERTAIN |
| Biomes V2 prototype | Science presentation-v2 | Prototype | code/assets | UNCERTAIN |
| Science visual QA workflows | GitHub workflows | Working build/QA infrastructure | CI artifacts | KEEP |
| Fake/non-durable progress UI | Science workspace variants | Prototype | no durable persistence confirmed | RETIRE CANDIDATE / replace only when real progress exists |
| Durable class/teacher lesson progress | not implemented | Missing | none | UNCERTAIN future capability |

## 4.14 Native Science PowerPoint production

| Capability | Current location | Status | Data reality | Classification |
|---|---|---|---|---|
| Immutable J1/J2 source decks | PPT repo | Authoritative | files + hashes | KEEP |
| Current accepted shell authority | PPT audit docs | Authoritative checkpoints | files + hashes | KEEP |
| Multi-state interaction slide architecture | production shells | Working/certified | native PPT | KEEP |
| Asset manifests | courseware QA/manifests | Working | files/JSON | KEEP |
| Structural QA | QA outputs | Working | generated reports | KEEP |
| Native click QA | QA outputs | Working | generated reports | KEEP |
| Source-fidelity rules | audit docs | Working governance | documentation | KEEP |
| Production output checkpoints | output/recovery folders | Working | native PPT files | KEEP |
| Historical prototypes/review decks | repo history | Historical | files | RETIRE CANDIDATE as authority only; preserve evidence |
| Web Science player | eep repo | Separate system | web | NOT A DUPLICATE of native PPT |

The native PowerPoint system must remain independent. InstructOS/Science should link to authoritative presentations rather than absorb their production pipeline.

## 4.15 Ask InstructOS

| Capability | Current location | Status | Data reality | Classification |
|---|---|---|---|---|
| Ask InstructOS UI | Home/OS | Working UI | conversation/session context | KEEP |
| Flutter assistant service | `instructos_assistant_service.dart` | Working | callable client | KEEP |
| Firebase callable | `functions/src/index.ts` | Implemented | server-side | KEEP |
| OpenAI server call | Firebase Function | Implemented | server-side secret | KEEP |
| Auth requirement | callable | Implemented | Firebase Auth | KEEP |
| Conversation history payload | service/function | Implemented | request-scoped | KEEP |
| contextMode | service/function | Implemented | request-scoped | KEEP |
| Generic safety against invented app data | function prompt | Implemented | prompt contract | KEEP |
| Rich grounded teacher context | partially implemented / historical diverged branch | Incomplete authority | context payload only | UNCERTAIN / MERGE |
| Autonomous app actions | not established | Missing | none | UNCERTAIN future capability |

The current callable is real, but it should not be treated as fully grounded in all InstructOS data. The diverged `feature/ask-instructos-ai-grounding` branch needs later forensic review before AI consolidation.

---

# 5. Duplication families

## 5.1 Home / Dashboard / Command Center

Implementations:
- legacy TeacherDashboard
- OS Home
- Teacher Home integration panel
- Command Center region
- Daily Signals rail
- pinned-app launchpad
- class-workspace list
- bottom dock

Strongest direction:
- **OS Home + Teacher Home integration panel** as canonical front door.

Useful pieces to salvage from older generations:
- message/unread signal
- reminders
- class launcher/context
- Ask InstructOS
- selected quick utilities only if they remain genuinely useful.

Do not remove old Home tools until the capability map is reviewed.

## 5.2 Teach / Classroom / legacy dashboard class tools

Implementations:
- Classroom surface
- Teach surface
- Teacher Dashboard class-tool panel

Strongest direction:
- **Classroom** for live class context and seating/map composition.

Capabilities not yet fully consolidated into Classroom:
- whiteboard
- timer
- group maker
- quick poll
- random student
- participation
- QR
- schedule teaching view

This is a **MERGE**, not a simple retirement.

## 5.3 Seating

Implementations:
- legacy full Seating screen
- Classroom seating map
- full-screen seating presentation
- seating references inside Teach

Strongest implementation:
- **existing Seating engine** for persistence and editing;
- **Classroom** for normal live-teaching composition.

## 5.4 Planner / schedule / timetable / reminders

Implementations:
- Planner
- legacy Dashboard reminders
- legacy Dashboard timetable
- ClassScheduleService
- schedule UI inside class detail
- schedule tool inside old dashboard

Strongest direction:
- **Planner** for teacher-wide planning;
- **ClassScheduleService** for class-specific teaching plans;
- class notes remain separate until a durable lesson-history design exists.

## 5.5 Communication / messages

Implementations:
- Communication Hub
- Home unread signal
- Command Center message prompt
- Daily Signals message card

Strongest implementation:
- **Communication Hub/service/repository** for actual message domain;
- Home should consume one compact signal instead of reproducing multiple message panels.

## 5.6 Class workspace / class detail

Implementations:
- `ClassSurface`
- `ClassDetailScreen`
- compatibility/secondary routes

Strongest direction:
- **ClassSurface** as canonical context shell;
- preserve feature-rich class-detail functionality until equivalent actions are deliberately placed.

## 5.7 Science lesson presentation

Implementations:
- ScienceLessonsApp
- enhanced J1/J2 players
- CoursewareApp
- presentation-v2 prototypes
- native PowerPoint

These are not all true duplicates:
- native PPT = authoritative classroom artifact production;
- web Science = organization/web presentation;
- multiple web players/prototypes are a duplication family inside the web system and need later authority selection.

## 5.8 IED content production

Implementations:
- production-ready IED Studio
- bilingual/content-lifecycle branch
- Science-descendant branches that also modify Studio/public content

Strongest direction:
- authority by subsystem, not branch reset:
  - production-ready security/auth/admin
  - bilingual lifecycle/design controls
  - Science lesson/courseware additions

---

# 6. Things Stuart may have forgotten

These are substantial enough that they should be consciously reviewed before the shell is simplified:

1. **The old Teacher Dashboard has a full classroom tool suite**: random name picker, group maker, participation, schedule, quick poll, timer, QR, and whiteboard, with presentation modes.
2. **Teach Surface is a second live-teaching environment** with whiteboard, timer, groups, seating, and quick poll.
3. **Planner already imports calendar events from CSV/XLSX**, not just manual reminders.
4. **Class Detail already supports class notes with optional reminder dates** and class schedules.
5. **Exam entry is much richer than a score grid**: local file import, Drive link import, Drive browser, Google authentication, and debounced saves are already implemented.
6. **Export is a mature subsystem** supporting student/class/class-details/all-classes scopes and CSV/XLSX/PDF.
7. **Communication is a real repository-backed subsystem**, not just the Home unread card.
8. **School Data Inbox/import staging exists** as a newer operational surface.
9. **IED Studio includes staff provisioning, permissions, protected owner rules, and audit history**, far beyond simple content editing.
10. **IED bilingual lifecycle work exists on a separate branch** with scheduling/status/placement/design capabilities that must not be lost during Science reconciliation.
11. **Science has several web presentation generations** in addition to the native PowerPoint system.
12. **Ask InstructOS is a real server-side callable/OpenAI implementation**, but a small grounding branch remains diverged and should be reviewed before AI is declared consolidated.

---

# 7. Data reality

## Repository-backed / durable core
Primarily InstructOS:
- classes
- students
- grading categories
- grade items
- scores
- score history
- exams
- seating layouts
- room setups

Repository abstraction:
- `DataRepository`
- `FirestoreRepository`
- `LocalRepository`
- `RepositoryFactory`

## Local / SharedPreferences
Currently includes:
- Planner reminders
- Planner timetables
- selected timetable
- class notes
- class schedules
- some dashboard preferences

These are useful and real, but should not be described as cross-device/cloud durable.

## IED Firebase
Separate project:
- `eep-student-showcase`

Persisted:
- projects
- contentItems
- hubPages
- adminUsers
- staffUsernames
- auditLogs

## Communication
A local/Firestore repository abstraction exists. Its exact production mode depends on repository configuration.

## Science
Stable lesson/resource identity exists in source code.
Durable teacher/class lesson progress is **not established**.

## Native PowerPoint
Authority is file/manifest/hash/QA based, not app-database based.

## AI
Ask InstructOS uses:
- Firebase Auth
- callable Functions
- server-side secret
- request-scoped context/conversation

It does not currently equal a universal data agent over every InstructOS subsystem.

---

# 8. Strongest existing implementations

- **Home front door:** current OS Home + Teacher Home integration panel
- **Live classroom composition:** current Classroom surface
- **Seating persistence/editing:** existing Seating engine/service/models
- **Teacher-wide planning:** Planner
- **Class-specific schedule:** ClassScheduleService + existing class schedule UI/import
- **Class notes:** ClassNoteService + ClassDetailScreen
- **Academic grading:** existing Gradebook/services/calculation stack
- **Exam handling:** ExamInputScreen + FinalExamService + import/Drive support
- **Results:** FinalResultsScreen + CalculationService
- **Exports:** ExportScreen + ExportService
- **Student profile:** StudentDetailScreen
- **Communication domain:** Communication Hub/service/repositories
- **IED security/admin:** `codex/production-ready-ied-hub`
- **IED bilingual lifecycle/layout:** `feature/bilingual-content-layout-scheduling-v2`
- **Science lesson/resource model:** Science lesson types/data in `science-courseware-production`
- **Science web courseware direction:** requires later authority choice between current production branch and final-production descendants
- **Native Science PPT:** audit-defined accepted/certified checkpoints in private PPT repo
- **AI backend:** current Firebase callable/OpenAI implementation, with grounding reconciliation still open

---

# 9. Uncertainties that must remain explicit

1. Which legacy Teacher Dashboard class tools Stuart still actively wants.
2. Whether participation counts should become durable class/student records or remain session utilities.
3. Whether QR belongs in Classroom, Resources, or nowhere in the final hierarchy.
4. Whether whiteboard should remain a dedicated full-screen app, a Classroom tool, or both.
5. Whether School Data Inbox belongs top-level, under Imports, or under administration.
6. Which communication workflows are actively used versus technically implemented.
7. Which Planner/class-note/class-schedule records need cloud migration.
8. Whether class schedules and future lesson progress should eventually converge.
9. Which Science web player generation is the final web authority.
10. How the production IED branch, bilingual lifecycle branch, and Science branch should be reconciled without regression.
11. Whether the unique commits on `feature/ask-instructos-ai-grounding` contain grounding behavior worth restoring.
12. Whether a global student identity is ever needed across classes.
13. Whether one teacher identity bridge between the two Firebase projects is necessary.
14. Which current Home navigation mechanism should survive once shell simplification begins.

---

# 10. No-change check

This inventory phase makes **no application behavior changes**.

It does not:
- redesign Home;
- simplify the shell;
- change routes;
- change Firebase;
- alter Classroom;
- alter Planner;
- alter grading;
- alter IED;
- alter Science;
- alter PowerPoint;
- add lesson progress;
- add class mapping;
- retire anything.

Only documentation is authorized in this phase.

---

# 11. Review decision for Stuart

Before the next implementation phase, Stuart should review this map at the level of teacher jobs, not code.

The key questions are:

- Which old teaching tools do you still value?
- Which areas should be visible every day versus one click deeper?
- Which duplicate implementation feels best?
- Which features can disappear from the front page without disappearing from the product?
- Which specialist systems should remain separate but visually connected?

Only after that review should the next phase define the final product hierarchy and Shell/Home simplification.

