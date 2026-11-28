#!/usr/bin/env bash
# Called only inside firebase emulators:exec for demo-gradeflow-periods.
set -euo pipefail
export GRADEFLOW_COORDINATOR_PROJECT=demo-gradeflow-periods
mkdir -p test-results/grading-period-emulator
dart run tool/grading_period_coordinator.dart --test-faults >test-results/grading-period-emulator/coordinator.log 2>&1 &
coordinator_pid=$!
trap 'kill "$coordinator_pid" 2>/dev/null || true; wait "$coordinator_pid" 2>/dev/null || true' EXIT
ready=false
for attempt in $(seq 1 60); do
  kill -0 "$coordinator_pid" 2>/dev/null || { cat test-results/grading-period-emulator/coordinator.log; exit 1; }
  # GET is intentionally 404; this is only a loopback readiness probe.
  if [[ "$(curl -sS --max-time 1 -o /dev/null -w '%{http_code}' http://127.0.0.1:8787/rollover 2>/dev/null || true)" == 404 ]]; then
    ready=true
    break
  fi
  sleep 1
done
if [[ "$ready" != true ]]; then
  cat test-results/grading-period-emulator/coordinator.log
  exit 1
fi
flutter test --no-pub test/trusted_grading_coordinator_test.dart --reporter expanded | tee test-results/grading-period-emulator/trusted-coordinator.log
flutter test --platform chrome --no-pub test/firestore_grading_period_emulator_test.dart --reporter expanded | tee test-results/grading-period-emulator/browser-firestore.log
