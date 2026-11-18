# GradeFlow V2 — Teacher Personalisation release handoff

**Status:** Prepared for human review only. **NOT merged or deployed.**

**Existing live project:** `gradeflow-20260113`  
**Existing live URL:** `https://gradeflow-20260113.web.app/os/home`  
**Feature PR:** `https://github.com/gastonstuart-lab/Gradeflow/pull/162` (draft)  
**PR base:** `integration/gradeflow-v2-release-candidate-20261115`  
**Approved fictional-data visual preview:** `https://gradeflow-native-menu-review.vercel.app/`

## Scope and governing rules

This is a teacher-facing **appearance and account-menu** feature. A teacher's accent colour changes **decorative backgrounds only**, never grading data, text, buttons, focus states, or other functional UI. Light, Dark, and System are separate whole-interface settings. The compact top-right account menu includes appearance, user-triggered fullscreen, installed-app help, and a confirmed sign-out.

Do not modify Firebase Auth, Firestore, rules, functions, student records, production project settings, or the approved Planner/Teaching Studio layouts. The visual preview has fictional data and cannot substitute for real V2 browser acceptance.

Repository `AGENTS.md` treats production deployment as **human-only**. An agent may prepare and test this handoff, but must not merge a risky PR, use GitHub production credentials, deploy, or change live school data autonomously.

## Release blockers: verify before any live action

1. [ ] **Human review of PR #162** and explicit merge decision. Record merge SHA and checked release SHA. A draft PR alone is not deployable approval.
2. [ ] All four workflows on the **same exact head SHA** pass:
   - Teacher appearance PR checks (including native Flutter desktop/phone visuals and background-only guard).
   - GradeFlow workflow reliability candidate (full Flutter checks).
   - Native Gradebook review gate (including saved weights, score edit and Excel export).
   - GradeFlow reliability actual browser acceptance (authenticated local/emulator tests).
3. [ ] Review the output of `Verify reviewed LIVE-mode build and Hosting-only configuration` and its artifact `gradeflow-v2-live-mode-review-not-deployed`. Confirm `GRADEFLOW_LIVE_CLASSROOM_V2=true`, `--base-href /`, `lib/main.dart`, SHA-256, exact Git commit and complete Hosting-only configuration.
4. [ ] **Identify the currently deployed live source/release** and reconcile it against the approved V2 integration branch and candidate. This cannot be inferred from a successful build or visual preview.
5. [ ] The pre-existing release workflow `.github/workflows/deploy-reviewed-gradeflow-v2.yml` on `main` is pinned to **`19c90232724224d7a2eeed624dd8f13c47ccc170`**, an older source. **Do not invoke its `deploy` action for this feature**. Separately review and authorize the exact-commit release method, its build artifact and its environment protection. No change to this production workflow is included in PR #162.
6. [ ] Owner confirms the intended release, schedule, and rollback plan. Ensure a suitable authenticated human/operator is responsible for any production actions.

## Pre-release acceptance — actual V2 UI

Perform on desktop/Surface and tablet, in Light and Dark modes:

- [ ] Sign in via the existing production-compatible authentication flow and verify the correct teacher account.
- [ ] Open Home, Planner, Classes, Gradebook and Classroom; no top-right account menu overlaps Weather, Export Excel, grade cells, class actions, or drag/drop surfaces.
- [ ] Select Neon Boxes, then cyan, orange, and a custom RGB/HEX colour. **Only page backgrounds change**; cards, grade values, text, menus and controls retain normal app theme colours.
- [ ] Inspect dense Gradebook tables in both themes; ambient effect does not bleed through student data.
- [ ] Tap +/− grading controls repeatedly, bulk-fill scores, verify save/persistence and Excel export.
- [ ] Verify classroom seat dragging, students list, adding a student, planner events, and Teaching Studio controls are unaffected.
- [ ] Verify that Sign out requires confirmation and returns to the normal login route; cancel preserves the session.
- [ ] Verify fullscreen is user-triggered, exits using Esc, and doesn't disrupt app navigation. Installed-app mode is optional and never forced after OAuth login.

## Human-only production procedure

**Never execute these commands in an autonomous agent session.** Commands are a checklist for the authorized release operator after review.

1. Record exact **tested commit SHA**, `main.dart.js` SHA-256 and signed-off release notes. Rebuild from that pinned source with locked dependencies; do not silently substitute `main`, an integration branch head, or a separate preview build.
2. Confirm the target is **only** Firebase Hosting for **`gradeflow-20260113`**. The Hosting config must have `public: build/web` and the fallback `** -> /index.html`, and must **not** include Firestore, functions, database, storage or other deployment targets.
3. Before replacing anything, clone the current live Hosting release into a **short, timestamped** rollback channel. Record the actual channel, deployer, Git SHA, UTC time and channel expiry; retain the backup until post-release acceptance is complete. Firebase preview channels can expire, so verify the channel's retention rather than treating it as a permanent archive.

   ```bash
   firebase hosting:clone gradeflow-20260113:live gradeflow-20260113:before-v2-YYYYMMDDHHMMSS --project gradeflow-20260113
   ```

4. Publish the **pinned reviewed build only**, using the approved protected production release workflow and existing Firebase project. The intended Hosting-only command is:

   ```bash
   firebase deploy --only hosting --project gradeflow-20260113 --config firebase.live.json --non-interactive
   ```

   This command is shown **for human review**, not authorization to run it. Do not run it unless the operator has verified the working directory contains the exact pinned artifact.

5. Immediately smoke-test on `https://gradeflow-20260113.web.app/os/home`: login, Home, Calendar/Planner, Gradebook scoring + Excel, Classroom seating, teacher settings, sign-out, and both themes. Check the browser console, mobile layout, and loading/login flows.
6. If anything fails, the operator should stop using the broken release and restore the recorded channel to live:

   ```bash
   firebase hosting:clone gradeflow-20260113:before-v2-YYYYMMDDHHMMSS gradeflow-20260113:live --project gradeflow-20260113
   ```

   Substitute the **actual** backup channel from step 3. Verify the live app and report the rollback outcome. No Firestore data restore should be needed for this Hosting-only UI release.

## Report at completion

Capture exact Git SHA, build SHA-256, workflow run IDs and results, reviewers, backup channel, operator, release timestamp, live URL, smoke-test result, any issues, and rollback outcome (if used).

**Hold condition:** If source lineage, CI, permissions, confirmation, backup, or the reviewed release artifact cannot be proven, do not deploy.
