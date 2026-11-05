# Design integration hold — 5 November 2026

Status: BLOCKED FOR DESIGN CORRECTION. PRs #68 and #69 are open drafts, neither merged. The existing integration preview is not the approved finished design.

## Authoritative direction from Stuart
Preserve the newer Home, Classroom and floor-planning experience. Integrate grade entry into that experience; do not replace newer interactions with older functional screens. The right panel slides in and out. Student/table picking highlights the actual seats/tables on the map. Do not add a bottom Class tools panel. Planner and bottom navigation must belong to the same approved experience and work end to end.

## Confirmed causes and affected destinations
| Entry | Current implementation | Problem / correction required |
| --- | --- | --- |
| Home -> Classroom | `lib/os/surfaces/classroom_surface.dart` | Functional legacy shell adapted with materials rather than the approved complete experience. |
| Class tools | Same file, bottom Positioned panel | Wrong placement, opens by default; replace with the requested sliding right panel. |
| Pick student / Random student | `_openStudentPicker` -> `StudentPickerSheet` | Old modal picker; must use on-map highlighting, and include table selection. |
| Room setup | `SeatingDesignerView` with showToolbar and showStudentPanel true | Exposes older editing controls; must adapt approved room-builder interaction without replacing stored layouts/IDs. |
| Present | `_ClassroomPresentationView` -> SeatingDesignerView, premiumAppearance absent | Drops even the appearance adaptation; must preserve the same approved room identity and picker behavior. |
| Dock -> Planner | `lib/os/os_dock.dart` -> `/os/planner` -> `PlannerSurface` | Still the older Planner implementation. A valid route is not proof of design parity. |
| Dock -> Classes | `AppRoutes.classes` | Legacy class-list destination rather than the approved new class navigation. Audit against Home bindings. |
| Teach-mode dock | `OSDock._buildDockItems`: Whiteboard/Timer callbacks empty | Existing inert callbacks. Do not expose as working features. |
| Other class tools | Schedule/Students/Results -> old detail screens | Every exposed destination needs a design acceptance decision, not another button leading to an old screen. |

## Recovered reference and important conflict
Recovered approved visual source: `72ad2d7` / refinement `3d0ed8c`, files `lib/teaching_preview.dart`, `lib/components/teaching_preview_room.dart`, `teaching_preview_room_builder.dart`, `teaching_preview_desktop.dart` in the premium/recovery worktrees. This source is isolated and uses fictional records. Its right detail panel has the slide transition, but it also retains an older bottom Class tools tray. Stuart's latest explicit correction supersedes that tray. Copying that checkpoint wholesale would therefore repeat the error.

## Correct recovery method
1. Keep the gradebook save/import/export implementation isolated on the existing draft. No merge or live-data transfer.
2. Establish one screen/interaction inventory from the recovered design plus Stuart's corrections; preserve it as the visual and navigation acceptance contract.
3. Adapt real services behind the approved screens. Keep stable class/student/seat/table identities and persisted room geometry. Never seed the fictional preview roster.
4. Start with Classroom: sliding right panel, on-map student/table highlights, approved room-builder controls, consistent presentation. Keep gradebook access in the approved panel/student actions rather than adding a toolbar of duplicate buttons.
5. Connect Planner, Classes, Home and dock through the same approved shell. Remove or disable unfinished actions; do not silently redirect to older screens.
6. Click every visible control and return path at desktop and compact sizes, with screenshots and checks for panel motion, highlighted selection, reload and unsaved score protection. Service tests alone are insufficient.
7. Update the draft report and screenshots only after that acceptance pass. Human visual review precedes merge.

## Current evidence
The previous 59 passing tests establish bounded logic and legacy behavior, not preservation of the approved design. The previous report and screenshots remain historical evidence of the rejected hybrid. Cloud saving, mobile and dark-theme validation were not completed. No production deployment or real school-data transfer occurred.
