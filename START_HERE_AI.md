# AI Setup Start Here

Status: deprecated frontend setup guide.

Do not follow older instructions that ask you to paste OpenAI keys into VS Code,
`.env`, terminal environment variables for Flutter, or `--dart-define`.

Do not put OpenAI API keys in Flutter/web code, `--dart-define`, VS Code launch
config, `.vscode/settings.json`, or client-side environment variables.

## Current Safe Architecture

```text
Flutter UI -> service wrapper -> Firebase callable Function -> OpenAI API
```

OpenAI API keys must stay server-side in Firebase Functions / Google Cloud
secret storage. The current Ask InstructOS backend is a placeholder callable and
does not call OpenAI yet.

Use local Firebase emulator smoke tests to verify callable behavior. Add real
OpenAI integration only in a later reviewed backend slice.
