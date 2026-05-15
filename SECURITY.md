# Security Guidelines - Gradeflow

Last updated: May 15, 2026

## Critical: OpenAI API Key Management

OpenAI API keys must never be exposed to Flutter/web clients.

Do not put OpenAI API keys in Flutter/web code, `--dart-define`, VS Code launch
config, `.vscode/settings.json`, or client-side environment variables.

Use this architecture only:

```text
Flutter UI -> service wrapper -> Firebase callable Function -> OpenAI API
```

Store OpenAI credentials in Firebase Functions / Google Cloud server-side secret
storage and read them only from backend function runtime code.

## API Key Exposure History

A production OpenAI API key was previously committed to git history. That key
was revoked and should be treated as permanently compromised.

If you have access to old history, assume any historical OpenAI key is unsafe.
Do not reuse it.

## Current Security Status

- API keys are not stored in version control.
- `.env` is ignored by git.
- `.vscode/settings.json` contains no OpenAI keys.
- Future OpenAI integration must be server-side only.

## Best Practices

1. Never commit secrets.
2. Never expose OpenAI keys to Flutter web.
3. Never pass OpenAI keys with `--dart-define`.
4. Never put OpenAI keys in VS Code settings or launch configs.
5. Use Firebase Functions / Google Cloud Secret Manager for OpenAI credentials.
6. Rotate any key after suspected exposure.
7. Monitor OpenAI usage after any suspected leak.

## Audit Checklist

- [ ] Search tracked files for `sk-`, `OPENAI_API_KEY`, and related names.
- [ ] Confirm `.vscode/settings.json` has no OpenAI key values.
- [ ] Confirm docs do not instruct frontend key setup.
- [ ] Confirm any future backend OpenAI key is stored in server-side secret storage.
- [ ] Use tools such as `gitleaks` for deeper history scanning when needed.

## If You Suspect a Key Leak

1. Immediately revoke the key in the service provider dashboard.
2. Generate a new key only if still needed.
3. Store the new key server-side only.
4. Check logs and billing dashboards for unauthorized usage.
5. Audit git history and any published artifacts.
