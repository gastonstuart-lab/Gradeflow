#!/usr/bin/env bash
# Dedicated Vercel build for the complete, fictional-data-only GradeFlow app.
# Never use this script to build the Firebase production website.
set -euo pipefail

if [[ "${VERCEL:-}" != "1" ]]; then
  echo "Building preview outside Vercel is allowed for local review only."
fi
if [[ "${VERCEL_GIT_COMMIT_REF:-}" != "preview/gradeflow-pr173-full-review-20261120" && "${VERCEL:-}" == "1" ]]; then
  echo "REFUSED: Public review build is pinned to its isolated review branch."
  exit 1
fi

export FLUTTER_ROOT="${PWD}/.flutter-review-sdk"
if [[ ! -x "$FLUTTER_ROOT/bin/flutter" ]]; then
  git clone --quiet --depth 1 --branch 3.38.0 \
    https://github.com/flutter/flutter.git "$FLUTTER_ROOT"
fi
export PATH="$FLUTTER_ROOT/bin:$PATH"
flutter --version
flutter config --enable-web
flutter pub get --enforce-lockfile
# Verify the full-bleed Home never recreates the former dock click-through.
flutter test \
  test/gradeflow_public_review_safety_test.dart \
  test/home_floating_dock_continuity_test.dart \
  test/os_shell_surfaces_test.dart
flutter build web --release --no-wasm-dry-run \
  --target lib/main.dart --base-href / \
  --dart-define=GRADEFLOW_PUBLIC_REVIEW_LOCAL_ONLY=true

(
  cd teacher-tools-preview
  npm ci --ignore-scripts --no-audit --no-fund
  npm run build
)
mkdir -p build/web/teaching-studio
cp -a teacher-tools-preview/dist/. build/web/teaching-studio/
test -s build/web/main.dart.js
test -s build/web/teaching-studio/index.html
test -s build/web/teaching-studio/pdfjs/build/pdf.worker.mjs

# Never copy a Firebase config or service credentials into the public bundle.
if [[ -f build/web/firebase.json || -f build/web/firebase.live.json ]]; then
  echo "REFUSED: Firebase release config found in public preview output."
  exit 1
fi
echo "Full GradeFlow review built with local-only fictional data; Firebase disabled."
