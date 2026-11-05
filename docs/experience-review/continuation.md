# Continue the cohesive teacher experience review

- Repository: https://github.com/gastonstuart-lab/Gradeflow
- Branch: `feat/instructos-cohesive-teacher-experience-20261105`.
- Base: `feat/instructos-gradebook-20261105` (draft PR #69), itself stacked on draft PR #68. Main and production were not changed. Keep this stack in draft; do not merge/deploy automatically.
- Scope: Stuart requested a strong whole-product design/function/teacher-flow evaluation, especially matching launch, sign-in and Home with the approved premium Classroom.
- Read `teacher-experience-audit.md` and `pr-report.md` in this folder. Before/after screenshots use synthetic local demo data.
- Current local release preview: http://127.0.0.1:8793/os/home; isolated sign-in preview: http://127.0.0.1:8794/. Servers may need restarting after the session ends. Build output is `build/cohesion-review`.
- Rebuild: `flutter build web --release --no-wasm-dry-run --output build/cohesion-review`. Test: `flutter test`. Analyze: `dart analyze lib test`.
- 143 tests pass; release build and analysis pass. Browser verified zero-score persistence after reload, restored the demo value, and downloaded a valid synthetic XLSX export.
- Preserve: shared navy/teal entry/workspace foundation; premium wooden/teal Classroom; sliding right tools; on-map picks; canonical Planner/Classes/Native Gradebook routes. Do not reactivate old Dashboard/Gradebook/Seating interfaces.
- Release hold: separately approved auth/local-account security work, legacy exam save acknowledgement/retry/navigation, policy/export parity and authorized cloud/offline validation. Do not call the candidate production-ready.
- Real standalone gradebook and eight-class roster were not imported or altered. Never infer missing marks, student matches or unconfirmed subject weights.
- Next review with Stuart: sign-in → Home → selected class → Classroom → Gradebook → Planner → student records. Then prioritize release blockers from the audit before adding more features.
