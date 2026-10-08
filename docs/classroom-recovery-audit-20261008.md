# Classroom recovery audit — 8 October 2026

## Scope and checkpoint

Recover the standalone fictional-data teaching preview, preserving the approved
six-table seating geometry and existing interactions. Starting checkpoint:
`3fe4f7cbb9573194d1e08c5dfccb47b3f0c1d401`.

Cloud recovery workspace: `/workspace/Gradeflow-Classroom-Recovery`, branch
`recovery/classroom-density-audit-20261008`. The original cloud checkout remains
at `3b0d930`; the owner's Windows workspaces are not accessible here and were
not changed. No application source has been changed during this audit.

## Findings supported by source history

- `64e7c82779dacdff68a9194f72575500e9ead8d4` is the nearest styling candidate
  before the neutral furniture pass. It retains colored table accents, prominent
  numeric table labels, and the current physical side-seat rules. It is a
  candidate for visual comparison, not an established owner-approved benchmark.
- `e965209` removes the per-table accents, replaces prominent numbers with
  `TABLE n`, and changes circular student tokens to small chair markers. This
  corresponds to the reported loss of table identity and visual substance.
- Earlier colorful checkpoint `824fba7` uses different seat placement. Do not
  restore its room component wholesale: that would restore obsolete geometry.
- `f942016` introduces presentation cells that divide the full available height
  between two rows. `45a1e3e` correctly generalizes this to configured rows and
  columns, but retains the height-filling behavior. Furniture inside each cell
  is centered and remains fixed in height. Row-center distance therefore grows
  with viewport height instead of furniture size. `74fcaa1` enlarges the viewport
  available to this layout; it does not originate the cell-height formula.
- Current presentation furniture uses an 88-pixel tabletop, 46-pixel chair
  marker, and 72-pixel student slot regardless of viewport height. More vertical
  canvas does not increase these sizes. This explains the density mismatch at
  source level; runtime screenshots have not yet confirmed the diagnosis.
- Normal mode is a width-driven, intrinsic-height room inside `_map()`'s scroll
  view. It cannot use remaining viewport height coherently through tabletop
  decoration changes alone.
- The normal-mode environmental frame places teacher/storage at a fixed
  bottom-right position in a Stack alongside the seating child, without a
  separately reserved furniture zone. Possible visual crowding needs screenshots.
- The environmental wrapper is used in normal mode; presentation directly
  renders `TeachingPreviewRoom`. The two modes do not currently share that frame.

## Locked behavior

Preserve table numbering/order, fictional student IDs and seat assignments,
three under-table slots, and existing default side-seat rules (left of table 1,
right of table 3). The missing owner-approved screenshot remains the authority;
source inspection alone does not establish that these rules match it.

Preserve custom-room configuration, seat movement/undo, selected and spotlight
states, attendance/homework/quiz/group interactions, theme controls, bottom Class
Tools, right student/private panels, and secondary-panel exclusivity. Keep
production app entry, authentication, backend, records, and launchers untouched.

## First controlled recovery change

Start with presentation layout density in
`lib/components/teaching_preview_room.dart`, with focused coverage in
`test/teaching_preview_layers_test.dart`. Replace viewport-height-driven row
separation with a bounded composition sized from the existing furniture and
active status content. Retain configured table count/columns and seat indexing.
Account for small heights through a deliberate fit/scroll policy rather than
clipping labels or controls. Do not select numeric bounds until baseline browser
captures and active-mode heights are available.

First compare before/after at 1920×1080, 1366×768, 1400×1000, a Surface-style
3:2 viewport, and a narrow window. Verify table order, side-seat relationships,
label readability, row separation, exceptions, and overflow. Leave normal-mode
toolbar, environmental furniture, and styling for separate passes. Once density
is demonstrated, compare `64e7c82` and the supplied premium reference before
choosing any furniture treatment; do not assume brighter colors are preferred.

## Validation and blockers

Completed: remote checkpoint discovery, historical source comparisons, Git
blame of presentation sizing, current renderer/panel/test inspection, isolated
worktree creation, and original-checkout preservation checks.

Not run: Flutter analysis, widget tests, preview build, browser screenshots, or
application functional checks. Flutter is absent. The official release manifest
request to `storage.googleapis.com` still returns HTTP 403. Network additions
were saved during onboarding but have not taken effect in this running instance.
Review/save the network settings before retrying SDK setup. Preserve TLS and
official archive checksum verification during installation.

After access is restored, install a compatible stable Flutter SDK with Dart
>=3.8.0 and run, from this recovery worktree:

```bash
flutter pub get --enforce-lockfile
flutter analyze
flutter test test/teaching_preview_layers_test.dart
flutter test test/teaching_preview_test.dart
flutter test test/teaching_preview_clock_test.dart
flutter test test/teaching_preview_desktop_test.dart
flutter test test/teaching_preview_quiz_test.dart
flutter build web --release --no-wasm-dry-run \
  --target lib/teaching_preview.dart --output build/teaching-preview
```

Serve the actual built preview and capture light/dark normal, tools-open,
student-panel, and presentation states using the available system Chromium or
installed Playwright Chromium. Watch browser errors and validate interactions;
do not substitute mockups for application screenshots. Check tracked changes
after dependency installation/build and preserve the lockfile.

The latest approved seating screenshot and earlier premium screenshots were not
included in the handover and have not been located in the repository. Request
them before claiming a benchmark or geometric/visual approval. The repository's
design mockups and dashboard screenshots are not evidence of that approval.

No recovery implementation, build, test pass, visual approval, push, merge, or
deployment is claimed. Resume the first pass once runtime validation is possible.
