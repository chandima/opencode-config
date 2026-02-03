---
name: skill-evals-run
description: "Run the OpenCode skill-loading eval suite for this repo. Use when asked to run skill evals, skill-loading evals, or the skill-evals-run command."
allowed-tools: Bash(./.opencode/evals/skill-loading/opencode_skill_eval_runner.sh) Read
context: fork
---

# Skill Evals Run

Run the local skill-loading eval suite with the shell runner.

## Prerequisites

- `opencode` is installed and on PATH.
- Provider config is available under `~/.config/opencode/` (used even with `--isolate-config`).
- If using `--disable-models-fetch`, `~/.cache/opencode/models.json` exists and includes the target model.
- Auth/credentials are present (typically `~/.local/share/opencode/auth.json`).
- Network access is available for model calls.

## Command

Run:

```bash
.opencode/evals/skill-loading/opencode_skill_eval_runner.sh \
  --repo "$PWD" \
  --dataset .opencode/evals/skill-loading/opencode_skill_loading_eval_dataset.jsonl \
  --matrix .opencode/evals/skill-loading/opencode_skill_eval_matrix.json \
  --disable-models-fetch \
  --isolate-config \
  --parallel 3
```

## Arguments

If the user provides any of the following flags, append them to the command:

- `--filter-id <regex>`
- `--filter-category <substring>`
- `--parallel <n>`

If `--parallel` is omitted, keep the default of 3.

## After the run

- Summarize PASS/FAIL counts and list failed case IDs.
- If failures exist (PASS/FAIL, not ERROR), reference `.opencode/evals/skill-loading/docs/skill-optimization-steering.md` and suggest the next remediation step.
- If any cases are ERROR, do not suggest optimization. Instead, inspect `.opencode/evals/skill-loading/.tmp/opencode-eval-results/<run>/results.json` and any traces to identify the crash, then re-run the evals once the error is resolved.

## Notes

- Run from the repo root so relative paths resolve.
- `--isolate-config` also disables project config, so no extra flag is required to avoid loading repo config/plugins during evals.
- With `--disable-models-fetch`, the runner falls back to `~/.cache/opencode/models.json` when present. Use `--models-url file://...` if you need a different cache file.
- Include the exact command used in the response.
