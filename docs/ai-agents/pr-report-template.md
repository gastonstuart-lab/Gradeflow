# PR Report Template

Use this template for every agent-created PR.

## Executive summary

What this PR does and why it exists.

## Files changed

List exact files changed.

## What changed

Summarize the actual changes in practical language.

## Risk level

Green / Amber / Red / Black.

Explain why.

## Preserved behavior

Confirm what was intentionally not changed, especially:

- App code.
- Firebase.
- Auth.
- Routing.
- Dependencies.
- UI behavior.
- Backend behavior.
- Deployment workflows.

## Verification results

List commands run and results.

Example:

```text
git status --short --branch - passed
flutter analyze - not run; documentation-only PR
flutter test - not run; documentation-only PR
flutter build web --release --no-wasm-dry-run - not run; documentation-only PR
```

## Screenshots / visual QA if relevant

Add screenshots, screen recordings, or notes when UI changed.

Use `Not applicable` for documentation-only changes.

## Known limitations

List anything the PR does not solve.

## Rollback notes

Explain how to undo the change if needed.

## Human review required

Name the decisions Stuart must review before merge.

