# Dashboard Redesign Notes

## What Changed Visually

- Rebuilt the dashboard into a premium dark SaaS shell with a dedicated sidebar, stronger card hierarchy, and a separate live panel on large screens.
- Replaced the previous hero/app-bar stack with a true dashboard summary surface: welcome state, today line, and high-priority metric cards.
- Introduced clearer section ordering:
  - `Today / summary`
  - `Your Classes`
  - `Quick Actions`
  - `Insights`
  - `Planning`
  - `Workspace`
  - `Live Panel`
- Restyled reused planning and workspace cards to sit inside the new dark dashboard system instead of feeling like standalone utility widgets.
- Added richer class status cards with focus state, status bands, and direct actions instead of plain dashboard buckets.

## Responsive Behavior By Breakpoint

- `Desktop >= 1180px`
  - Three-panel layout: left sidebar, center dashboard, right live panel.
  - Live panel stays visible as a dedicated rail.
  - Main content is roomy, multi-card, and dashboard-first.

- `Tablet 760px - 1179px`
  - Compact icon-first sidebar.
  - Main dashboard remains rich but stacks more aggressively.
  - Live panel moves into the main content flow instead of staying in a permanent right rail.

- `Mobile < 760px`
  - Dedicated single-column mobile layout.
  - Bottom navigation separates `Home`, `Planning`, `Tools`, and `Live`.
  - Home focuses on summary, classes, quick actions, and insights.
  - Communication/live content moves to its own destination instead of squeezing into a desktop clone.

## What Is Still An Approximation Of The Mockup

- The desktop live rail is structurally aligned with the mockup, but it currently uses real dashboard data feeds, reminders, news, and announcements instead of a full staff-chat product.
- Class status cards are visually close to the mockup style, but their status logic is based on current available data: timetable, reminders, roster size, and selection state. There is not yet a true cross-class grading health engine.
- Header actions use current GradeFlow capabilities like theme toggle, feedback, and logout rather than a finished notification/mail/communication system.

## What A Final Polish Pass Would Need

- Precise visual QA against the approved mockups at real device widths and browser zoom levels.
- More exact spacing and typography tuning after side-by-side screenshot comparison.
- A richer class health model so cards can show true missing-grades, test-due, or attention-needed states.
- A real communication backend or school messaging layer to fully replace the current live-brief approximation.
- Small interaction polish:
  - hover states
  - card transition tuning
  - sidebar active-state refinement
  - more deliberate motion on mobile tab changes

## What Supports Future Admin And Communication Editions

- Sidebar reserves explicit edition slots for `Admin` and `Communication`.
- Desktop keeps a dedicated right-rail concept that can evolve into a true communication surface without crowding teacher workflows.
- Mobile already has a separate `Live` destination, which gives Communication Edition a clean path on phone.
- The teacher dashboard remains centered on teacher operations, while the new shell makes it easier to attach future role-specific surfaces without turning the home experience back into a feature pile.
