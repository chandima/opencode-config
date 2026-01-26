---
name: writing-plans
description: Use when you have a spec or requirements for a multi-step task, before touching code. Creates agent-native implementation plans with phases, deliverables, and test criteria.
allowed-tools: Read Write Edit Glob Grep Bash Task
context: fork
---

# Writing Plans

## Overview

Write implementation plans optimized for agentic execution. Plans should contain everything needed to implement without re-research: key decisions, schemas, code examples, file paths, and test criteria.

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

**Save plans to:** `docs/plans/YYYY-MM-DD-<feature-name>.md`

## Plan Document Header

**Every plan MUST start with this header:**

```markdown
# [Feature Name] Implementation Plan

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

**Sources:** `archive/sources.md` | [SRC-001], [SRC-002]

---
```

## Key Decisions Table

For significant technology choices, include a decision table. This prevents re-research by capturing rationale upfront.

```markdown
## Key Decisions

| Decision | Choice | Rationale | Alternatives Rejected |
|----------|--------|-----------|----------------------|
| [Category] | [Selected option] | [Why this fits requirements] | [Option A (reason)], [Option B (reason)] |

**Sources:** [SRC-001], [SRC-002] - see `archive/sources.md`
```

*Example:*
| Database | PostgreSQL | ACID compliance needed, team expertise | MongoDB (no transactions), SQLite (scaling concerns) |

**When to include:**
- Technology stack choices (database, framework, model)
- Architecture patterns (sync vs async, monolith vs services)
- Significant tradeoffs (cost vs performance)

**Skip when:**
- Simple plans following established patterns
- No major choices to document

## Source Document Archiving

**Never delete source documents.** When consolidating research into a plan, preserve originals.

**Archive Structure:**
```
docs/plans/
├── YYYY-MM-DD-feature-name.md       # Active plan
└── archive/                          # Source documents
    ├── sources.md                    # Index with key findings
    └── {date}-{description}.md       # Original research docs
```

**Source Index Format (`archive/sources.md`):**
```markdown
# Source Documents

| ID | Title | Type | Date | Key Findings |
|----|-------|------|------|--------------|
| SRC-001 | [Research topic] | research | YYYY-MM-DD | [Key insight 1]; [Key insight 2] |
```

## Phase Structure (Agent-Native)

Organize work into phases with clear deliverables and test criteria. Each phase maps to a TodoWrite milestone.

```markdown
## Phase N: [Phase Name]

**Deliverables:**
- [ ] `path/to/file.ts` - Description of what it does
- [ ] `path/to/test.ts` - Test coverage for above

**Schema/Types:** (if applicable)
```typescript
interface Example {
  id: string;
  name: string;
}
```

**Code Example:** (reference implementation)
```typescript
export function exampleFunction(): Example {
  return { id: "1", name: "test" };
}
```

**Test Criteria:**
```bash
npm test -- --grep "example"
# Expected: All tests pass
```

**Commit:** `feat: add example functionality`
```

## What to Include in Plans

| Element | Why It Matters |
|---------|----------------|
| Key Decisions table | Prevents re-research |
| Database schemas | Exact SQL/types to execute |
| Code examples | Reference implementations |
| Exact file paths | Know where to create/modify |
| Test commands | Verification criteria |
| Commit messages | Consistent git history |

## What NOT to Include

- Micro-steps like "run test, verify it fails, then implement" - agent handles this naturally
- References to non-existent sub-skills or worktrees
- Overly granular 2-5 minute human-paced steps
- Execution mode choices (agent executes directly)

## Task Granularity

**Right-sized for agents:**
- One phase = one logical unit of work (feature, component, integration)
- Phase contains all files, schemas, examples needed
- Test criteria defines "done"
- Commit message provided

**Too granular (avoid):**
```markdown
Step 1: Write failing test
Step 2: Run test to verify failure
Step 3: Write implementation
Step 4: Run test to verify pass
Step 5: Commit
```

**Right-sized:**
```markdown
## Phase 2: User Authentication

**Deliverables:**
- [ ] `src/auth/service.ts` - Auth service with login/logout
- [ ] `src/auth/middleware.ts` - JWT validation middleware  
- [ ] `tests/auth/service.test.ts` - Unit tests

**Code Example:** [complete implementation]

**Test Criteria:** `npm test -- auth` passes

**Commit:** `feat(auth): add authentication service`
```

## Remember

- Exact file paths always
- Complete code examples (not "add validation here")
- Test commands with expected output
- Reference relevant skills with `@skills/skill-name`
- Archive sources, document decisions
- Phases map to TodoWrite items

## Execution

After saving the plan:

1. Use `TodoWrite` to create tasks from phases
2. Execute phases sequentially
3. Run test criteria after each phase
4. Commit after each phase passes

The agent executes the plan directly using the Task tool for complex phases or inline for simple ones.
