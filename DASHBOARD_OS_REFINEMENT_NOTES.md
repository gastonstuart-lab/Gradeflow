# Dashboard OS Refinement Notes

## What Was Removed Or Simplified

- Replaced the raw web startup flash with a dark pre-Flutter launch shell in `web/index.html`.
- Shortened launch and login copy so the first-run experience feels more controlled and less explanatory.
- Compressed hero language in the dashboard so it reads like a command surface instead of a long introduction.
- Tightened section subtitles across classes, quick actions, workspace mode, previews, and secondary surfaces.
- Reduced reading load inside class cards by shortening labels from `Status` / `Next step` / `Class signals` to `State` / `Next` / `Signals`.
- Trimmed quick-action descriptions, preview-card descriptions, summary-tile details, live-story text, and announcement copy.

## How The Widget System Improved

- The top-right rail now reads more like a system surface instead of a descriptive sidebar.
- The system widget is more compact and OS-like:
  - subtler label chips
  - animated time transition
  - shorter state text
  - fewer explanatory labels
- Summary tiles in the hero are more scannable and less poster-like.
- Secondary preview cards now behave more like standby surfaces instead of mini essays about each section.

## How Communication Is Now Surfaced

- Added a dedicated communication widget in the live rail.
- It now shows:
  - unread count
  - short summary state
  - latest active channels
  - preview text
  - quick entry into the full communication workspace
- This uses existing channel, unread, sender, and last-message data rather than a fake placeholder feed.
- Communication now feels closer to a live system panel instead of being buried in general updates.

## What Still Prevents A Full OS-Level Experience

- The dashboard still behaves like a premium page layout, not a fully dockable multi-pane workspace.
- Secondary sections can be focused, but they are not yet persistent floating widgets or resizable panels.
- Communication is now surfaced well, but there is still no notification-center model, toast stream, or background activity layer.
- The live rail is stronger, but it is still assembled from cards rather than a deeper windowed desktop metaphor.
- Marketing-grade screenshot polish will still depend on carefully staged live data and one dedicated capture pass.
