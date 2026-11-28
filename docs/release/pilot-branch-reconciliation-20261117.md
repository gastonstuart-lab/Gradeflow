# GradeFlow unresolved-branch reconciliation — 17 November 2026

Baseline: `31a1a3ec6f22275872c0fa8073b8da446614a2e8`. Compared the changed-file lists of all 19 previously divergent PRs with exact baseline file contents. This is source review, not a fresh runtime certification or a review of all historical user approvals.

## Decisions

### [#119: P0 Gradebook: make Excel exports match saved per-class grading weights](https://github.com/gastonstuart-lab/Gradeflow/pull/119)

Retained: both application files are byte-identical. Baseline test adds legacy calculation, CSV, XLSX and text-report parity assertions. Old standalone CI need not be restored wholesale.

Preserved head: `c1b7b09d78b63f75fb459577a91bd3d83ea23f90`.

| Changed file | Comparison with baseline |
|---|---|
| `.github/workflows/verify-gradebook-export-parity.yml` | absent from baseline |
| `lib/screens/native_gradebook_screen.dart` | identical |
| `lib/services/gradebook_export_projection.dart` | identical |
| `test/gradebook_export_projection_test.dart` | different |

### [#116: Design Lab: isolated real-widget gallery and demo-only quick Gradebook entry](https://github.com/gastonstuart-lab/Gradeflow/pull/116)

Preserved separate design tool: all six files absent. Design Lab/demo stepper is not production Gradebook behavior. Retain branch for design work; do not treat as pilot blocker.

Preserved head: `922e17c0f8b635cbf61f983049b5979310ec4404`.

| Changed file | Comparison with baseline |
|---|---|
| `.github/workflows/verify-design-lab.yml` | absent from baseline |
| `lib/components/gradebook/gradeflow_quick_score_stepper.dart` | absent from baseline |
| `lib/design_lab/gradebook_lab_sample.dart` | absent from baseline |
| `lib/design_lab/gradeflow_design_lab_app.dart` | absent from baseline |
| `lib/design_lab_main.dart` | absent from baseline |
| `test/design_lab_widget_gallery_test.dart` | absent from baseline |

### [#100: Review: make login branding readable over Background Boxes](https://github.com/gastonstuart-lab/Gradeflow/pull/100)

Superseded login iteration: current login and tests differ. Compare visual acceptance with the approved later login before any recovery; no whole-file replacement.

Preserved head: `2e48c5efce4867bed97894aa5c1cf5c97b3a79fb`.

| Changed file | Comparison with baseline |
|---|---|
| `.github/workflows/login-contrast-review.yml` | absent from baseline |
| `lib/screens/login_screen.dart` | different |
| `test/login_screen_test.dart` | different |

### [#99: Integration review: unified Gradebook, shared rooms, Teacher Home and safer Boxes login](https://github.com/gastonstuart-lab/Gradeflow/pull/99)

Superseded integration iteration: login, launch, background and tests evolved. Current integration is the application baseline; old review workflow absent.

Preserved head: `2d623d536dde34491936a85d6f8954652c73b4f9`.

| Changed file | Comparison with baseline |
|---|---|
| `.github/workflows/launch-boxes-review.yml` | absent from baseline |
| `lib/components/gradeflow_launch_experience.dart` | different |
| `lib/screens/login_screen.dart` | different |
| `lib/widgets/branding/instructos_boxes_background.dart` | different |
| `test/gradeflow_launch_gate_test.dart` | different |
| `test/instructos_boxes_background_test.dart` | different |
| `test/login_screen_test.dart` | different |
| `web/index.html` | different |

### [#98: Login/launch: native Background Boxes and a single branded loading experience](https://github.com/gastonstuart-lab/Gradeflow/pull/98)

Superseded launch iteration: same family as #99. Preserve original branch; do not restore old startup/login files over current guards.

Preserved head: `bbabd60df734cfc97de3fa8181ff6cda96aaa477`.

| Changed file | Comparison with baseline |
|---|---|
| `.github/workflows/launch-boxes-review.yml` | absent from baseline |
| `lib/components/gradeflow_launch_experience.dart` | different |
| `lib/screens/login_screen.dart` | different |
| `lib/widgets/branding/instructos_boxes_background.dart` | different |
| `test/gradeflow_launch_gate_test.dart` | different |
| `test/instructos_boxes_background_test.dart` | different |
| `test/login_screen_test.dart` | different |
| `web/index.html` | different |

### [#88: Planner V2 staging: strict Firestore rules and cross-teacher emulator tests](https://github.com/gastonstuart-lab/Gradeflow/pull/88)

Core staging protection retained: rules, workflow and package metadata identical; emulator configuration and rule tests evolved. Current tests include cross-teacher score/read/write denial and closed shared communication.

Preserved head: `755c6005fe542c4f7277edd78bc025521e0ef14e`.

| Changed file | Comparison with baseline |
|---|---|
| `.github/workflows/planner-v2-staging-rules.yml` | identical |
| `firebase.staging.json` | different |
| `firestore.staging.rules` | identical |
| `staging-tests/package.json` | identical |
| `staging-tests/rules.test.mjs` | different |

### [#87: Planner V2: dedicated staging Firebase configuration and no local-login fallback](https://github.com/gastonstuart-lab/Gradeflow/pull/87)

Core dedicated-staging config retained: config class, workflow and config tests identical. Startup/auth/services evolved; no authorization rollback proposed.

Preserved head: `3933f7489b1959857011ef2e09b9f46ab65aecd2`.

| Changed file | Comparison with baseline |
|---|---|
| `.github/workflows/planner-v2-staging-config.yml` | identical |
| `docs/release/planner-v2-firebase-staging-setup.md` | different |
| `lib/config/planner_v2_firebase_config.dart` | identical |
| `lib/main.dart` | different |
| `lib/services/auth_service.dart` | different |
| `lib/services/firebase_service.dart` | different |
| `test/planner_v2_firebase_config_test.dart` | identical |

### [#86: Planner V2 staging: block production Firebase access before authenticated startup](https://github.com/gastonstuart-lab/Gradeflow/pull/86)

Staging isolation retained and extended: workflow/tests identical; safety class adds existing-project-preview and live-release modes while retaining dedicated checks.

Preserved head: `a6fd7c4694fd3dfeb477ee03a6b6f25c19eedf0a`.

| Changed file | Comparison with baseline |
|---|---|
| `.github/workflows/planner-v2-staging-safety.yml` | identical |
| `lib/config/planner_v2_staging_safety.dart` | different |
| `lib/main.dart` | different |
| `test/planner_v2_staging_safety_test.dart` | identical |

### [#85: Release review: protect latest Planner V2 zoom build and gate integration](https://github.com/gastonstuart-lab/Gradeflow/pull/85)

Protected-review workflow identical. Routing/release documentation evolved. Historical release gating is not a missing teacher feature.

Preserved head: `31a0138c37a4f8ed965bf267f4466463a6da1114`.

| Changed file | Comparison with baseline |
|---|---|
| `.github/workflows/planner-v2-protected-release-review.yml` | identical |
| `docs/release/classroom-v2-integration-review-20261109.md` | different |
| `lib/nav.dart` | different |

### [#73: Restore stationary Classroom, animated picks and fullscreen teaching tools](https://github.com/gastonstuart-lab/Gradeflow/pull/73)

Picker behavior retained (animator differences are formatting; test identical). Classroom/canvas/presentation changed through later recovery; full interaction acceptance remains required.

Preserved head: `1222af97669755fbed5cfa7f54f2e109f545cdc0`.

| Changed file | Comparison with baseline |
|---|---|
| `lib/components/seating/classroom_picker_animator.dart` | different |
| `lib/components/seating/seating_canvas.dart` | different |
| `lib/components/seating/seating_designer_view.dart` | different |
| `lib/os/surfaces/classroom_presentation_view.dart` | different |
| `lib/os/surfaces/classroom_surface.dart` | different |
| `test/classroom_picker_animator_test.dart` | identical |
| `test/classroom_surface_test.dart` | different |

### [#71: Premium Classroom: Teach/Arrange safeguards and fit-to-room presentation](https://github.com/gastonstuart-lab/Gradeflow/pull/71)

Older framing/Arrange implementation superseded by expanded occupied-room framing, centre-preserving zoom and visible-workspace geometry. Original framing test file absent: recover useful assertions only after adapting to present APIs.

Preserved head: `532d650725200e1d5928d5b720927a0b7f2070ab`.

| Changed file | Comparison with baseline |
|---|---|
| `docs/classroom-preservation-and-usability-contract-20261106.md` | different |
| `lib/components/seating/classroom_map_framing.dart` | different |
| `lib/components/seating/seating_canvas.dart` | different |
| `lib/components/seating/seating_designer_view.dart` | different |
| `lib/os/surfaces/classroom_surface.dart` | different |
| `test/classroom_map_framing_test.dart` | absent from baseline |
| `test/classroom_surface_test.dart` | different |

### [#67: Add editable one-page A4 substitute handover to Classroom seating](https://github.com/gastonstuart-lab/Gradeflow/pull/67)

Confirmed missing feature: _createEditableHandover, its toolbar entry and generateEditableSubstituteHandoverPdf are absent. Existing generateSubstitutePacketPdf remains, but is not equivalent. Preserve patch; recover into current canonical Classroom entry with fictional A4/layout and routing verification.

Preserved head: `3387cf07ed8c2d1c75e64b1ab576e0b9d793096a`.

| Changed file | Comparison with baseline |
|---|---|
| `lib/screens/class_seating_screen.dart` | different |
| `lib/services/export_service.dart` | different |

### [#66: InstructOS teaching journey preview](https://github.com/gastonstuart-lab/Gradeflow/pull/66)

Separate teaching prototype: preview entry point, room/quiz/desktop widgets, script and tests absent. Preserve as design reference; not a safe production patch bundle.

Preserved head: `305945db008360ead9e9f7ef436f023074393080`.

| Changed file | Comparison with baseline |
|---|---|
| `UPDATE_AND_PREVIEW_INSTRUCTOS.cmd` | absent from baseline |
| `docs/teaching-journey-preview.md` | absent from baseline |
| `lib/components/teaching_preview_clock.dart` | absent from baseline |
| `lib/components/teaching_preview_desktop.dart` | absent from baseline |
| `lib/components/teaching_preview_quiz.dart` | absent from baseline |
| `lib/components/teaching_preview_room.dart` | absent from baseline |
| `lib/components/teaching_preview_room_builder.dart` | absent from baseline |
| `lib/teaching_preview.dart` | absent from baseline |
| `test/teaching_preview_clock_test.dart` | absent from baseline |
| `test/teaching_preview_desktop_test.dart` | absent from baseline |
| `test/teaching_preview_layers_test.dart` | absent from baseline |
| `test/teaching_preview_quiz_test.dart` | absent from baseline |
| `test/teaching_preview_test.dart` | absent from baseline |

### [#65: Propose minimal classroom controls and display contracts](https://github.com/gastonstuart-lab/Gradeflow/pull/65)

Confirmed missing proposal document. Preserve as historical proposal; unresolved participation/display/storage decisions must not become policy by copying it.

Preserved head: `a294ffdbaafb6b768707de9b267f7dcf7483c6dd`.

| Changed file | Comparison with baseline |
|---|---|
| `docs/instructos-classroom-contracts.md` | absent from baseline |

### [#63: Characterize academic calculations and persistence failures](https://github.com/gastonstuart-lab/Gradeflow/pull/63)

Confirmed missing characterization tests (two files). Preserve and adapt to current services; tests record undesirable semantics and do not fix them. Source still has catch/log paths in StudentScoreService; do not claim all grading entry points acknowledge durable saves.

Preserved head: `d73f44f31700c32fab2f1c8ceaf4158dc2c2952b`.

| Changed file | Comparison with baseline |
|---|---|
| `test/calculation_service_test.dart` | absent from baseline |
| `test/student_score_service_test.dart` | absent from baseline |

### [#60: Preserve working class across InstructOS shell transitions](https://github.com/gastonstuart-lab/Gradeflow/pull/60)

Alternative context implementation: baseline has lastSelectedClassId, bindSelectionToUser, routing identity binding and account-switch controller tests. PR-specific provider test absent. Full context/reset behavior is not identical; adapt an account-switch/navigation acceptance test rather than replacing the controller.

Preserved head: `1531b1805e24377f99f36344dd95ead2c32b0688`.

| Changed file | Comparison with baseline |
|---|---|
| `lib/os/os_controller.dart` | different |
| `lib/os/surfaces/teach_surface.dart` | different |
| `lib/providers/app_providers.dart` | different |
| `test/os_context_provider_test.dart` | absent from baseline |
| `test/os_controller_test.dart` | different |

### [#59: Record the locked InstructOS product constitution](https://github.com/gastonstuart-lab/Gradeflow/pull/59)

Confirmed missing product constitution document. Agent and design-direction files differ. Recover constitution deliberately with current product direction and add links without replacing all agent instructions.

Preserved head: `7a1bff5a44621534a89c2b70ccb9ab891f1d3867`.

| Changed file | Comparison with baseline |
|---|---|
| `AGENTS.md` | different |
| `INSTRUCTOS_PRODUCT_CONSTITUTION.md` | absent from baseline |
| `docs/gradeflow_os_design_direction.md` | different |

### [#21: Recover InstructOS branding and Flutter 3.41 compatibility](https://github.com/gastonstuart-lab/Gradeflow/pull/21)

Legacy branding/SDK recovery: many historic assets/previews absent, current app/config differs. Product config and communication repository identical. Preserve asset source; do not roll back lockfile, SDK compatibility or current UI.

Preserved head: `ba5b5b0f999ba8077873674186ca5aacd84c281d`.

| Changed file | Comparison with baseline |
|---|---|
| `assets/branding/instructos/instructos_app_icon.svg` | absent from baseline |
| `assets/branding/instructos/instructos_favicon.svg` | absent from baseline |
| `assets/branding/instructos/instructos_logo_lockup_dark.svg` | absent from baseline |
| `assets/branding/instructos/instructos_logo_lockup_light.svg` | absent from baseline |
| `assets/branding/instructos/instructos_mark_dark.svg` | absent from baseline |
| `assets/branding/instructos/instructos_mark_light.svg` | absent from baseline |
| `assets/branding/instructos/instructos_wordmark_dark.svg` | absent from baseline |
| `assets/branding/instructos/instructos_wordmark_light.svg` | absent from baseline |
| `assets/branding/schools/school_logo2.png` | absent from baseline |
| `assets/images/logo_default.svg` | absent from baseline |
| `docs/visual-qa/instructos-branding/01-splash-loading-v2.png` | absent from baseline |
| `docs/visual-qa/instructos-branding/01-splash-loading.png` | absent from baseline |
| `docs/visual-qa/instructos-branding/01-startup-final.png` | absent from baseline |
| `docs/visual-qa/instructos-branding/02-login-final.png` | absent from baseline |
| `docs/visual-qa/instructos-branding/02-login-screen-v2.png` | absent from baseline |
| `docs/visual-qa/instructos-branding/02-login-screen.png` | absent from baseline |
| `docs/visual-qa/instructos-branding/03-os-home-v2.png` | absent from baseline |
| `docs/visual-qa/instructos-branding/03-os-home.png` | absent from baseline |
| `docs/visual-qa/instructos-branding/seating-toolbar-overflow-fixed.png` | absent from baseline |
| `lib/components/dashboard_story_carousel.dart` | different |
| `lib/components/gradeflow_launch_experience.dart` | different |
| `lib/components/school_banner.dart` | different |
| `lib/components/seating/seating_toolbar.dart` | different |
| `lib/config/gradeflow_product_config.dart` | identical |
| `lib/config/instructos_branding.dart` | different |
| `lib/os/os_assistant.dart` | different |
| `lib/os/surfaces/home_surface.dart` | different |
| `lib/os/surfaces/planner_surface.dart` | different |
| `lib/repositories/communication_repository.dart` | identical |
| `lib/screens/login_screen.dart` | different |
| `lib/screens/teacher_dashboard/dashboard_personalization.dart` | different |
| `lib/screens/teacher_dashboard/dashboard_shell.dart` | different |
| `lib/screens/teacher_dashboard_screen.dart` | different |
| `lib/widgets/branding/instructos_brand_widgets.dart` | absent from baseline |
| `pubspec.lock` | different |
| `pubspec.yaml` | different |
| `test/login_screen_test.dart` | different |
| `web/index.html` | different |
| `web/manifest.json` | different |

### [#1: Premium AppBar redesign and carousel visual uplift for teacher dashboard](https://github.com/gastonstuart-lab/Gradeflow/pull/1)

Legacy dashboard visual proposal: both files evolved substantially. Preserve as reference; pilot uses current approved Home rather than replacing it with this dashboard.

Preserved head: `91280890f1c1ba7c594c99caf0406cc7c823fa9b`.

| Changed file | Comparison with baseline |
|---|---|
| `lib/components/dashboard_story_carousel.dart` | different |
| `lib/screens/teacher_dashboard_screen.dart` | different |

## Pilot recovery order

1. Save acknowledgement and grading semantics: adapt the missing #63 characterization coverage to current APIs, inspect each user-facing caller, and verify rejected writes do not report success. In particular, distinguish Native Gradebook from legacy/quick-score paths. A catch/log path is a risk requiring a reproducer, not proof of a visible failure in every path.
2. Context/account changes: exercise Home → Planner → Teach and account switch using current selection implementation; add current-provider regression coverage for any reproduced gap.
3. Recover #59 constitution as a small documentation change after reconciling present direction. Keep #65 as proposal until its outstanding product decisions are resolved.
4. Recover #67's editable lesson brief into current canonical Classroom with fictional roster/layout snapshot, long-text/large-roster pagination checks, PDF preview/download and a reachable button. Its original implementation uses fixed A4 layout; do not claim it supports every class size without rendering.
5. Retain #116/#66 and legacy branding as separate design/reference work. Keep security/configuration branches from overwriting current release guards.
6. Review #150 and assemble one candidate on the current application lineage. Run the teacher journeys in the companion register, then physical Surface/provider acceptance and a small teacher pilot.

No PR was closed or merged. No production settings, rules, school records or application source were changed. Missing source is preserved by original commit IDs and a source-recovery archive. That archive contains historical patches, not an installable release; blindly applying it can restore obsolete behavior. Existing tests/CI results cited elsewhere remain prior evidence.
