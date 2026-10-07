# Teaching journey interaction preview

Stuart requested a visible Today → Start Class → Classroom journey on 7 October 2026, following review of the working-context branch. This Amber UI experiment implements that authorized scope with fictional data.

## Run

`flutter run -d chrome -t lib/teaching_preview.dart`

Release: `flutter build web --release --no-wasm-dry-run --target lib/teaching_preview.dart --output build/teaching-preview`

Serve that output with a local HTTP server. This is a separate entry point: normal main.dart, authentication, routes and deployment remain unchanged. No Firebase or repository services are imported by the preview.

## Review the journey

1. Today gives one next-class action and an example continuation prompt.
2. Start class opens a fictional twelve-student seating map.
3. Homework check changes the same tiles. Selecting a student exposes explicit Done, Missing, Absent and Unchecked actions for one named example assignment.
4. A contextual private panel retains notes and follow-up flags by synthetic student ID.
5. A timer continues while its panel is closed. Finishing pauses it.
6. Finish collects a continuation draft and returns to Today with the session summary. Reopening retains the same lesson; it does not create a new session.

All state is in memory and disappears on refresh. The persistent banner and action panels state this limitation. No save acknowledgement, cloud recovery, real timetable inference, academic score change or public display is implied.

## Deliberately deferred

Participation controls await the unresolved policy decision from proposal #65. This preview does not select a grading or tally policy. Separate-screen projection, resources integration, durable notes/homework/session adapters, class switching and actual roster/seating integration remain separate work. Use the existing GradeFlow machinery when implementing those approved integrations; this fixture is not a replacement backend.

## Acceptance and validation

The interaction tests cover homework/note/continuation retention through Finish and reopen, plus timer-panel continuity and 390px layout. Review the visual hierarchy and tap flow on Surface Pro before integrating into the app shell. It is a teacher workspace, not a public classroom display.

Rollback: remove the standalone entry point, its tests and this document. No data migration or production rollback is necessary.
