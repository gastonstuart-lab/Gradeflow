# AI Integration Guide

> Deprecated frontend AI import guidance has been removed.

Do not put OpenAI API keys in Flutter/web code, `--dart-define`, VS Code launch
config, `.vscode/settings.json`, or client-side environment variables.

The legacy Flutter-side OpenAI import path has been removed. The app must not
call OpenAI or OpenAI proxy endpoints directly from Flutter/web.

Future AI import work should use this architecture:

```text
Flutter UI -> Firebase callable Function -> server-side secret -> OpenAI API
```

Only Firebase Functions or another trusted server-side component may read
OpenAI secrets or call the OpenAI API. Flutter should call an authenticated
backend endpoint and render the returned preview for user confirmation.

## Current Status

- Local roster, class, timetable, calendar, and exam import parsing remains in
  Flutter.
- The old `OpenAIConfig`, `OpenAIClient`, `AiImportService`, and
  `AiAnalyzeImportDialog` frontend path has been removed.
- Ask InstructOS remains a separate Firebase callable placeholder and was not
  changed by this cleanup.

## Future Migration Notes

When AI-assisted imports return, implement them server-side first:

1. Add or extend a Firebase callable Function.
2. Store OpenAI credentials only in Firebase/Google Cloud server-side secrets.
3. Require authenticated callable requests.
4. Return structured preview data to Flutter.
5. Keep local parsers as the default non-AI path.
6. Add emulator tests for authenticated success and unauthenticated rejection.

Do not restore Flutter-side OpenAI clients, `--dart-define` key setup, or
client-side proxy-key configuration.
