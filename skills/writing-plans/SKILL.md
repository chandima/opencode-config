---
name: writing-plans
description: Use when you have a spec or requirements for a multi-step task, before touching code
---

# Writing Plans

## Overview

Write comprehensive implementation plans assuming the engineer has zero context for our codebase and questionable taste. Document everything they need to know: which files to touch for each task, code, testing, docs they might need to check, how to test it. Give them the whole plan as bite-sized tasks. DRY. YAGNI. TDD. Frequent commits.

Assume they are a skilled developer, but know almost nothing about our toolset or problem domain. Assume they don't know good test design very well.

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

**Context:** This should be run in a dedicated worktree (created by brainstorming skill).

**Save plans to:** `docs/plans/YYYY-MM-DD-<feature-name>.md`

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):**
- "Write the failing test" - step
- "Run it to make sure it fails" - step
- "Implement the minimal code to make the test pass" - step
- "Run the tests and make sure they pass" - step
- "Commit" - step

## Plan Document Header

**Every plan MUST start with this header:**

```markdown
# [Feature Name] Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

**Sources:** `archive/sources.md` | [SRC-001], [SRC-002]

---
```

## Source Document Archiving

**Never delete source documents.** When consolidating research into a plan, preserve original source documents for future reference.

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
| SRC-002 | [Design discussion] | design | YYYY-MM-DD | [Architecture decision]; [Deployment approach] |
```

*Example: `SRC-001 | Auth Provider Research | research | 2025-01-20 | OAuth2 preferred over SAML; Auth0 best for MVP`*

**Source Preservation Policy:**
1. Move original research docs to `archive/`
2. Create `archive/sources.md` index with key findings
3. Reference sources in plan header and decision table
4. Keep archives even after plan completion

## Key Decisions Table

For significant technology choices, include a decision table in the plan. This prevents "decision amnesia" where rationale is lost after consolidation.

```markdown
## Key Decisions

| Decision | Choice | Rationale | Alternatives Rejected |
|----------|--------|-----------|----------------------|
| [Category] | [Selected option] | [Why this fits requirements] | [Option A (reason)], [Option B (reason)] |

**Sources:** [SRC-001], [SRC-002] - see `archive/sources.md`
```

*Example:*
| Database | PostgreSQL | ACID compliance needed, team expertise | MongoDB (no transactions), SQLite (scaling concerns) |
| Auth | OAuth2 + PKCE | Industry standard, mobile-friendly | Session cookies (no SPA support), API keys (no user context) |

**When to include:**
- Technology stack choices (database, framework, model)
- Architecture patterns (sync vs async, monolith vs services)
- Significant tradeoffs (cost vs performance)

**Skip when:**
- Simple plans following established patterns
- No major choices to document

## Runtime Reasoning Capture

During plan execution, use explicit reasoning steps for complex decisions. Based on research showing significant improvement on policy-heavy tasks.

**During execution, use this pattern:**

```markdown
**Step N: Evaluate options**

Think through:
- What constraints apply here?
- What did the source research recommend?
- Are there edge cases to consider?

Document your reasoning before proceeding.
```

**When to use:**
- Policy-heavy decisions during implementation
- When tool output needs interpretation
- Before making choices that deviate from the plan

This creates an audit trail of WHY specific implementation choices were made, not just WHAT was done.

## Task Structure

```markdown
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

**Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

**Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

**Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

**Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
```

## Remember
- Exact file paths always
- Complete code in plan (not "add validation")
- Exact commands with expected output
- Reference relevant skills with @ syntax
- DRY, YAGNI, TDD, frequent commits
- Archive sources, document decisions

## Execution Handoff

After saving the plan, offer execution choice:

**"Plan complete and saved to `docs/plans/<filename>.md`. Two execution options:**

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

**Which approach?"**

**If Subagent-Driven chosen:**
- **REQUIRED SUB-SKILL:** Use superpowers:subagent-driven-development
- Stay in this session
- Fresh subagent per task + code review

**If Parallel Session chosen:**
- Guide them to open new session in worktree
- **REQUIRED SUB-SKILL:** New session uses superpowers:executing-plans
