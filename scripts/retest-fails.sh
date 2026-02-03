#!/usr/bin/env bash
set -euo pipefail

PARALLEL=3
FILTER_ID=""
FILTER_CATEGORY=""
DRY_RUN=false

while [ $# -gt 0 ]; do
  case "$1" in
    --parallel)
      PARALLEL="${2:-3}"
      shift 2
      ;;
    --filter-id)
      FILTER_ID="${2:-}"
      shift 2
      ;;
    --filter-category)
      FILTER_CATEGORY="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

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
  echo "No results.json found; run evals first." >&2
  exit 1
fi

fail_regex="$(
  python - <<'PY' "$latest" "$FILTER_ID"
import json, sys, pathlib, re
path = pathlib.Path(sys.argv[1])
filter_re = sys.argv[2]
rows = json.loads(path.read_text())
fails = [r.get("case_id") for r in rows if r.get("status") == "FAIL" and r.get("case_id")]
if filter_re:
    try:
        rx = re.compile(filter_re)
    except re.error:
        print("")
        raise SystemExit(2)
    fails = [cid for cid in fails if rx.search(cid)]
fails = sorted(set(fails))
if not fails:
    print("")
else:
    print("(" + "|".join(fails) + ")")
PY
)"

if [ -z "$fail_regex" ]; then
  echo "No failed cases to retest." >&2
  exit 0
fi

cmd=(
  ./.opencode/evals/skill-loading/opencode_skill_eval_runner.sh
  --repo "$PWD"
  --dataset .opencode/evals/skill-loading/opencode_skill_loading_eval_dataset.jsonl
  --matrix .opencode/evals/skill-loading/opencode_skill_eval_matrix.json
  --disable-models-fetch
  --isolate-config
  --parallel "$PARALLEL"
  --filter-id "$fail_regex"
)

if [ -n "$FILTER_CATEGORY" ]; then
  cmd+=(--filter-category "$FILTER_CATEGORY")
fi

if [ "$DRY_RUN" = true ]; then
  printf '%q ' "${cmd[@]}"
  printf '\n'
  exit 0
fi

exec "${cmd[@]}"
