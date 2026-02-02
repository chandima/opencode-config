## Planning protocol (PLAN.md is the source of truth)
- Always read `PLAN.md` before making changes.
- If the user says "continue", use the newest entry in **STATUS UPDATES** to determine:
  - what changed last,
  - current intended behavior ("Behavior now"),
  - and how to validate ("Validate" command).
- Treat `PLAN.md` as a *resume log*, not a task tracker:
  - Do NOT add TODO lists, checkboxes, or task-management structures.
  - Keep entries short and factual.

## Updating PLAN.md (required when you change behavior)
- After completing meaningful work, append a new **STATUS UPDATES** entry (newest first) using the template fields:
  - Change
  - Behavior now
  - Validate (one command; two max if needed: quick/full)
  - Notes (optional)
- If you make a notable tradeoff, add a one-line entry to **DECISIONS**.
- If you discover a pitfall or non-obvious constraint, add a one-line entry to **DISCOVERIES / GOTCHAS**.

## Validation
- Before claiming completion, run the `Validate:` command from the most recent STATUS UPDATE.
- Prefer minimal command output in chat (summarize; do not paste huge logs unless asked).

---

# PLAN - planning-doc-skill

## PURPOSE (1-2 sentences)
What "done" looks like for users/CI.

## STATUS UPDATES (append-only; newest first)
### YYYY-MM-DD
Change:
- <one-line summary of what changed>

Behavior now:
- <what's true now / contract / invariant (1-3 bullets max)>

Validate:
- `<command>` -> <expected outcome>

Notes:
- <gotcha / risk / rollback hint (optional; 1 bullet)>

### YYYY-MM-DD
...

## PHASE PLAN (execute one phase at a time; becomes historical after complete)

### Phase 1 - <name>
Goal: ...
Scope: ...
Done when: ...
Verify: `<command>` -> <expected>
Notes: ...

### Phase 2 - <name>
...

### Phase 3 - <name>
...

## DECISIONS (short; newest first)
- YYYY-MM-DD - <decision> - <rationale>

## DISCOVERIES / GOTCHAS (short; newest first)
- YYYY-MM-DD - <gotcha> - <symptom + fix/avoidance>
