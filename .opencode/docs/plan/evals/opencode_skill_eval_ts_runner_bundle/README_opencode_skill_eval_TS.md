# OpenCode Skill Loading Eval (JS/TS Runner)

This bundle contains a **PASS/FAIL** runner that evaluates whether OpenCode correctly **loads skills** via the native `skill` tool, across a **matrix of agents and models**.

## Files
- `opencode_skill_eval_runner.mjs` — runnable Node runner (no deps)
- `opencode_skill_eval_runner.ts` — TypeScript source (same logic)
- `opencode_skill_eval_runner.sh` — shell wrapper
- `opencode_skill_loading_eval_dataset.jsonl` — dataset
- `opencode_skill_eval_matrix.json` — (agent, model) run matrix
- `opencode_skill_eval_gradespec.md` — grading rules

## Prereqs
- Node.js 18+
- `opencode` installed and on PATH

## Run (isolated / deterministic — recommended)
Runs each test in a **fresh temp copy** of your repo (known state per test).

```bash
./opencode_skill_eval_runner.sh \
  --repo /path/to/your/repo \
  --dataset opencode_skill_loading_eval_dataset.jsonl \
  --matrix opencode_skill_eval_matrix.json \
  --outdir opencode-eval-results
```

Exit code:
- `0` all PASS (SKIP allowed)
- `1` any FAIL/ERROR

Artifacts:
- `opencode-eval-results/junit.all.xml`
- per-run `opencode-eval-results/<run>/junit.xml`
- JSON summaries in `results*.json`

## Persistent server mode (optional)

OpenCode supports attaching CLI commands to a running server (global `--attach`), and `opencode serve` starts a headless server.
If you pass `--start-server`, this runner will:

- Create a per-run **workspace** copied from your repo
- Start `opencode serve` in that workspace
- Run tests with `opencode --attach <url> run ...`
- Reset the workspace between tests for a known state (default)

```bash
./opencode_skill_eval_runner.sh \
  --repo /path/to/your/repo \
  --dataset opencode_skill_loading_eval_dataset.jsonl \
  --matrix opencode_skill_eval_matrix.json \
  --start-server \
  --server-port 4096 \
  --server-hostname 127.0.0.1 \
  --server-reset reset
```

Reset modes:
- `--server-reset reset` (default): restore files from a pristine snapshot + clear `.opencode/sessions` and `.opencode/cache`
- `--server-reset restart`: also restarts the server per test (max isolation, slowest)
- `--server-reset none`: fastest, but NOT deterministic (state can leak across tests)

> Note: server mode is only worth it if process startup is your bottleneck; the default copy-per-test mode is the cleanest for CI.

## Customizing the matrix

Edit `opencode_skill_eval_matrix.json`:

```json
{
  "runs": [
    { "name": "build_gpt", "agent": "build", "model": "litellm/gpt-5.1-codex" },
    { "name": "plan_gpt",  "agent": "plan",  "model": "litellm/gpt-5.1-codex" }
  ]
}
```
