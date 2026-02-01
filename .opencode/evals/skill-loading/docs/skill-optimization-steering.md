# Skill Optimization Steering (Post-Eval Remediation)

Purpose: a practical playbook for refining SKILL.md files and supporting assets when evals show missed, wrong, or flaky skill invocation. Use this when a skill fails to load, triggers incorrectly, or produces unstable output.

This guidance assumes the Agent Skills open format (SKILL.md + optional scripts/references/assets) and model-driven skill selection based primarily on name/description metadata with progressive disclosure.

## 1) Quick triage (fast checks before editing)

1. Confirm the skill is discoverable
   - File location is correct for the target product (repo- or user-level skill directories).
   - `SKILL.md` exists and has valid YAML frontmatter.
   - `name` matches the folder name and is lowercase with hyphens only.

2. Validate structure
   - Run a spec validator if available (for example, skills-ref validate) to catch name/description issues.

3. Verify trigger signal
   - Compare the failing prompt against the skill `description`.
   - Ask: are the exact words a user would type present in `description`?

4. Check for conflicts
   - Scan other skills for overlapping keywords. If two skills match the same phrases, you will see wrong-skill triggers or nondeterminism.

5. Inspect environment assumptions
   - Does the skill assume a package manager, repo layout, or tool availability?
   - Are scripts referenced but missing, slow, or flaky?

## 2) Failure taxonomy -> likely root cause

A) Skill did not load
- Common causes: wrong path, missing/invalid frontmatter, name mismatch, invalid name format, missing keywords in description.
- Fix: correct file location; fix YAML frontmatter; align name with folder; tighten description with user vocabulary.

B) Wrong skill loaded
- Common causes: overlapping descriptions, broad or generic keywords.
- Fix: differentiate descriptions with unique trigger terms; add explicit negative boundaries ("Do NOT use for...") to the less appropriate skill; consider merging similar skills.

C) Skill loads but misses expected commands
- Common causes: instructions too loose, or scripts not emphasized.
- Fix: move fragile workflows into scripts; add explicit command templates or checklists for low-variance tasks.

D) Skill loads but output is off-spec
- Common causes: definition of done unclear, no examples, missing verification steps.
- Fix: add a short "Definition of done" section and one tight example; add validation loops (run -> verify -> fix).

E) Skill triggers too often
- Common causes: description too broad, no negative cues.
- Fix: remove generic terms, add negative examples, or set manual-only invocation if the workflow has side effects.

## 3) Description optimization (highest leverage)

The `description` is the primary selector for implicit invocation. Make it short, specific, and keyword-dense.

Checklist:
- Start with a task verb and concrete domain nouns.
- Include a "Use for X, Y, Z" phrase that mirrors user language.
- Avoid vague words like "helper", "tool", "general", "assistance".
- Keep it short enough that the trigger terms are not buried.
- Use third-person phrasing (not "I" or "you").

Pattern:
- "<Action> <domain object>. Use for <keywords a user would type>."

## 4) Structure for progressive disclosure

Keep the main `SKILL.md` lean and navigable. Move long reference content to `references/` and include short, explicit links in SKILL.md so the agent knows when to load them.

Guidelines:
- Put the trigger cues in the frontmatter `description`, not buried in body text.
- For complex workflows, add a short checklist in SKILL.md and link detailed steps elsewhere.
- If instructions exceed a few hundred lines, split into references.

## 5) Make execution deterministic when needed

If the workflow is fragile (deployments, audits, migrations), reduce degrees of freedom:
- Provide exact commands or scripts.
- Use "Do not modify" language for critical steps.
- Add explicit validation steps ("Run X, then confirm Y").

If the task is flexible (research, explanation), keep guidance higher level and avoid over-specifying.

## 6) Reduce ambiguity between skills

When two skills overlap, choose a primary and rewrite boundaries:
- Primary skill: keep positive trigger terms.
- Secondary skill: add "Do NOT use for ..." or exclude the primary's keywords.
- If overlap is strong, merge or split by domain (e.g., "github-ops" vs "security-auditor").

## 7) Remediation loop (eval-driven)

Use the eval failure as the next test case. Iterate in this order:

1. Reproduce the failure with a minimal prompt.
2. Adjust description and/or instructions.
3. Re-run the single failing case.
4. Update or add a dataset case to lock the fix.
5. Run the full suite to ensure no regressions.

## 8) Model-specific tuning

Skill effectiveness varies by model. If the same skill must work across multiple models:
- Keep descriptions crisp and direct.
- Use short, explicit steps for fragile tasks.
- Avoid over-explaining; models with stronger reasoning can ignore noise, weaker ones may get lost.

## 9) Safety and control

For high-risk workflows:
- Use minimal tool permissions (`allowed-tools`) where supported.
- Consider disabling model-initiated invocation and require explicit user invocation.
- Audit scripts and external references; avoid untrusted sources.

## 10) Remediation checklist (copy/paste)

- [ ] SKILL.md path is correct for the target product
- [ ] Frontmatter valid; name matches folder and naming rules
- [ ] Description contains user-typed keywords and "Use for" list
- [ ] Description avoids overlap with similar skills
- [ ] Instructions are concise; heavy detail moved to references
- [ ] Scripts exist and are referenced explicitly for fragile steps
- [ ] Clear definition of done + verification step
- [ ] Eval dataset includes explicit, implicit, and negative cases

## References (source material)

- https://smartscope.blog/en/blog/agent-skills-guide/
- https://agentskills.io/specification
- https://agentskills.io/what-are-skills
- https://developers.openai.com/codex/skills
- https://developers.openai.com/codex/guides/agents-md
- https://developers.openai.com/blog/eval-skills
- https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
- https://code.claude.com/docs/en/skills
- https://claude.com/blog/equipping-agents-for-the-real-world-with-agent-skills
- https://github.com/anthropics/skills
- https://github.com/openai/skills
- https://github.com/agentskills/agentskills
