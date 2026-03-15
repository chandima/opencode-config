# PLAN — Skill-Creator Upgrade: Merge Anthropic Eval & Optimization Capabilities

## Goal

Upgrade `skills/skill-creator/` by selectively adopting Anthropic's superior eval framework, description optimization, and iterative improvement workflow — while preserving our multi-harness compatibility (OpenCode, Codex, Copilot). The upgraded skill must remain self-contained (symlink-safe), use **intent-based question patterns** (not tool-specific references) for guided interviews across all three harnesses, and be fully validated with smoke tests and new eval cases in the existing `evals/skill-loading/` framework.

## Background

Anthropic's `skill-creator` (33KB SKILL.md, 8 Python scripts, 3 sub-agent prompts) is significantly more capable but is Claude-only. Our skill (6KB) is correctly multi-platform but lacks eval, benchmarking, and description optimization. This plan merges the best of both.

## Anthropic Feature Coverage Matrix

Complete inventory of Anthropic's capabilities and our adoption decision for each:

### ✅ Adopting (7 features)

| # | Anthropic Feature | Our Adaptation | Phase |
|---|-------------------|----------------|-------|
| 1 | **Guided interview** — Capture Intent + Interview & Research before creating | Intent-based question pattern (one-at-a-time, suggest options, autonomous defaults for Codex) | P4 |
| 2 | **Eval framework** — write evals, run with-skill vs baseline | Bash+jq scripts instead of Python. SKILL.md instructions for eval writing. | P2, P5 |
| 3 | **Grading system** — grade eval output against expectations | `grade-eval.sh` with deterministic string/regex/file checks | P2 |
| 4 | **Benchmark aggregation** — mean/stddev/delta statistics | `aggregate-benchmark.sh` producing benchmark.json | P2 |
| 5 | **JSON schemas** — evals.json, grading.json, benchmark.json, metrics.json, timing.json, history.json | `references/schemas.md` — drop Claude-specific fields, keep portable ones | P3 |
| 6 | **Description optimization** — train/test split, iterative trigger-accuracy improvement | SKILL.md workflow instructions + `optimize-description.sh` framework | P5 |
| 7 | **Iterative improvement loop** — improve→eval→grade→repeat | SKILL.md instructions (agent uses Task sub-agents on all harnesses) | P1 |
| 8 | **Skill writing guide** — progressive disclosure, principle of least surprise, communication style | Merge Anthropic's writing prose into our SKILL.md | P1 |

### ❌ Not Adopting (6 features)

| # | Anthropic Feature | Why Not |
|---|-------------------|---------|
| 1 | **`agents/` sub-agent .md files** (grader.md, analyzer.md, comparator.md) | OpenCode/Codex don't consume agent delegation files. Instructions inlined in SKILL.md instead. |
| 2 | **Blind A/B comparison** (`comparator.md` + `comparison.json`) | Requires spawning parallel sub-agents with isolated contexts — Codex can't do this reliably. Too complex for v1. |
| 3 | **`eval-viewer/` HTML app** (viewer.html + generate_review.py) | Requires Python + browser + `open` command. Markdown reports are more portable across terminal-based harnesses. |
| 4 | **`package_skill.py`** — package skill as downloadable .skill file | Claude.ai-specific (user downloads from web UI). Our skills are git-managed + symlinked — packaging is irrelevant. |
| 5 | **`present_files` tool usage** | Claude.ai-only tool. Not available on any of our three harnesses. |
| 6 | **Claude.ai + Cowork mode instructions** | Platform-specific sections. Our harnesses don't support these modes. |

### 🔮 Future Consideration (2 features)

| # | Anthropic Feature | When |
|---|-------------------|------|
| 1 | **Blind A/B comparison** | After v1 proves stable. Would require verifying sub-agent spawning works reliably on all three harnesses. |
| 2 | **HTML eval viewer** | If markdown reports prove insufficient. Could be added as optional `--html` flag on aggregate script. |

## Plan

- [x] **Phase 1: SKILL.md Rewrite** — Expand SKILL.md with Anthropic-inspired capabilities adapted for all three harnesses
- [x] **Phase 2: Eval Framework Scripts** — Add portable eval/benchmark/grading scripts (bash, not Python+Anthropic SDK)
- [x] **Phase 3: Reference Schemas** — Add `references/schemas.md` with JSON schemas for eval, grading, benchmark results
- [x] **Phase 4: Intent-Based Guided Interview** — Restructure the interview phase using harness-agnostic intent-based instructions (no tool-specific references) with autonomous-mode defaults
- [x] **Phase 5: Description Optimization Workflow** — Add description optimization instructions and supporting scripts
- [x] **Phase 6: Smoke Tests** — Expand `tests/smoke.sh` to cover all new scripts and validation paths
- [x] **Phase 7: Eval Cases** — Add new JSONL eval cases to `evals/skill-loading/opencode_skill_loading_eval_dataset.jsonl` for the upgraded skill
- [x] **Phase 8: Integration Validation** — Run full test battery and eval suite to confirm everything passes

---

## Phase Details

### Phase 1: SKILL.md Rewrite

Restructure SKILL.md into these sections (preserving existing frontmatter with `allowed-tools` and `context: fork`):

**Frontmatter changes:**
- Update `description` to include new trigger words: "eval", "benchmark", "optimize description", "improve skill", "measure performance"
- Add `allowed-tools: Read Write Edit Glob Grep Bash Task WebFetch` (unchanged)

**New/expanded sections:**

1. **Workflow Overview** — Decision tree: Create → Improve → Eval → Optimize Description
2. **Phase 1: Search Before Create** — Keep existing (already good)
3. **Phase 2: Adaptive Interview** — Rewrite using intent-based question pattern (see Phase 4 below)
4. **Phase 3: Generate Skill** — Keep existing scaffolding logic
5. **Phase 4: Validation Checklist** — Keep existing
6. **Phase 5: Eval Framework** (NEW) — Instructions for writing evals, running them, grading results
7. **Phase 6: Iterative Improvement** (NEW) — Improve→eval→grade loop adapted from Anthropic's workflow
8. **Phase 7: Description Optimization** (NEW) — Trigger-accuracy optimization workflow
9. **Phase 8: Benchmarking** (NEW) — With-skill vs without-skill comparison
10. **Quick Mode** — Keep existing
11. **Runtime Profiles** — Keep existing multi-harness documentation
12. **Reference Examples** — Update to point to schemas and templates

**Key adaptations from Anthropic:**
- Replace `agents/` sub-agent .md files with inline SKILL.md instructions (all harnesses can read SKILL.md)
- Replace Python scripts requiring Anthropic SDK with bash scripts using `Task` sub-agents
- Replace `present_files` references with harness-agnostic output instructions
- Add explicit Copilot and Codex compatibility notes

### Phase 2: Eval Framework Scripts

Create portable bash scripts in `scripts/`:

| Script | Purpose | Anthropic Equivalent |
|--------|---------|---------------------|
| `scripts/run-eval.sh` | Run a single eval case against a skill | `scripts/run_eval.py` |
| `scripts/grade-eval.sh` | Grade eval output against expectations | `agents/grader.md` |
| `scripts/aggregate-benchmark.sh` | Aggregate multi-run results with stats | `scripts/aggregate_benchmark.py` |
| `scripts/validate-runtime.sh` | Keep existing | (no equivalent) |

**Design principles:**
- All bash, no Python dependencies (Codex/Copilot don't guarantee Python env)
- Use `jq` for JSON processing (universally available)
- Scripts output JSON to stdout for composability
- Each script has `--help` and follows existing `set -euo pipefail` conventions
- Scripts are self-contained within the skill directory (symlink-safe)

**`scripts/run-eval.sh`:**
```
Usage: run-eval.sh --skill <path> --prompt <text> [--output-dir <dir>]
```
- Creates workspace directory
- Records start time
- Executes prompt against skill (via harness Task sub-agent or direct invocation)
- Captures output, timing, tool usage metrics
- Writes `outputs/`, `metrics.json`, `timing.json`

**`scripts/grade-eval.sh`:**
```
Usage: grade-eval.sh --run-dir <path> --expectations <json-array>
```
- Reads eval output from run directory
- Grades each expectation (pass/fail with evidence)
- Writes `grading.json` with pass rate, evidence, summary
- Deterministic grading: string matching, file existence, regex patterns

**`scripts/aggregate-benchmark.sh`:**
```
Usage: aggregate-benchmark.sh --results-dir <path> --skill-name <name>
```
- Reads all `grading.json` files from iteration directory
- Computes mean, stddev, min, max for pass_rate, time, tokens
- Groups by with_skill / without_skill configuration
- Writes `benchmark.json` and `benchmark.md` summary

### Phase 3: Reference Schemas

Create `references/schemas.md` adapted from Anthropic's version:

**Schemas to include:**
- `evals.json` — Eval case definitions (id, prompt, expected_output, expectations)
- `grading.json` — Grading output (expectations, summary, execution_metrics, timing)
- `metrics.json` — Execution metrics (tool_calls, total_steps, files_created)
- `timing.json` — Wall clock timing data
- `benchmark.json` — Aggregated benchmark results with statistics
- `history.json` — Iteration tracking for improve mode

**Adaptations:**
- Remove Claude-specific fields (`claims`, `user_notes_summary`, `eval_feedback`)
- Keep it runtime-agnostic
- Add harness-specific notes where relevant (e.g., "tool_calls keys vary by harness")

### Phase 4: Intent-Based Guided Interview

**Problem validated:** The three harnesses have fundamentally different question-asking mechanisms:

| Harness | Native Tool | Structured Choices? | Blocks for Answer? |
|---------|-------------|--------------------|--------------------|
| **OpenCode** | `question` (header + options + multiple) | ✅ Yes | ✅ Yes |
| **Copilot** | `ask_user` (question + choices) | ✅ Yes | ✅ Yes |
| **Codex** | **None** — no question tool exists | ❌ No | ⚠️ Only via conversational turn |

**Iron rule:** SKILL.md must NEVER reference specific tool names (`ask_user`, `question`). Skills are instructions read by the agent — the agent decides which tool to use based on what's available in its runtime. Tool-specific references become dead instructions on harnesses that lack that tool.

**Intent-based pattern (works on all three):**

The SKILL.md should use intent-based language that each harness's agent naturally maps to its native mechanism:

```markdown
## Interview (ask one question at a time, wait for each answer)

Before creating, gather these answers from the user. Ask one question at a time
and wait for the answer before proceeding to the next.

1. "What's the primary purpose of this skill?" — accept freeform answer
2. "What tools will it need?" — suggest: Bash, Read/Glob/Grep, WebFetch, Task, MCP tools
3. "Which runtime should this target?" — suggest: OpenCode, Codex, Copilot, All three
4. "Will it have executable scripts?" — suggest: Yes or No
5. "Should it include eval test cases?" — suggest: Yes (recommended) or No

**Context-aware shortcuts:**
- If the user's original request already answers a question, skip it
- If running in an autonomous/batch mode where questions would block,
  use sensible defaults and document assumptions made

**Defaults for autonomous mode:**
- Runtime: portable (safest default)
- Scripts: yes (if the user mentioned automation)
- Eval test cases: yes
- Tools: Read Glob Grep Bash (minimal safe set)
```

**How each harness handles this:**
- **OpenCode**: Agent sees "ask one question, suggest options" → uses its `question` tool with options array
- **Copilot**: Agent sees "ask one question, suggest options" → uses `ask_user` tool with choices array
- **Codex**: Agent sees "ask one question" → outputs question text, waits for next conversational turn; in autopilot mode → uses documented defaults

**Eval integration:**
- Existing check `should_ask_external_search: true` continues to work (tests intent, not tool)
- New eval cases should test: (a) questions are asked in interactive mode, (b) defaults are used in autonomous mode
- Eval grading checks for the *behavior* (did it ask?) not the *mechanism* (which tool?)

### Phase 5: Description Optimization Workflow

Add a description optimization section to SKILL.md, adapted from Anthropic's approach:

**Workflow (harness-agnostic):**

1. **Generate trigger queries** — Agent creates 20+ test queries: half should-trigger, half should-not-trigger
2. **User review** — Present queries for approval/editing via `ask_user`
3. **Optimization loop** — For each candidate description:
   - Test against query set (does the description trigger correctly?)
   - Score: true positive rate + true negative rate
   - Iterate up to 5 times, selecting best by held-out test score
4. **Apply result** — Update SKILL.md frontmatter with optimized description

**Script:** `scripts/optimize-description.sh`
```
Usage: optimize-description.sh --skill <path> --queries <json-file> [--iterations 5]
```
- Reads current description from SKILL.md frontmatter
- Runs trigger-matching simulation (keyword/semantic overlap scoring)
- Proposes improved descriptions via Task sub-agent
- Tracks results in `optimization-results.json`

**Note:** Full trigger-accuracy optimization requires the eval runner. This script provides the framework; actual triggering depends on the harness's skill-loading mechanism.

### Phase 6: Smoke Tests

Expand `tests/smoke.sh` to cover all new functionality:

```bash
# Existing tests (keep):
# Test 1: Validator help
# Test 2: Validate skill-creator (opencode)
# Test 3: Invalid runtime handling

# New tests:
# Test 4: run-eval.sh --help works
# Test 5: grade-eval.sh --help works
# Test 6: aggregate-benchmark.sh --help works
# Test 7: optimize-description.sh --help works
# Test 8: Validate skill-creator for codex runtime
# Test 9: Validate skill-creator for portable runtime
# Test 10: SKILL-TEMPLATE.md exists and has valid frontmatter
# Test 11: references/schemas.md exists and is non-empty
# Test 12: Grade a mock eval (create temp fixtures, grade, verify JSON output)
```

### Phase 7: Eval Cases

Add new JSONL eval cases to `evals/skill-loading/opencode_skill_loading_eval_dataset.jsonl`:

**New cases (following existing conventions):**

1. **`skill_creator_eval_request`** — "I have a skill that isn't working well. Can you help me write eval test cases for it and run them?"
   - `expected_skills_any_of: ["skill-creator"]`
   - `checks.required_phrases: ["I'm using the skill-creator skill"]`
   - Tests: eval framework activation

2. **`skill_creator_improve_existing`** — "My github-ops skill has low accuracy. Help me benchmark it and improve it."
   - `expected_skills_any_of: ["skill-creator"]`
   - Tests: improvement workflow activation

3. **`skill_creator_optimize_description`** — "The context7-docs skill doesn't trigger when users ask about library docs. Optimize its description for better triggering."
   - `expected_skills_any_of: ["skill-creator"]`
   - Tests: description optimization trigger

4. **`skill_creator_interview_questions`** — "Create a new skill for Kubernetes operations."
   - `expected_skills_any_of: ["skill-creator"]`
   - `checks.should_ask_external_search: true`
   - Tests: interview questions are asked (not skipped)

5. **`skill_creator_quick_all_runtimes`** — "Quick scaffold a skill called 'slack-notify' that works on all three runtimes."
   - `expected_skills_any_of: ["skill-creator"]`
   - Tests: quick mode + multi-runtime awareness

### Phase 8: Integration Validation

1. Run expanded smoke tests:
   ```bash
   bash skills/skill-creator/tests/smoke.sh
   ```

2. Run full test battery:
   ```bash
   bash scripts/test-battery.sh --filter skill-creator
   ```

3. Validate all existing eval cases still pass (no regressions):
   ```bash
   # Verify existing skill-creator eval cases parse correctly
   grep 'skill-creator' evals/skill-loading/opencode_skill_loading_eval_dataset.jsonl | python3 -c "import sys,json; [json.loads(l) for l in sys.stdin]; print('All valid')"
   ```

4. Validate the SKILL.md with the runtime validator for all supported runtimes:
   ```bash
   bash skills/skill-creator/scripts/validate-runtime.sh skills/skill-creator --runtime opencode
   bash skills/skill-creator/scripts/validate-runtime.sh skills/skill-creator --runtime codex
   bash skills/skill-creator/scripts/validate-runtime.sh skills/skill-creator --runtime portable
   ```

---

## File Change Summary

| File | Action | Description |
|------|--------|-------------|
| `skills/skill-creator/SKILL.md` | Rewrite | Expand from ~250 to ~500 lines with eval/improve/optimize sections |
| `skills/skill-creator/scripts/run-eval.sh` | Create | Portable eval runner |
| `skills/skill-creator/scripts/grade-eval.sh` | Create | Deterministic eval grader |
| `skills/skill-creator/scripts/aggregate-benchmark.sh` | Create | Benchmark aggregator with statistics |
| `skills/skill-creator/scripts/optimize-description.sh` | Create | Description optimization framework |
| `skills/skill-creator/scripts/validate-runtime.sh` | Keep | No changes needed |
| `skills/skill-creator/references/schemas.md` | Create | JSON schemas for eval/grading/benchmark |
| `skills/skill-creator/assets/SKILL-TEMPLATE.md` | Keep | No changes needed |
| `skills/skill-creator/tests/smoke.sh` | Expand | Add tests for all new scripts |
| `evals/skill-loading/opencode_skill_loading_eval_dataset.jsonl` | Append | Add 5 new eval cases |

## Constraints

- **Symlink safety:** All new files stay within `skills/skill-creator/`. No `../` escapes.
- **No Python dependencies:** Scripts use bash + jq only. No pip installs required.
- **No Anthropic SDK:** All Claude-specific code replaced with harness-agnostic alternatives.
- **Backward compatible:** Existing eval cases and smoke tests must still pass.
- **Progressive disclosure:** SKILL.md stays under 5,000 tokens. Heavy content in `references/` and `scripts/`.

## Decisions

- 2026-03-15 — Use bash+jq for scripts instead of Python — ensures Codex/Copilot compatibility without runtime dependencies
- 2026-03-15 — Inline sub-agent instructions in SKILL.md instead of separate `agents/*.md` files — all three harnesses read SKILL.md but not all support agent delegation files
- 2026-03-15 — Keep `validate-runtime.sh` unchanged — it's already unique value over Anthropic's version
- 2026-03-15 — Add eval cases to existing dataset (not a separate file) — matches existing eval framework conventions
- 2026-03-15 — Use intent-based question language, NOT tool-specific references — OpenCode has `question` tool, Copilot has `ask_user` tool, Codex has NO question tool at all. SKILL.md must say "ask the user" not "call ask_user". Each agent maps intent to its native mechanism.
- 2026-03-15 — Add autonomous-mode defaults for Codex — Codex runs with `approval_policy = "never"` and has no structured question tool. Skills must degrade gracefully by providing sensible defaults when questions would block execution.

## Discoveries

- 2026-03-15 — Anthropic's skill-creator uses `present_files` tool (Claude.ai only) and `cowork` mode — neither exists in OpenCode/Codex/Copilot. Must be replaced with file-write + user notification patterns.
- 2026-03-15 — Existing eval dataset already has 2 skill-creator cases (`scaffold_new_skill_jira`, `design_skill_without_saying_skill`) — new cases must not overlap with these.
- 2026-03-15 — Anthropic's `improve_description.py` requires the Anthropic Python SDK for LLM calls — must be reimplemented as SKILL.md instructions that use the harness's native Task/sub-agent mechanism instead.
- 2026-03-15 — **Critical tri-harness gap:** OpenCode's question tool uses `header`+`options`+`multiple` parameters. Copilot's ask_user uses `question`+`choices`+`allow_freeform` parameters. Codex has NO question tool — it relies on conversational turns. A SKILL.md that references any specific tool name will be dead instructions on at least one harness. Intent-based language is the only portable approach.
- 2026-03-15 — Codex config has `approval_policy = "never"` — meaning the agent executes autonomously by default. Any skill interview step that blocks on user input will cause Codex to either hang or skip. This is why autonomous-mode defaults are mandatory, not optional.
- 2026-03-15 — Only 1 existing eval case tests question-asking (`scaffold_new_skill_jira` with `should_ask_external_search: true`). The eval framework checks intent/behavior, not tool usage — which aligns perfectly with intent-based instructions.
