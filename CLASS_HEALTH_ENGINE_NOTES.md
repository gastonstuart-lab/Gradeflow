## Class Health Engine

### What changed

This pass turns dashboard class cards into a real teacher decision surface instead of a static summary. Each class now goes through a shared health engine that computes:

- status level: `Ready`, `Attention`, or `Urgent`
- primary reason: the clearest explanation of what matters now
- secondary detail: why it matters in teacher workflow terms
- recommended next action: the best immediate move from the dashboard
- supporting metrics: compact setup and timing context for the card

The logic is implemented in:

- [class_health_model.dart](c:/Users/Stuart/Nosapp/Gradeflow/lib/models/class_health_model.dart)
- [class_health_service.dart](c:/Users/Stuart/Nosapp/Gradeflow/lib/services/class_health_service.dart)

The dashboard cards now consume that shared output in:

- [teacher_dashboard_screen.dart](c:/Users/Stuart/Nosapp/Gradeflow/lib/screens/teacher_dashboard_screen.dart)
- [dashboard_redesign_sections.dart](c:/Users/Stuart/Nosapp/Gradeflow/lib/screens/teacher_dashboard/dashboard_redesign_sections.dart)
- [dashboard_shell.dart](c:/Users/Stuart/Nosapp/Gradeflow/lib/screens/teacher_dashboard/dashboard_shell.dart)

### Real signals used

The engine only uses signals that already exist in GradeFlow or can be cleanly derived from current state:

- timetable proximity and live class timing from the active dashboard timetable
- whether the dashboard has any active timetable selected
- whether a class can be matched into the selected timetable
- reminder urgency from dashboard reminders tied to a class
- class-note follow-up urgency from saved class notes with `remindAt` dates
- focused class state from the selected dashboard class
- roster size from stored students per class
- gradebook readiness from active grade item count
- planning context from syllabus presence and open class notes
- seating readiness from saved seating layouts
- seating completeness from assigned seats versus roster size
- seating attention markers from seat reminders, notes, or status colors
- room-setup linkage from assigned room setup state

### Logic and heuristics introduced

The engine computes class health by ordering grounded issues from most urgent to least urgent and surfacing the highest-priority one.

Current issue heuristics include:

- missing roster
- overdue reminder or class-note follow-up
- missing seating when class time is live or near
- incomplete seating assignments when some students are still unplaced
- seating note / intervention markers that need review
- seating exists but no linked room setup
- dashboard timetable missing entirely
- class not represented in the active timetable
- gradebook still empty near class time
- due-soon planning follow-up
- thin planning context when the roster exists but syllabus and notes are both sparse
- ready state when no stronger blockers exist

### Where approximations were necessary

Some useful signals are not yet modeled explicitly in the current codebase, so the engine uses careful approximations:

- planning readiness is approximated from syllabus presence and class-note activity
- follow-up urgency combines dashboard reminders and dated class notes instead of a dedicated task system
- timetable coverage is approximated by matching class identity against timetable slot titles
- export readiness is approximated from a stable setup baseline:
  roster + seating + grade items + planning context
- seating completeness uses assigned-seat count versus roster size rather than a separate attendance-readiness model

These are grounded approximations, not invented analytics.

### How class health is computed

For each class:

1. Static class signals are loaded from repository-backed data.
2. Runtime dashboard signals are collected from the current dashboard session.
3. The service evaluates issue heuristics in priority order.
4. The strongest current issue becomes the visible card status.
5. The engine also emits the best next action and compact supporting metrics.

This keeps health computation reusable and prevents dashboard widgets from duplicating logic.

### How this improves dashboard actionability

The dashboard now helps answer the teacher questions that matter in the moment:

- what needs attention right now
- why it matters
- what to do next

Examples of outcomes now supported:

- `Starts in 45 min and the roster is still empty`
- `4 follow-up items overdue`
- `35 min away and 4 seats still need assigning`
- `Roster imported, but timetable context is still missing`
- `Ready for today and no immediate follow-up is needed`

Each class card now points toward a meaningful destination:

- classes workspace
- class workspace
- seating
- gradebook
- timetable
- planning section
- export

### What future data would improve the engine

The next best data additions would make the engine materially smarter:

- per-class attendance freshness
- explicit assignment and grading completion state
- export history and final-results status
- richer timetable-to-class linking than title matching
- planning milestones instead of generic notes
- class-level activity timestamps across grading, seating, and reporting
- shared school/admin intervention flags

### How this can support future Admin Edition analytics

Because health logic is now computed in a dedicated service, the same model can later support admin surfaces such as:

- classes at risk across a department
- timetable coverage gaps by teacher
- missing roster / seating / gradebook readiness counts
- follow-up pressure across teams
- export-ready versus setup-incomplete classes

That gives Admin Edition a grounded way to show operational readiness instead of cosmetic analytics.
