---
name: writing-plans
description: "Use when planning multi-step tasks. Invoke in Plan mode (Tab) for research/iteration, then Build mode to save. Also use to update existing plans."
allowed-tools: Read Write Edit Glob Grep Bash Task
context: fork
---

# Writing Plans

## Overview

Write implementation plans optimized for agentic execution. Plans should contain everything needed to implement without re-research: key decisions, schemas, code examples, file paths, and test criteria.

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

**Save plans to:** `docs/plans/YYYY-MM-DD-<feature-name>.md`

## OpenCode Integration

### Plan Mode (Tab to toggle)

When in Plan mode (READ-ONLY):
- Research codebase, gather context
- Propose architecture verbally
- Iterate based on user feedback
- DO NOT create/modify files

### Transition to Build Mode

When user says "Go ahead" or toggles to Build:
1. Save plan to `docs/plans/YYYY-MM-DD-<feature>.md`
2. Initialize changelog with v1.0
3. Archive any research sources
4. Update AGENTS.md if planning decisions affect project conventions
5. Create TodoWrite tasks from phases

### Updating Existing Plans

On skill load, check for existing plans:
```bash
ls docs/plans/*.md 2>/dev/null
```

If plan exists and user intent is to modify:
1. Read current plan
2. Identify changes needed
3. Update relevant sections
4. Append changelog entry (increment version)

## Plan Document Header

**Every plan MUST start with:**

```markdown
# [Feature Name] Implementation Plan

**Version:** v1.0 | **Updated:** YYYY-MM-DD

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

**Sources:** `archive/sources.md` | [SRC-001], [SRC-002]

---
```

## Changelog

Track major plan changes with semantic versioning:

```markdown
## Changelog

| Version | Date | Source | Summary |
|---------|------|--------|---------|
| v1.0 | 2026-01-25 | Plan mode | Initial plan |
| v1.1 | 2026-01-25 | User feedback | Added rate limiting to auth phase |
| v2.0 | 2026-01-26 | SRC-003 | Restructured to microservices |
```

**Source types:**
- `Plan mode` - Created during planning session
- `User feedback` - TUI conversation updates
- `SRC-XXX` - Based on archived research
- `Implementation` - Discovered during build

**Version rules:**
- v1.0 → v1.1: Minor additions/clarifications
- v1.x → v2.0: Major restructure or scope change

## Key Decisions Table

For significant technology choices, include a decision table:

```markdown
## Key Decisions

| Decision | Choice | Rationale | Alternatives Rejected |
|----------|--------|-----------|----------------------|
| [Category] | [Selected option] | [Why this fits] | [Option A (reason)], [Option B (reason)] |

**Sources:** [SRC-001], [SRC-002] - see `archive/sources.md`
```

**When to include:**
- Technology stack choices (database, framework, model)
- Architecture patterns (sync vs async, monolith vs services)
- Significant tradeoffs (cost vs performance)

## Source Document Archiving

**Never delete source documents.** When consolidating research, preserve originals.

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

Organize work into phases with clear deliverables and test criteria:

```markdown
## Phase N: [Phase Name]

**Deliverables:**
- [ ] `path/to/file.ts` - Description
- [ ] `path/to/test.ts` - Test coverage

**Schema/Types:** (if applicable)
```typescript
interface Example {
  id: string;
  name: string;
}
```

**Code Example:**
```typescript
export function example(): Example {
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

## What to Include

| Element | Why It Matters |
|---------|----------------|
| Key Decisions table | Prevents re-research |
| Database schemas | Exact SQL/types to execute |
| Code examples | Reference implementations |
| Exact file paths | Know where to create/modify |
| Test commands | Verification criteria |
| Commit messages | Consistent git history |

## What NOT to Include

- Micro-steps like "run test, verify it fails" - agent handles naturally
- Overly granular 2-5 minute human-paced steps
- References to non-existent skills

## Task Granularity

**Right-sized for agents:**
- One phase = one logical unit of work
- Phase contains all files, schemas, examples needed
- Test criteria defines "done"
- Commit message provided

**Example:**
```markdown
## Phase 2: User Authentication

**Deliverables:**
- [ ] `src/auth/service.ts` - Auth service with login/logout
- [ ] `src/auth/middleware.ts` - JWT validation middleware
- [ ] `tests/auth/service.test.ts` - Unit tests

**Test Criteria:** `npm test -- auth` passes

**Commit:** `feat(auth): add authentication service`
```

## Remember

- Exact file paths always
- Complete code examples (not "add validation here")
- Test commands with expected output
- Reference skills with `@skills/skill-name`
- Archive sources, document decisions
- Phases map to TodoWrite items
- **Update changelog on major changes**
- **Update AGENTS.md if conventions change**

## AGENTS.md Updates

Planning decisions may establish conventions that should be documented in AGENTS.md. After finalizing a plan, check if updates are needed.

### Find the Relevant AGENTS.md

Search from current directory upward to git root:
```bash
# Find closest AGENTS.md in hierarchy
find . -maxdepth 3 -name "AGENTS.md" -o -name "CLAUDE.md" 2>/dev/null | head -1
```

Hierarchy (most specific wins):
1. `./AGENTS.md` - Current directory
2. `../<parent>/AGENTS.md` - Parent directories
3. Root `AGENTS.md` - Project-wide conventions

### When to Update

Update AGENTS.md if the plan establishes:

| Decision Type | AGENTS.md Section |
|---------------|-------------------|
| New naming conventions | Conventions |
| New file/folder structure | Repository Structure |
| New testing patterns | Testing |
| New tool/command usage | Available Commands |
| New skill conventions | Skill Conventions |
| Architecture patterns | Architecture |

### What to Add

Keep updates minimal and focused:

```markdown
## [Section Name]

### [Convention Name] (added YYYY-MM-DD)

[Brief description of the convention]

**Rationale:** [Link to plan] `docs/plans/YYYY-MM-DD-feature.md`
```

### What NOT to Add

- Implementation details (belong in plan, not AGENTS.md)
- Temporary decisions (only permanent conventions)
- Feature-specific logic (belongs in code/docs)

### Example Update

If plan establishes a new API versioning convention:

```markdown
## API Conventions

### Versioning (added 2026-01-25)

All API endpoints use URL path versioning: `/api/v1/`, `/api/v2/`

**Rationale:** `docs/plans/2026-01-25-api-versioning.md`
```

## Execution

After saving the plan:

1. Use `TodoWrite` to create tasks from phases
2. Execute phases sequentially
3. Run test criteria after each phase
4. Commit after each phase passes
5. Update plan changelog if scope changes during build
