# Communication security prototype — 16 November 2026

## Security/privacy impact

The active default Firestore release was read through the authenticated Firebase CLI's rules API, without reading database documents. It matches the permissive repository communication rules: any authenticated user can read every school communication path, and a matching caller-controlled schoolKey is sufficient for writes. This is a confirmed deployed authorization gap, not just an old source finding.

Observed release: projects/gradeflow-20260113/releases/cloud.firestore.
Observed ruleset: projects/gradeflow-20260113/rulesets/7d55cd76-bd85-4805-88e4-e96d031aac31.
Updated: 2026-04-04T06:17:00.293208Z.
Raw source SHA-256: 1c258cf9874e4beccc93fc5b3d62aa03530a2afd766d1d06dc3cfaa6810fa4ce (mixed original line endings).

No production rules, messages, membership documents, roles or data were changed. The active rules were copied only to private local scratch storage. OAuth credentials are outside the repository and are not included in changes or artifacts.

## Prototype policy

A trusted administrator provisions communicationAccess/{firebaseUid} using the Firebase Console or an approved Admin SDK process. Client writes to this collection are always denied, including writes by school admins. One primary school is supported per user.

Example below is fictional and is NOT a production enrollment instruction:

```text
communicationAccess/fictional-teacher-uid
  active: true
  schoolKey: "fictional-school"
  role: "teacher"                  // teacher | departmentLead | admin
  displayName: "Fictional Teacher" // administrator-verified public name, <=100
  channelIds: ["staff", "admin-alerts"] // <=100, explicit least-privilege grants
```

School membership, role and channel grants never come from editable profiles, email domains, channel names, client-supplied authorRole or /users/{uid} documents. A personal-email user can be assigned the correct school explicitly. Private channels require an explicit grant even for school admins. Clients may read only their own access document. This record contains no email, address or other private profile fields.

Channel documents retain the existing schema. Channel creation/deletion, membership, readOnly, kind and other metadata are trusted administrator operations. Client-created cloud channels and automatic sample-channel/message seeding are intentionally disabled. Local fictional demo behavior is preserved. A future admin provisioning UI/backend is outside this change.

Members can create bounded messages only in granted channels. Author UID, verified display name and role must match the trusted access record. Admin alerts require an admin grant AND membership in admin-alerts; a normal teacher cannot impersonate an admin or bypass readOnly. Messages are immutable for all clients. Timestamps must be server timestamps; bodies are 1..4000 characters.

A message and its channel summary must be committed in the same batch. lastMessageId binds preview/sender/time to that new message using getAfter; replay, fabricated summaries and metadata edits are rejected. Cloud read queries use administrator-granted document IDs in groups of ten, and message queries are bounded to at most 100. Queries were tested against the actual rules, rather than assuming rules filter broad collection reads.

## Client and session behavior

FirestoreCommunicationRepository reads trusted access from the server for each operation, ignores profile school/name/role hints, sorts authorized channel query results locally and commits message/summary atomically. Preview builds do not send messages or write read markers.

CommunicationService clears shared state when the account/backend changes, when access loading fails, and after a rejected operation. Pending responses from an earlier account cannot repopulate the new account's view. This is not a general guarantee that a revocation remotely erases previously viewed/downloaded content; server access is enforced on future reads/writes. Real-time push revocation and cache-at-rest policy remain separate considerations.

## Data touched / secrets / Firebase impact

Only fictional local emulator records are used in tests. No student, parent or staff documents were read, exported, migrated or changed. No IAM, secrets, Functions, Auth configuration, dependencies or production deployment workflow changes. Existing /users/{uid}/** academic ownership and data schemas are unchanged; general academic field validation is outside this scoped communication fix.

The communication metadata additions are a trusted access collection and optional lastMessageId on channel documents. Existing message/history data is not rewritten. Old records created under permissive rules cannot be retroactively considered verified; operator review is required before treating legacy authors/admin labels as authoritative.

## Verification and attack outcomes

| Attack / acceptance | Prototype outcome |
|---|---|
| Unauthenticated public get/list | Denied |
| Other-school or unprovisioned/revoked member read/write | Denied |
| Granted channel-ID query / bounded ordered messages | Allowed |
| Broad or mixed-authority channel query / private channel | Denied |
| Self-create/promote/reactivate/reassign membership | Denied |
| Read another user's access/private academic data | Denied |
| Write admin role into own profile | Does not grant authority |
| Forge author UID/name/role, school/channel/message identity | Denied |
| Teacher admin alert / readOnly bypass | Denied |
| Trusted admin alert in granted channel | Allowed |
| Update/delete/hijack message or createdAt | Denied |
| Missing/extra fields, wrong types, oversized/empty text | Denied |
| Arbitrary metadata/ACL/create/delete channel | Denied |
| Fake/replayed summary, message without matching summary | Denied |
| Orphan message access after missing parent channel | Denied |
| Negative/huge channel counts or invalid enum | Immutable to clients; validated on summary updates |
| Counter replay or workflow state transition | No client counter/state-transition capability is granted |
| Old account async response after switch/sign-out | Suppressed by session-generation checks |

Tests: communication-rules.test.mjs (15 groups), communication_access_test.dart, communication_session_safety_test.dart, and actual Flutter Firebase repository acceptance in integration/communication_security_main.dart plus communication-repository-browser.mjs. The SDK acceptance uses local Auth and Firestore emulators, not mocked Firestore or production credentials.

## Required approvals and rollout

**Do not deploy this prototype blindly.** Unprovisioned users and old clients will lose shared Messages access after strict rules are enabled. That is intentional fail-closed behavior, but requires a coordinated rollout. Core academic ownership is preserved.

1. Review the policy and the new tests; confirm one-school-per-user, channel limits, immutable messages and administrator-managed cloud channels fit the product.
2. A human operator reviews existing channel/history integrity and approves the authoritative UID → school → role → channels mapping. Do not infer enrollment from email/domain/profile or automatically trust old admin labels.
3. Provision the reviewed access documents and ensure channel metadata meets the documented validators through an approved administrator process. Do not create real membership records autonomously.
4. Back up the active rules; reread the current production release and abort/review if it differs from the observed ruleset. Stage the complete new client plus Studio artifact and verify against a separate staging project with fictional accounts.
5. Obtain explicit approval for a coordinated rules + Hosting rollout. Apply strict rules first to close exposure; old clients will temporarily fail closed until refreshed. Existing Hosting-only publishing does not deploy Firestore rules. No production release is embedded in this PR.
6. Verify authorized/unauthorized access with operator-approved test accounts/channels, including personal-email teachers, private channels, admin alerts, revoked users and full reload. Record exact deployed ruleset and Hosting receipt.

Never roll back to permissive cross-school rules simply to restore convenience. Safer rollback is temporarily denying shared communication while retaining academic ownership, then resolving provisioning/client compatibility under review. No automatic rollback or record deletion is included.

## Safe to proceed / blocking issues

Safe to proceed with prototype code review and fictional emulator verification: yes.
Safe to broadly deploy/share: not yet. Blocking items are human approval of policy/provisioning, legacy-data integrity review, coordinated rollout, and production acceptance. This document does not certify legal/privacy compliance or exhaustive security.
