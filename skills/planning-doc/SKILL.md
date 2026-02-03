---
name: planning-doc
description: "Create or update PLAN.md planning documents when users ask for a plan or planning. Use when asked to create a plan, planning document, or plan-based workflow."
allowed-tools: Bash(git:*) Read Glob Grep
context: fork
---

# Planning Doc

## Plan steering

- Always read `PLAN.md` before making changes.
- If the user says "continue", use the newest entry in **STATUS UPDATES** to determine:
  - what changed last,
  - current intended behavior ("Behavior now"),
  - and how to validate ("Validate" command).
- Treat `PLAN.md` as a resume log, not a task tracker:
  - Do NOT add TODO lists, checkboxes, or task-management structures inside **STATUS UPDATES**.
  - Checklists are allowed only in dedicated sections like **Gap Report**, **Workstreams**, or **Discovery** when the user provided that structure.
  - Keep entries short and factual.
  - Preserve user-provided structure if it's already effective; do not forcibly reformat it into the template.

## Workflow

1. Determine the current branch: `git rev-parse --abbrev-ref HEAD`.
2. If on the default branch (usually `main` or the branch pointed to by `refs/remotes/origin/HEAD`):
   - Stop and prompt the user to create and check out a feature branch before proceeding.
   - Use the git skill or git commands to guide branch creation.
3. Derive the plan path:
   - If the branch matches `^(feat|fix|chore)/(.+)$`, use prefix = match 1 and feature = match 2.
   - Otherwise use prefix = `feat` and feature = full branch name.
   - Plan path: `docs/plans/<prefix>/<feature>/PLAN.md`.
4. If PLAN.md does not exist:
   - Create directories and create the plan from `references/plan-template.md`.
   - Replace the header placeholder with the feature name.
   - Fill in PURPOSE and the PHASE PLAN based on the user request.
   - Add optional sections (Goal, References, Scope, Current Baseline, Definition of Done, Open Questions, Change Log, Test Results, Gap Report, Workstreams) if they help the request.
5. If PLAN.md exists:
   - Do not overwrite. Add to the plan for the current feature.
   - Append or refine the PHASE PLAN as needed; keep STATUS UPDATES newest-first.
   - Add optional sections if missing and clearly useful for the plan's intent (parity/migration, audits, or multi-workstream work).

## Updating PLAN.md

- After completing meaningful work, append a new **STATUS UPDATES** entry (newest first) using the template fields:
  - Change
  - Behavior now
  - Validate (one command; two max if needed: quick/full)
  - Notes (optional)
- If you make a notable tradeoff, add a one-line entry to **DECISIONS**.
- If you discover a pitfall or non-obvious constraint, add a one-line entry to **DISCOVERIES / GOTCHAS**.
 - Record executed validation results in **TEST RESULTS** (dated) when applicable.

## Validation

- Before claiming completion, run the `Validate:` command from the most recent STATUS UPDATE.
- Prefer minimal command output in chat (summarize; do not paste huge logs unless asked).

## TDD

- For non-trivial tasks, follow the repository TDD protocol: write a failing test first, then implement the minimal change, then refactor.

## Resource

- Planning template: `references/plan-template.md` (use this file verbatim as the starting point)
