# GradeFlow — Home-only settings: manual production release review

**Status: DRAFT / NOT MERGED / NOT DEPLOYED.** Publication is human-only. Production Firebase / student data must not be touched by AI agents.

**Existing production:** `gradeflow-20260113`, https://gradeflow-20260113.web.app/os/home. Do not create a new Firebase project.

## Reason and scope

The live UI sometimes sent the teacher from Home to Planner when changing a background. The teacher approved keeping the compact account/settings menu on Home only. The fix already merged in [PR #165](https://github.com/gastonstuart-lab/Gradeflow/pull/165), **integration** source commit `072be2c331c87554f4a2e9c8587f2da9575370ea`. The current production site has not yet received the fix.

The new workflow `.github/workflows/publish-reviewed-home-settings-20261118.yml` is a **separate** protected workflow. The previously used `publish-reviewed-teacher-personalisation-20261118.yml` remains pinned to an *older* package and **must not be run for this fix**.

## Verified exact package and tests

- [Integrated Flutter build, success](https://github.com/gastonstuart-lab/Gradeflow/actions/runs/44243424792) — exact source `072be2c331c87554f4a2e9c8587f2da9575370ea`.
- [Actual authenticated browser acceptance, success](https://github.com/gastonstuart-lab/Gradeflow/actions/runs/44243424728) — exact same source.
- [Appearance checks, success](https://github.com/gastonstuart-lab/Gradeflow/actions/runs/44243432062) — exact same source.
- [Read-only complete-package check, success](https://github.com/gastonstuart-lab/Gradeflow/actions/runs/44246589466); built and tested unchanged Studio from the identical pinned source; checked public live site against prior release.
- Package artifact: [home-only-settings-complete-review-package](https://github.com/gastonstuart-lab/Gradeflow/actions/runs/44246589466/artifacts/14402590064), ID `14402590064`, ZIP SHA-256 `9d5a401586a1d17329e911389ea8e0a5444ef7476eb02fd8592ed39b92a03a89`.
- Package manifest: **820 files**, each SHA-256 verified.
- Flutter `main.dart.js` SHA-256: `46c42d38139a3b89359796591a7e296ee0ad205d8d47c8b96e529eb41c64a3da`.
- Teaching Studio `index.html` SHA-256: `8a0a695344d947c81a0d2f64d8d188a5192d493e929c97ab1cab873789a84fdb`.
- Artifact expires **2026-12-02 05:48 UTC**; any expiry requires fresh package review, never a silent substitution.
- Old production baseline artifact: `native-gradebook-review-app`, run `44219883596`, SHA-256 artifact digest `b6069310903509b5492861941d3b730a8ecc1cec17d79f2d3fb274dda737090a`; source `4a87559c88b15ec403066fca8f9760822aa0b441`.

## Production workflow safety gates

1. **Pull request** to `main` executes read-only `review-exact-package`: checks exact Git SHA, PRs, successful tests, archive digests, all 820 file digests and Hosting-only config; compares the 10 public live endpoints with last recorded release. No credentials and no deployment.
2. **After a separate human-approved merge to main**, manual workflow dispatch offers `action=check` (read-only) or `action=deploy`. Deploy is prohibited unless triggered on `main` with the typed confirmation `REPLACE`.
3. The deploy job also requires the GitHub `production` environment, exact pinned package, artifact-not-expired guard and `gradeflow-20260113` workload identity. Confirm GitHub production environment protections and required reviewers are actually configured before attempting publication; the environment name alone does not prove they are.
4. The deploy job rehashes all package files, verifies unchanged `firebase.live.json` allows **Hosting only** and verifies public live bytes again immediately before replacement.
5. Before publication, the operator clones the live Hosting release to a unique `before-home-${GITHUB_RUN_ID}` channel, records actual channel, then deploys **Hosting only** to the existing site. Never alter Firestore rules, student/teacher records, authentication, functions, secrets, storage, billing, or Firebase project settings.
6. The job compares 10 published endpoints to the approved bytes and uploads a receipt, including the backup channel. If publication verification fails, stop and perform a **human-authorized** restore using the recorded backup channel. Verify backup retention; Firebase preview channels may expire.
7. Human smoke tests after a successful release: sign-in, Home-only settings, choosing Neon boxes without navigating, Planner and back, refresh persistence, theme contrast, Gradebook scoring and Excel, class management and Classroom, Teaching Studio, sign-out.

**HOLD** if any pinned source SHA, CI result, artifact digest/expiry, manifest, Hosting-only config, live baseline, required environment protection, or user approval is missing or mismatched.

## Instructions for the authorized human operator (NOT YET APPROVED)

After the draft release-workflow PR passes read-only checks, confirm and approve its separate merge to `main`. Then explicitly approve any actual live publication. On GitHub Actions, select **Review and manually publish GradeFlow Home-only settings**, choose `main`, choose **deploy**, and enter **REPLACE**. This is a final irreversible publication request until a separately authorized rollback; do not select deploy merely to preview. Use **check** to verify readiness without publishing.

This documentation and the draft workflow are preparation only; creating, reviewing, or merging this PR does not deploy anything. The operator must record the actual workflow run, published source SHA, backup channel, publication result, UTC timestamp, smoke-test results and any rollback.
