---
name: planning-doc
description: "Create or update PLAN.md planning documents when users ask for a plan or planning. Use when asked to create a plan, planning document, or plan-based workflow."
allowed-tools: Bash(git:*) Read Glob Grep
context: fork
---

# Planning Doc

## Workflow

1. Always read the current PLAN.md first (if it exists). It is the source of truth.
2. Determine the current branch: `git rev-parse --abbrev-ref HEAD`.
3. If on the default branch (usually `main` or the branch pointed to by `refs/remotes/origin/HEAD`):
   - Stop and prompt the user to create and check out a feature branch before proceeding.
   - Use the git skill or git commands to guide branch creation.
4. Derive the plan path:
   - If the branch matches `^(feat|fix|chore)/(.+)$`, use prefix = match 1 and feature = match 2.
   - Otherwise use prefix = `feat` and feature = full branch name.
   - Plan path: `docs/plans/<prefix>/<feature>/PLAN.md`.
5. If PLAN.md does not exist:
   - Create directories and create the plan from `references/plan-template.md`.
   - Replace the header placeholder with the feature name.
   - Fill in PURPOSE and the PHASE PLAN based on the user request.
6. If PLAN.md exists:
   - Do not overwrite. Add to the plan for the current feature.
   - Append or refine the PHASE PLAN as needed; keep STATUS UPDATES newest-first.
7. When you complete meaningful work, append a STATUS UPDATES entry (newest first) and run the latest Validate command before claiming completion.
8. Before stopping, update DECISIONS or DISCOVERIES / GOTCHAS if any new tradeoffs or surprises occurred.

## Resource

- Planning template: `references/plan-template.md` (use this file verbatim as the starting point)
