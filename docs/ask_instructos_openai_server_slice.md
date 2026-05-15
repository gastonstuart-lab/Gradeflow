# Ask InstructOS Server-Side OpenAI Slice

## Architecture

Use only the existing server-side boundary:

```text
Flutter Ask InstructOS UI
  -> InstructOSAssistantService
  -> Firebase callable Function: askInstructOS
  -> OpenAI API from Firebase Functions only
  -> reply returned to Flutter
```

Flutter must never read, receive, store, or forward an OpenAI API key. The
callable remains authenticated and should continue validating payload shape and
message length before any model call.

## Secret Setup Placeholder

Create the secret outside the repo and never paste a real value into source,
docs, `.env`, VS Code config, Flutter build flags, or chat:

```bash
firebase functions:secrets:set OPENAI_API_KEY
```

The implementation slice should bind the secret to `askInstructOS` with
Firebase Functions v2 secret support, for example by defining an
`OPENAI_API_KEY` secret in backend code and listing it in the function
`secrets` option. Do not read the secret in Flutter.

## Package Recommendation

Recommended first implementation: use the Node 20 runtime's built-in `fetch`.

Reasons:
- No new runtime dependency is needed.
- The first slice only needs one simple chat/reply request.
- The review surface stays small and easier to audit.
- It avoids adding SDK configuration before rate limits, model policy, and
  response contracts are settled.

The official OpenAI Node SDK is reasonable later if the backend needs structured
helpers, streaming, retries, tool calling, or richer API coverage. It is not
needed for the first server-side text reply slice.

## First Implementation Boundaries

Do:
- Keep `askInstructOS` as the only entry point.
- Require Firebase Auth.
- Keep the existing message, conversation, and context-mode validation limits.
- Send only the user message and the already provided conversation items.
- Return a plain `{reply: string}` response.
- Log only safe operational metadata, never full prompts or model output.
- Fail closed if the secret is missing or the OpenAI response is invalid.

Do not:
- Change Flutter UI.
- Add class, student, planner, grade, attendance, or timetable context.
- Read or write Firestore.
- Add tool calling.
- Add voice.
- Add streaming.
- Reintroduce any frontend OpenAI path.

## Model Recommendation Placeholder

Use a small, current OpenAI text model appropriate for brief assistant replies.
Select the exact model in the implementation PR after checking current OpenAI
model guidance and cost limits. Keep the model name in backend code only.

## Error Handling Plan

Map backend failures to safe callable errors:
- Missing authentication: keep `unauthenticated`.
- Invalid payload: keep `invalid-argument`.
- Missing server-side secret: return `failed-precondition`.
- OpenAI timeout, network failure, or 5xx: return `unavailable`.
- OpenAI 401/403: return `failed-precondition` without exposing provider
  details to the client.
- OpenAI 429: return `resource-exhausted`.
- Malformed provider response: return `internal`.

Client-facing error messages should be generic. Logs should include request
metadata such as UID, message length, conversation item count, status class, and
latency, but not full prompt text, secrets, or provider response bodies.

## Cost And Rate-Limit Notes

The first implementation should include conservative controls:
- Keep the existing payload size limits.
- Set a short request timeout.
- Set a small maximum output token budget.
- Consider low temperature for predictable replies.
- Add per-user or per-project rate limiting before broader rollout.
- Monitor Firebase Functions and OpenAI usage after enabling the real call.

## Testing Plan

Before deployment, verify locally with emulators:
- `npm run lint`
- `npm run build`
- unauthenticated callable request returns `UNAUTHENTICATED`
- authenticated callable request succeeds when an emulator-safe fake provider
  or mocked fetch is used
- missing-secret path fails safely without printing a secret
- invalid payloads still return `invalid-argument`
- Flutter fallback behavior still works when the callable is unavailable

Also run:
- `flutter analyze`
- `flutter test`
- `flutter build web --release --no-wasm-dry-run`

Do not test with a production OpenAI key from Flutter or any client-side path.

## Rollback Plan

If the real provider call causes errors, cost spikes, or unsafe behavior:
- Revert the implementation commit or restore the placeholder reply.
- Disable or remove the Functions secret binding for `askInstructOS`.
- Keep the Flutter service unchanged so the existing fallback behavior remains.
- Review logs for safe metadata only; never add prompt/secret logging during
  incident response.

## Explicitly Forbidden

- No frontend OpenAI key.
- No Flutter/web OpenAI client.
- No `--dart-define` OpenAI key.
- No VS Code key config.
- No `.env` or client-side environment OpenAI key.
- No class/student/planner context yet.
- No Firestore reads or writes.
- No tool calling.
- No voice.
- No Firebase deploy in the planning slice.
