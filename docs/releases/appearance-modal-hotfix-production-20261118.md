# GradeFlow Home appearance modal hotfix — protected live release

**Status: draft review; NOT deployed.** This release targets the existing Firebase Hosting project `gradeflow-20260113` only. It must never create a new project or touch teacher/student Firestore data.

## Why this release exists

After [PR #165](https://github.com/gastonstuart-lab/Gradeflow/pull/165) was published live in [run #44249217959](https://github.com/gastonstuart-lab/Gradeflow/actions/runs/44249217959), the teacher confirmed an unresolved regression: clicking any appearance option on Home — specifically **Aurora** and **Soft dots** — unexpectedly navigates to Planner and leaves appearance unchanged. The account/settings menu is intentionally Home-only, so it cannot then be used on Planner.

The review fix is [PR #168](https://github.com/gastonstuart-lab/Gradeflow/pull/168), approved only when all its exact-head tests are green. It replaces Flutter's anchored account pop-up with an isolated modal route that intercepts clicks and gestures before they reach Home navigation controls. No Home/Planner redesign. Existing settings/personalisation, signout, fullscreen and Teaching Studio functionality is preserved.

## Exact candidate

- Fix source (PR #168 head): `29fc631f4e980195a4a2f8bbf2ee15920018b4c2`. The source must be the same commit used by all test runs and the package.
- Appearance test and native Flutter menu preview: [run #44254368446](https://github.com/gastonstuart-lab/Gradeflow/actions/runs/44254368446).
- Integrated Flutter candidate and preserved Studio: [run #44254368499](https://github.com/gastonstuart-lab/Gradeflow/actions/runs/44254368499).
- Full app, Gradebook data / Excel and complete package: [run #44254368445](https://github.com/gastonstuart-lab/Gradeflow/actions/runs/44254368445).
- **Critical real authenticated browser acceptance**: [run #44254368535](https://github.com/gastonstuart-lab/Gradeflow/actions/runs/44254368535). It clicks Dark, Aurora, Soft dots, Minimal, Neon boxes and cyan in the real Home menu, asserts Home URL and selected state, then checks Planner and preference persistence. **Do not merge/release unless this succeeds.**
- Complete candidate artifact: [native-gradebook-review-app, ID 14405192654](https://github.com/gastonstuart-lab/Gradeflow/actions/runs/44254368445/artifacts/14405192654), SHA-256 archive digest `ffeddb9629b558ff972896098d67383189ed0fb4e2389e9feb7173829afc35e0`; includes full per-file `review-manifest.json`, Flutter and unchanged Teaching Studio.
- Artifact expiry and digest must be checked again immediately before deployment.

## Current live baseline and rollback

- Last production publication: run `44249217959`, original source `072be2c331c87554f4a2e9c8587f2da9575370ea`.
- Currently live package: [complete review package, ID 14402590064](https://github.com/gastonstuart-lab/Gradeflow/actions/runs/44246589466/artifacts/14402590064); archive digest `9d5a401586a1d17329e911389ea8e0a5444ef7476eb02fd8592ed39b92a03a89`.
- Prior unique rollback channel from that live deployment: `before-home-44249217959`. Any future new deploy creates an additional unique `before-modal-${GITHUB_RUN_ID}` channel containing the *current* live release.

## New release workflow and safety

The existing `.github/workflows/publish-reviewed-home-settings-20261118.yml` is re-pinned in the *separate draft release branch* `release/appearance-modal-hotfix-20261118`. **Do not invoke the old main-branch workflow before this updated version is reviewed and merged**: the old version publishes the already-buggy package. This is intentionally a narrow, reviewed workflow change, not a new app version.

A pull request to `main` runs a **read-only** job: requires exact PR #168 head SHA, all exact-head tests successful, candidate archive digest, per-file source/provenance checks, Hosting-only configuration, current live baseline and ten published-byte checks. This job has no Firebase credentials or deployment permissions.

The production job **never runs on PR/push**. Only an owner-initiated `workflow_dispatch` from `main` with `action=deploy` and the exact typed confirmation `REPLACE` can attempt it, via the `production` GitHub environment. Verify that actual human reviewer protections are enabled; the environment name alone is not approval. It then rechecks candidate SHA and file hashes, verifies current public baseline bytes immediately before replacement, authenticates using the existing `gradeflow-20260113` WIF service account, clones live to a unique rollback channel, deploys only Firebase Hosting, and byte-verifies the published Flutter + Studio files. An archived release receipt records source, artifact ID/digest, and rollback channel.

**Forbidden:** new Firebase project, database or rules writes, Auth configuration, environment/secrets modifications, Firestore, student records, functions, storage, automatic publication, reuse of unverified artifacts.

## Acceptance on the real live Windows desktop after successful human publication

1. Open `https://gradeflow-20260113.web.app/os/home`, force-refresh with Ctrl+Shift+R if a browser tab predates the release, and sign in normally.
2. Home account/settings → Appearance & colours. Click **Aurora**, **Soft dots**, **Minimal**, and **Neon boxes** individually. Each must select the appearance, visibly change the decorative background and **keep the URL at /os/home** with panel open.
3. Change glow colour (including cyan) and Dark/Light. Stay on Home. Click Done, return via Home → Planner → Home, and refresh; preferences should persist.
4. Planner has **no appearance menu**. Normal dock navigation still works after closing the modal.
5. Smoke-test Gradebook score edit/save, XLSX export, Classroom, Teaching Studio and sign-out; preserve all live teacher/student data.

**HOLD publication** for any failed test, missing SHA/artifact, expired or wrong baseline, missing human approval, or mismatch in published file bytes. Rollback only on separately authorized operator action, using the recorded `before-modal-...` channel.
