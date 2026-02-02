---
name: skill-evals-run
description: Run the OpenCode skill-loading eval tests for this repo
arguments:
  - name: filter-id
    description: Regex of case IDs to run (optional)
    required: false
  - name: filter-category
    description: Substring match for categories to run (optional)
    required: false
  - name: parallel
    description: Number of parallel workers (default 3)
    required: false
---

# Skill Evals Run Command

Run the skill-loading eval suite for this repository using the local runner.

## Instructions

1. Build the base command (repo-scoped defaults):
   ```
   .opencode/evals/skill-loading/opencode_skill_eval_runner.sh \
     --repo "$PWD" \
     --dataset .opencode/evals/skill-loading/opencode_skill_loading_eval_dataset.jsonl \
     --matrix .opencode/evals/skill-loading/opencode_skill_eval_matrix.json \
     --disable-models-fetch \
     --isolate-config \
     --parallel 3
   ```

2. If `$ARGUMENTS` includes any flags (e.g., `--filter-id`, `--filter-category`, `--parallel`), append them to the command and run it.

3. After the run:
   - Summarize PASS/FAIL counts and list failed case IDs.
   - If there are failures, reference `.opencode/evals/skill-loading/docs/skill-optimization-steering.md` and suggest the next remediation step.

## Usage Examples

```bash
# Full run (default parallel=3)
/skill-evals-run

# Run only cases matching IDs
/skill-evals-run --filter-id "gh_|mcp_"

# Run only a category
/skill-evals-run --filter-category "github-ops"
```
