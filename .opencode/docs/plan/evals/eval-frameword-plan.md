Below is a **practical, OpenCode-native eval framework** to test **skill discovery + skill loading + correct skill usage**—with an experiment matrix that helps you tell whether failures are **model routing**, **prompt harness**, or **skill packaging**.

---

## 0) What “skill loading” means in OpenCode (observable signals)

OpenCode skills are **discovered** from `SKILL.md` files and shown to the model as `<available_skills>` in the **`skill` tool description**; the agent **loads** one by calling `skill({ name: "…" })`. ([OpenCode][1])

So you can evaluate skill loading purely from traces:

* **Discovery present**: `<available_skills>` exists in the tool schema/description (or not, if disabled). ([OpenCode][1])
* **Attempted load**: model emits a `skill` tool call with a `name`. ([OpenCode][1])
* **Permission outcome**: `allow/ask/deny` patterns affect whether it loads or is hidden / blocked. ([OpenCode][1])
* **Downstream compliance**: the agent follows the loaded instructions to produce the right outputs.

You can collect all of this with **`opencode run --format json`** (“raw JSON events”) and/or via `opencode export` for full session data. ([OpenCode][2])

---

## 1) Define success: 4 score buckets (what you’ll measure)

Borrow the “outcome / process / style / efficiency” framing from systematic skill evals: ([OpenAI Developers][3])

### A) Process (skill routing + loading)

* **Invocation rate**: % of runs where the agent calls `skill(...)` when it *should*
* **False invocations**: % where it calls `skill(...)` when it *shouldn’t*
* **Correct skill selection**: skill name matches expected (or in an allowed set)
* **Time-to-load**: step count (or seconds) until the first `skill` call
* **Permission behavior**: respects `allow/ask/deny` and doesn’t “hallucinate” hidden skills ([OpenCode][1])

### B) Outcome (task success)

Task-specific deterministic checks (tests pass, file exists, expected diff, etc.).

### C) Style/Policy adherence (did it follow the skill’s rules)

E.g., formatting, required steps, safety constraints, commit message conventions.

### D) Efficiency / thrash

* tool-call count
* token usage (or proxy: message length / step count)
* repeated failed loads, loops

---

## 2) Build a **Skill Loading Benchmark** (dataset design)

Create a JSONL dataset where each item specifies:

* the **prompt**
* the **expected skill(s)** (or “none”)
* the **expected artifacts/commands** (optional)
* the **grading checks** to run

Example dataset item (JSONL):

```json
{
  "id": "git_release_001",
  "prompt": "We’re cutting a release. Draft release notes from merged PRs and propose a semver bump.",
  "expected_skills": ["git-release"],
  "forbidden_skills": [],
  "checks": {
    "must_call_skill": true,
    "must_include": ["release notes", "version bump"],
    "must_not_include": ["I can't access git history"]
  }
}
```

### Include 6 task families (to isolate failure modes)

1. **Obvious trigger** (high precision): prompt explicitly names the workflow (“use our release workflow”)
2. **Implicit trigger** (realistic routing): prompt implies it (“cut a release”)
3. **Near-miss / decoy**: prompt is adjacent but not the skill (“summarize PRs” vs “cut release”)
4. **Multi-skill choice**: prompt requires selecting one of several similar skills (tests description quality)
5. **Permission gating**: same task, but skill permission is `ask` or `deny` (tests safe fallback) ([OpenCode][1])
6. **Context pressure**: long repo context / distracting instructions (tests robustness; this is where routing often collapses—see Vercel’s findings about skills being skipped vs embedded instructions). ([Vercel][4])

---

## 3) Experiment matrix (the “ultrathink” part)

Run each dataset item across a grid to pinpoint what’s broken.

### Variables to sweep

**Harness**

* `opencode run` baseline
* `opencode run --agent plan` vs `--agent build` (Plan is more constrained; may reduce thrash and increase “think then load”) ([OpenCode][5])
* Skill tool disabled vs enabled (`tools.skill: false`) ([OpenCode][1])

**Instruction placement**

* Skill-only (no AGENTS guidance)
* AGENTS adds a single routing instruction (“If task matches, load skill tool first”)
* “AGENTS-index” style (docs/instructions embedded) baseline comparator (Vercel-style) ([Vercel][4])

**Permissions**

* `permission.skill["*"]=allow`
* `ask` for risky skills
* `deny` for internal skills (ensure they’re hidden) ([OpenCode][1])

**Model**

* Your top 2–4 models (routing quality varies hugely by model; this is often the real culprit)

### What the matrix tells you

* If **skill invocation jumps** with a small AGENTS routing hint → this is largely **prompt/harness**.
* If invocation is still low even with explicit hint → likely **model routing/tool-use weakness** (Vercel saw skills underperform even with explicit instructions). ([Vercel][4])
* If invocation is fine but outcomes are wrong → skill content quality / specificity.
* If permission settings change behavior unexpectedly → your permission patterns or naming collisions are wrong. ([OpenCode][1])

---

## 4) Runner architecture (OpenCode-native, trace-first)

### Option A: CLI runner (fastest to implement)

Use:

* `opencode run --format json` to capture raw event stream (tool calls + outputs) ([OpenCode][2])
* `opencode export <sessionId>` to fetch complete session JSON afterward ([OpenCode][2])

**Key grading inputs**

* Did the JSON stream include a `tool_name: "skill"` call?
* What `name` was requested?
* Did it succeed / was it blocked?

### Option B: Server + SDK (best for scale/CI)

* Run `opencode serve` ([OpenCode][6])
* Use the official JS/TS SDK to create sessions, stream events, and fetch artifacts ([OpenCode][7])

This is cleaner for parallelization + stable “seeded” infrastructure.

---

## 5) Scoring: deterministic + rubric (recommended split)

Following the evals pattern: combine **hard checks** + **light rubric**. ([OpenAI Developers][3])

### Deterministic checks (must-pass)

* `must_call_skill == true` → fail if no `skill` call
* `expected_skill in called_skills`
* `forbidden_skill not in called_skills`
* permission compliance: if denied, skill should not appear / should not load ([OpenCode][1])
* artifact checks: files changed, tests pass, etc.

### Rubric checks (judge or heuristic)

Score 1–5 for:

* “Did the output clearly follow the loaded workflow steps?”
* “Did it avoid unnecessary tool thrash?”
* “Did it ask clarifying questions when the skill instructs it to?” ([OpenCode][1])

---

## 6) Metrics & dashboards that actually diagnose routing

Track these per (model × harness × condition):

* **Skill Recall** = should-load & did-load / should-load
* **Skill Precision** = did-load & should-load / did-load
* **Top confusion pairs** (expected skill A, loaded skill B)
* **Load latency** (median steps before `skill`)
* **Outcome pass rate** conditional on load vs no-load (tells you if the skill *helps*)
* **Permission correctness** (deny skills hidden; ask triggers approval flow) ([OpenCode][1])

This immediately answers: “Are we failing because we didn’t load, or because loading doesn’t help?”

---

## 7) Remediation tactics you can A/B within the framework

These are the levers your eval will validate:

### Skill packaging fixes (often the biggest win)

* Make `description` highly “routable”: include user phrasing + concrete triggers (OpenCode says keep it specific enough for the agent to choose correctly). ([OpenCode][1])
* Avoid overlapping names/descriptions across skills (confusion matrix will show collisions)
* Add an explicit “When to use me / When not to use me” section inside the skill

### Harness fixes (routing nudges)

* Add one small AGENTS rule: “If task matches a listed skill, load it before acting.”
* Consider forcing Plan mode for classification-heavy tasks before Build execution (Plan is restricted and encourages analysis-first). ([OpenCode][5])

### Permission design

* Start with permissive (`allow`) during development evals, then tighten to `ask/deny` once routing is stable. ([OpenCode][1])

---

## 8) Minimal “starter kit” you can implement in a day

1. Build `skills_eval.jsonl` (50–200 cases across the 6 families)
2. Write a runner that:

   * executes `opencode run --format json --title <id> "<prompt>"` ([OpenCode][2])
   * parses tool calls; records `called_skills[]`
3. Add checkers:

   * deterministic (JSON fields)
   * rubric (LLM-judge or simple heuristics)
4. Run the experiment matrix nightly; gate merges on:

   * Skill Recall ≥ X
   * Precision ≥ Y
   * No regressions in confusion pairs

---

If you want, paste **one or two of your real OpenCode skills** (just the YAML frontmatter + description + “when to use”) and I’ll generate:

* a **50-case eval dataset** tailored to them (with near-misses + decoys),
* the **matrix** you should run first,
* and a **scoring spec** that will surface whether the issue is *routing vs skill quality vs permissions*.

[1]: https://opencode.ai/docs/skills "Agent Skills | OpenCode"
[2]: https://opencode.ai/docs/cli/ "CLI | OpenCode"
[3]: https://developers.openai.com/blog/eval-skills "Testing Agent Skills Systematically with Evals"
[4]: https://vercel.com/blog/agents-md-outperforms-skills-in-our-agent-evals?utm_source=chatgpt.com "AGENTS.md outperforms skills in our agent evals - Vercel"
[5]: https://opencode.ai/docs/agents/ "Agents | OpenCode"
[6]: https://opencode.ai/docs/server/ "Server | OpenCode"
[7]: https://opencode.ai/docs/sdk/ "SDK | OpenCode"
