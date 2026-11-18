# GradeFlow Home-only settings — reviewed production-package handoff

**Status: review-only, NOT merged to main and NOT deployed.**  
**Target after future human approval:** existing Firebase Hosting site `gradeflow-20260113`, https://gradeflow-20260113.web.app/os/home

## Scope and provenance

- User-reported defect: changing the Home background unexpectedly navigated to Planner; preferences appeared to work only from Planner.
- User decision: keep the full settings/account menu on **Home only**, while retaining decorative backgrounds on other pages.
- Fix: [PR #165](https://github.com/gastonstuart-lab/Gradeflow/pull/165) merged only to integration, exact squash SHA `072be2c331c87554f4a2e9c8587f2da9575370ea`.
- Post-merge successful integration build: [44243424792](https://github.com/gastonstuart-lab/Gradeflow/actions/runs/44243424792), SHA `072be2c331c87554f4a2e9c8587f2da9575370ea`, artifact `14400718024`, digest `sha256:e6ed1ade30a859d5e3ab3b235139975a165df951aa1481d4602fcde633a24996`.
- Post-merge real-auth browser: [44243424728](https://github.com/gastonstuart-lab/Gradeflow/actions/runs/44243424728) **success**.
- Post-merge appearance: [44243432062](https://github.com/gastonstuart-lab/Gradeflow/actions/runs/44243432062) **success**.
- PR's four pre-merge workflows all succeeded on head `61d070653e2c08cc2169600d44cfd7e434b1c25e`.

## Read-only complete package gate

The sibling GitHub workflow `.github/workflows/review-home-menu-fix-20261118.yml` is limited to a PR for **main** and has only `contents: read` and `actions: read` permission. It cannot deploy. Its fixed source is the exact successful integration merge SHA above. It:

1. Verifies the merged PR, successful post-merge run IDs and integrated Flutter artifact digest.
2. Downloads the exact live-mode Flutter build from successful run `44243424792`. It does not substitute a new source branch.
3. Builds and runs Teaching Studio tests from that **same pinned commit** and packages its assets under `teaching-studio/`.
4. Checks the Hosting-only `firebase.live.json` configuration; no rules, functions, storage or database deployment targets.
5. Generates `review-manifest.json` containing the exact Git commit, tree, component blob hashes, full file inventory, every file SHA-256, source CI run and artifact digest.
6. Downloads the last reviewed production package from run `44219883596` and uses the previously approved read-only public Hosting verifier to compare it with the **current live** website.
7. Uploads `home-only-settings-complete-review-package` for review with 14-day retention.

**No Cloud/Firebase credentials, identity tokens, write permissions, production APIs or deployment steps are used.** Public Hosting byte verification does not read or alter teacher/student records.

## Human-only next gates

- Confirm this PR's read-only workflow passes and record its exact artifact ID, run ID and SHA-256 digest.
- Review the package, source and changes in a separate, guarded deployment-workflow PR; DO NOT reuse the older `publish-reviewed-teacher-personalisation-20261118.yml`, which is pinned to the previous release.
- The repository's `AGENTS.md` treats deployment workflows as Red risk and actual production deployments as human-only. Obtain explicit founder approval before any deployment-workflow modification/merge or publishing.
- In a separately approved future release: verify live bytes immediately before publication, clone the current live Hosting release to a unique rollback channel, deploy **Hosting only** to `gradeflow-20260113` and verify the published bytes against this exact manifest. No data, auth, rules or functions changes.
- Human smoke test on desktop: Home menu only, Neon boxes choice stays on Home, Home → Planner → Home retains background, reload retains it, both themes, Gradebook export/scoring, Classroom, Planner, Teaching Studio, sign-out.

If any check fails or exact provenance cannot be established: **hold publication**.

## Report

Workflow run, artifact ID/digest, exact merge SHA, manifest file count, public live baseline result, reviewers, human approval and expiry must be documented before creating a new production-publishing workflow.
