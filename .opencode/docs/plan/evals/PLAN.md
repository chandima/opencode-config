# Evaluation Framework Plan

Purpose: establish a deterministic, CI-friendly evaluation framework for OpenCode skill loading and usage, using the existing runner bundle and dataset schema in `.opencode/docs/plan/evals/`.

## Status update (2026-02-01)

- Implemented the evaluation framework in `.opencode/evals/skill-loading/` with runner, dataset, matrix, grading spec, and docs.
- Added `summary.json` output (precision/recall, confusion pairs, per-skill stats).
- Enforced `checks.should_ask_external_search` for skill-creator cases.
- `checks.optional_skills` is treated as **allowed extras for diagnostics** (not pass/fail).
- Runner now excludes `AGENTS.md` and `.opencode/` from test copies to avoid workflow instructions contaminating eval runs.
- Command regex checks consider `bash` tool inputs (not just assistant text).
- Added `--disable-models-fetch` to avoid `models.dev` access in offline/CI environments.
- Default dataset reduced to a small starter set; full dataset preserved as `opencode_skill_loading_eval_dataset.full.jsonl`.
- Eval matrix now GPT-only to keep early runs small.
- Server mode now uses `--port` to reuse the running server (avoids `--attach` context errors). Default remains per-test until server mode proves faster.
- Added timing instrumentation: per-case prep/run/parse/grade breakdowns (`--timing-detail`) plus optional timestamped event traces (`--trace-events`) and time-to-first-event/tool/skill fields.
- `--isolate-config` now skips auto-loading repo `opencode.json` unless `--config` is explicitly provided (prevents beads/plugin contamination). It sets `OPENCODE_CONFIG_DIR` to a temp dir. Project config is only disabled if `--disable-project-config` is passed.
- When `--isolate-config` is used without `--config`, the runner writes a minimal config (plugins disabled, `asu-discover` denied) to keep evals deterministic.
- The runner injects a minimal `AGENTS.md` guard in temp workspaces to forbid Beads usage during eval runs.
- The runner now prepends a short prompt guard that forbids Beads and requires calling `skill` when a skill is named (disable with `--no-guard`).
- Added parallel execution (`--parallel`) with per-test timeout progress bars and per-run `progress.json`.
- Parallel runs now isolate OpenCode cache per worker to avoid cache corruption/race conditions.
- Added a hard timeout fallback to prevent hangs after timeout.
- Added `--shell-run` (default on non-Windows) to launch OpenCode via `bash -lc` for better compatibility; can be disabled with `--no-shell-run`.
- The runner now sets `OPENCODE_TEST_HOME` per worker to avoid log-path errors when `opencode` runs as a child process.

## Phase 1 — Align goals and success criteria
- Confirm the four evaluation buckets: **Process**, **Outcome**, **Style/Policy**, **Efficiency**.
- Define pass/fail thresholds and what constitutes a “must-load” vs “allowed” vs “forbidden” skill.
- Decide baseline agents/models to measure (plan/build + model list) and what a “regression” means.
- Document constraints: skill loading is only observable via `tool_use` events with `tool == "skill"`.

## Phase 2 — Dataset finalization
- Adopt the JSONL schema from `opencode_skill_loading_eval_dataset.jsonl` and ensure all fields are intentional:
  - Core: `id`, `category`, `prompt`.
  - Expectations: `must_call_skill`, `expected_skills_any_of`, `forbidden_skills`.
  - Checks: `forbid_tools`, `must_not_call_any_skill`, `must_not_call_skills`, `required_phrases`, `required_commands_regex`, `suggested_first_commands_regex`, `should_explain_permission`, `required_outputs_files`.
- Expand coverage across the 6 task families (explicit, implicit, near‑miss, multi‑skill, permission gating, context pressure).
- Confirm deny/permission cases (e.g., `asu-discover`) and “must explain permission” scenarios.
- Validate any fields that are currently ignored by the runner (e.g., `optional_skills`) and decide whether to enforce or remove.

## Phase 3 — Runner validation and configuration
- Standardize on the Node runner (`opencode_skill_eval_runner.mjs` or `.ts`) and shell wrapper.
- Verify execution modes:
  - **Default**: per‑test repo copy for determinism.
  - **Optional**: server/attach mode with reset strategy (`reset|restart|none`).
- Confirm required inputs: `--repo`, `--dataset`, `--matrix` and optional flags for filtering.
- Define the default output structure (`results.json`, `junit.xml`, combined `results.all.json`/`junit.all.xml`).

## Phase 4 — Matrix and experiment design
- Finalize `opencode_skill_eval_matrix.json` for baseline runs (agent + model grid).
- Add experiment rows for instruction placement, permissions modes, and harness variants.
- Decide which cases should be skipped for `plan` agent (e.g., tests with output file requirements).

## Phase 5 — Grading and diagnostics
- Confirm deterministic grading rules:
  - Skill load detection via `tool_use` + `tool == "skill"` + `state.input.name`.
  - Forbidden tool/skill checks.
  - Required phrase/regex checks.
  - Permission explanation checks (must mention skill + deny/permission/blocked wording).
  - Output file existence and non‑empty checks.
- Define summary metrics: precision/recall for skill selection, false positives (unneeded skill), false negatives (missed skill), permission‑handling accuracy.

## Phase 6 — CI integration
- Create a CI‑friendly invocation standard (non‑zero exit on FAIL/ERROR; SKIP allowed).
- Choose a default output directory and retention policy for artifacts.
- Ensure runner prerequisites are documented (Node 18+, `opencode` on PATH).

## Phase 7 — Reporting and iteration loop
- Establish a triage workflow from `results.all.json` and JUnit output:
  - Identify failure clusters by category and agent/model.
  - Track confusion pairs (wrong skill vs expected skill).
  - Measure latency/efficiency where available.
- Feed findings back into: dataset, skill packaging, skill descriptions, and permission config.

## Deliverables
- Finalized dataset JSONL and matrix JSON.
- Runner invocation guide and CI snippet.
- Baseline results + a repeatable analysis checklist.
- A short “how to interpret results” section for future contributors.

## Non‑goals (for this plan)
- No changes to production code in this repository.
- No new skills or refactors outside of the evaluation framework.
