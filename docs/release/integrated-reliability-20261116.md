# Integrated GradeFlow reliability candidate — 16 November 2026

Stuart requested implementation following the full current-build audit. This candidate combines the published PDF pen package (`8e27356`) with the tested class/import/room recovery candidate (`0e65d1c`) without merging the old default application source.

## Scope

- Preserve the published Classroom, Planner, Home and Teaching Studio design and independent PDF handwriting/eraser adapter.
- Include the existing destination-safe roster imports, durable class creation, partial grading-setup retry, semester-aware duplicate protection and best-effort room rollback from PRs #137/#140/#141/#143.
- Make legacy Results, student detail and both single/all-class export calculations use the persisted class coursework split. Remove misleading fixed 40/60 report labels; show saved percentages in Results and Exams.
- Clear batch exam marks with an explicit persisted null, matching Firestore's additive upsert contract. Keep zero distinct from missing and preserve other pupils.
- Enable existing test-only CI on this isolated candidate. No production workflow, auth, Firebase rules, dependency, schema or school record changes.

## Release truth

Default `main` control SHA is `ebd61ad`. Production run 43831120846 backed up Hosting to `before-studio-43831120846`, deployed successfully and then failed the PDF viewer HTML comparison. Public Studio HTML/viewer/pen-JS/CSS sampled in this audit subsequently matched reconstructed `8e27356` package files. Do not describe the red run as green or assume it never deployed.

This is a review candidate, not an automatic production release. The canonical deployable package contains BOTH Flutter `build/web` and `/teaching-studio/`. An ordinary build of old main is not the current application.

## Acceptance

Regression tests cover persisted custom 70/30 grades matching Gradebook, CSV/XLSX and student report text, invalid/boundary weights, and clearing/reopening against an additive exam repository. Existing import, room, class recovery and all twelve Studio browser regressions remain required. The authenticated browser gate uses fictional Auth/Firestore emulators only.

Exact check results are recorded in the PR after execution. Original corrected timetable files, Google OAuth/Drive, real Surface input and production rules remain outside automated certification.

## Follow-up boundaries

- Production communication-rule membership/author/admin checks require an explicit security implementation and deployed-rules review before shared use. No live database access is part of this candidate.
- Dependencies need targeted advisory triage; no forced upgrades.
- Room compensation is not a transaction; concurrent-device import uniqueness and checkpointed rollover remain separate work.
- Other legacy update/archive/delete paths can still swallow failures; this candidate does not claim every save path is fixed.
- Studio still requires explicit file downloads; crash recovery is separate.

## Review and rollback

Review the joined fictional teacher journey and partial-failure messages. No source merge implies deployment. Production publishing remains a separate protected action; preserve the known backup. Revert this candidate before release if rejected, without clearing browser data or changing school records.
