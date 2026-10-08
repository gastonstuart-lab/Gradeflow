# Existing teaching-preview failure tracker

All ten failures were recorded before the viewport/material pass. They are tracked here separately from visual recovery. Existing tests and assertions remain enabled and unchanged. No green full-suite claim is made.

Baseline: `e3e790b` (12 passed, 10 failed). Current scoped run: 14 passed, 9 failed. The five density tests and the new records/seat-target regression pass.

| ID | Existing test | Current status | Follow-up scope |
| --- | --- | --- | --- |
| PV-01 | Start menu opens timer and returns to narrow teacher desktop | Passing in this run — monitor | Flexible front-wall layout eliminates the observed narrow projector-row overflow; test now passes without changes to the test. |
| PV-02 | bottom tools preserve room and student panel stays right at 1400.0 | Open — failing | Panel animation timing; existing test inspects outgoing layers after 100 ms, transition is 240 ms. |
| PV-03 | bottom tools preserve room and student panel stays right at 390.0 | Open — failing | Panel animation timing; existing test inspects outgoing layers after 100 ms, transition is 240 ms. |
| PV-04 | chooser completes once and leaving Today cancels animation | Open — failing | Workflow/test expectation investigation; separate from material design. |
| PV-05 | desktop calendar and reminders survive navigating to class | Open — failing | Workflow/test expectation investigation; separate from material design. |
| PV-06 | fullscreen timer hides classroom and preserves running state | Open — failing | Workflow/test expectation investigation; separate from material design. |
| PV-07 | homework, private note and continuation survive the lesson flow | Open — failing | Existing exact-text/status expectations; duplicate status text also appears in baseline diagnostics. |
| PV-08 | room setup is a draft and applying preserves every student record | Open — failing | Workflow/test expectation investigation; separate from material design. |
| PV-09 | seat moves keep the same student note and homework check | Open — failing | Existing student-detail/seat-flow expectation; records and move callback not modified by recovery. |
| PV-10 | timer continues behind a closed panel on a narrow screen | Open — failing | Workflow/test expectation investigation; separate from material design. |

The follow-up descriptions identify observed baseline symptoms, not promises that every failure has a single cause. Resolve each in its own workflow-focused investigation. Do not change assertions merely to make the suite green.

Current logs: `/workspace/artifacts/classroom-recovery/premium-suite.log`; baseline logs: `density2-suite.log` and `baseline-3.38.9-tests.log` in the same directory. The pass report records the release build and actual-browser checks independently.

## Separate browser continuity observation

A Playwright probe typed a synthetic private note, switched students, and attempted to read it back through Flutter web semantics. The value was empty on reopening in both the new preview and a control build using the checkpoint's unchanged journey source. This browser-path retention check is **not verified**; do not claim it passed. The control build retained the current room component, isolating the unchanged journey/editor logic rather than claiming a complete historical artifact reconstruction.

The new focused Flutter regression **does** pass: it uses the real material seat hit targets and verifies notes and homework after closing/reopening students and swapping seats. This supports unchanged record ownership; it does not resolve the browser semantics/editor observation or the nine remaining full-workflow test failures. No note, homework, panel-state or seat-move handlers were modified.

Diagnostic logs remain at `premium-browser-check.log` for successful viewport/panel checks, `baseline-flow-check.log` for the unsuccessful control probe, and `premium-records-test.log` for the passing framework regression under `/workspace/artifacts/classroom-recovery`. Earlier unsuccessful web-note probes are retained outside the checkout.
