# InstructOS / GradeFlow — Current Release and AI Handoff

**Verified as of 17 November 2026, 20:05 Asia/Taipei.** This document is a time-stamped handoff, not a continuously refreshed status API. Before any change, re-query GitHub branches, PRs, checks and the actual Firebase release receipt.

## 1. One product, one repository, one production site

- Product: **InstructOS**, formerly/also referred to as GradeFlow. The GitHub repository retains the name `gastonstuart-lab/Gradeflow`.
- GitHub source of truth: `https://github.com/gastonstuart-lab/Gradeflow`.
- **Current application integration branch:** `integration/gradeflow-v2-release-candidate-20261115`.
- **Application integration commit following PR #156:** `1dfc2899e26cd1445e2db45a80529854c2861660`.
- **Verified reviewed application source commit:** `b4dcfe0e7f56f9bc083f868f3237cfc64be4852c`.
- Those integration/reviewed commits share the **exact same Git source tree**: `6a7d1ce8fbff1ee2902fe1741feb1100de8129c6`. This tree, not a guess based on branch names, establishes application source equivalence.
- **Main branch purpose at this checkpoint:** protected release control and shared project configuration. It is *not* the application integration HEAD. Do **not** blindly use `main` as the base for application feature work, and do **not** merge `main` into the integration branch without reconciling source lineages.
- Production Firebase project/site: `gradeflow-20260113`; `https://gradeflow-20260113.web.app/os/home`. This is the one live site; do not create a second Firebase project.

## 2. Last confirmed live release

- Production release-control PR: **#157**, merged into `main` as `5c54a81b4124198037590faff7dc513342ace693`.
- Successful GitHub Actions protected production release: **#44075283653**, completed 17 November 2026 at approximately 20:04 Taiwan time.
- Tested full-package source: `b4dcfe0e7f56f9bc083f868f3237cfc64be4852c`, identical source tree to integration PR #156.
- Exact reused artifact: build/review run **44026447494**, artifact **14303306855** (`native-gradebook-review-app`), ZIP digest `sha256:c95d9014681e58cf39a8a335ef26990eb9e0dce299f4d00b2153df514f4ce841`.
- Hosting verified manifest plus **819** file hashes before deployment. Successful backup clone **`before-reliability-44075283653`** and Hosting-only publish. The public `main.dart.js`, `index.html`, `/os/home`, Flutter bootstrap, Teaching Studio and PDF.js assets passed post-deploy HTTP byte verification.
- Release receipt artifact: **14325838638**. Source-of-evidence link: `https://github.com/gastonstuart-lab/Gradeflow/actions/runs/44075283653`.
- Firebase backup preview-channel Auth domain could not be added automatically, according to CLI warning. The live Hosting publication succeeded; signing in via the *backup preview URL* may require separate authorized-domain setup. Do not loosen production auth to resolve this casually.
- Release only replaced Firebase Hosting files. It **did not** change Firebase Auth, Firestore data/rules, Functions, IAM or school records. Temporary **Messages denial/containment** from PR **#149** remains in effect; security prototype PR **#148** is not deployed.

## 3. What the latest release includes

Gradebook bulk column-fill, safe overwrite confirmation, blanks-only option, grouped Undo, and responsive +/- scoring with buffered writes, based on user feedback on 17 November. Also retains earlier live Gradebook saved-weight/failure-reporting fixes, Home, Planner V2, Classroom, Teaching Studio with PDF/ink, and other previously published workflows. No redesigns of those approved interfaces were requested or published.

Verified evidence for the latest candidate:
- Flutter analysis, **375 Flutter tests passed, 2 original-file tests skipped**.
- **12 Teaching Studio browser tests passed**.
- Authenticated fictional-emulator Gradebook browser acceptance passed including actual Excel download, reload persistence and score adjustments.
- **3 broader authenticated local-emulator browser journeys passed**, including class/category recovery and room reuse.
- CI: `44026447494` (full package and Gradebook), `44026447506` (broader browser), `44026447526` (reliability/Flutter/Studio).
- These checks **do not certify** Google-provider sign-in against real credentials, physical Surface Pen/touch acceptance, the two fixture-dependent original-file cases, or every legacy workflow. Do not claim the application is fully launch-ready.

## 4. Outstanding work — do not misreport draft work as shipped

1. **Class creation / roster imports / grading-category retry:** review and reconcile existing draft PRs **#140**, **#143**, and their dependencies, against the *current* integration source, then run fresh exact-head CI and authentic fictional-data browser acceptance before considering promotion. Avoid duplicate-class creation and phantom-save successes.
2. **Room reuse persistence and rollback:** review draft **#141**, which is stacked on class reliability; test it together with current integration rather than merging stale stacked branches blindly. Never copy a room at the cost of losing pupil/seat assignments.
3. **Original school timetable XLSX acceptance:** prior synthetic and extracted-file checks do not prove real XLSX import. Need explicit school-file acceptance without exposing actual student data to external coding agents.
4. **Reports, Attendance, Files and teacher end-to-end navigation:** validate every real workflow rather than relying on component test counts.
5. **Messages/security:** shared Messages remain temporarily locked in production. Draft **#148** proposes a scoped permission model but requires trusted membership provisioning and separate security/data review. Never re-enable permissive cross-school rules as an easy rollback.
6. **Pilot readiness reconciliation:** draft documentation PR **#151** inventoried historical branches but is not merged; use it for review, not as an authoritative live deployment receipt.
7. **Device and auth acceptance:** test on the actual Surface Pro 11 and desktop, both colour modes, touch/Pen/PDF, login and exports.
8. **Custom domain/brand:** still undecided; domain registration or connection is unrelated to code lineage. Do not alter Firebase DNS/auth without explicit authorization.

## 5. Handoff procedure for Codex, Antigravity, Claude Code, or other agents

1. Read root `AGENTS.md` and `docs/ai-agents/README.md`. Respect the risk model, data restrictions, and human approval gates. This release document clarifies the *current app source lineage* but does not override any security policy.
2. Fetch the current GitHub integration branch and PR state. Verify it still points to the intended app, and identify the **actual deployed source** via the latest successful protected Hosting release. Do not assume `main` contains latest UI code.
3. For an app change: branch from the verified current **application integration** head, not a stale PR and not the release-control `main` tree. For release-control documentation/workflow changes: branch from `main`. Use isolated worktrees where available.
4. Write one scoped issue/work packet; classify risk; use **fictional local emulator data**; do not download/inspect production student/parent/staff records or credentials; do not auto-deploy or bypass review.
5. Keep each change in a reviewable PR with exact files, source SHA/tree, tests, browsers/screenshots, risks and remaining gaps. Any merge/deployment of amber/red/black changes requires the prescribed explicit approval; an approved application merge is **not** a deploy.
6. Publish only through the existing protected, pinned-artifact **Hosting-only** release process on `main`, with pre-deploy backup and post-release HTTP verification. A green CI job or a merge does not establish a successful production publication.
7. Update this timestamped handoff only after checking the latest actual release, and preserve previous rollback references.

## 6. Product constraints

- Existing Firebase project only; no migrations or second production site.
- Preserve approved compact Home, Planner V2, Classroom, Teaching Studio, and current grading/export policies unless explicitly changed.
- No unauthorised live school-data access, destructive action, Messages permission changes, domain purchases, authentication changes, or auto-publishing.
- Prefer reliability, persistence and workflow completion over cosmetic feature expansion.
