# GradeFlow Deep Audit

## Current Architecture Summary

GradeFlow is a Flutter web-first teacher workflow app built around provider-managed `ChangeNotifier` services, route-based screens, and a hybrid persistence model:

- UI:
  - `lib/screens/*` contains most product surfaces.
  - `teacher_dashboard_screen.dart` is the de facto operating system shell, tools hub, reminder center, import center, Drive entrypoint, and presentation launcher.
  - `class_list_screen.dart`, `class_detail_screen.dart`, `student_list_screen.dart`, `gradebook_screen.dart`, and export/seating screens each own substantial workflow logic directly in widgets.
- State:
  - `AppProviders` wires many `ChangeNotifier` services globally.
  - Most services are CRUD-oriented wrappers over `RepositoryFactory.instance`.
  - Several dashboard/timetable/reminder flows bypass repository abstractions and write directly to `SharedPreferences`.
- Persistence:
  - Core academic entities use `DataRepository` with `LocalRepository` or `FirestoreRepository`.
  - Authentication and storage mode selection are coupled through `AuthService` and `RepositoryFactory`.
  - Some important dashboard/schedule/timetable preferences remain local-only even when Firestore is enabled.
- Import:
  - `FileImportService` is a large multi-purpose parser with roster, class, schedule, timetable, exam, diagnostics, and spreadsheet decoding logic.
  - Import orchestration is duplicated across `teacher_dashboard_screen.dart`, `class_list_screen.dart`, `student_list_screen.dart`, and `exam_input_screen.dart`.
- Product identity:
  - Several school-specific defaults are hardcoded across `main.dart`, login/banner components, dashboard services, and attendance links.

## Oversized Files and Hotspots

Highest-risk source hotspots by size:

1. `lib/screens/teacher_dashboard_screen.dart` (~5583 lines)
2. `lib/services/file_import_service.dart` (~2260 lines)
3. `lib/screens/class_list_screen.dart` (~2186 lines)
4. `lib/services/seating_service.dart` (~1807 lines)
5. `lib/components/dashboard_story_carousel.dart` (~1315 lines)
6. `lib/screens/class_detail_screen.dart` (~1309 lines)
7. `lib/screens/student_list_screen.dart` (~1234 lines)
8. `lib/screens/gradebook_screen.dart` (~1223 lines)
9. `lib/screens/export_screen.dart` (~1112 lines)
10. `lib/screens/class_seating_screen.dart` (~942 lines)

These files are not just large; they mix product orchestration, persistence, parsing, UI composition, and behavior-specific edge cases.

## Top 10 Technical Risks

1. Dashboard concentration risk:
   `teacher_dashboard_screen.dart` owns too many workflows, making even safe edits expensive and regression-prone.
2. Import blast radius:
   `FileImportService` mixes decoding, detection, parsing, heuristics, diagnostics, and conversion into one service.
3. UI-to-storage coupling:
   Dashboard reminders, quick links, timetable state, and attendance settings write directly to `SharedPreferences` from the screen layer.
4. Blurry source-of-truth model:
   Repository-backed entities and local-only dashboard data coexist without a clearly communicated storage contract.
5. Auth/storage coupling:
   `AuthService` decides storage backend and migration timing, so login behavior indirectly changes persistence behavior.
6. Repeated import orchestration:
   Similar file-picking, type detection, Drive browsing, and preview patterns appear in multiple screens.
7. Testing asymmetry:
   Parsing has some tests, but the most fragile UI orchestration layers have little protection.
8. Screen-level business logic:
   Large screens compute transformations, run imports, persist data, and manage dialogs directly.
9. School-specific hardcoding:
   Branding, weather/news locality, and attendance URLs are embedded in UI and service files.
10. Provider sprawl:
   Many global providers are long-lived and screen code reaches into multiple services directly, increasing coupling.

## Top 10 Product / UX Risks

1. Dashboard overload:
   Homepage, planning, live brief, research, Drive, presentation, and classroom tools all compete for attention.
2. Weak hierarchy:
   Core daily teacher actions are not clearly separated from optional/supporting utilities.
3. Import intent confusion:
   Similar upload concepts exist in dashboard, class list, student list, and exams, but each screen explains them differently.
4. Mixed mental models:
   “Calendar”, “schedule”, “timetable”, “class tools”, and “quick links” overlap conceptually and visually.
5. Too much vertical density:
   Important workflows are buried below secondary cards and scroll-heavy sections.
6. Cloud capability ambiguity:
   A teacher cannot easily tell what is local-only, what syncs, and what is safe across devices.
7. Product identity drift:
   The app can feel like a powerful internal tool for one school rather than a broadly adoptable platform.
8. Core workflow dilution:
   Research/search/live-news features are interesting but can visually compete with grading, roster, seating, and planning.
9. Teacher-first vs school-first mismatch:
   The app is strongest as a teacher operating system, but the UI currently mixes personal workspace and institution context without clear boundaries.
10. Secondary features lack containment:
   Useful extras are on the main stage rather than opt-in workspace modules.

## Top 10 Monetization / Scaling Blockers

1. Hardcoded school assumptions reduce portability and demo readiness.
2. No explicit workspace/storage story for multi-device trust.
3. Limited separation between personal teacher data and future shared department/school data.
4. No clear feature-tier boundaries in the current architecture.
5. Dashboard structure does not yet communicate “professional operating system” confidence.
6. Local-only dashboard artifacts make cross-device value harder to sell.
7. Import workflows are powerful but not packaged as reliable “time saved” value props.
8. Absence of admin/config boundaries makes school onboarding look custom rather than scalable.
9. School-specific live data defaults weaken broader market credibility.
10. Founder velocity is high today, but large-file fragility threatens sustainable roadmap execution.

## Prioritized Action Plan

### Quick Wins

1. Split dashboard code by concern without rewriting its behavior.
2. Move dashboard-local persistence behind a dedicated service.
3. Introduce a clearer dashboard information architecture that emphasizes daily core workflows first.
4. Split `FileImportService` into concern-based modules while preserving its public API.
5. Centralize school/product configuration and storage-mode messaging.

### Structural Changes

1. Define a formal “workspace data contract”:
   repository-backed academic data vs local workspace preferences vs future shared/team data.
2. Consolidate import orchestration into reusable flows instead of per-screen implementations.
3. Introduce screen-specific controllers/view-models where widget files still carry business logic.
4. Move class schedules, dashboard reminders, and other planning artifacts toward a more explicit persistence strategy.
5. Prepare for org-level adoption by separating teacher defaults, school branding, and shared configuration.

## What Should Remain Core

- Class management
- Student rosters
- Gradebook workflows
- Final results and exports
- Seating plans and classroom operations
- Class schedule / timetable utilities
- Fast import from messy school files
- Teacher dashboard as an operational command center

## What Should Become Secondary or Contained

- Research/search helpers
- Live news and weather
- Generic external quick links
- Experimental AI analysis entrypoints
- Presentation launcher as a contextual mode, not a homepage identity

## Recommended Product Direction

GradeFlow should present itself as a teacher operating system built around:

1. Daily execution:
   what I teach today, who is in front of me, what is due, what needs grading.
2. Class operations:
   roster, grading, seating, exports, schedules, class utilities.
3. Planning:
   calendar, class timelines, imports, reminders.
4. Workspace add-ons:
   research helpers, live info, custom links, optional integrations.

That hierarchy improves both UX and monetization because the premium value proposition becomes obvious: save teacher time every day, then expand into shared department/school workflows.

## Execution Focus for This Pass

This pass should safely deliver:

1. A modularized dashboard structure.
2. A modularized import service.
3. Clearer dashboard hierarchy with secondary features demoted.
4. Centralized product configuration to reduce school-specific coupling.
5. Documentation that gives a solo founder a reliable path forward.
