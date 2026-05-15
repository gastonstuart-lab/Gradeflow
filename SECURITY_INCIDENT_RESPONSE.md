# Security Incident Response - API Key Exposure

## Incident Summary

A production OpenAI API key was previously exposed in repository history. The
key was revoked and must be treated as permanently compromised.

Do not print, reuse, or redistribute any historical secret value. If a report
needs to reference a key, redact it and show only the file or variable name plus
at most the first and last three characters.

## Current Safe Architecture

```text
Flutter UI -> service wrapper -> Firebase callable Function -> OpenAI API
```

The Flutter/web app must never read or receive an OpenAI API key. Only a
server-side Firebase Function may read the secret and call OpenAI.

## Hard Rules

- Do not put OpenAI API keys in Flutter/web code.
- Do not pass OpenAI API keys with `--dart-define`.
- Do not put OpenAI API keys in VS Code launch config or `.vscode/settings.json`.
- Do not put OpenAI API keys in client-side environment variables.
- Do not commit `.env` files containing real secrets.
- Do not print secrets during verification.

## If a Key Is Exposed

1. Revoke the key immediately in the provider dashboard.
2. Generate a replacement only if still needed.
3. Store the replacement only in Firebase Functions / Google Cloud server-side
   secret storage.
4. Audit tracked files and git history for additional exposures.
5. Check provider billing and usage logs for unauthorized activity.
6. Document the incident using redacted key references only.

## Safe Verification

Verify setup through backend-only emulator tests or deployed backend checks that
do not echo secrets. For Ask InstructOS, use the Firebase callable emulator
smoke tests until a reviewed server-side OpenAI integration is added.

## Notes

The current Ask InstructOS callable is a placeholder. No real OpenAI integration
is added by this cleanup.
