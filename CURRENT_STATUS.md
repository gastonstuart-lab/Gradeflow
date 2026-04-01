# Gradeflow Current Status
**Date**: April 1, 2026

## Working Now
1. The seating workspace is in active shape.
   Layout creation, duplication, room editing, reusable room setups, full-screen presentation mode, seat notes, seat locks, shuffle, and substitute handout generation are all implemented.
2. Web export and PDF preview flows compile cleanly through platform-safe boundaries.
   Browser-only download and clipboard behavior now live behind conditional imports instead of being embedded directly in screens.
3. Seating regression coverage is in place across logic, widgets, and browser flow.
   The service suite covers room setup save/apply/refresh behavior, widget tests cover seating canvas and full-screen interaction, and Playwright covers toolbar and room setup save flow in the browser.

## Verified In This Session
1. `flutter test test/seating_service_test.dart test/seating_canvas_test.dart test/full_screen_seating_test.dart`
   Result: passed
2. `flutter analyze lib/screens/export_screen.dart lib/screens/class_seating_screen.dart lib/components/seating lib/services/seating_service.dart test/seating_service_test.dart test/seating_canvas_test.dart test/full_screen_seating_test.dart`
   Result: no issues found
3. `flutter build web`
   Result: succeeded
4. `npx.cmd playwright test e2e/seating_room_setup.spec.ts --project=chromium`
   Result: passed

## What Changed Today
1. Removed direct `dart:html` usage from the seating and export screens.
2. Split the PDF preview widget into conditional web and stub implementations.
3. Added reusable browser file-action helpers for download and clipboard work.
4. Added a service regression test for linked room setup refresh behavior.
5. Added a Playwright regression for seating toolbar actions and room setup save flow.

## Current Risks
1. WebAssembly dry-run warnings still exist, but they now come from the third-party `image` package rather than Gradeflow's own web code.
2. Native build verification is still limited in this environment.
   Windows desktop is not configured in the repo, and Android build tools are not installed locally.

## Next Priorities
1. Add browser coverage for substitute handout preview/download and export-screen download actions.
2. Decide whether WebAssembly support matters for this release and, if it does, investigate alternatives or upgrades for the `image` package warning.
3. Do a wider manual UI pass on mobile-width and tablet-width seating layouts in the browser.
