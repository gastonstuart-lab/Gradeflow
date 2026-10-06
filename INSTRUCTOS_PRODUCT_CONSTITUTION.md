# InstructOS Product Constitution

Authoritative product direction approved by Stuart on 6 October 2026. This constitution governs product and interaction decisions; AGENTS.md governs implementation risk, data safety and review.

**Keep the machinery. Replace the experience.**

InstructOS is a calm, coherent operating environment for a teacher's working day. It brings together preparation, live teaching, follow-up, planning, and school work without making the teacher operate a database. It is for teachers, beginning with Stuart's real classroom use.

## Three interaction rules

1. **Bring information to the teacher.** Relevant class, student, resource, and task information appears where the teacher can use it.
2. **Reveal complexity only when requested.** A simple surface expands into contextual actions, panels, and advanced workspaces as needed.
3. **Remember things so the teacher does not have to.** Preserve context, unfinished work, reminders, and previous actions with an honest account of what has been saved.

## Teacher states, not database categories

Design around arriving, understanding today, preparing a class, teaching, checking homework, acting on a student, finishing, and planning the next day. The teacher's state determines what is visible. Database entities do not determine the navigation hierarchy.

## Depth and continuity

The main workspace remains underneath temporary tools. A student action surface expands into deeper student information in place. Dismissing a panel returns to the same class, student, seating view, and work position. Class identity follows the teacher; ask for a selection only when context is missing or genuinely ambiguous. Preserve drafts and running tools until explicitly completed or dismissed under a clear rule.

Teaching, planning, advanced grading, and school/IED work share typography, spacing, controls, motion, panel behavior, and return logic. Technical modules may remain separate. The teacher experiences one environment. Projection must not expose private notes, grades, or staff communication.

## Relationship to GradeFlow and school systems

GradeFlow supplies the existing academic, classroom, integration, and persistence machinery. Preserve proven behavior and contracts. Replace or wrap interfaces when necessary; do not rewrite valuable engines to obtain a new appearance. Deep grading, imports, exams, reporting, and configuration remain accessible as advanced workspaces.

School/IED resources and communication belong to the same environment, subordinate to the immediate teaching state. Shared access and data boundaries remain explicit and enforced; visual continuity does not imply shared permissions or storage.

## Boundaries

InstructOS must never become a giant dashboard, a wall of cards, an exhaustive feature menu, unrelated tools, a database-shaped UI, recolored legacy screens, ten separately designed applications, a bolted-on chatbot, a context-reselection loop, or decorative OS gimmicks. Do not expose backend operations merely because they exist.

For each visible feature ask: **Does this make the teacher's next action easier right now?** If not, put it underneath, in an advanced workspace, or in the parking lot.

New ideas are either **REQUIRED FOR CURRENT FLOW** or **PARKING LOT**. Only required work changes active scope. Real classroom friction is the primary UX evidence. Historical mockups cannot override this constitution. Safety and data constraints still apply.


