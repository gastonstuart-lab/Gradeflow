# InstructOS release control — 2026-11-28

## Authority
The live application is https://gradeflow-20260113.web.app/os/home.
Reported deployed source: 11c214ed090aa4fcfbb1bb4131779ce3b1a5c190 (PR #178 head).
Live manifest commit/tree/build run and seven public endpoint SHA-256 checks PASSED (PR #189, run 46109136380). Historical immutable artifact unavailable; original package cannot be independently re-attested. Current served bytes agree with public manifest and pinned source identifiers.
Do not merge divergent main or legacy UI work into this branch wholesale.
Preserve approved Home, Planner V2, Teaching Studio, native gradebook, seating, dock, mobile layout and all existing teacher data.

## Release 1: classroom experience
- Native timer: PR #186 merged to integration at 93145a30c7fd34a4eabb4ea4435320645db83aec; focused analyzer and widget test passed (run 46108265339). Browser/Surface visual acceptance and sound verification pending.
- Screensaver: PR #187; full application analyzer, focused tests and main.dart preview compilation passed (run 46108957602); wider appearance check pending. Themes: aurora, space, ocean, sunset, minimal, grid; clock/date/message, speed, delay, fullscreen; never interrupt teaching.
- Teaching card: PR #188; focused schedule tests passed (run 46109058282), full main.dart preview compilation passed (run 46109058236); wider appearance check pending. Automatically current/next scheduled lesson, time remaining, quick tools, no Home redesign.

## Subsequent workstreams
- Teaching tools: PDF pen colour/thickness and eraser; collapsible/pinnable left whiteboard toolbar; free image/GIF/sticker search and insertion (verify license and safe search).
- Assessment: preserve and evaluate PRs #180–185; integrate compatible work into native_gradebook_screen.dart, NOT legacy gradebook_screen.dart. Archive pre-midterm results, new editable 2 quiz/6 classwork/6 homework/6 participation defaults. Seat behaviour deduction of 10 per event, starting at 100 per lesson, with undo; talking after warning, eating, sleeping, out of seat without permission, not completing work, late to class, late from break, more than one toilet break, other homework, bad language.

## Release gates
1. Confirm exact live source, rollback identifier and complete app route/shell parity.
2. Build lib/main.dart with authorized preview mode, not standalone classroom entrypoints. Existing Firebase preview has local synthetic login and read-only repository; audit other write paths before hosting or use isolated staging/emulators.
3. Run focused tests and full regression suites on the same integrated candidate. Build the full web bundle. No database/rules/functions/live hosting deployment from preview jobs.
4. Verify actual browser preview, navigation, native gradebook, Planner, classroom, teaching tools and mobile layout before owner review.
5. Publish production only with explicit owner approval and verified rollback path.

## Responsibilities
GitHub is source of truth. GitHub Actions runs routine tests. Work handles bounded complex implementations and real browser verification; avoid repeated broad audits and waiting for CI on agent credits. ChatGPT reviews results, maintains this ledger and coordinates next actions. Report completed code, tested, deployed and verified separately. Do not describe a draft PR as shipped. Never request secrets in chat.

## Packaging correction
The initial preview build artifact contained the Flutter web build but did not explicitly bundle Teaching Studio. `scripts/package-classroom-preview.sh` preserves the proven Studio build process and creates a full source/hash manifest. It must be invoked by the final combined workflow before preview publication; this script itself does not deploy anything.
