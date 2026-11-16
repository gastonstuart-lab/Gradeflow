# InstructOS AI Agent Operating Rules

InstructOS / GradeFlow is a Flutter and Firebase teacher operating system. It helps Stuart build a practical school workflow product while protecting school, student, parent, and staff data.

This file is the repo-level instruction sheet for Codex, Copilot, Claude Code, and any future AI development agent. Agents are helpers, not owners. Stuart is the founder and final decision maker.

Before doing agent work, read this file and `docs/ai-agents/README.md`.

For product and interaction decisions, read [INSTRUCTOS_PRODUCT_CONSTITUTION.md](INSTRUCTOS_PRODUCT_CONSTITUTION.md). It records Stuart's locked teacher-state direction and supersedes conflicting historical mockups or page-by-page redesign plans. The safety, risk and review rules in this file continue to apply.

## Build Philosophy

- Keep the product useful for real teachers before making it clever.
- Prefer small, reviewable changes over broad rewrites.
- Preserve existing behavior unless the GitHub issue explicitly asks for a change.
- Treat school data as high risk by default.
- Stop when the task becomes unclear, sensitive, destructive, or larger than the issue.

## Quality Lock Principle

Quality Lock means every change must leave InstructOS more reliable, clearer, or safer than before.

Agents must:

- Work from a scoped GitHub issue or explicit Stuart request.
- Make one branch and one PR per issue.
- Run relevant checks.
- Report evidence honestly.
- Keep risky work in draft PRs until Stuart reviews it.

Agents must not hide work in chat-only patches or undocumented local changes.

## GitHub Workflow Rules

1. Start from latest `main`.
2. Create a scoped branch for the issue.
3. Keep the PR small.
4. Make documentation, code, tests, or config changes only when the issue allows them.
5. Open a draft PR by default.
6. Include a full PR report using `docs/ai-agents/pr-report-template.md`.
7. Do not merge unless Stuart explicitly says to merge.

Preferred workflow:

| Step | Required action |
| --- | --- |
| Issue | Define goal, scope, non-goals, acceptance criteria, and risk level. |
| Plan | Agent writes a short plan and names sensitive areas. |
| Branch | Agent works on a dedicated branch. |
| Verification | Agent runs relevant checks and records results. |
| PR | Agent opens a draft PR with evidence. |
| Review | Stuart makes the final decision. |

## Risk Model Summary

| Level | Agent autonomy | Examples | Merge policy |
| --- | --- | --- | --- |
| Green | Agent may code and open a PR. | Docs, copy changes, tests, simple UI polish, obvious empty states, low-risk spacing, small non-behavioral refactors. | Draft PR preferred. Can be marked ready after tests. Human review still recommended. |
| Amber | Agent may code but must open draft PR only. | Bounded app features, workflow UI changes, non-sensitive logic, assistant UX, import/export UI, responsive layout. | No autonomous merge. Human visual review required. |
| Red | Plan-only unless Stuart approves implementation. | Auth, Firebase rules, data models, migrations, secrets, billing, Cloud Functions, OpenAI backend/model changes, deployment workflows, shared folder permissions, AI prompts using student data, parent communication logic. | Human approval required before code. Security review required. |
| Black | Never autonomous. | Production deploys, deleting real data, sending parent messages, legal/compliance decisions, changing live school data, exposing secrets, bypassing GitHub protections, changing payment or contract terms. | Human-only. |

See `docs/ai-agents/task-risk-model.md` for the full model.

## Forbidden Autonomous Actions

Agents must not autonomously:

- Access, process, export, migrate, send, or expose live student, parent, or staff data.
- Change authentication, authorization, IAM, Firebase security rules, secrets, billing, production deployment, or payment terms.
- Send parent/student/staff communications.
- Delete real data.
- Modify production Firebase projects or deploy production infrastructure.
- Bypass GitHub protections or merge risky work.
- Make legal, safeguarding, privacy, compliance, pricing, or contract decisions.
- Add dependencies, change routing, change auth, or alter backend behavior unless the issue explicitly allows it and the risk model permits it.

If unsure, stop and ask for review.

## Required PR Report Format

Every agent PR must report:

- Goal.
- Files changed.
- What changed.
- Tests run.
- Verification results.
- Risks.
- Preserved behavior.
- Rollback notes if relevant.
- Human review required.

Use `docs/ai-agents/pr-report-template.md`.

## Standard Verification Commands

Use the checks that fit the change:

```powershell
flutter analyze
flutter test
flutter build web --release --no-wasm-dry-run
```

Documentation-only PRs may not need full Flutter verification when no app code changed. At minimum, confirm:

```powershell
git status --short --branch
```

Do not make unrelated code changes just to satisfy formatting.

