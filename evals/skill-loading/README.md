# OpenCode Skill Loading Eval Framework

Deterministic eval runner for OpenCode skill routing + loading. It runs a JSONL dataset through `opencode run --format json`, detects `skill` tool calls, and grades PASS/FAIL. It also produces summary diagnostics (precision/recall, confusion pairs, per‑skill stats).

## Contents

- `opencode_skill_eval_runner.mjs` — runnable Node runner (no deps)
- `opencode_skill_eval_runner.ts` — TypeScript source
- `opencode_skill_eval_runner.sh` — shell wrapper
- `opencode_skill_loading_eval_dataset.jsonl` — balanced dataset (explicit + implicit + near-miss + negatives)
- `opencode_skill_eval_matrix.json` — agent/model matrix (GPT only)
- `opencode_skill_eval_gradespec.md` — grading rules
- `docs/skill-testcase-steering.md` — guidance for writing new eval cases
- `docs/skill-optimization-steering.md` — guidance for refining skills after eval failures
- `docs/skill-resources.md` — external references for skill authoring

## Prereqs

- Node.js 18+
- `opencode` installed and on PATH

## Run (deterministic, recommended)

```bash
./evals/skill-loading/opencode_skill_eval_runner.sh \
  --repo /path/to/your/repo \
  --dataset evals/skill-loading/opencode_skill_loading_eval_dataset.jsonl \
  --matrix evals/skill-loading/opencode_skill_eval_matrix.json \
  --disable-models-fetch \
  --isolate-config \
  --outdir evals/skill-loading/.tmp/opencode-eval-results \
  --parallel 3
```

Exit code:
- `0` all PASS (SKIP allowed)
- `1` any FAIL/ERROR

Artifacts:
- `evals/skill-loading/.tmp/opencode-eval-results/junit.all.xml`
- `evals/skill-loading/.tmp/opencode-eval-results/results.all.json`
- `evals/skill-loading/.tmp/opencode-eval-results/summary.json`
- per-run `evals/skill-loading/.tmp/opencode-eval-results/<run>/results.json`
- per-run `evals/skill-loading/.tmp/opencode-eval-results/<run>/junit.xml`
- optional per-run traces `evals/skill-loading/.tmp/opencode-eval-results/<run>/trace/<caseId>.ndjson` (when `--trace-events`)
- per-run progress `evals/skill-loading/.tmp/opencode-eval-results/<run>/progress.json` (updated after each case)
- run lock `evals/skill-loading/.tmp/opencode-eval-results/.lock` (prevents concurrent runs in the same outdir)

Runtime UI:
- When running in a TTY, active tests show per‑test timeout progress bars.
- By default (non‑Windows), the runner launches `opencode` via `bash -lc` for better compatibility. It also sets `OPENCODE_TEST_HOME` to a temp dir per worker to avoid log‑path issues in child processes. Use `--no-shell-run` to disable.

## Persistent server mode (optional)

This starts `opencode serve` and attaches each run to it. It resets the workspace between tests for determinism.

```bash
./evals/skill-loading/opencode_skill_eval_runner.sh \
  --repo /path/to/your/repo \
  --dataset evals/skill-loading/opencode_skill_loading_eval_dataset.jsonl \
  --matrix evals/skill-loading/opencode_skill_eval_matrix.json \
  --start-server \
  --disable-models-fetch \
  --isolate-config \
  --server-port 4096 \
  --server-hostname 127.0.0.1 \
  --server-reset reset
```

Reset modes:
- `reset` (default): restore workspace files + clear `.opencode` state
- `restart`: reset + restart server per test (slowest, most isolated)
- `none`: fastest, not deterministic

Note: the runner uses `--port <port>` when `--start-server` is enabled (instead of `--attach`) to avoid OpenCode's “No context found for instance” attach error.

## Summary metrics

`summary.json` includes:
- overall skill precision/recall
- false positives/negatives
- per-skill precision/recall
- confusion pairs (expected → loaded)
- average event index of the first skill load

## Timing instrumentation (optional)

Add `--timing-detail` to record per‑case timing breakdowns (prep/run/parse/grade) in `results.json`.

Add `--trace-events` to write timestamped event timelines per case (NDJSON). Each line is a JSON object with:
- `t_ms`: milliseconds since opencode process start
- `event`: parsed JSON event (or `raw` for non‑JSON)

## CI snippet (generic)

```bash
node evals/skill-loading/opencode_skill_eval_runner.mjs \
  --repo "$PWD" \
  --dataset evals/skill-loading/opencode_skill_loading_eval_dataset.jsonl \
  --matrix evals/skill-loading/opencode_skill_eval_matrix.json \
  --outdir evals/skill-loading/.tmp/opencode-eval-results
```

## Notes

- Default mode copies the repo per test; your working tree is not mutated.
- The runner excludes `AGENTS.md` and `.opencode/` from test copies to avoid workflow instructions interfering with evals.
- Use `--isolate-config` to avoid global/project OpenCode config contamination (sets `OPENCODE_CONFIG_DIR` to a temp dir and disables project config). This prevents loading the repo `opencode.json` and skips repo `AGENTS.md`, avoiding plugin side-effects during evals.
- When `--isolate-config` is used without `--config`, the runner writes a minimal config (no plugins; `asu-discover` denied) to keep eval behavior deterministic.
- The runner injects a minimal `AGENTS.md` guard into temp workspaces for eval isolation, and also prepends a prompt guard.
- By default, the runner prepends a short **prompt guard** that enforces explicit skill usage when a user names a skill or asks for exact gh/GitHub CLI commands. Disable with `--no-guard` for fully raw prompts.
- Use `--shell-run` or `--no-shell-run` to control the launch mode.
- The runner sets `OPENCODE_EVAL=1` and a default `MCPORTER_TIMEOUT=20` to keep skill scripts fast and deterministic. Override via environment if needed.
- The minimal eval config allows `external_directory` to avoid permission prompts when skills execute scripts.
- The runner sets `OPENCODE_REPO_ROOT` so eval-mode scripts can write outputs into the repo tree.
- Plan agent runs skip tests that require output files.
- Update `opencode_skill_eval_matrix.json` for your model list.
- If your environment blocks outbound access to `models.dev`, pass `--disable-models-fetch`.
- For new test cases, follow the rubric in `docs/skill-testcase-steering.md`.
