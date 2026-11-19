# GradeFlow release register and pilot readiness

Prepared 17 November 2026 (Taiwan). Read-only GitHub reconciliation; no merge, closure, deployment or live school-data access performed.

## Baseline

Application: `31a1a3ec6f22275872c0fa8073b8da446614a2e8`, branch `integration/gradeflow-v2-release-candidate-20261115`.
The committed [QA report](https://github.com/gastonstuart-lab/Gradeflow/blob/qa/native-gradebook-20261117/docs/qa/native-gradebook-20261117.md) records Firebase Hosting version `94fb48744253991d` published 16 November at 20:34 Taiwan time and matching application bytes. This audit did not independently re-query Firebase.
Main holds separate release controls and Messages containment. Do not substitute main's application files for the baseline.

## Findings

64 open PRs inventoried. 42 have complete heads in baseline history, one (#140) has equivalent core changes and subsequent baseline recovery, two are separate unreleased candidates, and 19 require file-level reconciliation. Ancestry proves incorporation in history, not that every historical behavior survives subsequent edits or is accepted by teachers. Open status is not proof of missing code. Approval in chats was not independently verified for every PR.

#140: compared all four files changed by its six extra commits. Class creation dialog and safety tests match after line-ending normalization; grading category service is identical. Class-list screen contains subsequent partial-setup and identity recovery from #143. Treat as accounted for at this scope; do not merge the old whole screen over the baseline.

## Register

| PR | Title | Finding | Unique branch commits |
|---|---|---|---|
| [#150](https://github.com/gastonstuart-lab/Gradeflow/pull/150) | Show saved category weights in native Gradebook and verify Excel workflow | Unreleased candidate | 3 |
| [#148](https://github.com/gastonstuart-lab/Gradeflow/pull/148) | Prototype school/channel authorization and verified communication writes | Unreleased Messages prototype | 2 |
| [#131](https://github.com/gastonstuart-lab/Gradeflow/pull/131) | GradeFlow V2 release candidate: approved Planner and reliability integration | Included in baseline history | 0 |
| [#143](https://github.com/gastonstuart-lab/Gradeflow/pull/143) | Guard class-import grading setup and offer safe retry after partial save (#142) | Included in baseline history | 0 |
| [#141](https://github.com/gastonstuart-lab/Gradeflow/pull/141) | Report room reuse failures and recover prior arrangements | Included in baseline history | 0 |
| [#140](https://github.com/gastonstuart-lab/Gradeflow/pull/140) | Keep failed class creation open and confirm durable saves | Equivalent core fix; later class-list recovery in baseline | 6 |
| [#130](https://github.com/gastonstuart-lab/Gradeflow/pull/130) | Planner V2: Today and full-width teaching Week with contextual class tools | Included in baseline history | 0 |
| [#129](https://github.com/gastonstuart-lab/Gradeflow/pull/129) | Planner foundation: validate timetable imports, confirm class links and save local versions safely | Included in baseline history | 0 |
| [#128](https://github.com/gastonstuart-lab/Gradeflow/pull/128) | Reject passwordless local fallback and clarify preview-only demo entry | Included in baseline history | 0 |
| [#127](https://github.com/gastonstuart-lab/Gradeflow/pull/127) | Retain exam edits on save failure and serialize exam-entry saves | Included in baseline history | 0 |
| [#126](https://github.com/gastonstuart-lab/Gradeflow/pull/126) | Fix saved-weight Excel exports on the current deployed app source | Included in baseline history | 0 |
| [#124](https://github.com/gastonstuart-lab/Gradeflow/pull/124) | V2: prominent Add student actions and reliable duplicate-safe roster saving | Included in baseline history | 0 |
| [#122](https://github.com/gastonstuart-lab/Gradeflow/pull/122) | Fix: allow exactly the Classes V2 review host in preview safety guard | Included in baseline history | 0 |
| [#120](https://github.com/gastonstuart-lab/Gradeflow/pull/120) | Classes V2: eight-class command centre with real roster, seating and score coverage | Included in baseline history | 0 |
| [#119](https://github.com/gastonstuart-lab/Gradeflow/pull/119) | P0 Gradebook: make Excel exports match saved per-class grading weights | Needs file-level reconciliation | 5 |
| [#116](https://github.com/gastonstuart-lab/Gradeflow/pull/116) | Design Lab: isolated real-widget gallery and demo-only quick Gradebook entry | Needs file-level reconciliation | 8 |
| [#114](https://github.com/gastonstuart-lab/Gradeflow/pull/114) | Weather flyout finishing pass: short-screen fit, visible hourly scrolling and dark/mobile regression tests | Included in baseline history | 0 |
| [#112](https://github.com/gastonstuart-lab/Gradeflow/pull/112) | Home: expandable Android-style weather chip with hourly graph and 5-day forecast | Included in baseline history | 0 |
| [#109](https://github.com/gastonstuart-lab/Gradeflow/pull/109) | Planner V2: weekly calendar, dated day details, Agenda and Tasks | Included in baseline history | 0 |
| [#107](https://github.com/gastonstuart-lab/Gradeflow/pull/107) | Home planning recovery: event-aware calendar, bounded week view and typed imports | Included in baseline history | 0 |
| [#104](https://github.com/gastonstuart-lab/Gradeflow/pull/104) | Recover school calendar import, student seating, classroom navigation and class imports | Included in baseline history | 0 |
| [#103](https://github.com/gastonstuart-lab/Gradeflow/pull/103) | Release review: theme-aware Background Boxes on tested GradeFlow V2 | Included in baseline history | 0 |
| [#102](https://github.com/gastonstuart-lab/Gradeflow/pull/102) | Home only: remove full-width dock footer and keep floating dock clear | Included in baseline history | 0 |
| [#101](https://github.com/gastonstuart-lab/Gradeflow/pull/101) | Review: compact subject-coloured Home class rail (replace oversized Teaching Day panel) | Included in baseline history | 0 |
| [#100](https://github.com/gastonstuart-lab/Gradeflow/pull/100) | Review: make login branding readable over Background Boxes | Needs file-level reconciliation | 4 |
| [#99](https://github.com/gastonstuart-lab/Gradeflow/pull/99) | Integration review: unified Gradebook, shared rooms, Teacher Home and safer Boxes login | Needs file-level reconciliation | 10 |
| [#98](https://github.com/gastonstuart-lab/Gradeflow/pull/98) | Login/launch: native Background Boxes and a single branded loading experience | Needs file-level reconciliation | 22 |
| [#97](https://github.com/gastonstuart-lab/Gradeflow/pull/97) | Classroom shared rooms + approved Teacher Home carousel and personalisation (review only) | Included in baseline history | 0 |
| [#96](https://github.com/gastonstuart-lab/Gradeflow/pull/96) | GradeFlow grading recovery: dense Gradebook, in-seat quick grades, editable weights and dark dock fix | Included in baseline history | 0 |
| [#94](https://github.com/gastonstuart-lab/Gradeflow/pull/94) | Draft: GradeFlow V2 live website release candidate — rollback-first, not deployed | Included in baseline history | 0 |
| [#93](https://github.com/gastonstuart-lab/Gradeflow/pull/93) | Auth-staging browser gate: actual Flutter Classroom against demo-only Firebase emulators | Included in baseline history | 0 |
| [#92](https://github.com/gastonstuart-lab/Gradeflow/pull/92) | Staging E2E: real Firebase Auth + Firestore class, seating and grades persistence | Included in baseline history | 0 |
| [#91](https://github.com/gastonstuart-lab/Gradeflow/pull/91) | Integrated release candidate: approved Classroom V2 + safe authenticated staging | Included in baseline history | 0 |
| [#90](https://github.com/gastonstuart-lab/Gradeflow/pull/90) | Remember selected teaching class when returning to premium Home | Included in baseline history | 0 |
| [#89](https://github.com/gastonstuart-lab/Gradeflow/pull/89) | Classroom V2: fit occupied furniture, pan view, reclaim Present screen | Included in baseline history | 0 |
| [#88](https://github.com/gastonstuart-lab/Gradeflow/pull/88) | Planner V2 staging: strict Firestore rules and cross-teacher emulator tests | Needs file-level reconciliation | 25 |
| [#87](https://github.com/gastonstuart-lab/Gradeflow/pull/87) | Planner V2: dedicated staging Firebase configuration and no local-login fallback | Needs file-level reconciliation | 20 |
| [#86](https://github.com/gastonstuart-lab/Gradeflow/pull/86) | Planner V2 staging: block production Firebase access before authenticated startup | Needs file-level reconciliation | 10 |
| [#85](https://github.com/gastonstuart-lab/Gradeflow/pull/85) | Release review: protect latest Planner V2 zoom build and gate integration | Needs file-level reconciliation | 6 |
| [#84](https://github.com/gastonstuart-lab/Gradeflow/pull/84) | Planner V2: free seat dragging and transactional seat history | Included in baseline history | 0 |
| [#83](https://github.com/gastonstuart-lab/Gradeflow/pull/83) | Planner V2 Stage 4: editable table width and depth in contextual panel | Included in baseline history | 0 |
| [#82](https://github.com/gastonstuart-lab/Gradeflow/pull/82) | Planner V2 Stage 3: undo/redo, durable save state and Escape cancel | Included in baseline history | 0 |
| [#81](https://github.com/gastonstuart-lab/Gradeflow/pull/81) | Planner V2 Stage 2: opt-in direct table gestures and single-save commits | Included in baseline history | 0 |
| [#80](https://github.com/gastonstuart-lab/Gradeflow/pull/80) | Planner V2 foundation: scale-correct drag and free resize geometry | Included in baseline history | 0 |
| [#79](https://github.com/gastonstuart-lab/Gradeflow/pull/79) | Fix: allow open-floor table dragging towards visible left edge | Included in baseline history | 0 |
| [#78](https://github.com/gastonstuart-lab/Gradeflow/pull/78) | Review: enlarge Classroom floor furniture using adaptive viewport fit | Included in baseline history | 0 |
| [#77](https://github.com/gastonstuart-lab/Gradeflow/pull/77) | Review: open Classroom floor and simplified arrange controls | Included in baseline history | 0 |
| [#76](https://github.com/gastonstuart-lab/Gradeflow/pull/76) | Synthetic-only Classroom browser preview (separate GitHub Pages deployment) | Included in baseline history | 0 |
| [#75](https://github.com/gastonstuart-lab/Gradeflow/pull/75) | Review: bundle local Roboto for offline Classroom text | Included in baseline history | 0 |
| [#74](https://github.com/gastonstuart-lab/Gradeflow/pull/74) | Recover Classroom from preserved Surface work with stationary teaching and active pickers | Included in baseline history | 0 |
| [#73](https://github.com/gastonstuart-lab/Gradeflow/pull/73) | Restore stationary Classroom, animated picks and fullscreen teaching tools | Needs file-level reconciliation | 10 |
| [#71](https://github.com/gastonstuart-lab/Gradeflow/pull/71) | Premium Classroom: Teach/Arrange safeguards and fit-to-room presentation | Needs file-level reconciliation | 15 |
| [#70](https://github.com/gastonstuart-lab/Gradeflow/pull/70) | Unify InstructOS teacher experience and audit release blockers | Included in baseline history | 0 |
| [#69](https://github.com/gastonstuart-lab/Gradeflow/pull/69) | Restore Classroom interactions and integrate native gradebook | Included in baseline history | 0 |
| [#68](https://github.com/gastonstuart-lab/Gradeflow/pull/68) | Integrate approved Teacher Home with functional class context | Included in baseline history | 0 |
| [#67](https://github.com/gastonstuart-lab/Gradeflow/pull/67) | Add editable one-page A4 substitute handover to Classroom seating | Needs file-level reconciliation | 2 |
| [#66](https://github.com/gastonstuart-lab/Gradeflow/pull/66) | InstructOS teaching journey preview | Needs file-level reconciliation | 53 |
| [#65](https://github.com/gastonstuart-lab/Gradeflow/pull/65) | Propose minimal classroom controls and display contracts | Needs file-level reconciliation | 1 |
| [#63](https://github.com/gastonstuart-lab/Gradeflow/pull/63) | Characterize academic calculations and persistence failures | Needs file-level reconciliation | 1 |
| [#60](https://github.com/gastonstuart-lab/Gradeflow/pull/60) | Preserve working class across InstructOS shell transitions | Needs file-level reconciliation | 1 |
| [#59](https://github.com/gastonstuart-lab/Gradeflow/pull/59) | Record the locked InstructOS product constitution | Needs file-level reconciliation | 1 |
| [#56](https://github.com/gastonstuart-lab/Gradeflow/pull/56) | Improve seating plan classroom control surface | Included in baseline history | 0 |
| [#21](https://github.com/gastonstuart-lab/Gradeflow/pull/21) | Recover InstructOS branding and Flutter 3.41 compatibility | Needs file-level reconciliation | 2 |
| [#1](https://github.com/gastonstuart-lab/Gradeflow/pull/1) | Premium AppBar redesign and carousel visual uplift for teacher dashboard | Needs file-level reconciliation | 2 |

## Ordered work packets

1. Reconcile the 19 divergent branches by changed-file/content comparison. Prioritize #119 (grading/export), #60/#63 (context and persistence tests), #67 (substitute handover) and #59 (product constitution). Review older UI/recovery branches against approved present behavior, retaining useful unique work in scoped branches. Do not close or merge solely on ancestry. Output: per-file retained/superseded/missing decision with evidence.
2. Review #150 as the next bounded candidate on the baseline. Its only production-source change is the saved-weight status label; all other files are tests, fixtures, CI and evidence. Existing run 43977962887 reports 370 Flutter tests, 12 Studio browser tests and one native Gradebook/Excel journey passing. These are prior reported results, not fresh execution in this audit. Candidate is not deployed.
3. Build a single pilot package containing only reconciled, reviewed changes; record source commit, full Studio inclusion, package hashes, known issues and rollback reference. Verify exact candidate in the workflow below.
4. Stuart runs the physical Surface and actual provider acceptance items. Then two or three teachers use separate test accounts before school-data onboarding.

## Pilot acceptance checklist

All pending unless specific existing evidence is cited. A prior emulator pass does not certify real provider, physical hardware or actual files.

| Journey | Existing evidence | Required before pilot |
|---|---|---|
| Sign in/out and reopen | Prior emulator auth journeys | Actual chosen provider; second account; expired session; visible failures |
| Teacher isolation | Owner-only academic rules and staging tests reported | Two fictional teacher accounts: cross-account reads/writes denied, account-switch cache cleared; review active rules separately |
| Create/import classes and pupils | #146 emulator journeys include failure/retry and partial setup | Representative fictional CSV/XLSX in every supported import route; duplicates, cancellation, reopen, missing pupil, isolation |
| Plan lessons | Planner included; prior widget/browser checks | Original-format timetable with fictional content; empty periods, bell times, links, reload; document device-local timetable limitation |
| Classroom and room reuse | #146 failure/recovery acceptance | Arrange/reopen, pupil isolation, Surface drag/touch, visible failed save; document best-effort compensation |
| Gradebook and Excel | #150 native journey reports zero/clear, invalid edit, reload and numeric workbook parity | Run exact pilot candidate; representative grading policy; review missing-score semantics and every export entry point offered to pilot teachers |
| PDF and Whiteboard | 12 prior Studio tests; pen fix included | Surface handwriting/eraser, undo, download/reopen, reload/unsaved-work warnings; confirm any autosave limitations |
| Multiple devices | Not certified | Same teacher edits/reopens on Surface and desktop; concurrent edits produce defined result or explicit pilot restriction |
| Shared Messages | Temporary containment publication recorded | Keep unavailable during first pilot; #148 needs separately reviewed membership provisioning and coordinated rollout |
| Support and recovery | Existing release backup process | Visible version, short bug-report steps, known issues, export/backup guidance, verified rollback procedure |

## Release decisions

No blanket merge or PR closure recommended. Keep #148 separate from the first pilot. Do not claim cross-device uniqueness, interrupted rollover resume, universal aggregation/export parity or physical hardware certification from current evidence. Preserve accepted UI while addressing verified defects. Source commits remain in GitHub; CI artifacts for #150 expire after 14 days, so reproducible source is the durable record.

## Next completion target

A reconciled list of unique useful code plus a single candidate that passes the above core journeys. Then Stuart's bounded acceptance session, followed by a small teacher pilot. This report establishes the work queue; it is not a certification that the pilot is ready.


## Reconciliation follow-up

The 19 divergent branches now have changed-file comparisons and initial recovery decisions in the companion branch-reconciliation report. Confirmed absent work includes the editable substitute handover (#67), product constitution (#59), characterization tests (#63), proposal document (#65), and separate Design Lab/teaching prototypes. Grading/export application code from #119 is identical to the baseline. Source triage does not certify runtime behavior or justify closing PRs.
