Here you go — I rewrote the runner in **TypeScript (plus a runnable Node `.mjs` build)** and bundled everything into a single zip for easy download. It supports:

* **PASS/FAIL exit code** (0 on success, 1 on any FAIL/ERROR)
* **JUnit XML output** for CI
* **Agent + model matrix** (e.g., plan/build × models)
* **Known-state per test** (default: per-test temp repo copy)
* **Optional persistent server + context attachment** via OpenCode’s global `--attach` and `opencode serve` ([OpenCode][1])

## Download

[Browse the TS/JS runner bundle](./opencode_skill_eval_ts_runner_bundle)

---

## What’s inside the bundle

* [opencode_skill_eval_runner.ts](./opencode_skill_eval_ts_runner_bundle/opencode_skill_eval_runner.ts) — TypeScript source
* [opencode_skill_eval_runner.mjs](./opencode_skill_eval_ts_runner_bundle/opencode_skill_eval_runner.mjs) — runnable Node (no deps)
* [opencode_skill_eval_runner.sh](./opencode_skill_eval_ts_runner_bundle/opencode_skill_eval_runner.sh) — shell wrapper
* [opencode_skill_loading_eval_dataset.jsonl](./opencode_skill_eval_ts_runner_bundle/opencode_skill_loading_eval_dataset.jsonl) — your dataset
* [opencode_skill_eval_matrix.json](./opencode_skill_eval_ts_runner_bundle/opencode_skill_eval_matrix.json) — matrix (agent+model)
* [opencode_skill_eval_gradespec.md](./opencode_skill_eval_ts_runner_bundle/opencode_skill_eval_gradespec.md) — grading rules
* [package.json](./opencode_skill_eval_ts_runner_bundle/package.json) — optional convenience metadata

---

## How to run (recommended deterministic mode)

This mode runs each test in a **fresh temp copy** of your repo, giving you a *known state per test*.

```bash
./opencode_skill_eval_runner.sh \
  --repo /path/to/your/repo \
  --dataset opencode_skill_loading_eval_dataset.jsonl \
  --matrix opencode_skill_eval_matrix.json \
  --outdir opencode-eval-results
```

It calls `opencode run --format json` to collect JSONL events ([Open Code][2]) and grades skill loading by detecting the `skill` tool being invoked (OpenCode loads skills on-demand via the native `skill` tool) ([OpenCode][3]).

Artifacts:

* `opencode-eval-results/junit.all.xml`
* `opencode-eval-results/<run>/junit.xml`
* `results*.json`

---

## Optional: persistent server + attach (only if you want it)

OpenCode supports attaching CLI commands to a running server using the **global `--attach` flag** ([OpenCode][1]), and `opencode serve` runs a headless HTTP server (default port 4096) ([OpenCode][4]).

Enable it with:

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

Server reset modes:

* `reset` (default): restore workspace files from pristine snapshot + clear `.opencode` session/cache between tests
* `restart`: also restarts the server per test (most isolated, slower)
* `none`: fastest, but state can leak across tests

This is implemented because attached server context can otherwise persist across test cases; resetting ensures each test begins from a known state.

---

If you want, I can also add **per-skill precision/recall summaries** (confusion matrix: expected vs loaded) into the output JSON for quicker diagnosis.

[1]: https://opencode.ai/docs/cli/ "CLI | OpenCode"
[2]: https://open-code.ai/en/docs/cli "CLI Commands - Run OpenCode from Terminal - OpenCode Docs"
[3]: https://opencode.ai/docs/skills?utm_source=chatgpt.com "Agent Skills | OpenCode"
[4]: https://opencode.ai/docs/server/ "Server | OpenCode"
