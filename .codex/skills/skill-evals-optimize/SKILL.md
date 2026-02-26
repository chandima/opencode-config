---
name: skill-evals-optimize
description: "Optimize OpenCode skill-loading eval failures. Use when triaging failed eval cases, applying limited fixes, and re-running targeted evals."
allowed-tools: Bash(./evals/skill-loading/opencode_skill_eval_runner.sh) Bash(./scripts/*) Bash(python:*) Read Glob Grep
context: fork
---

# Skill Evals Optimize

Triage failed eval cases using the steering guide, apply limited fixes, and retest with a strict iteration cap.

## Inputs

- Results root: `evals/skill-loading/.tmp/opencode-eval-results`
- Max optimization iterations: **2**
- Steering guide: `evals/skill-loading/docs/skill-optimization-steering.md`

## Workflow

1. **Locate latest results and list failed cases**
   ```bash
   bash scripts/list-fails.sh
   ```

2. **For each failed case**
   - Read the case entry in `opencode_skill_loading_eval_dataset.jsonl`.
   - Consult the steering guide for the appropriate fix strategy.
   - Propose the smallest targeted change (skill description, prompt, permissions, or tests).

3. **Retest only the failed cases**
   ```bash
   bash scripts/retest-fails.sh --parallel 3
   ```

4. **Enforce the iteration cap (2 max)**
  - After two fix+retest cycles, **stop optimizing**.
  - Acknowledge remaining failures as legitimate model limitations or out-of-scope behaviors.

## Helper Scripts

- `bash scripts/list-fails.sh` lists FAIL case IDs from the latest run.
- `bash scripts/retest-fails.sh` re-runs only failing cases.
  - Use `--filter-id` to scope (e.g., `--filter-id "gh_|c7_"`).
  - Use `--dry-run` to print the command without executing.

## Rules

- Do not broaden permissions or weaken tests to force a pass.
- Prefer minimal, reversible changes.
- If a failure persists after two iterations, label it as legitimate and move on.

## Output

- Summarize PASS/FAIL counts.
- List failed case IDs and which ones were accepted as legitimate failures.
- Reference the steering guide for any remaining follow-up.
