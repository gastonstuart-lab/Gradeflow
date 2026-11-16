#!/usr/bin/env bash
# Read-only verification: retries mismatched/error responses, never deploys.
set -euo pipefail
root="${1:?Expected build directory required}"
base="${2:?Published base URL required}"
base="${base%/}"
release="${3:?Release identifier required}"
attempts="${GRADEFLOW_VERIFY_ATTEMPTS:-6}"
delay="${GRADEFLOW_VERIFY_DELAY_SECONDS:-2}"
[[ "$attempts" =~ ^([1-9]|10)$ ]] || { echo 'Invalid verification attempts' >&2; exit 2; }
[[ "$delay" =~ ^([0-9]|10)$ ]] || { echo 'Invalid verification delay' >&2; exit 2; }
[[ "$release" =~ ^[A-Za-z0-9_-]+$ ]] || { echo 'Invalid release identifier' >&2; exit 2; }
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
for relative in main.dart.js index.html os/home flutter_bootstrap.js teaching-studio/ teaching-studio/index.html teaching-studio/pdfjs/web/viewer.html teaching-studio/pdfjs/web/gradeflow-pen.mjs teaching-studio/pdfjs/web/gradeflow-pen.css teaching-studio/pdfjs/build/pdf.worker.mjs; do
  expected="$root/$relative"
  case "$relative" in
    os/home) expected="$root/index.html" ;;
    teaching-studio/) expected="$root/teaching-studio/index.html" ;;
  esac
  test -s "$expected" || { echo "Missing expected asset: $relative" >&2; exit 1; }
  matched=0
  for ((attempt=1; attempt<=attempts; attempt++)); do
    if curl --fail --silent --show-error --compressed --connect-timeout 5 --max-time 15 \
      -H 'Cache-Control: no-cache' -H 'Pragma: no-cache' \
      "$base/$relative?release=$release&attempt=$attempt" -o "$temporary/current" \
      && cmp -s "$expected" "$temporary/current"; then
      matched=1
      echo "Byte-verified: $relative"
      break
    fi
    echo "Asset not yet verified: $relative (attempt $attempt/$attempts)" >&2
    if ((attempt < attempts)); then sleep "$delay"; fi
  done
  if ((matched == 0)); then
    echo "Published bytes do not match: $relative" >&2
    exit 1
  fi
done
