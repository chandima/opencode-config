# Skill Testcase Steering (Agent Skills)

Purpose: provide a durable rubric for writing **skill-loading eval cases** that reflect how skills are supposed to be discovered and activated in real use. This is the reference to use whenever new skills are added to this repo.

## Source grounding (short)

Agent Skills are directories that include a `SKILL.md` file plus optional scripts/resources, and are intended to be discovered and loaded dynamically to improve task performance.
`SKILL.md` requires YAML frontmatter with `name` and `description`. The description should say **what the skill does and when to use it**.
Progressive disclosure: skill metadata is loaded up front, the full `SKILL.md` is loaded when the skill is activated, and additional files are loaded only when needed.
Optional directories (`scripts/`, `references/`, `assets/`) exist to support execution, deeper docs, and templates; scripts should be self-contained and handle edge cases gracefully.

## Principles for writing eval cases

1) **Natural routing over obedience**
   Test whether the model chooses to load a skill because the description aligns with the user request, not because the prompt says "use skill X." Use explicit prompts only when you are specifically testing explicit routing compliance.

2) **Mirror progressive disclosure**
   Prompts should trigger the skill based on metadata keywords ("when to use"), then rely on the skill's own instructions for actions or commands. This matches how skills are designed to load on demand.

3) **Tooling realism**
   If a skill has scripts, the expected behavior should be to run the skill's script(s) rather than invent ad-hoc commands. This aligns with the skill structure in the spec (scripts are the executable interface).

4) **Explicit denial handling**
   When a skill is denied by permissions, the correct behavior is to name the denied skill and explain the limitation, then offer a safe alternative workflow.

5) **Determinism vs. realism**
   - Baseline suite should be realistic (no skill-steering guard).
   - Optional harnesses can be used for diagnostics, but must not replace the natural-routing baseline.

## Coverage checklist (use for every new skill)

For each new skill, add at least 4 cases:

- **Explicit**: user directly asks for the skill or names it.
- **Implicit**: user asks for the task without naming the skill.
- **Near-miss**: similar request that should NOT load the skill.
- **Negative**: general question where no skill should load.

If the skill has permission constraints or denial rules, add:
- **Denied**: user requests a denied skill; must explain denial and not load it.

If the skill writes artifacts:
- **Output artifact**: ensure required output file(s) exist and are non-empty.

## Prompt design rules

- Include "when to use" trigger language that appears in the skill's `description` (metadata) for explicit/implicit cases.
- Avoid telling the model how to route in baseline tests. The description should drive routing.
- Prefer single intent prompts to reduce ambiguity.
- For multi-skill scenarios, explicitly require only one of them, and mark others as forbidden/allowed extras.

## Case taxonomy (recommended categories)

- `explicit/<skill>`: user names the skill.
- `implicit/<skill>`: user describes task only.
- `near-miss/<skill>`: close but should not load.
- `negative/no-skill`: generic question, no skill.
- `permission/deny-skill`: denied skill, require explanation.
- `multi/<skill>`: overlapping skills; ensure correct one.

## Dataset field guidance (JSONL)

Use these fields consistently in each case:

- `id`: kebab case, stable.
- `category`: one of the taxonomy labels above.
- `prompt`: natural user request.
- `expected_skills_any_of`: list (can be empty).
- `forbidden_skills`: list (can be empty).
- `must_call_skill`: `true` only when skill loading is required.
- `checks`:
  - `must_not_call_any_skill`
  - `must_not_call_skills`
  - `required_phrases`
  - `required_commands_regex`
  - `suggested_first_commands_regex`
  - `should_explain_permission`
  - `required_outputs_files`

## Example templates

### Explicit (skill named)
```
prompt: "Use <skill-name> to <task>."
expected_skills_any_of: ["<skill-name>"]
must_call_skill: true
```

### Implicit (no skill name)
```
prompt: "How do I <task>?"
expected_skills_any_of: ["<skill-name>"]
must_call_skill: true
```

### Near-miss (avoid skill)
```
prompt: "Explain <related concept>."
expected_skills_any_of: []
must_call_skill: false
checks: { must_not_call_any_skill: true }
```

### Denied skill (permission)
```
prompt: "Use <denied-skill> to <task>."
forbidden_skills: ["<denied-skill>"]
checks: { must_not_call_skills: ["<denied-skill>"], should_explain_permission: true }
```

## What "good" looks like

OK: Skill is loaded because the description matches the request (natural routing).
OK: For scripted skills, the model uses the skill's scripts, not custom commands.
OK: Denied skills are named and explained; alternatives offered.
OK: Negative cases do not load skills.

## What "bad" looks like

BAD: Skill loads only when prompted explicitly to do so.
BAD: Ad-hoc commands are used despite scripts existing.
BAD: Denied skills are ignored or mentioned without permission reasoning.
