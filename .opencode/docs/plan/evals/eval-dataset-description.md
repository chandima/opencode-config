I unpacked your zip and generated an **OpenCode skill-loading eval dataset** tailored to the skills and permissions in your `opencode.json`.

Key repo facts I used:

* Skills found: `context7-docs`, `github-ops`, `skill-creator`, `mcporter`, `security-auditor`, `asu-discover`
* Your `opencode.json` sets `permission.skill["*"]="allow"` **but** `permission.skill["asu-discover"]="deny"` → dataset includes *deny/forbidden* cases for `asu-discover` and otherwise ignores it.

This dataset is designed to be graded from OpenCode traces by checking whether the agent calls the **native `skill` tool** to load the right SKILL.md on demand (that’s how OpenCode skills work). ([OpenCode][1]) Permission/deny behavior is also explicitly testable via config. ([OpenCode][2])

---

## Download the dataset

[Download the JSONL eval dataset](./opencode_skill_eval_ts_runner_bundle/opencode_skill_loading_eval_dataset.jsonl)

**Size:** ~24KB, **Cases:** 60

Coverage breakdown:

* `github-ops`: 16
* `context7-docs`: 11
* `skill-creator`: 9
* `mcporter`: 8
* `security-auditor`: 7
* `negative/no-skill`: 6
* `permission/deny-skill` (asu-discover): 3

---

## Dataset schema

Each JSONL row looks like:

```json
{
  "id": "gh_release_draft_commands",
  "category": "github-ops/explicit",
  "prompt": "Using github-ops, draft commands to create a new GitHub Release ...",
  "expected_skills_any_of": ["github-ops"],
  "forbidden_skills": ["asu-discover"],
  "must_call_skill": true,
  "checks": {
    "forbid_tools": ["WebFetch"],
    "suggested_first_commands_regex": ["\\./scripts/.*\\.sh\\b", "\\bgh\\s+"]
  }
}
```

Field intent:

* **`expected_skills_any_of`**: at least one of these should be loaded via `skill({name})`
* **`forbidden_skills`**: must not be loaded (used for `asu-discover`)
* **`must_call_skill`**: whether any skill load is required
* **`checks`**: lightweight process assertions (phrases, regex for expected commands, required output file paths, etc.)

---

## How to run + grade (OpenCode-oriented)

You can run each prompt headlessly and capture tool calls via JSON output (OpenCode supports `opencode run --format json`). ([OpenCode][3])
OpenCode skills are loaded on-demand through the `skill` tool, so your grader just needs to parse the event stream and detect `tool_name == "skill"` plus the requested `name`. ([OpenCode][1])

---

## What’s “OpenCode-specific” about this dataset

* It assumes skills are **discoverable and loadable** via OpenCode’s **native `skill` tool** mechanism. ([OpenCode][1])
* It includes **permission-deny tests** for `asu-discover`, because OpenCode permissions control whether actions/tools/skills are allowed/asked/blocked. ([OpenCode][2])
* Prompts are written to match your skill intents:

  * `github-ops`: GitHub operations via `gh` / `./scripts/*.sh` (and “don’t WebFetch github.com” style constraints)
  * `context7-docs`: library/framework documentation via `./scripts/docs.sh search/docs`
  * `mcporter`: MCP discovery/list/call via `./scripts/mcporter.sh`
  * `security-auditor`: audit workflow that should produce `.opencode/docs/SECURITY-AUDIT.md`
  * `skill-creator`: includes the required announce phrase and “search before create” behavior

If you want, I can also generate:

* a **grader spec** (exact regexes + pass/fail logic per case),
* and a **runner script** template that executes `opencode run --format json` and computes recall/precision for each skill.

[1]: https://opencode.ai/docs/skills?utm_source=chatgpt.com "Agent Skills - opencode.ai"
[2]: https://opencode.ai/docs/permissions/?utm_source=chatgpt.com "Permissions - opencode.ai"
[3]: https://opencode.ai/docs/cli/?utm_source=chatgpt.com "CLI | OpenCode"
