#!/usr/bin/env bash
set -euo pipefail

RESULTS_ROOT="${RESULTS_ROOT:-.opencode/evals/skill-loading/.tmp/opencode-eval-results}"
FILTER_ID=""
PARALLEL="3"
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --results-root)
      RESULTS_ROOT="$2"; shift 2 ;;
    --filter-id)
      FILTER_ID="$2"; shift 2 ;;
    --parallel)
      PARALLEL="$2"; shift 2 ;;
    --dry-run)
      DRY_RUN=1; shift ;;
    -h|--help)
      echo "Usage: retest-fails.sh [--results-root DIR] [--filter-id REGEX] [--parallel N] [--dry-run]"; exit 0 ;;
    *)
      echo "Unknown arg: $1"; exit 1 ;;
  esac
 done

FILTER_REGEX=$(RESULTS_ROOT="$RESULTS_ROOT" FILTER_ID="$FILTER_ID" python - <<'PY'
import json
import os
import pathlib
import re
import sys

root = pathlib.Path(os.environ.get("RESULTS_ROOT", ".opencode/evals/skill-loading/.tmp/opencode-eval-results"))
filter_id = os.environ.get("FILTER_ID", "")

if not root.exists():
    print("")
    sys.exit(1)

results = list(root.glob("*/results.json"))
if not results:
    print("")
    sys.exit(1)

latest = max(results, key=lambda p: p.stat().st_mtime)
try:
    data = json.loads(latest.read_text())
except Exception:
    print("")
    sys.exit(1)

fails = [r.get("case_id") for r in data if r.get("status") == "FAIL" and r.get("case_id")]
if filter_id:
    re_filter = re.compile(filter_id)
    fails = [cid for cid in fails if re_filter.search(cid)]

if not fails:
    print("")
    sys.exit(0)

escaped = [re.escape(cid) for cid in fails]
regex = "^(" + "|".join(escaped) + ")$"
print(regex)
PY
)

if [[ -z "$FILTER_REGEX" ]]; then
  echo "No failed cases found to retest."
  exit 0
fi

CMD=(
  .opencode/evals/skill-loading/opencode_skill_eval_runner.sh
  --repo "$PWD"
  --dataset .opencode/evals/skill-loading/opencode_skill_loading_eval_dataset.jsonl
  --matrix .opencode/evals/skill-loading/opencode_skill_eval_matrix.json
  --disable-models-fetch
  --isolate-config
  --parallel "$PARALLEL"
  --filter-id "$FILTER_REGEX"
)

if [[ "$DRY_RUN" -eq 1 ]]; then
  printf '%q ' "${CMD[@]}"
  echo
  exit 0
fi

"${CMD[@]}"
