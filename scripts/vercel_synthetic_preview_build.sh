#!/usr/bin/env bash
set -euo pipefail

# Standalone, synthetic-only Vercel preview. Never run lib/main.dart.
# No Firebase environment variables or credentials are needed.
export PUB_CACHE="/tmp/gradeflow-preview-pub-cache"
export FLUTTER_HOME="/tmp/gradeflow-preview-flutter"
if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
  git clone --depth 1 --branch 3.38.0 https://github.com/flutter/flutter.git "$FLUTTER_HOME"
fi
export PATH="$FLUTTER_HOME/bin:$PATH"
flutter config --no-analytics
flutter precache --web
flutter pub get
flutter build web --release --no-wasm-dry-run --target lib/main_classroom_preview.dart --base-href /
test -s build/web/index.html
test -s build/web/main.dart.js
