# Teacher OS Upgrade Notes

## What Was Added

- A premium launch gate now sits in front of app startup so GradeFlow fades in through a polished splash instead of dropping straight into the router.
- The login screen was upgraded into a premium sign-in workspace that matches the product's dark cinematic direction.
- A lightweight teacher whiteboard was added for pen, mouse, or touch use with clear and undo support.
- Dashboard hero personalization was added with built-in hero styles and an optional local custom backdrop image.
- The top-right live rail now includes a dedicated system widget card for time, status, weather, next item, and focus context.
- Dashboard secondary sections now use a workspace mode strip and preview cards so the screen feels more like a focused operating surface.

## Splash And Launch Experience

- `GradeFlowLaunchGate` now wraps app startup and waits for both auth initialization and a short minimum display window.
- The launch panel uses the shared animated background system, premium glass surface treatment, and restrained motion.
- Transition into login or dashboard now happens through `AnimatedSwitcher` instead of an abrupt route swap.

## Whiteboard Mode

- The whiteboard is available from the dashboard quick actions and from the classroom tools tab set.
- Teachers can draw with mouse, touch, or pen using a low-latency `CustomPainter` surface.
- Ink presets include chalk, amber, and cyan with fine, medium, and bold stroke widths.
- Undo and clear are available directly in the toolbar.
- Opening the whiteboard full-screen from the dashboard now preserves the current whiteboard controller state for that session.

## Hero Personalization

- The dashboard hero now supports built-in styles:
  - `Midnight`
  - `Horizon`
  - `Studio`
  - `Ember`
- Teachers can optionally upload a custom hero image.
- A dark readability overlay stays on top of custom imagery so the hero remains legible.
- Personalization is stored through dashboard preferences on a per-user basis.

## Live Widget Upgrade

- The right rail now has a dedicated system widget card above the news, weather, and event cards.
- The widget highlights:
  - current time
  - weekday and date
  - live class / next planning status
  - weather snapshot
  - next item indicator
  - current teacher focus
- This makes the live rail feel more like an OS status surface instead of a stack of unrelated cards.

## Dashboard Modularity

- A workspace mode strip was added below quick actions.
- Teachers can focus the dashboard on:
  - `Today`
  - `Classroom`
  - `Planning`
  - `Workspace`
- The chosen section stays expanded while the others collapse into preview cards with one-click re-entry.
- Classes, urgent actions, and the hero remain immediately visible, so modularity does not hide critical information.

## Limitations

- Whiteboard strokes are session-local and not yet persisted across app restarts.
- Full-screen whiteboard continuity is preserved when launched from the dashboard, but not through every possible future entry path unless that path passes the controller.
- Custom hero images are local preference assets, not cloud-synced shared profile media.
- The live system widget depends on the existing weather/news services and will only be as current as those sources allow.
- Dashboard modularity currently focuses secondary surfaces only; it is not yet a full windowed multi-panel desktop model.

## What Should Be Done Next

- Add whiteboard persistence and optional export/share for lesson captures.
- Add a dedicated hero personalization preview thumbnail strip and cloud-backed profile media if user accounts support it cleanly.
- Add regression widget tests for the system widget rail and workspace mode switching.
- Explore a persistent classroom command bar so whiteboard, timer, poll, and QR feel even more OS-like.
- Introduce richer state restoration so the dashboard reopens to the same focused workspace section and classroom utility context.
