---
name: skill-evals-optimize
description: Optimize failed skill-loading eval cases with a strict iteration cap
arguments:
  - name: filter-id
    description: Regex of case IDs to optimize (optional)
    required: false
  - name: max-iterations
    description: Max fix+retest cycles (default 2)
    required: false
---

# Skill Evals Optimize Command

Triage failing eval cases using the steering guide, apply limited fixes, and retest. Stop after a strict iteration cap and accept legitimate failures.

## Instructions

1. Locate the latest `results.json` under `evals/skill-loading/.tmp/opencode-eval-results/` (or use the helper script):
   ```bash
   bash scripts/list-fails.sh
   ```
2. Extract failed case IDs (`status == FAIL`). If `--filter-id` is provided, restrict to those cases.
3. Read `evals/skill-loading/docs/skill-optimization-steering.md` before proposing any fix.
4. For each failed case, propose the smallest targeted change and apply it.
5. Re-run only the failed cases using the eval runner (or use the helper script):
   ```bash
   evals/skill-loading/opencode_skill_eval_runner.sh \
     --repo "$PWD" \
     --dataset evals/skill-loading/opencode_skill_loading_eval_dataset.jsonl \
     --matrix evals/skill-loading/opencode_skill_eval_matrix.json \
     --disable-models-fetch \
     --isolate-config \
     --parallel 3 \
     --filter-id "<failed-id-regex>"
   ```
   ```bash
   bash scripts/retest-fails.sh --parallel 3
   ```
6. Enforce the max iteration cap (default 2, or `--max-iterations` if provided). After reaching it, stop optimizing and acknowledge remaining failures as legitimate.

## Usage Examples

```bash
# Optimize all failed cases (default max-iterations=2)
/skill-evals-optimize

# Optimize only a subset
/skill-evals-optimize --filter-id "gh_|c7_"

# Override iteration cap
/skill-evals-optimize --max-iterations 1
```
