# AI Setup

Status: deprecated frontend setup guide.

Older versions of this document described putting OpenAI keys in VS Code,
terminal environment variables, `.env`, or Flutter `--dart-define` values.
That is unsafe for Flutter web because those values can be exposed to the
client bundle or local tooling.

Do not put OpenAI API keys in Flutter/web code, `--dart-define`, VS Code launch
config, `.vscode/settings.json`, or client-side environment variables.

## Safe Direction

Use this architecture only:

```text
Flutter UI
  -> service wrapper
  -> Firebase callable Function
  -> OpenAI API called server-side only
```

When real OpenAI integration is added later:

1. Store the OpenAI API key as a Firebase Functions / Google Cloud secret.
2. Read the secret only inside the Firebase Function runtime.
3. Require Firebase Auth before making real AI calls.
4. Keep Flutter/web responsible only for sending validated request payloads and
   rendering responses.

The current `askInstructOS` callable is intentionally a placeholder. No real
OpenAI integration is configured by this document.
