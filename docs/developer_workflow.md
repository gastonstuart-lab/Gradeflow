# GradeFlow Developer Workflow

This is the small cockpit for running GradeFlow work with Codex, Copilot, or a local VS Code session.

## Default Loop

1. Pick one GitHub issue.
2. Create one branch for that issue.
3. Confirm the issue has one result, acceptance criteria, allowed scope, forbidden scope, verification commands, and screenshot requirements when visual work is involved.
4. Paste the issue's "Start prompt for Codex/Copilot" into the agent session.
5. Ask the agent to inspect first and report a short plan before editing.
6. Keep edits inside the issue's allowed scope.
7. Run the local verification tasks.
8. Open one PR that closes the issue.

## VS Code Tasks

Use **Terminal > Run Task...** for the local shortcuts:

- `Flutter: Analyze` runs `flutter analyze`.
- `Flutter: Test` runs `flutter test`.
- `Flutter: Build Web` runs `flutter build web`.
- `GradeFlow: Verify Local` runs analyze, then tests.
- Existing Git and Playwright helper tasks remain available for handoff and browser checks.

## Launch Configs

Use **Run and Debug**:

- `GradeFlow Web: Chrome Debug` starts Flutter web on Chrome in debug mode.
- `GradeFlow Web: Chrome Profile` starts Flutter web on Chrome in profile mode.

## Guardrails

- Do not mix unrelated fixes into the same branch.
- Do not let workflow issues drift into `lib/`, `test/`, `web/`, `android/`, `ios/`, Firebase logic, routing, UI, dependencies, or generated build outputs.
- For visual work, collect before and after screenshots before opening the PR.
- If verification is skipped, write down why.
