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
