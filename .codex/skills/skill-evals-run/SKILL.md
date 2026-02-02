---
name: skill-evals-run
description: "Run the OpenCode skill-loading eval suite for this repo. Use when asked to run skill evals, skill-loading evals, or the skill-evals-run command."
allowed-tools: Bash(./.opencode/evals/skill-loading/opencode_skill_eval_runner.sh) Read
context: fork
---

# Skill Evals Run

Run the local skill-loading eval suite with the shell runner.

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
- If failures exist, reference `.opencode/evals/skill-loading/docs/skill-optimization-steering.md` and suggest the next remediation step.

## Notes

- Run from the repo root so relative paths resolve.
- `--isolate-config` also disables project config, so no extra flag is required to avoid loading repo config/plugins during evals.
- Include the exact command used in the response.
