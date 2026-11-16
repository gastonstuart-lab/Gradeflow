# Shared Messages containment — review before production

The active default Firestore rules allow cross-school communication access. The full replacement in PR #148 passed its rule, real-client and application checks, but reviewed memberships and channel/history integrity remain prerequisites for broad activation.

This smaller containment patch temporarily denies all client access to schools/*/communicationChannels/**. Existing /users/{uid}/** ownership is unchanged: classes, students, grading categories, scores, exams, seating and private read markers retain the same owner-only permissions. No documents are deleted or migrated. Containment blocks future server access; it does not erase data already viewed, cached or downloaded. This is not a fix for every possible academic schema-validation issue.

## Availability decision

Shared Messages will be unavailable to clients, including callers with an admin claim. Confirm whether staff depend on it and accept the interruption before publishing. Nothing is deployed by merging this PR: its workflow is an emulator-only check, not a production deployment.

The existing Hosting release remains pinned to application commit 31a1a3e. Merging this main-based rules patch does not publish PR #148's prototype client or alter Hosting.

## Before a human publishes

1. Review this exact patch and confirm the Messages availability tradeoff.
2. Save the current production rules/configuration. The last read-only verification found ruleset projects/gradeflow-20260113/rulesets/7d55cd76-bd85-4805-88e4-e96d031aac31, raw SHA-256 1c258cf9874e4beccc93fc5b3d62aa03530a2afd766d1d06dc3cfaa6810fa4ce. If it has changed, stop and review the newer policy before replacing it.
3. After explicit approval and merge, a human operator publishes the reviewed firestore.rules to ONLY gradeflow-20260113's default Firestore database using the Firebase Console or the dedicated config and --only firestore:rules. Do not deploy firebase.json broadly or publish Functions/Hosting/Auth changes as part of containment.
4. Read the new active rule release back and compare its source. Do not inspect live student or staff records to test access. Use emulator evidence and operator-approved fictional acceptance channels if any online acceptance is needed.
5. Record the new release/ruleset and source hash. Preserve this safe containment policy as the fallback for the later prototype rollout; do not automatically restore permissive cross-school rules.

## Next rollout stage

Keep PR #148 draft pending review of trusted UID → school/role/channel grants and existing communication history. Provision only explicitly approved memberships through an authorized administrator process. Stage the new client and strict rules with fictional accounts before a coordinated release. Do not infer grants from email/profile names or treat old admin labels as verified.

## Verification

The dedicated test compiles these exact rules in a loopback-only demo Firestore emulator. It tests deny behavior for anonymous users, two teachers and forged admin claims; direct reads/queries/creates/updates/deletes; profile/self-grant bypass; and preserved academic owner CRUD with cross-user denial. No production data is accessed, no new app dependencies are introduced, and no deployment job is present.
