#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TMP_ROOT="$(mktemp -d)"
RESULTS_DIR="$TMP_ROOT/run-1"
mkdir -p "$RESULTS_DIR"

cat > "$RESULTS_DIR/results.json" <<'JSON'
[
  {"case_id": "alpha_case", "status": "PASS"},
  {"case_id": "beta_case", "status": "FAIL"},
  {"case_id": "gamma_case", "status": "FAIL"}
]
JSON

export RESULTS_ROOT="$TMP_ROOT"

OUTPUT="$({ bash "$SCRIPT_DIR/scripts/list-fails.sh"; } )"
if ! echo "$OUTPUT" | rg -q -- "beta_case"; then
  echo "Expected beta_case in list-fails output"
  exit 1
fi

DRY_RUN_CMD="$({ bash "$SCRIPT_DIR/scripts/retest-fails.sh" --dry-run; } )"
if ! echo "$DRY_RUN_CMD" | rg -q -- "--filter-id"; then
  echo "Expected retest-fails to include --filter-id"
  exit 1
fi

FILTERED="$({ bash "$SCRIPT_DIR/scripts/list-fails.sh" --filter-id "gamma"; } )"
if echo "$FILTERED" | rg -q -- "beta_case"; then
  echo "Expected filter-id to exclude beta_case"
  exit 1
fi

rm -rf "$TMP_ROOT"

echo "Smoke test passed"
