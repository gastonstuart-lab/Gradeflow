# GradeFlow Firebase Functions

This scaffold hosts backend-only Firebase callable functions for GradeFlow.

`askInstructOS` is intentionally a placeholder in this slice. It validates the
request shape, requires Firebase Auth, and returns a fixed readiness reply.

Out of scope for this slice:

- OpenAI API calls
- API keys or secrets
- Firestore reads/writes
- class, student, or planner context
- frontend wiring
- tool calling
- voice input
