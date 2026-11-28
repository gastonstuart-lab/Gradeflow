#!/usr/bin/env bash
set -euo pipefail

preview/coordinator-linux-x64 --test-faults > evidence/coordinator.log 2>&1 &
coordinator=$!
python3 -m http.server 7357 --bind 127.0.0.1 --directory preview/web > evidence/web.log 2>&1 &
web=$!
trap 'kill "$coordinator" "$web" 2>/dev/null || true' EXIT

curl -fsS --retry 20 --retry-connrefused --retry-delay 1 -X OPTIONS http://127.0.0.1:8787/rollover
curl -fsS --retry 20 --retry-connrefused --retry-delay 1 http://127.0.0.1:7357/ -o /dev/null
node test/emulator/slice-3-browser.mjs | tee evidence/results.txt
