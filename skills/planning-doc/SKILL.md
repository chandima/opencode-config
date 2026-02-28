---
name: planning-doc
description: "Create or update PLAN.md planning documents when users ask for a plan or planning. Use when asked to create a plan, planning document, or plan-based workflow."
allowed-tools: Bash(git:*) Read Glob Grep
context: fork
---

# Planning Doc

Create and maintain `PLAN.md` files tied to git branches. The plan serves two audiences:
- **Agent:** determine where things are at and continue from where they left off.
- **Human:** quickly see the plan, changes, and current status.

## Plan Steering

- Always read `PLAN.md` before making changes.
- On resumed sessions, read the latest **Status Updates** entry and run `git diff --stat` to detect drift.
- If the user says "continue", use the newest status update to determine what changed last and what to do next.
- Treat `PLAN.md` as a resume log, not a task tracker — keep entries short and factual.
- Use checkboxes in the **Plan** section to track progress.

## Workflow

1. Determine the current branch: `git rev-parse --abbrev-ref HEAD`.
2. If on the default branch (usually `main`):
   - Stop and prompt the user to create and check out a feature branch before proceeding.
3. Derive the plan path:
   - If the branch matches `^(feat|fix|chore)/(.+)$`, use prefix = match 1 and feature = match 2.
   - Otherwise use prefix = `feat` and feature = full branch name.
   - Plan path: `docs/plans/<prefix>/<feature>/PLAN.md`.
4. If PLAN.md does not exist:
   - Create directories and create the plan from `references/plan-template.md`.
   - Fill in the **Goal** and **Plan** sections based on the user request.
5. If PLAN.md exists:
   - Do not overwrite. Update checkboxes, append status updates.

## Updating PLAN.md

- After meaningful work, append a **Status Updates** entry (newest first):
  - **Change:** what changed
  - **State now:** what's true after this change
  - **Validate:** one command to verify
- Check off completed items in the **Plan** section.
- Add **Decisions** entries for notable tradeoffs.
- Add **Discoveries** entries for non-obvious findings or gotchas.

## Error Protocol

- Three-strike escalation for recurring failures:
  1. Diagnose and apply a targeted fix.
  2. Try a different approach (do not repeat the same failing action).
  3. Re-check assumptions and update the plan.
- After three failed attempts, escalate to the user with what was tried and the best next options.

## Validation

- Before claiming completion, run the `Validate:` command from the most recent status update.

## Resource

- Planning template: `references/plan-template.md`
