# AI Setup Quick Reference

Status: deprecated frontend setup guide.

Do not put OpenAI API keys in Flutter/web code, `--dart-define`, VS Code launch
config, `.vscode/settings.json`, or client-side environment variables.

Safe architecture:

```text
Flutter UI -> service wrapper -> Firebase callable Function -> OpenAI API
```

OpenAI credentials must live only in Firebase Functions / Google Cloud
server-side secret storage. The current `askInstructOS` callable is a
placeholder and does not include real OpenAI integration yet.

For this slice, use emulator smoke tests for verification. Do not configure
frontend OpenAI keys for Flutter web.
