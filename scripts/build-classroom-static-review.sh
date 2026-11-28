#!/usr/bin/env bash
set -euo pipefail
echo "Visual review source: $(git rev-parse HEAD)"
export FLUTTER_ROOT="$PWD/.flutter-review-sdk"
if [[ ! -x "$FLUTTER_ROOT/bin/flutter" ]]; then
  git clone --quiet --depth 1 --branch 3.38.0 https://github.com/flutter/flutter.git "$FLUTTER_ROOT"
fi
export PATH="$FLUTTER_ROOT/bin:$PATH"
flutter pub get --enforce-lockfile
flutter test test/native_presentation_timer_test.dart test/native_screensaver_test.dart test/native_teaching_card_schedule_test.dart
flutter build web --release --no-wasm-dry-run --no-web-resources-cdn --target lib/main.dart --base-href / \
  --dart-define=GRADEFLOW_EXISTING_PROJECT_PREVIEW=true \
  --dart-define=GRADEFLOW_EXISTING_PROJECT_PREVIEW_CHANNEL=classroom-experience-review \
  --dart-define=GRADEFLOW_SYNTHETIC_REVIEW_ONLY=true
sed -i '/<meta name="google-signin-client_id"/d' build/web/index.html
bash scripts/package-classroom-preview.sh
