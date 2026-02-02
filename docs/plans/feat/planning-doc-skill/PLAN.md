# PLAN - planning-doc-skill

## PURPOSE (1-2 sentences)
Provide a planning-doc skill that creates or updates PLAN.md files based on branch naming, enforces non-main branch workflow, and standardizes plan structure for planning requests.

## STATUS UPDATES (append-only; newest first)
### 2026-02-02
Change:
- Moved PLAN.md steering instructions into the planning-doc SKILL.md and removed them from the template.

Behavior now:
- PLAN.md templates start directly with the title and plan content.
- Steering instructions live in `skills/planning-doc/SKILL.md`.

Validate:
- `rg -n "^# PLAN - <project/feature name>$" skills/planning-doc/references/plan-template.md` -> template starts with the title

Notes:
- None.

### 2026-02-02
Change:
- Added planning-doc skill, plan template reference, and initialized PLAN.md for this feature.

Behavior now:
- Skill directs agents to read PLAN.md first and derive `docs/plans/<prefix>/<feature>/PLAN.md` from branch name.
- Plan template is stored in `skills/planning-doc/references/plan-template.md` and used verbatim when creating a new plan.
- Existing PLAN.md files are updated (not overwritten) with append-only STATUS UPDATES.

Validate:
- `git status -sb` -> working tree clean

Notes:
- Packaging step skipped because init/package scripts are not present in this repo.

## PHASE PLAN (execute one phase at a time; becomes historical after complete)

### Phase 1 - Define skill requirements
Goal: Capture planning-doc behavior and template requirements.
Scope: Identify branch naming rules, plan location, and template structure.
Done when: Requirements are reflected in SKILL.md instructions and reference template.
Verify: `rg -n \"planning-doc\" skills/planning-doc/SKILL.md` -> expected guidance present
Notes: Keep SKILL.md concise; link to reference template for full content.

### Phase 2 - Implement skill resources
Goal: Create the skill directory, SKILL.md, and template reference file.
Scope: Add `skills/planning-doc/` with SKILL.md and `references/plan-template.md`.
Done when: Files exist with correct frontmatter and content.
Verify: `rg -n \"name: planning-doc\" skills/planning-doc/SKILL.md` -> match found
Notes: ASCII-only content unless required otherwise.

### Phase 3 - Seed feature PLAN.md
Goal: Create the plan file for the current feature branch.
Scope: Add `docs/plans/feat/planning-doc-skill/PLAN.md` from template.
Done when: PLAN.md exists with feature header and filled PURPOSE/STATUS.
Verify: `rg -n \"PLAN - planning-doc-skill\" docs/plans/feat/planning-doc-skill/PLAN.md` -> match found
Notes: Append-only STATUS UPDATES, newest first.

## DECISIONS (short; newest first)
- 2026-02-02 - Create the skill manually without init/package scripts - scripts were not present in the repo.

## DISCOVERIES / GOTCHAS (short; newest first)
- 2026-02-02 - `scripts/init_skill.py` and `scripts/package_skill.py` not found - manual skill creation required.
