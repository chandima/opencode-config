#!/usr/bin/env bash
set -euo pipefail

RESULTS_ROOT="${RESULTS_ROOT:-.opencode/evals/skill-loading/.tmp/opencode-eval-results}"
FILTER_ID=""
AS_JSON=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --results-root)
      RESULTS_ROOT="$2"; shift 2 ;;
    --filter-id)
      FILTER_ID="$2"; shift 2 ;;
    --json)
      AS_JSON=1; shift ;;
    -h|--help)
      echo "Usage: list-fails.sh [--results-root DIR] [--filter-id REGEX] [--json]"; exit 0 ;;
    *)
      echo "Unknown arg: $1"; exit 1 ;;
  esac
 done

RESULTS_ROOT="$RESULTS_ROOT" FILTER_ID="$FILTER_ID" AS_JSON="$AS_JSON" python - <<'PY'
import json
import os
import pathlib
import re
import sys

root = pathlib.Path(os.environ.get("RESULTS_ROOT", ".opencode/evals/skill-loading/.tmp/opencode-eval-results"))
filter_id = os.environ.get("FILTER_ID", "")
as_json = os.environ.get("AS_JSON", "0") == "1"

if not root.exists():
    msg = f"results root not found: {root}"
    if as_json:
        print(json.dumps({"error": msg}))
    else:
        print(msg)
    sys.exit(1)

results = list(root.glob("*/results.json"))
if not results:
    msg = f"no results.json files under {root}"
    if as_json:
        print(json.dumps({"error": msg}))
    else:
        print(msg)
    sys.exit(1)

latest = max(results, key=lambda p: p.stat().st_mtime)
try:
    data = json.loads(latest.read_text())
except Exception as exc:
    msg = f"failed to read {latest}: {exc}"
    if as_json:
        print(json.dumps({"error": msg}))
    else:
        print(msg)
    sys.exit(1)

fails = [r.get("case_id") for r in data if r.get("status") == "FAIL" and r.get("case_id")]
if filter_id:
    re_filter = re.compile(filter_id)
    fails = [cid for cid in fails if re_filter.search(cid)]

out = {"latest": str(latest), "fails": fails}
if as_json:
    print(json.dumps(out))
else:
    print(f"latest: {out['latest']}")
    print("fails:")
    for cid in fails:
        print(f"- {cid}")
PY
