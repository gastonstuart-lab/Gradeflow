# Founder Next Steps

## What Changed

This pass made four material improvements:

1. The dashboard was turned back into a shell instead of a single giant behavior blob.
2. The dashboard UX was regrouped into clearer sections:
   `Today`, `Classroom`, `Planning`, and `Workspace`.
3. Dashboard-local persistence was moved behind `DashboardPreferencesService`.
4. `FileImportService` was split into smaller concern-based modules while keeping the public API intact.

There was also a portability pass:

- school/product defaults now live in `lib/config/gradeflow_product_config.dart`
- storage mode messaging now comes from `RepositoryFactory`
- app title / login / school identity / local weather-news defaults no longer hardcode product identity in as many places

## How The Architecture Is Now Organized

### Product configuration

- `lib/config/gradeflow_product_config.dart`
  central place for product name, default school name, attendance portal default, and dashboard locality defaults

### Dashboard

- `lib/screens/teacher_dashboard_screen.dart`
  now acts as the main shell and shared state container
- `lib/screens/teacher_dashboard/dashboard_workspace_sections.dart`
  dashboard information architecture and section rendering
- `lib/screens/teacher_dashboard/dashboard_persistence.dart`
  reminder / quick-link / timetable persistence helpers
- `lib/screens/teacher_dashboard/dashboard_imports.dart`
  Drive readiness and schedule import orchestration
- `lib/screens/teacher_dashboard/dashboard_timetable.dart`
  timetable management and editing flows
- `lib/screens/teacher_dashboard/dashboard_class_tools.dart`
  class tools, schedule panel, and presentation mode logic
- `lib/screens/teacher_dashboard/dashboard_live_brief.dart`
  live dashboard story rail and headline generation

### Import

- `lib/services/file_import_service.dart`
  reduced core facade
- `lib/services/file_import/file_import_detection.dart`
  schedule/file detection and diagnostics
- `lib/services/file_import/file_import_classes.dart`
  class import parsing plus spreadsheet row extraction helpers

### Persistence and storage clarity

- `lib/services/dashboard_preferences_service.dart`
  scoped local dashboard preference storage
- `lib/repositories/repository_factory.dart`
  now exposes storage backend labels and source-of-truth descriptions

## What Still Needs Work

The repo is stronger, but these areas still need another pass:

1. `class_list_screen.dart` is still too large and still owns too much import orchestration.
2. `student_list_screen.dart`, `class_detail_screen.dart`, and `gradebook_screen.dart` remain large screen-level controllers.
3. Dashboard reminders, quick links, and timetables are cleaner now, but they are still local-only artifacts.
4. The storage contract is clearer, but it is not yet unified for cloud-mode teacher workspace data.
5. School-level shared data and permissions are still future architecture, not implemented reality.
6. The dashboard live-feed surfaces are better contained now, but they still need product judgment over time to avoid distracting from core workflows.

## Next 10 Highest-Leverage Tasks

1. Refactor `class_list_screen.dart` into screen shell + import flow modules.
2. Consolidate repeated import orchestration used by class list, student list, exams, and dashboard.
3. Move class schedule persistence behind repository-aware storage rather than screen-local assumptions.
4. Decide which dashboard artifacts should become cloud-synced for authenticated teachers.
5. Add regression tests around dashboard section switching and import confirmation flows.
6. Create a shared configuration model for school branding, locality, and institution defaults.
7. Define the data model boundary for personal teacher data vs shared department data.
8. Introduce reusable workflow components for import preview, type mismatch warnings, and confirmation dialogs.
9. Reduce the size of `class_detail_screen.dart` and `gradebook_screen.dart`.
10. Add basic operational telemetry / error reporting hooks before commercial rollout.

## Safest Next Tasks

These are strong follow-ups with low regression risk:

1. Refactor `class_list_screen.dart` by moving import helpers into modules without changing UI behavior.
2. Add more tests around import parsing and dashboard navigation.
3. Centralize more hardcoded school defaults into the product config layer.
4. Extract reusable import preview / diagnostics widgets.
5. Improve documentation around data ownership and storage modes.

## Risky Tasks And Why

These are valuable, but should be approached deliberately:

1. Converting local dashboard artifacts to cloud sync
   risk: unexpected migrations, duplicate data, or new cross-device bugs
2. Introducing shared department data
   risk: unclear ownership and permission edges can create long-tail data bugs
3. Reworking class / student / gradebook state management all at once
   risk: large regression surface and hard-to-debug behavior changes
4. Enterprise-style permissions too early
   risk: complexity explosion before the underlying shared-data model is ready
5. Replacing current import heuristics wholesale
   risk: losing hard-earned real-world robustness on messy school files

## Recommended Operating Principle

For the next phase, keep shipping by this rule:

`separate workflows by responsibility before replacing their behavior`

That is what worked in this pass, and it is the best way to keep solo-founder speed without turning the repo into chaos again.
