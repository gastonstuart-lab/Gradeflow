# Classroom spacing pass — 8 October 2026

## Result and scope

At the recovery baseline `3fe4f7c`, presentation divided the available viewport
height between rows while leaving the furniture at fixed size. This created a
large empty aisle. Commit `828d162` fits the existing room as a single composition
whose rows take their natural content height. It scales uniformly to the available
width, centers vertically, and scrolls when the composition is taller than the
viewport. At 1920×1080, the visible empty band between front-row labels and the
back-row tables falls from approximately 320 pixels to 55 pixels.

Only the presentation branch of `TeachingPreviewRoom.build` changed. Table/seat
indexing, configured columns and existing responsive breakpoints, student IDs,
side-seat rules, callbacks, furniture/marker styling, controls, and normal mode
remain unchanged. Normal light-mode classroom pixels below the header match the
baseline exactly. Dark mode also matches apart from a transient theme tooltip.

This is an Amber layout refinement on the isolated branch
`recovery/classroom-density-audit-20261008`, not a claim that the premium visual
recovery is complete or owner-approved. The original checkout remains on `work`
at `3b0d930`, clean. There was no merge, push, or deployment.

## Actual browser evidence

These are screenshots of the compiled Flutter preview, not mockups. Baseline
captures were completed before editing the classroom.

| State | Baseline | After |
| --- | --- | --- |
| Normal, light | [Before](classroom-recovery/20261008/baseline-normal-light.png) | [After](classroom-recovery/20261008/after-normal-light.png) |
| Normal, dark | [Before](classroom-recovery/20261008/baseline-normal-dark.png) | [After](classroom-recovery/20261008/after-normal-dark.png) |
| Presentation, light | [Before](classroom-recovery/20261008/baseline-presentation-light.png) | [After](classroom-recovery/20261008/after-presentation-light.png) |
| Presentation, dark | [Before](classroom-recovery/20261008/baseline-presentation-dark.png) | [After](classroom-recovery/20261008/after-presentation-dark.png) |

Additional views: [1366×768](classroom-recovery/20261008/after-1366-presentation-light.png)
and [1440×960 Surface-style](classroom-recovery/20261008/after-surface-presentation-dark.png).
Browser interaction also opened bottom Class Tools and selected Alex to open
the right private/student panel. Additional captures and runner logs are retained
under `/workspace/artifacts/classroom-recovery`.

## Verification

Flutter **3.38.9**, official tag commit
`67323de285b00232883f53b84095eb72be97d35c`, Dart **3.10.8** matches the owner's
Windows Flutter version. Official Git installation succeeded after the SDK
archive manifest returned 404. `flutter pub get --enforce-lockfile` succeeded in
both checkouts without changing their lockfiles. Node 20.20.2, npm dependencies,
Playwright Chromium, and the existing Functions type check/build were prepared.

- Release preview builds passed before and after using
  `flutter build web --release --no-pub --no-wasm-dry-run --no-web-resources-cdn --target lib/teaching_preview.dart --output build/teaching-preview`.
- Four new density tests passed. They cover 1920×1080, 1366×768, and 1440×960
  row density, table order/alignment, side and under-table seats, preserved
  assignments, and short-window scrolling with group/homework status controls.
- The three density assertions were run against a temporary copy of the original
  renderer: all three failed, demonstrating the existing spacing regression.
  Temporary fixture files were removed; logs remain in the artifact directory.
- The five existing teaching-preview suites reported **7 passed, 10 failed**
  before modification. Those suites plus the four new tests reported
  **11 passed, 10 failed** afterward. The same ten test names fail in both runs.
- `flutter analyze --no-pub` reports the same four unused declarations before
  and after (`_ink`, `_paper`, `_green`, `_label` in `teaching_preview.dart`).
  Its exit status is 1; no analysis errors were reported.
- `git diff --check` passed. Dependency manifests, lockfiles, main application,
  backend, authentication, and production configuration were not changed.

The baseline failures include a 23-pixel projector-header overflow at narrow
widths, exact/unique text-finder mismatches, and an outgoing student-panel
assertion made after 100 ms although its transition lasts 240 ms. These are
existing failures; this pass deliberately does not repair unrelated controls,
panel behavior, or test expectations. Passing compilation is not represented
as a fully passing suite.

## Environment limitations and reproducibility

The browser cannot currently fetch the default Roboto font from
`fonts.gstatic.com`. Both baseline and after captures use the same local Roboto
Regular font from the checksum-validated installed pub dependency via a Playwright
request route. This is a browser validation workaround; it does not modify app
typography, source, manifests, or build assets. The shared font hostname was saved
as an additional environment network requirement. The existing Google sign-in
script in `web/index.html` also produces a blocked external-resource console
error; this synthetic preview does not use sign-in. No uncaught application
exception was observed during the captured interactions.

Flutter configuration uses `XDG_CONFIG_HOME=/workspace/.cache/config` and
`PUB_CACHE=/workspace/.cache/pub`. Dart additionally needs writable standard
cache directories `/home/agent/.dartServer` and `/home/agent/.dart-tool`; access
was granted and the directories created during this task. Future sandboxed
tasks may need the same scoped access. Live preview processes must restart.
Fresh-task snapshot restoration has not been tested.

The shared conversations were retrieved successfully after network access
changed. They include the current normal/presentation screenshots, but not the
earlier approved premium screenshot referenced in their text. No earlier styling
candidate has been treated as visual approval, and no furniture rollback occurred.

## Review and rollback

Review the presentation screenshots and spacing on the owner's display before
approval. Normal-mode density and all broader styling recovery remain for a
separate pass. Roll back this layout refinement by reverting `828d162` on the
isolated branch; the original recovery checkpoint is preserved. No migration or
production rollback is involved.
