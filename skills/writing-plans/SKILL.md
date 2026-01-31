---
name: writing-plans
description: "Beads-first planning for multi-step work. Use when user asks to 'plan', 'create a plan', 'design', 'break down', or 'help me plan' a feature/task. Delegates to my-plan agent for plan creation using Beads."
allowed-tools: Read Glob Grep Bash Task
context: fork
---

# Writing Plans (Beads-first)

## Immediate Action Required

When this skill is loaded, you MUST delegate planning work to the `my-plan` agent.

**Do NOT attempt to create plans yourself.** The `my-plan` agent is the designated read-only planning agent that:
- Creates Beads epics and tasks with dependency-aware DAGs
- Produces a computed "Ready Queue" of unblocked work
- Never modifies code or uses OpenCode todos

**Delegation command:**
```
Use the Task tool to invoke the my-plan agent with the user's planning request.
```

If the user is already in the `my-plan` agent, proceed with the workflow below.

---

## Agent Routing

| Agent | When to Use | Capabilities |
|-------|-------------|--------------|
| **my-plan** | Planning phase | READ-ONLY. Creates Beads epics/tasks, builds dependency DAG, produces Ready Queue. Bash limited to bd/bdui only. |
| **my-plan-exec** | Implementation phase | Full access. Implements ready work, runs tests, verifies changes, prompts user to commit/push. |

**Workflow:**
```
my-plan (create plan) → user approval → my-plan-exec (implement, verify, commit, push)
```

**Key points:**
- Plan should be reviewed by user BEFORE execution begins
- `my-plan-exec` implements, verifies, and prompts user to commit/push

---

## Purpose

Turn multi-step work into a **Beads plan**: one Epic + a dependency-aware DAG of tasks with crisp acceptance criteria and a computed “Ready Queue”.

**No redundant artifacts:**
- Do **NOT** maintain `.opencode/docs/PLANNING.md`, archives, or sources indexes.
- Do **NOT** use OpenCode TodoWrite/TodoRead.
Beads is the single planning ledger.

This is designed to work with:
- **my-plan** (planning + Beads)
- **my-plan-exec** (implementation from ready work)

Beads integration is provided by `opencode-beads` (auto `bd prime`, `/bd-*`, and `beads-task-agent`). :contentReference[oaicite:2]{index=2}  
Optional UI via `beads-ui` (`bdui start --open`, board/epics/issues). :contentReference[oaicite:3]{index=3}

---

## Invocation & Guardrails

**Announce at start:** "I'm using the writing-plans skill (Beads-first). Delegating to my-plan agent."

**Hard requirement:** Planning work MUST be performed by the `my-plan` agent.
- If you are not the `my-plan` agent, delegate immediately using the Task tool.
- If the user is in any other agent (including built-in plan/build), instruct them to switch to `my-plan` or delegate the work.

**Allowed side effects:**
- Beads operations only (creating/updating issues, dependencies, statuses, notes).
- Optional: start `beads-ui`.

**Disallowed:**
- Editing repository files.
- OpenCode todo tooling.
- Creating separate plan documents unless the user explicitly requests a human-facing doc.

---

## Workflow (my-plan)

### 0) Prime context (every time)
The plugin auto-runs `bd prime` at session start, but if anything feels stale, run it directly:

```bash
bd prime
bd ready
```

### 1) Frame the request in one paragraph
Capture:
- Goal (what “done” looks like)
- Constraints (tech, time, compatibility)
- Out-of-scope items (explicitly)

Ask only **blocking** questions.

### 2) Create / identify the Epic
Create a Beads Epic that represents the user request.
- Keep title short.
- Put the “definition of done” in the epic description/notes.

### 3) Decompose into Beads tasks (right-sized)
Each task must have:
- **Acceptance criteria** (bullet list)
- Expected files/areas touched (paths OK, no edits yet)
- Verification notes (tests/commands to run later; do not run in my-plan)

Rule of thumb: tasks should be independently implementable + testable.

### 4) Add explicit dependencies (build the DAG)
Model prerequisites with dependency links so readiness is computable.
Use Beads relationship types intentionally:
- **blocks** for true prerequisites (affects ready work) :contentReference[oaicite:6]{index=6}
- **parent-child** for epic/task structure (affects ready work) :contentReference[oaicite:7]{index=7}
- **related** / **discovered-from** for context/audit trail (does not block) :contentReference[oaicite:8]{index=8}

### 5) Produce the Ready Queue (the only “plan output” you need)
In chat, output:
- Epic (name + ID)
- Task list (IDs) grouped by milestone/phase if useful
- Dependencies summary
- **Top 3–7 READY tasks** in recommended order
- Risks / unknowns (only if actionable)

### 6) Optional: launch the UI for shared planning
If the user wants a dashboard, run:
```bash
bdui start --open
```
Mention:
- Board view (Blocked / Ready / In progress / Closed)
- Epics view (progress rollups)

---

## Handoff rules (streamlined)

### Handoff to execution (my-plan → my-plan-exec)
When the user approves the plan, do **one** of the following:

**Option A (recommended):**
- Tell the user: "Switch to `my-plan-exec` and execute READY tasks for Epic <ID>, one at a time."

**Option B (autonomous execution):**
- Only if the user explicitly asks: delegate specific issues to `beads-task-agent`.