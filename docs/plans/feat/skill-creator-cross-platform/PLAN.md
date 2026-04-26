# Skill Creator Cross-Platform & Quality Upgrade

## Problem

The `skill-creator` skill generates skills targeting OpenCode, Codex, and Copilot, but the repo now supports 4 platforms (+ Kiro) and the ecosystem has grown to 14+. The skill-creator has several gaps compared to best-in-class implementations:

1. **Kiro is missing entirely** — skills generated today won't mention Kiro compatibility
2. **Cross-platform frontmatter differences are undocumented** — `allowed-tools` syntax varies, `context: fork` only works on 2 platforms
3. **Description quality insights from research are absent** — CSO violations, missing "Do NOT use for" guidance
4. **No security guidance** for skills handling secrets or destructive operations
5. **Static validation is manual and incomplete** — misses token budgets, YAML safety, path escapes

## Research Summary

### Ecosystem Scan (April 2026)

Analyzed 8 skill-creator implementations across the ecosystem:

| Implementation | Strengths | Weaknesses |
|---------------|-----------|------------|
| **Anthropic official** | Best eval framework, blind A/B comparison, subagent parallel testing, "explain why" philosophy | Claude Code-only, no cross-platform |
| **FrancyJGLisboa v4** | 14-platform install matrix, auto-detect current platform, team registry, install.sh generation | No eval framework, very opinionated, 5000+ word SKILL.md |
| **Apollo GraphQL** | Best security guidance — blockquote warnings at point of risk, explicit data leakage patterns | Apollo-specific, no eval framework |
| **obra/superpowers** | CSO insight (description ≠ workflow summary), TDD for skills, pressure testing, token budgets | Claude Code-centric |
| **hqhq1025/skill-optimizer** | 14 static checks, session data mining, research-backed (6 papers), undertrigger detection | Optimizer only, not a creator |
| **Dean Peters** | Strict metadata validation, workshop facilitation, packaging presets | PM-domain specific |
| **agentskills.io spec** | Official standard: name (1-64 chars), description (1-1024 chars), progressive disclosure model | Spec only, not a tool |
| **Your current skill-creator** | Eval framework, description optimization with train/test split, search-before-create, adaptive interview | Missing Kiro, weak cross-platform, no security, no CSO insights |

### Key Research Findings

**Claude Search Optimization (CSO)** — obra/superpowers discovery:
> "Descriptions that summarize workflow create a shortcut the agent will take" — the agent reads the description, decides it already knows the workflow, and skips loading the full SKILL.md. Description must contain ONLY trigger conditions, NEVER workflow summary.

**Lost in the Middle** (Liu et al., 2023) — hqhq1025 citation:
> Critical information placed in the middle of long documents is missed by LLMs. Place the most important rules at the beginning and end of SKILL.md, not buried in the middle.

**MUST/NEVER density** — hqhq1025 static check:
> Skills with too many MUST/NEVER directives cause agents to ignore them all. Keep directive density low; explain *why* instead (Anthropic philosophy).

**"Do NOT use for" is critical** — agentskills.io spec + tech-leads-club standard:
> Prevents false activation, which is a bigger problem than under-triggering. Near-miss negative examples are the most valuable test cases.

### Cross-Platform Frontmatter Reality

| Field | OpenCode | Codex | Copilot | Kiro | Portable |
|-------|----------|-------|---------|------|----------|
| `name` | ✅ Required | ✅ Required | ✅ Required | ✅ Required | ✅ Required |
| `description` | ✅ Required | ✅ Required | ✅ Required | ✅ Required | ✅ Required |
| `allowed-tools` | ✅ Space-separated | ✅ Space-separated | ⚠️ Limited (`shell`) | ✅ Space-separated | Omit (varies) |
| `context: fork` | ✅ Supported | ❌ Ignored | ❌ Ignored | ✅ Supported | Omit |
| `compatibility` | ✅ Optional | ✅ Optional | ✅ Optional | ✅ Optional | ✅ Safe |
| `metadata` | ✅ Optional | ✅ Optional | ✅ Optional | ✅ Optional | ✅ Safe |
| `license` | ✅ Optional | ✅ Optional | ✅ Optional | ✅ Optional | ✅ Safe |

### Tool Permission Syntax Differences

| Platform | Syntax | Example |
|----------|--------|---------|
| OpenCode | Space-separated, scoped Bash | `Bash(gh:*) Bash(./scripts/*) Read Glob Grep` |
| Codex | Same as OpenCode | `Bash(gh:*) Bash(./scripts/*) Read Glob Grep` |
| Copilot | Simple keywords | `shell` (⚠️ broad — security risk) |
| Kiro | Same as OpenCode | `Bash(gh:*) Bash(./scripts/*) Read Glob Grep` |
| Portable | Omit entirely | *(let each platform's defaults apply)* |

## Proposed Approach

Targeted updates to the existing `skills/skill-creator/SKILL.md` — no structural rewrite. Changes organized by priority.

## Todos

### P0: Factual Corrections (skill-creator generates wrong output today)

#### 1. Add Kiro to all platform references
- Update the description field to include Kiro: `"OpenCode, Codex CLI, GitHub Copilot, Kiro"`
- Update `compatibility` field
- Add Kiro to interview question 3 ("Which runtime should this target?") suggestions
- Add Kiro to the Runtime Profiles section with its specifics
- Add Kiro to the Frontmatter Reference section notes

#### 2. Add cross-platform frontmatter reference table
- Add a new section "Cross-Platform Frontmatter" after the existing Frontmatter Reference
- Include the field support matrix (which fields work where)
- Document that `allowed-tools` syntax is space-separated for OpenCode/Codex/Kiro, different for Copilot
- Document that `context: fork` only works on OpenCode and Kiro
- Add guidance: "When targeting portable, use only `name` and `description` in frontmatter"

#### 3. Update Runtime Profiles with concrete guidance
- Replace vague "portable" description with: "Minimal required fields (`name`, `description`) only. Omit `allowed-tools` and `context: fork` — they are not universally supported."
- Add Kiro profile: "Same as OpenCode (`allowed-tools`, `context: fork`). Skills auto-discovered from `~/.kiro/skills/`."
- Add note: "Copilot's `allowed-tools` uses different syntax (`shell` keyword). When targeting Copilot, either omit `allowed-tools` or use Copilot-compatible values."

### P1: Quality Improvements (research-backed)

#### 4. Add "Do NOT use for" to description generation guidance
- In Phase 3 (Generate Skill), add to the SKILL.md generation checklist: "Description MUST include a 'DO NOT use for:' line with 2-3 negative triggers"
- In the Description Optimization workflow, add: "Include near-miss negative examples in should-not-trigger queries — these are the most valuable test cases"
- Update the Frontmatter Reference description field: add note "Include 'DO NOT use for:' to prevent false activation"

#### 5. Add CSO warning to description guidance
- Add a prominent warning box in the Description Optimization section:
  > **CSO Rule:** Description must contain ONLY trigger conditions, NEVER workflow summary. If the description summarizes what the skill does step-by-step, agents will read the description, decide they already know the workflow, and skip loading the full SKILL.md.
- Add to Phase 3 validation checklist: "Description does not leak workflow steps (CSO violation)"
- Add to the Frontmatter Reference description field: "Describe WHEN to use, not HOW it works"

#### 6. Add security section generation for applicable skills
- In Phase 2 (Interview), add question: "Does this skill handle secrets, credentials, or destructive operations?"
- If yes, generate a Security section in the SKILL.md with:
  - Blockquote warnings at point of risk (Apollo pattern): `> **Security: data leakage risk** — Never log or echo API keys...`
  - Credential handling guidance: "Use environment variables, never hardcode"
  - Destructive operation guidance: "Require user confirmation before delete/kill/drop operations"
- Add to Phase 4 validation checklist: "If skill handles secrets/destructive ops, Security section exists"

### P2: Tooling & Polish

#### 7. Add automated static validation checks
- Update `scripts/validate-runtime.sh` (or create if missing) to check:
  - Token count: SKILL.md body under 5000 tokens (word count × 1.33)
  - Description length: under 1024 chars (spec limit)
  - Description contains "Use when" or trigger conditions
  - Description contains "DO NOT use for" or equivalent
  - Description does not contain workflow verbs (generate, create, run, execute — CSO check)
  - No `../` path escapes in any file
  - YAML frontmatter parses without error
  - Name matches directory name
  - Scripts have `#!/usr/bin/env bash` and `set -euo pipefail`
- Output: pass/fail per check with actionable fix suggestions

#### 8. Add "explain why" to Writing Style section
- Add to Writing Style: "Explain *why* behind instructions rather than rigid MUST/NEVER directives. Agents follow rules better when they understand the reasoning. Reserve MUST/NEVER for true invariants (security, data loss). For preferences, explain the tradeoff."
- Add: "Keep MUST/NEVER directive density low — skills with too many absolute directives cause agents to ignore them all."

#### 9. Enhance interview with platform-specific follow-ups
- After Q3 ("Which runtime?"), if answer is NOT "portable" or "all":
  - For OpenCode/Kiro: "Should it use `context: fork` for isolated execution?"
  - For Copilot: "Note: `allowed-tools` uses different syntax on Copilot. I'll generate Copilot-compatible values."
- If answer IS "all" or "portable":
  - "I'll use only universally-supported frontmatter fields (`name`, `description`, `compatibility`). Platform-specific fields like `allowed-tools` and `context: fork` will be omitted."

## Files to Modify

| File | Changes |
|------|---------|
| `skills/skill-creator/SKILL.md` | All 9 todos — frontmatter, description, interview, generate, validate, optimize, writing style sections |
| `skills/skill-creator/scripts/validate-runtime.sh` | Todo 7 — automated static checks (create or update) |

## Validation

After implementation:
- Run `skills/skill-creator/tests/smoke.sh` — must pass
- Verify SKILL.md stays under 5000 tokens (currently ~3800, budget for ~1000 more)
- Test: create a skill with `--quick` targeting "portable" — verify no `allowed-tools` or `context: fork` in output
- Test: create a skill targeting "kiro" — verify Kiro-specific fields present
- Test: run validate-runtime.sh against an existing skill — verify checks pass

## Notes

- The skill-creator SKILL.md is currently ~545 lines / ~3800 tokens. The P0+P1 changes add ~200 tokens. P2 adds ~300 tokens. Total stays well under 5000.
- These changes are backward-compatible — existing skills created by the old version remain valid.
- The cross-platform frontmatter table is the single highest-value addition — it prevents the skill-creator from generating broken frontmatter for platforms that don't support certain fields.
- FrancyJGLisboa's 14-platform support and team registry features are out of scope — this repo only targets 4 platforms and doesn't need install.sh generation or team sharing workflows.
