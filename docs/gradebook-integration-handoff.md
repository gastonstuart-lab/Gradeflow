> Newer review checkpoint: `feat/instructos-cohesive-teacher-experience-20261105` continues this stack. Read [the teacher experience audit](experience-review/teacher-experience-audit.md) and [continuation notes](experience-review/continuation.md). The PR #69 checkpoint below remains historical evidence.

# Continue this work from GitHub or a new chat

## Current checkpoint
- Repository: https://github.com/gastonstuart-lab/Gradeflow
- Draft PR: https://github.com/gastonstuart-lab/Gradeflow/pull/69
- Branch: feat/instructos-gradebook-20261105
- Base dependency: draft PR #68, feat/approved-teacher-home-integration-20261029. Neither PR is merged. Do not merge/deploy automatically.
- Implementation checkpoint: ff09657. Read the latest branch tip for this handoff and any final build result.
- Current report: docs/gradebook-design-correction-20261105.md. Earlier report and design-hold record are historical evidence of the rejected hybrid.

## Stuart's direction
Integrate gradebook into the newer InstructOS Home/Classroom experience. Do not mix in old screens as primary destinations. Right tools panel must slide in/out; no bottom Class tools tray. Picking students/tables must highlight them directly on the map. Preserve existing real room layouts/identities. Keep primary navigation coherent and working.

## Implemented
Native gradebook with acknowledged writes, missing-score handling, explicit 40/60 and 20/30/30/20 policy, assessment/paste/undo, Excel export and explicit standalone backup import. Corrected Classroom right panel, on-map picks, readable teal seats, shared presentation materials and compact room controls. Cleaner Planner using existing persistence. New /os/classes chooser; OS Home/dock/launcher class navigation points there. Physical dock space reserved; dock onTap supports semantic activation instead of pointer-up-only activation. Existing class-record/import management remains separate through the class chooser's labelled settings control.

## Verification checkpoint
- 55 relevant tests passed; 12 final Classroom/OS surface checks repeated successfully.
- Dedicated dock accessibility activation test passed (Home, Planner, Classes).
- Targeted analysis: no issues.
- Final release build including the class-record-management header control passed (68.1 seconds). Targeted analysis also passed.
- Browser: right panel, map selection, class chooser, Planner, Home, quiz seat entry -> full gradebook checked. Demo reminder survived reload. Classroom dark theme and 700px room editor checked. Actual screenshots committed under docs/gradebook-integration/20261105-correction/.

## Next steps
1. Open/rebuild the saved candidate from this branch; the final local release build passed.
2. Visually review the corrected candidate with Stuart before removing the review hold. This is an improvement candidate, not a claim that every legacy screen now matches.
3. Continue the design acceptance pass for remaining specialized Home/student/results/admin destinations. Do not blindly reuse old screens or copy fictional preview state.
4. Verify cloud save/history/import behavior and rules compatibility in an authorized test environment before merge or real-data transfer. Legacy issue #62 remains outside the bounded workspace fix.
5. Keep academic imports explicit. Exact IDs are required; no guessed student matching. Native backup JSON is archival; import currently accepts standalone format. Import is sequential, not transactional.

## Local environment
Workspace: C:/Users/Stuart/Documents/Codex/2026-11-05/referenced-chatgpt-conversation-this-is-an/work/instructos-gradebook
Flutter: C:/Users/Stuart/flutter/bin/flutter.bat
Release output: build/gradebook-review
Latest build log: ../design-correction-build-final.log
Review URL: http://127.0.0.1:8790/os/class/demo-class-1/classroom
Local preview helper: ../serve_gradebook_review.py; blocks Firebase and service workers on purpose, uses synthetic local demo data. It may need restarting in a later session. Do not treat its expected Firebase console errors as production evidence.

## Data boundary
Stuart's real standalone gradebook at https://stuart-gradebook-2026-fall.earthykid33.chatgpt.site remains authoritative for today's entered marks and has not been changed by this integration. No real student records have been seeded, migrated or edited here. Do not overwrite it or import real data automatically. No grades or unconfirmed weights should be invented.

## Suggested opening message for the next chat
Continue GradeFlow PR #69 on branch feat/instructos-gradebook-20261105. Read docs/gradebook-integration-handoff.md and docs/gradebook-design-correction-20261105.md first. Preserve the newer design and real records. Check the final build, then continue visual and navigation review; do not merge or deploy.
