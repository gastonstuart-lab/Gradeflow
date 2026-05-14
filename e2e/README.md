# Playwright E2E

Playwright auto-builds the Flutter web release and serves `build/web` in SPA
mode while tests run. For faster local iteration, build once first and override
the server command:

```pwsh
$env:E2E_WEB_SERVER_COMMAND = "npx.cmd serve build/web -s -l 7357"
```

## Release Gates

```pwsh
npm run e2e:smoke
npm run e2e:routing
npm run e2e:core
```

- `e2e:smoke` runs the cold unauthenticated login/demo smoke checks.
- `e2e:routing` uses a one-time seeded demo auth state and checks shell/routing.
- `e2e:core` runs routing plus primary workflow checks.

## Non-Blocking Regression

```pwsh
npm run e2e:regression
npm run e2e:full
```

These keep slower export, seating, dashboard trust, and reporting checks visible
without making every small change wait on the whole suite.

## Notes

- Default URL is `http://127.0.0.1:7357`.
- Override port with `$env:PORT = "7357"` or set `$env:BASE_URL`.
- Gated commands use `playwright.gated.config.ts`, which creates
  `test-results/.auth/demo-user.json` once per run.
