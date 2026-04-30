# GradeFlow OS Design Direction

## 1. Purpose
This document is the single source of truth for the next major GradeFlow OS visual upgrade. It aligns product, UX, and implementation decisions across design and Flutter delivery while preserving existing data, routing, and service stability.

This direction is anchored to 10 target mockups:
- [01 Class Workspace Overview](docs/design/mockups/01_class_workspace_overview.png)
- [02 Teach Mode](docs/design/mockups/02_teach_mode.png)
- [03 Planner](docs/design/mockups/03_planner.png)
- [04 Classroom Map Seating](docs/design/mockups/04_classroom_map_seating.png)
- [05 Gradebook](docs/design/mockups/05_gradebook.png)
- [06 Schedule Details](docs/design/mockups/06_schedule_details.png)
- [07 Students Roster](docs/design/mockups/07_students_roster.png)
- [08 Whiteboard](docs/design/mockups/08_whiteboard.png)
- [09 Results Reports Export](docs/design/mockups/09_results_reports_export.png)
- [10 Communication Hub Messages](docs/design/mockups/10_communication_hub_messages.png)

## 2. Product Vision
GradeFlow is a premium teacher operating system.

The OS should feel like a focused command environment for daily teaching work, not a legacy dashboard. Every surface should prioritize direct teacher workflows, fast context switching, and confidence under classroom time pressure.

Key vision outcomes:
- Premium, professional, calm visual language in both dark and light themes.
- One coherent OS frame across all pages.
- Fewer clicks and less context loss for core teacher actions.
- Workspace-first design that supports planning, teaching, grading, communication, and reporting in one system.

## 3. Design Principles
- Workflow first: optimize for teacher tasks over decorative UI.
- Premium restraint: minimize noise, maximize clarity.
- Surface consistency: shared shell and interaction patterns across routes.
- Progressive detail: show essentials first, reveal depth when needed.
- Strong hierarchy: clear focus zones and action priority.
- System continuity: preserve route behavior and data logic while upgrading visuals.
- Dual-mode parity: dark and light themes must both feel first-class.

## 4. Dark Mode Rules
Dark mode target: premium, calm, glassy, professional, command-center feel.

Rules:
- Use deep neutral backgrounds with subtle tonal layering.
- Use translucent, rounded panels with restrained blur and soft edge highlights.
- Maintain high but comfortable contrast for text and data density zones.
- Reserve strong accent colors for status, selection, and primary actions.
- Keep chart/table readability high with non-neon highlights.
- Avoid heavy glow, saturated gradients, and playful visual effects.

## 5. Light Mode Rules
Light mode target: equally premium, clean, spacious, professional.

Rules:
- Use bright but soft neutral backgrounds, never plain white everywhere.
- Keep clear panel separation through elevation, subtle borders, and spacing.
- Match dark mode information hierarchy and component structure.
- Use the same accent semantics and status mapping as dark mode.
- Preserve readability in dense workspace areas like gradebook and roster.
- Avoid generic enterprise card clutter and overly playful tiles.

## 6. Global OS Layout Anatomy
The same OS structure must apply in both dark and light modes:
- Left OS sidebar for primary navigation and workspace context.
- Bottom OS dock for high-frequency task jumps.
- Top class or context header for active route state and key actions.
- Central task workspace as the main production area.
- Right insight or action rail where route context benefits from it.
- Floating rounded panels for tools, overlays, and quick actions.

Layout behavior targets:
- Keep shell persistent across route transitions where possible.
- Preserve keyboard and pointer efficiency for teacher workflows.
- Maintain responsive behavior without collapsing into legacy dashboard patterns.

## 7. Shared Component Targets
Shared components to define or upgrade before page-level polish:
- OS shell containers: sidebar, dock, header, rail scaffolds.
- Panel system: rounded panel variants with elevation and translucency rules.
- Typography scale: consistent heading, body, metric, and data table styles.
- Button system: primary, secondary, ghost, icon, dock actions.
- Input controls: search, filter chips, segmented controls, compact forms.
- Data surfaces: tables, list rows, class cards, status pills, badges.
- Feedback states: loading, empty, error, success, and inline hints.
- Overlay system: dialogs, drawers, command menus, floating tool panels.

## 8. Page-by-Page Target Designs for All 10 Mockups
### 8.1 Class Workspace Overview
Reference: [01 Class Workspace Overview](docs/design/mockups/01_class_workspace_overview.png)
- Define the canonical OS shell composition.
- Prioritize active class context, immediate next actions, and quick jump points.
- Replace dashboard-style card clutter with structured workspace zones.

### 8.2 Teach Mode
Reference: [02 Teach Mode](docs/design/mockups/02_teach_mode.png)
- Optimize for in-class speed and low cognitive load.
- Keep teaching actions reachable with minimal pointer travel.
- Use clean focus states for timer, agenda, and classroom controls.

### 8.3 Planner
Reference: [03 Planner](docs/design/mockups/03_planner.png)
- Make planning blocks scannable and editable with minimal friction.
- Align reminders, class schedule context, and actionable planning items.
- Keep panel rhythm consistent with the global OS shell.

### 8.4 Classroom Map Seating
Reference: [04 Classroom Map Seating](docs/design/mockups/04_classroom_map_seating.png)
- Provide clear spatial layout editing and assignment controls.
- Keep status visibility strong without visual noise.
- Support drag and placement clarity in both light and dark themes.

### 8.5 Gradebook
Reference: [05 Gradebook](docs/design/mockups/05_gradebook.png)
- Build a premium, high-density grading workspace.
- Emphasize edit confidence, scan speed, and category visibility.
- Keep sticky headers and metric context readable at all times.

### 8.6 Schedule Details
Reference: [06 Schedule Details](docs/design/mockups/06_schedule_details.png)
- Make daily and weekly class timing actionable and legible.
- Highlight upcoming sessions and pending tasks clearly.
- Preserve low-friction transitions to class-specific actions.

### 8.7 Students Roster
Reference: [07 Students Roster](docs/design/mockups/07_students_roster.png)
- Present roster management as a compact operational workspace.
- Keep student status, sorting, and quick actions immediately accessible.
- Ensure dense lists remain readable and calm.

### 8.8 Whiteboard
Reference: [08 Whiteboard](docs/design/mockups/08_whiteboard.png)
- Keep creative space central with unobtrusive control chrome.
- Support rapid mode changes and tool access without clutter.
- Ensure command-center visual continuity with OS shell language.

### 8.9 Results Reports Export
Reference: [09 Results Reports Export](docs/design/mockups/09_results_reports_export.png)
- Focus on trust, clarity, and export confidence.
- Surface summary metrics, report controls, and output states cleanly.
- Reduce ambiguity around what gets exported and why.

### 8.10 Communication Hub Messages
Reference: [10 Communication Hub Messages](docs/design/mockups/10_communication_hub_messages.png)
- Make conversations and channel triage efficient for teachers.
- Keep unread, priority, and context actions clear and fast.
- Balance message density with calm readability.

## 9. Implementation Phases
- Phase 0: establish design source of truth and assets
- Phase 1: shared GradeFlow OS design system components
- Phase 2: Class Workspace shell
- Phase 3: Seating or Classroom Map
- Phase 4: Gradebook
- Phase 5: Schedule and Details
- Phase 6: Students or Roster
- Phase 7: Planner
- Phase 8: Teach or Whiteboard
- Phase 9: Results or Reports or Export
- Phase 10: Communication Hub or Messages

Execution model for every phase:
- Inspect first, then implement.
- Use small safe branches.
- Preserve route behavior unless the phase explicitly allows route-level updates.
- Avoid touching Firebase, repository, and service logic unless unavoidable.
- Deliver dual-mode support in the same phase before closure.

## 10. Files Likely Involved Per Phase
### Phase 0
- docs/gradeflow_os_design_direction.md
- docs/design/mockups/

### Phase 1
- lib/os/os_palette.dart
- lib/os/os_touch_feedback.dart
- lib/os/os_widget_host.dart
- lib/os/gradeflow_os_shell.dart
- lib/theme.dart

### Phase 2
- lib/os/surfaces/home_surface.dart
- lib/os/surfaces/class_surface.dart
- lib/os/os_dock.dart
- lib/os/os_launcher.dart

### Phase 3
- lib/screens/class_seating_screen.dart
- lib/services/seating_service.dart (visual integration only, no logic rewrite)
- lib/components/ (seating-specific UI components)

### Phase 4
- lib/screens/gradebook_screen.dart
- lib/components/ (table and grading UI primitives)

### Phase 5
- lib/screens/class_detail_screen.dart
- lib/components/time_slot_timetable.dart
- lib/services/class_schedule_service.dart (UI contract checks only)

### Phase 6
- lib/screens/student_list_screen.dart
- lib/screens/student_detail_screen.dart
- lib/components/ (roster rows, filters, quick actions)

### Phase 7
- lib/os/surfaces/planner_surface.dart
- lib/components/global_system_shell.dart (if planner rail interactions need alignment)

### Phase 8
- lib/os/surfaces/teach_surface.dart
- lib/screens/teacher_whiteboard_screen.dart
- lib/components/teacher_whiteboard.dart

### Phase 9
- lib/screens/final_results_screen.dart
- lib/screens/export_screen.dart
- lib/screens/exam_input_screen.dart (only if required for visual continuity)

### Phase 10
- lib/screens/communication_hub_screen.dart
- lib/components/global_system_shell.dart
- lib/services/communication_service.dart (presentation contract checks only)

## 11. Risk Level Per Phase
- Phase 0: Low
- Phase 1: Medium
- Phase 2: Medium
- Phase 3: Medium
- Phase 4: High
- Phase 5: Medium
- Phase 6: Medium
- Phase 7: Medium
- Phase 8: High
- Phase 9: Medium
- Phase 10: Medium

Risk notes:
- High-risk phases include dense interaction zones or high-frequency workflows.
- Visual-only goals should remain isolated from data-service changes.

## 12. Tests and Checks After Each Phase
Run these checks at phase completion:
- UI parity check against relevant mockup(s).
- Light and dark mode visual QA at common breakpoints.
- Route and navigation regression smoke tests.
- Keyboard and pointer interaction pass for high-frequency actions.
- Empty, loading, and error state visual validation.
- Flutter analyze and test pass for touched modules.
- Targeted end-to-end flow verification for the changed route.

Recommended command pattern per phase:
- Analyze and unit tests for touched area.
- Targeted Playwright run for affected flows.
- Manual visual review screenshots for before and after comparison.

## 13. What Not To Touch Yet
- Do not rewrite app architecture.
- Do not refactor Firebase, repository, or persistence flows during visual phases.
- Do not alter core route contracts outside the approved route phase.
- Do not redesign unrelated legacy screens in parallel.
- Do not merge multiple high-risk UI surfaces in one PR.

## 14. Acceptance Criteria
The visual upgrade is accepted when:
- All 10 target mockup directions are reflected in implemented surfaces.
- Both dark and light themes are premium and consistent.
- OS shell anatomy is consistent across target routes.
- Teacher workflows require fewer clicks and less context switching.
- No regressions in existing Firebase and data behaviors.
- No major route navigation regressions.
- Regression tests and targeted flows pass for each phase.

## 15. Prompting Notes for Future Codex or Copilot Sessions
Use these instructions in future implementation sessions:
- Role: senior Flutter product architect plus UX implementer.
- Scope: phase-limited visual upgrade only.
- Safety: inspect first, then edit only approved files for that phase.
- Constraints: preserve data-service logic and route behavior unless phase-approved.
- Requirement: complete dark and light mode parity before closing phase.
- Delivery: provide mockup mapping, changed files list, risk callout, and test evidence each phase.
- Branching: keep PRs small and phase-specific.
