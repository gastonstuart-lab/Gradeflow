# AI Agent Operating Manual

This folder defines how AI agents may help build InstructOS safely.

The operating model is simple:

```text
GitHub issue -> risk classification -> specialist agent work -> tests -> draft PR -> human approval
```

Agents can help Stuart move faster, but they do not own the product, approve risky work, or make final decisions.

## Core Rules

| Rule | Meaning |
| --- | --- |
| Stuart decides | Stuart is the founder and final decision maker. |
| Work through GitHub | Use issues, branches, tests, and pull requests. Avoid hidden chat-only work. |
| Keep PRs small | One issue, one branch, one PR. |
| Draft PRs by default | Agents stop after opening a draft PR unless Stuart says otherwise. |
| Evidence required | Every PR needs goal, files changed, tests, risks, preserved behavior, and review notes. |
| School data is high risk | Do not autonomously access, process, expose, migrate, or send student, parent, or staff data. |
| Sensitive areas pause | Auth, Firebase, secrets, billing, deployments, data models, parent communication, and legal wording need approval. |
| If unsure, stop | Ask for review instead of guessing. |

## Agent Roles

| Role | Use when |
| --- | --- |
| [Product Lead Agent](product-lead.md) | Turning broad goals into scoped issues and acceptance criteria. |
| [Flutter Engineer Agent](flutter-engineer.md) | Implementing approved Flutter or Dart work. |
| [UX/UI Agent](ux-ui-agent.md) | Improving clarity, layout, copy, accessibility, and responsiveness. |
| [QA and Release Agent](qa-release-agent.md) | Verifying changes and recommending merge, hold, or stop. |
| [Firebase and Security Agent](firebase-security-agent.md) | Reviewing data, secrets, IAM, Firebase, and privacy risk. |
| [AI Assistant Architect Agent](ai-assistant-architect.md) | Improving Ask InstructOS prompts, context, retrieval, evals, and safety. |
| [Business and Pricing Agent](business-pricing-agent.md) | Thinking through tiers, packaging, pricing, and school adoption. |

## Standard Work Packet

Use `issue-packet-template.md` before implementation when the work is not already clear.

Every packet should include:

- Goal.
- User problem.
- Acceptance criteria.
- In scope and out of scope.
- Likely files.
- Forbidden files or areas.
- Risk level.
- Required agents.
- Required tests.
- Manual QA.
- Final report expectations.

## Standard PR Report

Use `pr-report-template.md` for every agent PR.

The report should make it easy for Stuart to answer:

- What changed?
- Why did it change?
- How was it checked?
- What could break?
- What behavior was preserved?
- What still needs human review?

## Default Stop Conditions

Agents stop when:

- The task touches Red or Black areas without explicit approval.
- The issue scope is unclear.
- Tests fail and the fix would expand scope.
- The agent would need live school data.
- A change could send messages, alter production data, expose secrets, or affect billing.
- The agent discovers the requested change conflicts with existing product behavior.

