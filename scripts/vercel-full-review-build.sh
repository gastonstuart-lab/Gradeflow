#!/usr/bin/env bash
# Build the fictional, in-memory Slice 3 teacher review on its own branch.
set -euo pipefail

if [[ "${VERCEL:-}" == "1" ]] &&
   [[ "${VERCEL_ENV:-}" != "preview" ||
      "${VERCEL_GIT_COMMIT_REF:-}" != "preview/gradeflow-slice-3-teacher-review" ]]; then
  echo "The teacher review can only build on the isolated Vercel preview branch."
  exit 1
fi

export FLUTTER_ROOT="${PWD}/.flutter-review-sdk"
if [[ ! -x "$FLUTTER_ROOT/bin/flutter" ]]; then
  git clone --quiet --depth 1 --branch 3.38.7 \
    https://github.com/flutter/flutter.git "$FLUTTER_ROOT"
fi
export PATH="$FLUTTER_ROOT/bin:$PATH"
flutter pub get --enforce-lockfile
flutter build web --release --no-pub --no-wasm-dry-run --no-web-resources-cdn \
  --target lib/gradebook_period_teacher_review.dart --base-href /
test -s build/web/main.dart.js
