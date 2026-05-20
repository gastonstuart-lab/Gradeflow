# Task Risk Model

Use this model before agent work starts. When a task fits more than one level, choose the higher risk level.

## Quick Decision Table

| Level | Agent autonomy | Typical work | Merge policy |
| --- | --- | --- | --- |
| Green | Safe for agents to code and open a PR. | Docs, tests, copy, simple UI polish. | Draft PR preferred. Can be marked ready after tests. Human review still recommended. |
| Amber | Agents may code but must open draft PR only. | Bounded app feature work or workflow UI changes. | No autonomous merge. Human visual review required. |
| Red | Plan-only unless Stuart explicitly approves implementation. | Sensitive systems, data, auth, security, billing, deployment, AI backend changes. | Human approval required before code. Security review required. |
| Black | Never autonomous. | Production actions, real data deletion, parent messages, legal decisions, secrets exposure. | Human-only. |

## Green Tasks

Safe for agents to code and open a PR.

Examples:

- Documentation.
- Copy changes.
- Tests.
- Simple UI polish.
- Obvious empty-state improvements.
- Low-risk widget spacing.
- Small non-behavioral refactors.

Merge policy:

- Draft PR preferred.
- Can be marked ready after tests.
- Human review still recommended.

## Amber Tasks

Agents may code but must open draft PR only.

Examples:

- Bounded app feature work.
- UI changes affecting workflows.
- Non-sensitive logic changes.
- Assistant UX changes.
- Import/export UI changes.
- Responsive layout changes.

Merge policy:

- No autonomous merge.
- Human visual review required.

## Red Tasks

Plan-only unless Stuart explicitly approves implementation.

Examples:

- Auth.
- Firebase security rules.
- Firestore data model changes.
- Migrations.
- Secrets.
- Billing.
- Cloud Functions.
- OpenAI backend/model changes.
- Production deployment workflows.
- School shared folder permissions.
- AI prompts using student data.
- Parent communication logic.

Merge policy:

- Human approval required before code.
- Security review required.

## Black Tasks

Never autonomous.

Examples:

- Production deploys.
- Deleting real data.
- Sending parent messages.
- Legal/compliance decisions.
- Changing live school data.
- Exposing secrets.
- Bypassing GitHub protections.
- Changing payment or contract terms.

Merge policy:

- Human-only.

## Escalation Rule

If an agent is unsure whether a task is Green, Amber, Red, or Black, it must stop and ask for review.

