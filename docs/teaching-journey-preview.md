# Teaching journey interaction preview

Stuart requested a visible Today → Start Class → Classroom journey on 7 October 2026, following review of the working-context branch. This Amber UI experiment implements that authorized scope with fictional data.

## Run

`flutter run -d chrome -t lib/teaching_preview.dart`

Release: `flutter build web --release --no-wasm-dry-run --target lib/teaching_preview.dart --output build/teaching-preview`

Serve that output with a local HTTP server. This is a separate entry point: normal main.dart, authentication, routes and deployment remain unchanged. No Firebase or repository services are imported by the preview.

An optional `--dart-define=SCHOOL_ATTENDANCE_URL=<school attendance URL>` enables a School attendance shortcut in the classroom toolbar. It opens a new browser tab through the existing url_launcher dependency. The teacher completes attendance in the school's signed-in browser session; this preview does not read, submit or synchronize attendance. The personal school URL is supplied to the local build rather than committed to source. Today also provides Enter quiz scores as a direct entry to the roster.

## Review the journey

1. Today gives one next-class action and an example continuation prompt.
2. Start class opens six numbered tables with circular seats, adapted from the standalone Classroom.html interaction. Twelve fictional students occupy twenty available seats. Seats lock during teaching. Arrange seats supports dragging or selecting a student and then a destination; occupied destinations swap students.
3. Homework check changes the same seats. Done is available directly below each student. Selecting a student exposes explicit Done, Missing, Absent and Unchecked actions for one named example assignment.
4. A contextual private panel retains notes and follow-up flags by synthetic student ID.
5. A timer continues while its panel is closed. Fullscreen timer fills the app viewport with a countdown ring, pause/reset and return controls, hiding the classroom and private panels. Finishing pauses it.
6. Finish collects a continuation draft and returns to Today with the session summary. Reopening retains the same lesson; it does not create a new session.
7. Quiz scores opens a roster beside the tables. Enter advances focus; selecting a student from a seat opens single-student entry. Two fictional assessments demonstrate independent marks, and New demo quiz creates an in-memory GradeItem with a name and positive maximum. The current assessment's entered count appears in Finish.
8. Pick student and Pick table animate highlights across seated students or occupied tables, slowing before a randomly chosen result. Each candidate has an equal chance; animation is decorative. Stop chooser and Today cancel pending selection. Reduced-motion settings produce an immediate result. Homework absence is not treated as official attendance. Example student numbers 01–12 remain attached to student identity when seats move; actual school seat numbers are not connected yet.
9. Room setup opens a cancellable layout draft with 3–10 four-seat tables and 1–3 tables across. A miniature layout updates immediately. Applying distributes all twelve fictional students across the new tables; every fourth seat is visible, and smaller screens reduce columns to fit. Student identity, numbers, notes, homework and quiz state remain intact. Arrange seats allows subsequent individual moves. This is a first table-layout builder, not arbitrary desk positioning or roster import.
10. The teacher desktop combines the existing class card with a month calendar, day plan, session-only reminders and tool shortcuts. Selecting a date changes the example day plan: weekdays show the same fictional schedule, weekends show no demo lessons. Month navigation and Back to today work; no real timetable or Google Calendar connection is implied. Added reminders and completion state survive moving to the classroom and back, but refresh clears them. Start opens a tool menu; Home and Classroom remain in the bottom dock. A short fade between desktop and classroom respects reduced-motion settings. Focus timer hides the dock in its fullscreen view.
11. A live 24-hour clock sits in the shared header and timer focus view. It reads the device's local time every second rather than incrementing a counter; the wider header includes the date. Updates are isolated from the lesson state and are not a screen-reader live region. Clock timers stop when their widgets leave the screen.

Quiz percentages call the existing CalculationService using an explicit StudentScore and GradeItem. Blank and invalid draft values remain unentered and are not passed as missing score rows, avoiding the engine's missing-row full-mark default without altering that academic policy. Zero is explicitly entered. This is single-assessment normalization, not an integrated weighted/final-grade report. No StudentScoreService, repository, save acknowledgement or academic write is invoked. Creating an assessment here does not create one in the school account.

All state is in memory and disappears on refresh. The persistent banner and action panels state this limitation. No save acknowledgement, cloud recovery, real timetable inference, academic score change or public display is implied.

## Deliberately deferred

Participation controls await the unresolved policy decision from proposal #65. This preview does not select a grading or tally policy. Separate-screen projection, resources integration, durable notes/homework/session adapters, class switching and actual roster/seating integration remain separate work. Use the existing GradeFlow machinery when implementing those approved integrations; this fixture is not a replacement backend.

## Acceptance and validation

The interaction tests cover homework/note/continuation retention through Finish and reopen, idempotent direct Done, student-note/status ownership after dragging to an occupied seat, plus timer-panel continuity and 390px layout. Review the visual hierarchy and tap flow on Surface Pro before integrating into the app shell. It is a teacher workspace, not a public classroom display.

The reference HTML remains untouched. Only its table/seat geometry and interaction logic informed this change; no browser storage or school data was read or migrated. This is an adaptation of those interactions, not the complete original application. Free positioning and different desk types, real calendar/timetable integration, live weather and configurable external shortcuts remain future work.

Thirteen tests cover clock rereading across midnight and disposal, desktop calendar/reminder continuity and narrow Start-menu flow, lesson/seating flow, cancellable room drafts and identity/record preservation after applying a smaller layout, chooser completion/cancellation, fullscreen timer state and narrow layout, quiz normalization, blank/invalid/zero semantics, assessment isolation, immediate entry after creating an assessment, keyboard advance and marks retained through panel closure and Finish. Score-write reliability remains the independent prerequisite tracked in issue #62 before real records can be connected.

Rollback: remove the standalone entry point, its tests and this document. No data migration or production rollback is necessary.

## Room-first secondary layer revision

Class tools now opens as a compact bottom workspace rather than a left or right drawer. It is laid out outside the classroom viewport so it does not paint over seats; the room content keeps its original seating geometry and width-driven table sizing. Student/private details remain the only right-side secondary layer. Opening a student closes Class tools, and opening Class tools closes the student/private layer, so only one secondary layer is active at a time.

The classroom furniture has been restyled from bright per-table colours and circular button-like seats to restrained neutral table surfaces and compact chair markers with names and student numbers. Original table/seat placement and student identity remain unchanged.

Presentation mode now reduces header/footer chrome and outer padding so the classroom receives substantially more of the viewport. Light/dark controls remain visible in presentation, and the Class tools bottom workspace uses theme-aware text, surfaces and borders.

Focused layer tests were updated for bottom tools, right-side student details, exclusivity, dark mode and the expanded presentation canvas. This revision was written through GitHub without a runnable Flutter workspace in this chat, and this repository reported no workflow runs for the new head commit. A local Flutter test/build pass and Surface visual review are still required before approval. Keep this PR in draft; do not merge or deploy.
