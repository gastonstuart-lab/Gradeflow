# InstructOS teacher experience review — 5 November 2026

## Verdict

The earlier candidate was not ready for comfortable daily teaching. It mixed several interface generations, made some unsupported readiness claims, hid the primary teaching action below the fold, and contained academic-data trust failures. This branch establishes one calmer visual foundation and fixes several concrete workflow defects. It is a **review candidate, not a production-readiness sign-off**. Account security, legacy save acknowledgement and cloud verification still block real-school rollout.

The important improvement is predictability: Home chooses the class; Classroom teaches from its real room map; Gradebook handles full score entry; Planner handles dates and reminders; class records/imports remain a labelled secondary destination. A teacher should not need to understand how the application was assembled.

## Scope and evidence

Stuart explicitly requested a whole-product evaluation and improvement of appearance, behavior, flow and teacher comfort, including launch and sign-in. Source review covered every routed screen family in `lib/nav.dart`, shared components, navigation, score calculation and the most relevant storage services. Browser review used isolated local demo data, normally at 1280 × 720; sign-in also checked at 390 × 844 and in dark mode. Automated checks cover larger text, missing marks, safe class opening, navigation and Messages at both viewport sizes.

No real roster, grades, standalone gradebook, credentials, messages or production configuration were changed. The demo is not Stuart's authoritative eight-class roster. Drive, Google authentication, Firebase saves, real staff messages and permanent deletion were not exercised. A page rendering correctly is not proof its external integration works.

## Findings and disposition

| Priority | Finding | Result / required follow-up |
| --- | --- | --- |
| Critical | Local registration does not accept a password; failed Firebase login falls through to an email-only local account lookup. | Confirmed in `AuthService.register/login`. Authentication mechanics were not changed by this visual review. Requires separately approved security work before real teacher accounts/data. |
| High | Opening an unscored class plan could create demo scores/exams; adding a student granted full marks. | Removed both implicit write paths. Synthetic repository tests prove opening the plan and adding a student leave marks/exams unentered. Explicit demo seeding remains confined to demo setup. Unrouted legacy GradebookScreen still contains old default-score helpers; do not reactivate it. |
| High | Missing category marks could count as 100, or partial category weights could produce a misleading complete GPA. | Missing/null/invalid scores now keep derived results incomplete; zero counts. Stored active weights must total 100. Calculation tests cover student isolation, mixed maxima, inactive items and category-total placeholders. No saved marks were rewritten. |
| High | Legacy FinalExamService can swallow persistence errors and update its cache before acknowledgement; ExamInputScreen can leave while background writes are unresolved. | Still a release blocker. Native gradebook has acknowledged writes and leave guards from PR #69. This branch does not imply legacy exam entry has that guarantee. Use a dedicated failure/retry test task before rollout. |
| High | Old `/dashboard` and seating links exposed obsolete interfaces. | `/dashboard` now redirects to current Planner, preserving query/date. Seating links redirect to the premium Classroom with its right-hand setup panel. Old dashboard code remains for historical compatibility/testing but is no longer the routed destination. |
| High | Messages channel list/conversation disappeared because expanded lists had unbounded card constraints; narrow view stacked unusable panels. | Bounded panel children, phone switch between channels/conversation, compact phone conversation heading. Desktop and phone regression tests verify visible messages and selectable channels with no layout exceptions. Sending/backend behavior unchanged. |
| Medium | Launch, sign-in, PWA icons and teaching pages belonged to different visual systems. | Shared navy/teal identity, neutral canvas, typography hierarchy, surfaces, inputs and buttons; HTML bootstrap and Flutter launch match; icons regenerated from code-native mark. Light is the default for new preferences, saved dark/light choices are retained. |
| Medium | Decorative blur, glowing borders, repeated frames and oversized headers competed with information. | Calm static backgrounds, opaque shared cards, restrained borders; no continuously moving workspace surfaces. Removed glowing grading-category outlines and redundant support headings/roadmap prose. |
| Medium | Home hid Open Classroom at laptop height; class selector had white-on-white text after a theme change; calendar dates did nothing. | Removed redundant Day plan strip, compacted hero, fixed selector fill/contrast, made dates open the selected Planner day. Confirmed in browser. |
| Medium | Class hub showed hardcoded engagement, fixed lesson times and fictional live activity. | Replaced with actual class metadata/count and eight direct task destinations. No fabricated class-health percentages or activity feed. |
| Medium | Home Messages preview was invented conversation UI. | Uses CommunicationService records and navigation; no fake chat/search controls. External IED Studio/Science links retained and labelled as external resources. |
| Medium | Some copy described the build instead of helping a teacher. | Revised export/student/category instructions, removed Admin development roadmap, replaced unverified Knowledge Hub security badge with “Review before import”. More secondary wording can still be shortened. |
| Medium | Results/exports and native gradebook deliberately honor different policy boundaries for pre-existing custom categories. | Existing weights are never silently overwritten. New default categories use confirmed 20/30/20/30 in Participation/Homework/Classwork/Quiz order. Native final grade stays blank if stored policy differs until the teacher explicitly reviews/applies it. Legacy advanced aggregation needs a separate policy-parity review; do not assume all historic classes use this policy. |
| Medium | First-use CJK fallback can briefly show missing glyphs while browser fonts load. | Names render after fonts arrive in this review. Offline/slow-network font packaging still needs validation before classroom deployment. |

## Page-by-page assessment

“Browser” means rendered/reviewed with local demo data, not every destructive action or remote service tested.

| Screen / route family | Coverage | Assessment |
| --- | --- | --- |
| HTML launch, Flutter launch, `/` sign-in | Browser + phone/dark + widget/text-scale tests | Matching identity; password visibility and empty-email feedback work. Real login/account recovery/security remain separate gates. |
| `/os/home` | Browser + binding tests | Classroom is the clear primary action; selected class remains readable; calendar dates work; shortcuts describe their destination. Long lower content scrolls. |
| `/os/planner` | Browser + selected-date tests | Calendar/reminders/timetable use the shared look. Empty timetable is honest. Upload/Drive imports not remotely verified. |
| `/dashboard` | Before browser + redirect regression test; final browser check | Retired as an old entry point; resolves to current Planner instead of old purple sidebar dashboard. |
| `/os/classes` | Browser + dock tests | Direct teaching/grading choices. Records/import management remains a labelled secondary control. |
| `/classes` records management | Browser | Shared palette/cards. Still more wordy and spacious than a high-density record manager should be; archive/import/rollover need their own acceptance scenario. |
| `/os/class/:id` | Browser + safety test | Actual context and direct Classroom, Gradebook, Students, Class plan, Exams, Results, Export and Grading settings tools. |
| `.../classroom` | Browser + map interaction tests | Premium wooden tables/teal seats retained; student picks highlight actual seats; right tools open/close; full gradebook link works. |
| `.../seating` | Browser redirect | Opens that same premium Classroom in setup mode. No separate old seating screen. Furniture geometry/IDs preserved. |
| `.../gradebook` | Browser + existing repository/leave-guard tests | Full-page score workflow; zero/missing distinction, acknowledged status, paste/undo/backup/Excel. Wide tables require horizontal/vertical scrolling; laptop toolbar density merits a later compact option. |
| `.../students` | Browser + synthetic add-student test | Reduced duplicate context, more compact bilingual rows, search/sort retained, safe empty-name avatar. No automatic full marks on add. |
| `.../student/:id` | Browser + shared calculation tests | Readable summary and breakdown. Still repeats identity/context and could show more useful grade rows above the fold. |
| `.../schedule` | Browser + no-seeding test | Uses stored schedule and notes. Existing schedule management dialog retained. No demo academic marks created by opening it. |
| `.../categories` | Browser + default-policy preservation test | Plain shared cards and labelled edit/delete controls. Existing custom policy preserved; equalize action is not a substitute for confirmed subject policy. |
| `.../exams` | Browser + source audit | Renders consistently, but legacy autosave reliability is not approved. “500 ms” is an implementation detail that should be replaced as part of that save-state work. |
| `.../results` | Browser + calculation tests | Incomplete marks cannot silently become complete GPA. Older repeated context bands still consume space. |
| `.../export` | Browser + source review | Scope/format/preview are explicit. Native Gradebook Excel and legacy report exports are separate workflows; audit their parity with synthetic fixtures before real reporting. |
| Student/class recycle bins | Browser empty states | Recovery destinations render consistently. No deletions/purges performed; restore/purge with real data remains unverified. |
| `/communication` | Browser + desktop/phone layout regression tests | Channel lists and conversation are now usable. No messages sent. Role/access controls need their own security review. |
| `/admin` | Browser | Shared cards, simpler header/actions, duplicate counters and product-roadmap panel removed. Post-alert and recovery behavior not changed. |
| `/os/inbox` Knowledge Hub | Browser + existing layout/import tests | Clear preview-before-confirm approach. Shared-folder feature stays explicitly “Coming soon”. No real file uploaded or connected permissions changed. |
| `/whiteboard` | Browser drawing + return | Canvas accepts a stroke and Back returns Home. Focused board intentionally has no dock competing with drawing. |
| `/os/teach` | Browser empty-class state + existing tests | Projection is intentionally dark; requires a selected class. Public/private projection behavior needs a supervised classroom acceptance test. |
| Home Attention / Assistant / More tools | Source + existing tests; Messages preview corrected | Weather is a real service, not invented state. Audio/voice placeholders are labelled; these remain secondary and need separate feature-completeness checks. |
| External IED/Science destinations | Source only | Actual external resources, not redesigned or tested as part of this app. |

## Design contract for subsequent work

- Navy identifies the workspace; teal identifies actions and selection. Status colors retain their meaning.
- Shared theme, brand mark, calm canvas and opaque cards apply to entry, teaching and support pages. A different task can have a different layout without introducing another design system.
- Classroom keeps its wooden furniture and teal seats. Tools slide from the right. Picks highlight the actual map. Do not reintroduce the bottom tool tray or old picker.
- One primary task per page; no duplicate readiness/context bands, fictional activity, or roadmap/debug copy in the teacher's workflow.
- Missing scores remain missing. Saved means acknowledged storage. Imported weights and student matching require explicit review.
- Canonical routes are Home, Planner, Classes, Classroom and Native Gradebook. Old entry points redirect to them instead of mounting a second app shell.

## Verification

- `dart analyze lib test`: no issues.
- `flutter test --reporter compact`: all **143 tests passed** after the final changes. An earlier run exposed a stale Knowledge Hub badge-copy expectation; it was corrected and the entire suite rerun successfully.
- `flutter build web --release --no-wasm-dry-run --output build/cohesion-review`: passed, 97.4 seconds.
- `git diff --check`: passed.
- Browser: synthetic demo score changed 89 → 0, Saved acknowledged, page reloaded with 0 intact, restored to 89. No real score was used.
- Browser: Excel export downloaded successfully; generated XLSX ZIP validated, with `All Classes` and `Assessments` sheets (16 and 121 rows respectively, including headers, for the synthetic demo fixture).
- Final browser checks confirmed the old dashboard redirects to Planner, Messages displays actual demo channels/conversation, and simplified Admin renders correctly.

Screenshots in `before/` and `after/` are actual browser captures with synthetic demo students. They are review evidence, not designs or proof of remote-service correctness.

## Release decision

Hold production rollout. Accept this as a cohesive review candidate only after Stuart's visual review. Next work should prioritize (1) approved auth/local-account security work, (2) acknowledged legacy exam saves/retry/navigation, (3) policy/export parity with synthetic fixtures, then (4) supervised cloud/offline/import tests and smaller secondary-layout refinements. Do not migrate Stuart's standalone gradebook or merge this stack without explicit approval.
