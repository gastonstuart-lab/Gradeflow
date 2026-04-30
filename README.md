# GradeFlow

GradeFlow is a web-first Flutter app for teacher workflow management. It brings together class lists, student rosters, grading, exports, classroom tools, and seating plans in one project.

Built for The Affiliated High School of Tunghai University.

## Product Snapshot

- Class management with archive and restore flows
- Student roster management with CSV/XLSX import and soft delete
- Gradebook with categories, grade items, score history, and undo
- Final exam entry and calculated final results
- CSV, XLSX, PDF, and substitute handout export flows
- Teacher dashboard tools including name picker, groups, participation, schedule, quick poll, timer, and QR code
- Seating layout designer with templates, drag-and-drop placement, fullscreen view, and printable handouts
- Optional AI-assisted import analysis

## Direction

GradeFlow is currently strongest as a web app.

- Web is the primary supported target
- Android and iOS codepaths exist, but they should be treated as needing local SDK and device verification
- Some export and preview flows currently use web-specific implementations

## Data Model

The app supports two storage modes.

- Local-first mode uses SharedPreferences and works without a backend
- Cloud-backed mode uses Firebase Auth and Firestore when configured

Some dashboard and utility data is still stored locally even when Firebase is enabled, so the current architecture is hybrid rather than fully cloud-native.

## Demo Mode

Use the `Try Demo Account` button on the login screen to create and sign in with a seeded demo workspace.

The demo flow now includes:

- sample classes
- sample students
- default grading categories
- seeded grade items
- seeded scores
- seeded exam results

This makes the main flows usable immediately after login.

## Getting Started

Prerequisites:

- Flutter SDK 3.6.0 or newer
- Chrome for web development
- Node.js for Playwright E2E tests

Install and run:

```bash
flutter pub get
flutter run -d chrome
```

## Two-Machine Sync (Surface Pro + Desktop)

Use this routine on both machines to avoid drift and merge confusion during the day.

The important rule is simple: do not edit the same code on both machines at the same time unless both are connected to the exact same remote workspace. This repo setup is a safe handoff workflow, not true live multi-editor sync.

Fastest workflow inside VS Code:

1. When you sit down at either machine, run the task `Git: Arrive On This Machine`.
2. Work normally, then commit your changes when you want the other machine to see them.
3. Before switching devices, run `Git: Hand Off To Other Machine`.
4. If the task says you still have uncommitted changes, commit them first. Uncommitted work stays only on the current machine.

If you are unsure whether it is safe to switch, run `Git: Check Two-Machine Status`.

Terminal equivalent of the same flow:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/git-sync-safe.ps1
```

- Commit frequently in small chunks.
- Before switching devices, push your current branch.
- On the other machine, run the same sync command before editing.

Optional: push automatically after sync when local commits exist:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/git-sync-safe.ps1 -PushIfAhead
```

Recommended one-time local Git defaults on each machine:

```powershell
git config pull.rebase true
git config rebase.autoStash true
git config fetch.prune true
```

## Live Shared Workspace (Recommended)

If you want both machines to see the exact same files in real time, use the desktop as the host and let the Surface connect into it.

Why this is better:

- there is only one copy of the repo being edited
- both VS Code windows point at the same files
- Codex works against the same workspace instead of two drifting local copies

Desktop host setup:

1. On the desktop, open an elevated PowerShell window in this repo.
2. Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup-remote-workspace-host.ps1
```

3. Then run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/show-remote-workspace-host-info.ps1
```

4. Keep the desktop awake while you want to work from the Surface.

Surface client setup:

1. In VS Code on the Surface, install the `Remote - SSH` extension.
2. Run `Remote-SSH: Connect to Host...`.
3. Enter the target printed by `show-remote-workspace-host-info.ps1`, usually `desktopUser@DESKTOPNAME`.
4. After connecting, open `C:\Users\Stuart\Nosapp\Gradeflow` on the desktop host.

After that, both machines are looking at the same repo on the desktop. You can still use the git handoff workflow when you want to work with fully local copies instead.

## Optional Configuration

### OpenAI import support

AI-assisted import analysis is optional. The app still works without it.

Run with:

```bash
flutter run -d chrome \
  --dart-define=OPENAI_PROXY_API_KEY=sk-your-key-here \
  --dart-define=OPENAI_PROXY_ENDPOINT=https://api.openai.com/v1/chat/completions
```

### Firebase

Firebase initialization is optional. When Firebase is unavailable, the app falls back to local storage automatically.

## Verification

Core local verification commands:

```bash
flutter analyze
flutter test
flutter build web --release
```

Browser E2E verification:

```bash
npm install
npx playwright install chromium
npm run e2e
```

## Platform Status

| Platform | Status |
|----------|--------|
| Web | Fully supported |
| Android | Needs local SDK and device verification |
| iOS | Needs local Xcode and device verification |
| Windows | Experimental |
| macOS | Experimental |
| Linux | Experimental |

## Repository Layout

```text
lib/
  main.dart
  nav.dart
  theme.dart
  components/
  models/
  providers/
  repositories/
  screens/
  services/

test/
e2e/
```

## Current Caveats

- The dashboard screen and import service are still very large and should be split further
- Some browser automation assumptions were historically tied to older UI semantics
- Mobile support should not be considered release-ready without local validation

## License

Proprietary. All rights reserved.
