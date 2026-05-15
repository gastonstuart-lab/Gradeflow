# Ask InstructOS Backend Plan

## Current State

- Ask InstructOS already exists as a native mini-app inside the OS Home mini desktop.
- The current assistant behavior is local-only and mock-based.
- There is no backend, API, Firebase Functions, Firestore write, or OpenAI integration connected to the Ask InstructOS UI yet.

## Recommended Architecture

Use a server-side boundary for all real AI calls:

```text
Flutter Ask InstructOS UI
  -> Flutter assistant service wrapper
  -> Firebase callable Cloud Function
  -> OpenAI API called only from the server-side function
  -> reply returned to the UI
```

The Flutter UI should only know how to send a validated prompt payload and render a response. The OpenAI API key must live only in the backend function environment or secret store.

## Security Rules

- Never expose OpenAI API keys in Flutter or web client code.
- Require Firebase Auth for real AI calls.
- Use server-side secret/config storage for `OPENAI_API_KEY`.
- Validate message length and payload shape before calling OpenAI.
- Do not write to Firestore in the first AI slice.
- Avoid sending sensitive student data until a later, reviewed tool/context phase.

## First Implementation Slice Later

- Add a Firebase Functions scaffold.
- Add a callable `askInstructOS` function.
- Add the `cloud_functions` dependency to Flutter.
- Add `lib/services/instructos_assistant_service.dart`.
- Wire the Ask InstructOS UI to the service with loading/error states and mock fallback.
- Keep class and planner context out of scope.

## Later Phases

- Add scoped class/planner context.
- Add tool calling for safe app actions.
- Add App Check, rate limiting, and logging hygiene.
- Add voice after the text assistant is stable.

## Risks And Unknowns

- No `functions/` directory currently exists.
- `cloud_functions` is not currently installed.
- Existing Flutter-side OpenAI config should not be used for real web API keys.
- Need to choose the Firebase Functions runtime/language.
- Need usage and cost controls before broad rollout.
