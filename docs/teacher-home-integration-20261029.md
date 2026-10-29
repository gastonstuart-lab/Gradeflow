# Approved Teacher Home: first integration slice

Functional base: `1e66c5e` (`integration/instructos-unification`). Visual authority: owner-approved `72ad2d7`. Task branch: `feat/approved-teacher-home-integration-20261029`.

The normal Home route now presents the approved blue/teal desktop composition using existing functional inputs and destinations. No preview organizer, fictional lesson, fixed roster or preview record store is imported. The normal entry point, router, authentication, models, repositories, academic services, Classroom renderer and seating persistence are unchanged.

Stuart delegated the shortcut decision to engineering. The approved tile treatment now opens existing Grades, Students, Planner, Classroom, IED Studio and Science destinations. This gives teachers useful actions instead of disabled quiz/timer/room-builder controls. No preview quiz, timer, homework, notes or lesson-completion workflow was connected.

## Presentation and ownership

| Approved element | Functional source or action | Disclosure / necessary difference |
|---|---|---|
| Welcome and identity | Existing authenticated user / workspace snapshot and school name | No hard-coded Stuart identity; screenshots use the existing synthetic demo account. |
| Desktop framing | Presentation extracted from the approved desktop's gradient, 1380-pixel content limit, 3:2 columns, spacing, card material and typography | No fictional-preview banner in the functional app. |
| Clock | Approved device-clock implementation, isolated as `TeacherHomeClock` | Local device time only; no network time service. |
| Day-plan strip | Selected existing class | Timetable and next lesson remain in their visual positions as noninteractive unavailable states. No fabricated times or next-class claim. |
| Main class card | Existing class identity, subject and existing per-class student counts | Unknown counts are disclosed. No invented room, lesson topic, homework or follow-up counts. |
| Class selector | Current functional class list; Home-local selection | Explicitly forwards the selected class ID to existing routes. No new repository or preference writes. Selection is view state, not a promised saved preference. |
| Continuation area | No equivalent in the Home snapshot | Clearly labelled not connected; no lesson state transplanted. |
| Within reach | Existing destination callbacks / route helpers | Six existing actions replace three preview-only actions, using the approved tile design. |
| Calendar | Local device date | Read-only current month. No month/date editing or synchronization. |
| Things to remember | Existing pending reminders from `GlobalSystemShellController.workspaceSnapshot` | Read-only; loading, unavailable and loaded-empty states are distinct. No new reminder storage or editor. |
| Navigation | Existing `GradeFlowOSShell` and `OSDock` | The functional dock remains authoritative and unchanged; no duplicate Start menu, dock, router or shell. Its existing icon presentation differs from the preview's three labelled buttons. |
| More Home tools | Existing Home utilities and mini-apps | Reachable from the header and returnable using Back. Existing wallpaper/readability utilities remain on this retained tools surface; the approved default Home uses its approved gradient. |

The compact class selector uses the hero's upper label area. The card is not a lesson-status claim. The functional controls and longer disclosures can require scrolling, especially at short desktop and Surface-pane sizes. The existing dock reservation is consumed once, and lower content remains reachable above it.

## Files

- `lib/components/home/teacher_home_presentation.dart`: domain-free layout/card material extracted from the approved desktop.
- `lib/components/home/teacher_home_clock.dart`: approved clock implementation with a functional component name.
- `lib/components/home/approved_teacher_home.dart`: presentation binding for supplied class/snapshot data and callbacks; no repository access.
- `lib/components/home/teacher_home_integration_panel.dart`: opt-in approved presentation while retaining existing destination ownership and the legacy tools panel.
- `lib/os/surfaces/home_surface.dart`: supplies existing data, Home-local selection, loading status and existing utilities; retains the old tools view behind More Home tools.
- `test/approved_teacher_home_bindings_test.dart`: selected-class route identity, truthful unavailable states and read-only reminder/loading checks.

## Actual reference/current comparison

All images below are actual Flutter release-build browser captures. Reference is unchanged `72ad2d7`; current uses the normal functional entry and the existing synthetic local demo. No real school records or credentials were used.

| Viewport | Light reference / current | Dark reference / current |
|---|---|---|
| 1920×1080 | [Reference](teacher-home-integration/20261029/reference-1920-light.jpg) / [Current](teacher-home-integration/20261029/current-1920-light.jpg) | [Reference](teacher-home-integration/20261029/reference-1920-dark.jpg) / [Current](teacher-home-integration/20261029/current-1920-dark.jpg) |
| 1366×768 | [Reference](teacher-home-integration/20261029/reference-1366-light.jpg) / [Current](teacher-home-integration/20261029/current-1366-light.jpg) | [Reference](teacher-home-integration/20261029/reference-1366-dark.jpg) / [Current](teacher-home-integration/20261029/current-1366-dark.jpg) |
| 1440×960 | [Reference](teacher-home-integration/20261029/reference-1440-light.jpg) / [Current](teacher-home-integration/20261029/current-1440-light.jpg) | [Reference](teacher-home-integration/20261029/reference-1440-dark.jpg) / [Current](teacher-home-integration/20261029/current-1440-dark.jpg) |
| Surface effective 825×764, DPR 2 | [Reference](teacher-home-integration/20261029/reference-surface-light.jpg) / [Current](teacher-home-integration/20261029/current-surface-light.jpg) | [Reference](teacher-home-integration/20261029/reference-surface-dark.jpg) / [Current](teacher-home-integration/20261029/current-surface-dark.jpg) |

The effective Surface measurement is the Codex browser pane, not a maximized Chrome window. Explicit desktop overrides use DPR 1. Short-height and effective-viewport bottom captures demonstrate scrolling to lower controls. A separate local evidence gallery displays each pair side by side.

Real-browser checks opened Grade 11B (`demo-class-2`) from the class selector and confirmed its existing Classroom, Gradebook and Students routes, without entering scores or importing records. The retained canonical Classroom was also compared using the same Grade 10A demo layout and dark theme: [baseline](teacher-home-integration/20261029/baseline-classroom-1366-dark.jpg) / [current](teacher-home-integration/20261029/current-classroom-1366-dark.jpg). Its renderer and related models/services are byte-for-byte unchanged. Planner and More Home tools remained reachable. External connected destinations were preserved, not exercised against their services.

## Verification

SDK: trusted Flutter 3.38.9 / Dart 3.10.8. Locked dependency resolution passed without tracked dependency or lockfile changes.

Baseline `1e66c5e`: the eight requested Home/shell/navigation/Classroom/seating files passed all 45 tests. Current verification adds three focused tests, for 48 tests. Existing assertions were not weakened or edited. The new loading test initially used an exact widget-type finder that did not match `FilledButton.icon`; the finder was corrected to inspect the real button subtype and retained its disabled-action assertion.

| Fresh result | Exit | Outcome |
|---|---:|---|
| Locked dependency resolution | 0 | Passed; tracked lockfile unchanged |
| Baseline eight-file suite | 0 | 45 passed |
| Current nine-file suite | 0 | 48 passed, zero new failures |
| Focused analysis | 0 | No issues |
| Functional release web build | 0 | Passed |
| Diff whitespace check | 0 | Passed |
| Protected-file and approved-preview comparisons | 0 | No differences |

Commands:

```powershell
flutter pub get --enforce-lockfile
flutter analyze --no-pub lib/components/home lib/os/surfaces/home_surface.dart test/approved_teacher_home_bindings_test.dart
$tests = @(
  'test/teacher_home_integration_panel_test.dart',
  'test/approved_teacher_home_bindings_test.dart',
  'test/os_shell_surfaces_test.dart',
  'test/os_app_registry_test.dart',
  'test/connected_destinations_test.dart',
  'test/classroom_surface_test.dart',
  'test/full_screen_seating_test.dart',
  'test/seating_service_test.dart',
  'test/seating_canvas_test.dart'
)
flutter test --no-pub --reporter expanded @tests
flutter build web --release --no-wasm-dry-run --no-web-resources-cdn --no-pub --output build/home-review
git diff --check
```

The local review server is loopback-only and blocks production/Firebase/sign-in requests through CSP. Its final review origin also excludes service-worker registration so an earlier review bundle cannot mask the current build. These are review-server restrictions, not changes to application configuration. Existing offline demo login was used. External IED/Science destinations were not exercised against their backends; their existing destination bindings are retained.

## Boundaries and review

This is an Amber presentation integration and remains draft for Stuart's review. The standalone approved preview is untouched and remains separately runnable. The unapproved boundary candidate and PRs #66/#67 were not merged or incorporated.

The historical preview suite remains 14 passed / 9 failed, with four analyzer warnings; browser private-note retention is unresolved. That suite was not repaired in this slice and is not claimed green. Issue #62 remains a prerequisite for academic-write acknowledgement. No quiz, participation or Finish writes were connected. PR #67's separate export defects and drafts are out of scope.

Protected Nosapp, OneDrive, Desktop-export and earlier recovery work remain preserved. Rollback is a revert of this task's commit; no migration or stored-data rollback is required. Do not merge, deploy or start Classroom integration without the next explicit instruction.
