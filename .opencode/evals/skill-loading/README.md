# OpenCode Skill Loading Eval Framework

Deterministic eval runner for OpenCode skill routing + loading. It runs a JSONL dataset through `opencode run --format json`, detects `skill` tool calls, and grades PASS/FAIL. It also produces summary diagnostics (precision/recall, confusion pairs, per‑skill stats).

## Contents

- `opencode_skill_eval_runner.mjs` — runnable Node runner (no deps)
- `opencode_skill_eval_runner.ts` — TypeScript source
- `opencode_skill_eval_runner.sh` — shell wrapper
- `opencode_skill_loading_eval_dataset.jsonl` — **small** dataset (couple cases per skill)
- `opencode_skill_loading_eval_dataset.full.jsonl` — full dataset (archived)
- `opencode_skill_eval_matrix.json` — agent/model matrix (GPT only)
- `opencode_skill_eval_gradespec.md` — grading rules

## Prereqs

- Node.js 18+
- `opencode` installed and on PATH

## Run (deterministic, recommended)

```bash
./.opencode/evals/skill-loading/opencode_skill_eval_runner.sh \
  --repo /path/to/your/repo \
  --dataset .opencode/evals/skill-loading/opencode_skill_loading_eval_dataset.jsonl \
  --matrix .opencode/evals/skill-loading/opencode_skill_eval_matrix.json \
  --disable-models-fetch \
  --isolate-config \
  --outdir opencode-eval-results \
  --parallel 3
```

Exit code:
- `0` all PASS (SKIP allowed)
- `1` any FAIL/ERROR

Artifacts:
- `opencode-eval-results/junit.all.xml`
- `opencode-eval-results/results.all.json`
- `opencode-eval-results/summary.json`
- per-run `opencode-eval-results/<run>/results.json`
- per-run `opencode-eval-results/<run>/junit.xml`
- optional per-run traces `opencode-eval-results/<run>/trace/<caseId>.ndjson` (when `--trace-events`)
- per-run progress `opencode-eval-results/<run>/progress.json` (updated after each case)
- run lock `opencode-eval-results/.lock` (prevents concurrent runs in the same outdir)

Runtime UI:
- When running in a TTY, active tests show per‑test timeout progress bars.
- By default (non‑Windows), the runner launches `opencode` via `bash -lc` for better compatibility. It also sets `OPENCODE_TEST_HOME` to a temp dir per worker to avoid log‑path issues in child processes. Use `--no-shell-run` to disable.

## Persistent server mode (optional)

This starts `opencode serve` and attaches each run to it. It resets the workspace between tests for determinism.

```bash
./.opencode/evals/skill-loading/opencode_skill_eval_runner.sh \
  --repo /path/to/your/repo \
  --dataset .opencode/evals/skill-loading/opencode_skill_loading_eval_dataset.jsonl \
  --matrix .opencode/evals/skill-loading/opencode_skill_eval_matrix.json \
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
node .opencode/evals/skill-loading/opencode_skill_eval_runner.mjs \
  --repo "$PWD" \
  --dataset .opencode/evals/skill-loading/opencode_skill_loading_eval_dataset.jsonl \
  --matrix .opencode/evals/skill-loading/opencode_skill_eval_matrix.json \
  --outdir opencode-eval-results
```

## Notes

- Default mode copies the repo per test; your working tree is not mutated.
- The runner excludes `AGENTS.md` and `.opencode/` from test copies to avoid workflow instructions interfering with evals.
- Use `--isolate-config` to avoid global OpenCode config contamination (sets `OPENCODE_CONFIG_DIR` to a temp dir). When enabled, the runner **does not auto‑load** the repo `opencode.json` unless you pass `--config`, which avoids plugins like `opencode-beads` during evals.
- When `--isolate-config` is used without `--config`, the runner writes a minimal config (no plugins; `asu-discover` denied) to keep eval behavior deterministic.
- The runner injects a minimal `AGENTS.md` guard into temp workspaces to forbid Beads usage during evals. Add `--disable-project-config` only if you explicitly want to ignore `AGENTS.md`.
- By default, the runner also prepends a short **prompt guard** to each test to forbid Beads and to require loading a named skill via the `skill` tool. Disable with `--no-guard` if you want raw prompts.
- Use `--shell-run` or `--no-shell-run` to control the launch mode.
- Plan agent runs skip tests that require output files.
- Update `opencode_skill_eval_matrix.json` for your model list.
- If your environment blocks outbound access to `models.dev`, pass `--disable-models-fetch`.
