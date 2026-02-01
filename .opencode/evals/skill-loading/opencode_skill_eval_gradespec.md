# OpenCode Skill Loading Eval – Grading Spec

This suite evaluates **skill loading** in OpenCode: whether the agent selects and loads the correct `SKILL.md` using the native `skill` tool, and whether it follows the skill’s expected “signature” behaviors.

## What is considered “skill loading”?

A test counts as “loaded a skill” if the OpenCode JSON event stream contains a completed tool invocation where:

- `type == "tool_use"`
- `part.tool == "skill"`
- `part.state.input.name == "<skill-name>"`

This matches OpenCode’s Agent Skills model: skills are discovered and then loaded on-demand via the `skill` tool. See OpenCode docs: **Agent Skills** and **Permissions** (skill permission matches by skill name).

## Inputs and outputs

- **Input dataset**: JSONL. One row = one test case.
- **Runner**: `opencode_skill_eval_runner.mjs` (or `.ts` for source)
- **Outputs**:
  - Per-run `results.json` (structured results)
  - Per-run `junit.xml` (CI-friendly)
  - Combined `junit.all.xml` and `results.all.json`
  - `summary.json` with per-run precision/recall, confusion pairs, and per-skill stats

## Pass / fail rules (per test case)

Each case has:
- `must_call_skill` (bool)
- `expected_skills_any_of` (list[str])
- `forbidden_skills` (list[str])
- `checks` (dict)

### Tool call checks

**FAIL** if:
- Any tool in `checks.forbid_tools` is called (e.g., `webfetch`).
- Any skill in `forbidden_skills` or `checks.forbidden_skills` is loaded.
- `must_call_skill == true` but no `skill` tool call occurs.
- `checks.must_not_call_any_skill == true` but a `skill` load occurs.
- `checks.must_not_call_skills` contains any loaded skill name.

### Expected skill selection

If `expected_skills_any_of` is non-empty, **FAIL** unless at least one of those skills was loaded.

### Text “signature” checks

These checks look at the concatenated `text` events from the JSON stream. For command regex checks, the grader also includes `bash` tool inputs.

- `checks.required_phrases`: **ALL** phrases must appear (case-insensitive substring).
- `checks.required_commands_regex`: **ALL** regex patterns must match (assistant text + bash command inputs).
- `checks.suggested_first_commands_regex`: **ANY** regex must match (assistant text + bash command inputs).

### Permission-deny explanation

If `checks.should_explain_permission` is true, we require the output to mention **asu-discover** plus a deny/permission/block phrase.
(You can tighten this later based on your house style.)

### External search prompt (skill-creator)

If `checks.should_ask_external_search` is true, we require the output to ask about searching **external skill repositories** before creating a new skill.

### Required output files

If `checks.required_outputs_files` is present, **FAIL** unless each file exists and is non-empty **in the working directory where the run executed**.

> Note: the runner defaults to `--workdir copy`, so your real repo is not mutated.

## Agent/mode compatibility

Some cases require writing output files. The runner **SKIPs** any case that requires `required_outputs_files` when running with agent `plan`, because Plan is commonly configured as read-only / ask-to-edit.

This mirrors OpenCode’s built-in intent: Plan is for analysis without changes; Build is full access.

## Extending the grader

- Tighten regexes per case once you see stable outputs.
- Add “tool sequence” assertions (e.g., `context7-docs` should do `docs.sh search` then `docs.sh docs`) once you have stable tool traces.
- `optional_skills` are treated as allowed extra skills for diagnostics (not pass/fail).
