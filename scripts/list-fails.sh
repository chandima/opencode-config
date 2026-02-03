#!/usr/bin/env bash
set -euo pipefail

RESULTS_DIR=".opencode/evals/skill-loading/.tmp/opencode-eval-results"

latest_results_json() {
  python - <<'PY'
import pathlib
root = pathlib.Path(".opencode/evals/skill-loading/.tmp/opencode-eval-results")
if not root.exists():
    print("")
    raise SystemExit(0)
candidates = [p for p in root.rglob("results.json") if p.is_file()]
if not candidates:
    print("")
    raise SystemExit(0)
latest = max(candidates, key=lambda p: p.stat().st_mtime)
print(latest)
PY
}

latest="$(latest_results_json)"
if [ -z "$latest" ]; then
  echo "No results.json found under $RESULTS_DIR." >&2
  exit 0
fi

python - <<'PY' "$latest"
import json, sys, pathlib
path = pathlib.Path(sys.argv[1])
rows = json.loads(path.read_text())
fails = [r.get("case_id") for r in rows if r.get("status") == "FAIL"]
for cid in fails:
    if cid:
        print(cid)
PY
