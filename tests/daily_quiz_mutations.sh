#!/usr/bin/env bash
# Run only after the normal daily-quiz regression in the isolated CI database.
# Prove that removing either September 28 fix makes the new tests fail.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(psql -X -qAt -v ON_ERROR_STOP=1 -c 'select current_database()')" != portal_ci ]]; then
  echo 'Daily mutation checks require the isolated portal_ci database.' >&2
  exit 1
fi
guard=supabase/migrations/20260928_daily_quiz_placeholder_guard.sql
mutant=$(mktemp tests/.daily-quality-mutant-XXXXXX.sql)
failure=$(mktemp)
cleanup() {
  psql -X -q -v ON_ERROR_STOP=1 -f "$guard" >/dev/null
  rm -f "$mutant" "$failure"
}
trap cleanup EXIT

# This is the real immediate predecessor, including controls and release gates,
# with only the September 28 placeholder exclusion absent.
psql -X -q -v ON_ERROR_STOP=1 -f content-releases/2026-09-28-portal-controls.sql >/dev/null
if psql -X -qAt -v ON_ERROR_STOP=1 -f tests/daily_quiz_quality.sql >"$failure" 2>&1; then
  echo 'FAIL: daily quality test accepted the pre-guard selector.' >&2
  exit 1
fi
if ! grep -Fq 'accepted defective daily candidate: est / random / placeholder_distractor' "$failure"; then
  cat "$failure" >&2
  exit 1
fi
echo 'PASS: the pre-September-28 selector fails on a placeholder distractor.'
psql -X -q -v ON_ERROR_STOP=1 -f "$guard" >/dev/null

# Keep the test next to the original so all other relative SQL includes retain
# their meaning. Remove both executions of the repair, including idempotency.
sed '\|^\\ir ../content-releases/20260928_daily_quiz_missing_context.sql$|d' \
  tests/daily_quiz_quality.sql >"$mutant"
if psql -X -qAt -v ON_ERROR_STOP=1 -f "$mutant" >"$failure" 2>&1; then
  echo 'FAIL: daily quality test accepted unrepaired question content.' >&2
  exit 1
fi
if ! grep -Fq 'missing shared circle context:' "$failure"; then
  cat "$failure" >&2
  exit 1
fi
echo 'PASS: omitting the content repair fails on missing shared circle context.'
