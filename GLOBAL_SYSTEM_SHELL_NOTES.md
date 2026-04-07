# Global System Shell Notes

## What Became More Global

GradeFlow now has a route-level system shell wrapper for authenticated teacher surfaces instead of keeping shell behavior almost entirely inside the dashboard.

What changed:

- a global shell frame now wraps teacher routes such as classes, class detail flows, communication, admin, and the whiteboard
- the utility dock is now available across non-dashboard teacher surfaces on wider layouts
- the whiteboard now keeps a clearer shell return path so it behaves more like a launched tool than a disconnected page
- the dashboard still keeps its richer local shell, but it now shares notification lifecycle state with the broader app shell

This keeps the existing dashboard architecture intact while making the wider app feel more like one environment.

## Notification Lifecycle Behaviors Added

The attention center now supports a lightweight local lifecycle instead of behaving like a static feed.

Added behaviors:

- individual attention items can be dismissed
- dismissed items are stored locally per signed-in user
- dismissed items stay hidden until restored or until the underlying signal changes identity
- dismissed items can be restored from the attention center
- the dashboard attention center now uses the same dismissal state as the broader shell

This is intentionally local and safe. It does not pretend to be a full server-backed notification system.

## How Utility Persistence Improved

The dock now acts more like a persistent launcher:

- active utility state is inferred from the current route
- communication, admin, classes, and studio now feel like linked shell tools instead of isolated pages
- whiteboard has a stronger quick-return path to the last non-studio workspace route
- opening a different utility closes the attention center cleanly instead of leaving overlapping shell states behind

This improves continuity without forcing a major routing rewrite.

## What Still Prevents A Full Multi-Pane Teacher OS

GradeFlow is closer to a coherent operating shell, but it is not yet a full multi-pane workspace.

Still missing:

- shared multi-pane windowing or docked side-by-side tool surfaces
- cross-device notification sync and server-backed read/archive state
- a global command palette or system search layer
- deeper route-to-route utility handoff for dashboard-specific focuses like schedule and class-health detail
- a unified shell around every mobile surface without adding clutter

## Next Likely Evolution

The next strong step would be a true shared shell state model for all teacher workspaces, with:

- dashboard focus intents that other routes can launch into
- stronger route-aware utility transitions
- a richer notification model with local read/archive history and selective restore
- optional split-pane desktop behavior for communication or whiteboard alongside class work
