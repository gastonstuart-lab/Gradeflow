# GradeFlow Agent Instructions

GradeFlow is a solo-builder Flutter/Firebase project. Work in a small, inspect-first style that keeps Stuart in control.

## Workflow Rules

- Follow one issue, one branch, one result.
- Read the relevant issue and its latest "Start prompt for Codex/Copilot" before editing.
- Report a short plan before file edits.
- Keep changes inside the issue's allowed scope.
- Treat forbidden scope as binding unless Stuart explicitly changes it in the current session.
- Do not edit app source, Firebase logic, routing, UI, dependencies, or build outputs unless the issue explicitly allows it.
- Do not repair unrelated failures or refactor nearby code just because it is visible.
- Preserve user changes in the working tree.

## Required Issue Shape

Every implementation issue should state:

- One observable result.
- Acceptance criteria.
- Allowed scope.
- Forbidden scope.
- Verification commands.
- Screenshot requirements for visual work.

## Verification

Prefer the light local baseline first:

```powershell
flutter analyze
flutter test
```

Use `flutter build web` only when the issue asks for build verification or the environment is stable enough. For visual work, capture before and after screenshots and include them in the PR.

## Handoff

End with:

- Files changed.
- What changed for Stuart.
- Verification run and results.
- Assumptions, limitations, or skipped checks.
