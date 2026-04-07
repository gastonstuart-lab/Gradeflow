# Shell Dedup And Route Harmonization Notes

## Routes Cleaned Up

This pass focused on the main authenticated teacher surfaces already living inside the global shell:

- classes workspace
- class detail workspace
- communication hub
- admin workspace
- whiteboard / studio

The dashboard was preserved as the richer local shell surface and was not stripped back.

## What Duplicated Chrome Was Reduced

The biggest cleanup was removing older page-level route switch strips from non-dashboard pages now that the global shell already owns route launching.

Reduced duplication:

- local `Dashboard / Classes / Communication / Admin` route switch buttons were removed from page top bars where the global dock already covers that job
- communication no longer exposes an extra “Open classes” route-switch action in the page header
- whiteboard no longer carries a local back button that competed with the shell’s studio return model
- the global whiteboard focus bar now reserves its own top space instead of visually colliding with page content

This keeps the shell visible while reducing the feeling of “old page inside new shell.”

## Global Vs Local Responsibilities

The separation is now clearer:

Global shell responsibilities:

- utility launching
- cross-route attention center access
- route switching between major teacher surfaces
- studio return path behavior
- shell-level active-state cues

Local page responsibilities:

- create, import, refresh, and task-specific actions
- page metrics
- page filters and workspace controls
- task panels, threads, roster tools, and operational content

## What Still Feels Inconsistent

GradeFlow now feels more unified, but some differences still remain:

- some non-dashboard pages still keep their own theme/logout controls instead of a shared shell-level action cluster
- the dashboard still has a richer bespoke shell language than the rest of the app, which is correct for now but still visually distinct
- desktop shell behavior is stronger than tablet/mobile because the dock stays intentionally lighter on smaller layouts

## What Should Be Addressed Next

The next likely refinement would be a shared shell action cluster for authenticated teacher routes so theme, session, and account actions stop repeating per page.

After that, the strongest OS-feel step would be deeper route-to-route continuity:

- shared focus intents
- stronger shell transitions between utility surfaces
- optional split-pane desktop behavior for the highest-value workflows
