# Minimal classroom controls and display contracts

Status: reviewable proposal, 6 October 2026. Documentation only for #64. Stuart approved continuing the build sequence; he has not yet selected the participation policy, display transport or additive storage contract below. Recommendations are not implemented policy.

## Teacher workflow

Start Class opens the selected class's actual seating map. Selecting a student opens an action panel over that map. Closing a panel restores the same map position and selection. Homework Check temporarily changes the student tiles; entering or leaving it retains class, assignment and lesson context. The teacher's private workspace and student-visible classroom display share lesson identity, but contain different information.

Homework Check has one persistent mode switch, not a page change. The teacher chooses the assignment once. Selecting the same tile's Done action is idempotent; it does not cycle through unrelated states. Missing and Absent are separate deliberate actions. Unchecked is the initial state and can be restored explicitly. Exiting the mode preserves results and returns to the map. No submission is inferred from a numeric grade.

This is the proposed interaction to validate with Stuart, not a claim that the supplied prototype implements homework checks.

## Existing machinery and evidence

| Existing source | Contract to preserve / limit |
| --- | --- |
| [CalculationService](../lib/services/calculation_service.dart) | Missing score row contributes full marks; explicit null is excluded; scores normalize by item maxScore; final grade is 40% process / 60% exam. Homework status must not reinterpret these values. |
| [StudentScoreService](../lib/services/student_score_service.dart) | Uses a serialized queue, but catches score/history errors. updateScore completion and flushPendingWrites are not success acknowledgements. |
| [LocalRepository](../lib/repositories/local_repository.dart) | Academic score keys use class/item IDs; legacy global fallbacks remain. SharedPreferences caches a proposed value before its platform write; false platform results are not currently handled. |
| [FirestoreRepository](../lib/repositories/firestore_repository.dart) | Academic scores and history use separate writes. Current code is not proof of atomic score/history completion or deployed access rules. |
| [RepositoryFactory](../lib/repositories/repository_factory.dart) | Existing academic backend selection does not mean new classroom records already support local/cloud parity. |
| [ClassNoteService](../lib/services/class_note_service.dart) | Class-level notes are not a student-note ownership contract. Preserve existing class-note storage. |
| Supplied Classroom.html | Source-only evidence: spatial student selection, local notes, dated lesson memory and same-page Present mode. Notes keyed by display name must not become the new identity contract. No live browser storage inspected or prototype data migrated. |

[Academic characterization PR #63](https://github.com/gastonstuart-lab/Gradeflow/pull/63) contains synthetic tests for the first five boundaries. [Issue #62](https://github.com/gastonstuart-lab/Gradeflow/issues/62) tracks the reliable action-result proposal. Its implementation remains separately scoped.

## Decisions that remain open

| Decision | Recommended first version | What must be confirmed |
| --- | --- | --- |
| Participation | Each +/− records a ±1 lesson event; tally begins at 0, signed count has no artificial grade bounds. No automatic academic grade change. | Stuart's choice between a lesson tally and editing an existing participation grade. The latter requires exact item, delta, start, bounds and null handling. |
| Student-visible feedback | Show the selected student's intentional participation feedback; use signed text plus a visual cue, not color alone. No persistent public ranking. | Exact presentation and whether to show current lesson tally. |
| Physical display | Separate local browser window for an extended monitor, controlled from the private teacher workspace. | Extended, mirrored or separate-device setup. Mirroring duplicates pixels and cannot by itself give private controls and different public content. |
| New record storage | First reviewed adapter is explicitly local-only and teacher-scoped; do not promise sync. Keep a separate approved cloud-parity packet. | Whether local-only recovery meets Stuart's teaching setup. No backend silently chosen or implemented here. |
| Notes/reminders | Stable student ownership; reuse existing reminder integration only if it can preserve that ownership. | Minimal follow-up fields and approved adapter; no generic task engine. |

The two participation/display questions have been sent to Stuart. Dependent implementation must use his answers. This proposal deliberately leaves numerical academic effects unresolved.

## Stable identity and additive records

These are proposed fields, not new production models or a migration. All records carry schemaVersion, teacherId, classId, stable record ID, createdAt and updatedAt. Teacher/class/student ownership is validated at the action boundary; a seat, display name or array index never identifies a student record.

| Proposed record | Additional identity/data | Initial lifetime |
| --- | --- | --- |
| HomeworkAssignment | assignmentId, teacher-entered title; optional explicitly linked gradeItemId | Class-scoped; select explicitly, never create implicitly on mode entry. Grade linkage has no automatic score effect. |
| HomeworkCheck | assignmentId, studentId, status (unchecked/done/missing/absent), operationId, revision | One logical check per teacher/class/assignment/student. No row is displayed as Unchecked; an explicit Unchecked record is a deliberate reset. |
| ParticipationEvent | sessionId, studentId, operationId, delta (+1/−1 only if tally proposal is approved), sequence | Append event for each intentional action; derive lesson tally. Undo refers to the original event rather than resetting an academic grade. |
| StudentNote | noteId, studentId, text; optional reminderId | Follows student across seat moves and renames. Private. Deletion and cross-class transfer rules need separate review if requested. |
| LessonSession | sessionId, startedAt, assignmentId if selected, finishOperationId, finishedAt if complete, continuationText | One active session per teacher/class. Finish retry uses the same session/operation; no second completion on double tap. |

Existing academic entities and field meanings remain unchanged. Do not encode Done as 100, Missing as 0, Absent as null or Unchecked as an absent score row. A future explicit conversion policy would be a separate grade-policy decision.

OperationId identifies an attempted logical mutation. Transport retries reuse it. A new deliberate tap gets a new ID. Proposed adapters reject mismatched identity and older revisions; concurrency conflict behavior must be implemented and tested before multi-device claims. Storage key/path encoding must avoid delimiter collisions rather than concatenate unchecked IDs.

## Action result and recovery

An action owns its draft until persistence acknowledgement. The map can show immediate pending feedback, but must not label it Saved just because the queue drained. Recommended internal outcomes are Saved, Pending, Failed and Partial; user-facing wording should be simple: Saving, Saved, Could not save — Retry, or Score saved; history needs retry.

Saved identifies operationId, owner/class/student, resulting revision and the actual acknowledged backend. Local-only Saved means the local adapter acknowledged the record; it is not a cloud backup or a cross-device promise. Cloud acknowledgement/offline behavior must be defined and tested separately. A read from the optimistic preferences cache is not proof of persistence.

Failed keeps the intended action and last confirmed value available. Retry keeps operationId and does not repeat a participation delta or append duplicate history. Partial identifies which boundary completed. An old account/class's completion cannot update the current workspace. No action sends messages.

Proposed implementation sequence for #62: add an explicit result boundary to the smallest reviewed score/repository operations, preserve compatibility of existing consumers, and route new classroom consumers through that boundary. Handle both thrown failures and false local platform acknowledgements. Address cache reconciliation and score/history partial completion explicitly. Do not wrap the current swallowed-error Future and call it reliable. Repository scope, cloud result semantics and security review must be approved before implementing that seam.

## Start, tools and Finish

Start validates the selected class and roster/layout before enabling student actions. While loading or switching identities, old student actions disappear. If the class is archived/unavailable, retain honest context with a return path and no actionable stale roster. Shared StudentService load races require their own bounded review if shell guards cannot enforce this.

Timer state belongs to the lesson, not its temporary panel. Closing or switching a tool does not reset it. Resource panels reuse existing class links; missing resources and sign-in errors leave the classroom context intact. No new shared library or permissions work is implied.

Finish waits for the session's tracked action results, not only StudentScoreService.flushPendingWrites. Pending/failed actions remain visible with retry; private note drafts are not discarded. The teacher can return to teaching without losing the session. A completion record is acknowledged before marking the session finished. Repeated Finish uses the same finishOperationId. After recovery, restore confirmed outcomes and pending intentions; never replay participation taps as fresh actions.

Do not promise an atomic save across homework, participation, notes, score history and session completion. The proposed coordinator records each outcome and prevents misleading completion. Final timer pause/reset behavior and continuation-note composition belong to the Finish UI review.

## Public classroom display

Create the public payload from an explicit allowlist. Never send private records and hide their fields with CSS. Teacher controls choose which content is public. Default to a neutral display until a validated session/content selection is available.

| Allowlisted proposed payload | Excluded from transport |
| --- | --- |
| protocolVersion, displaySessionToken, sessionId, classId, monotonically increasing display revision | teacher account/session credentials, access tokens |
| selected public content kind and classroom-facing class label | private workspace/panel state, staff messages |
| public student IDs/names/seat coordinates only when the map is intentionally displayed | private notes/reminders, academic scores and history |
| timer state needed to render remaining time accurately | homework status list by default |
| teacher-selected lesson material safe for projection | raw resource credentials, full private resource catalog |
| approved participation cue/tally for an intentionally selected student | behavior commentary, grades, public ranking, inferred performance |

Only choose a transport after Stuart confirms the screen setup. A same-origin local window is a candidate for an extended monitor; origin/source/session validation and opaque session channel identity are required. Separate devices require a distinct network/auth/backend plan, not an expansion of the local UI issue. No route or transport is added by this document.

Switching class first clears the public content, then publishes a fresh validated session snapshot. Old session/revision messages are rejected. A reopened window receives an allowlisted snapshot, never the teacher's full state. A disconnected display must blank private-risk content and show an honest disconnected state under a reviewed liveness rule; exact heartbeat/timeout belongs to transport validation. Display controls cannot mutate academic records. Homework mode and private student panel changes do not automatically project their contents.

## Synthetic acceptance matrix

| Scenario | Required observation |
| --- | --- |
| Enter/leave Homework Check repeatedly | Same class/map/assignment; statuses retained; no score writes. |
| Tap Done twice, change to Missing, mark Absent, reset Unchecked | Explicit distinct outcomes; retries do not duplicate the logical check. |
| Missing academic row versus explicit null | Existing grading tests unchanged; neither determines homework state. |
| Seat move / rename | Note/check/tally follows studentId, not seat or name. |
| Participation tap/retry/undo | Approved lesson semantics only; no duplicate event or unapproved grade effect. |
| Score throw / false write acknowledgement / history failure | Honest Failed/Partial and recoverable action; no cache-only Saved. |
| Two rapid edits / stale completion / account switch | Correct ordering and ownership; previous context cannot act or overwrite UI. |
| Close/reopen timer panel | Timer continuity; pause/reset deliberate. |
| Finish double tap / failed completion / app recovery | Single completion identity; pending intentions preserved; no false Finished. |
| Inspect public serialization | Only allowlisted fields; no notes, reminders, grades/history or credentials. |
| Reopen display / class switch / stale revision / disconnect | Fresh correct session or neutral state; old content does not silently continue. |
| Backend unavailable / local-only mode | Label truthfully; no silent fallback that claims cloud sync. |

Before visual sign-off, resolve the installed Flutter/google_fonts baseline compilation issue in a separate scoped compatibility review. Tests in #63 pass for the local academic boundaries; they do not verify these proposed classroom records, UI, cloud security or display transport.

## Implementation boundaries and rollback

This document adds no runtime capability. Each approved adapter/UI/transport remains one issue/branch/draft PR with its own evidence. Academic persistence/model/backend changes are Red; no deployment or live data work follows from this proposal. Local UI can proceed independently using synthetic state once its interaction is settled; durable success cannot be claimed until the adapter contract is met.

Revert this documentation commit to withdraw the proposal. Later additive implementation must preserve existing records and explain how disabled consumers expose recoverable work. Never autonomously delete or migrate prototype/school data.
