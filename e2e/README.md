# Playwright E2E

Playwright auto-builds the Flutter web release and serves `build/web` in SPA mode while tests run.

## Run

```pwsh
cd c:\Dev\Gradeflow
npm install
npm run e2e
```

## Notes

- Default URL is `http://127.0.0.1:7357`.
- Override port with `$env:PORT = "7357"` (or set `$env:BASE_URL`).
