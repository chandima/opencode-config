# PLAN — skill-refinement

## Goal

Align all 8 skills with Anthropic's Agent Skills standard (agentskills.io spec, best practices guide, and "The Complete Guide to Building Skills for Claude" PDF). The refinements must preserve tri-harness compatibility (OpenCode, Codex, Copilot) — no changes that break `allowed-tools`, `context: fork`, or the symlink installation model.

## Context

Research compared Anthropic's official guidance (spec, best practices, description optimization guide, PDF guide, and 17 reference skills from anthropics/skills) against the 8 active skills in this repo. Full gap analysis in session plan.md.

Key standards:
- SKILL.md ≤ 500 lines / 5,000 tokens (progressive disclosure)
- Description: `[What] + [When] + [DO NOT]`, ≤ 1024 chars, imperative phrasing
- Three-level disclosure: frontmatter (always loaded) → body (on activation) → linked files (on demand)
- Conditional reference loading: "Read `references/X.md` if Y"
- `compatibility` field for environment requirements

## Plan

### Phase 1 — agent-browser refactor (HIGH priority)
- [ ] 1a. Audit agent-browser SKILL.md (632 lines) and identify sections to extract
- [ ] 1b. Move detailed auth patterns (~5 variants) to `references/auth-patterns.md`
- [ ] 1c. Move security section (content boundaries, domain allowlists, action policies) to `references/security.md`
- [ ] 1d. Move advanced topics (diffing, session management, ref lifecycle, annotated screenshots, JS evaluation, config file, browser engine selection) to `references/advanced.md`
- [ ] 1e. Add conditional loading cues in SKILL.md body ("Read `references/auth-patterns.md` if the target site requires login")
- [ ] 1f. Add `context: fork` to frontmatter (currently missing)
- [ ] 1g. Add negative triggers to description ("DO NOT use for API testing, non-browser HTTP requests, or headless scraping that doesn't need a real browser")
- [ ] 1h. Add `compatibility` field
- [ ] 1i. Validate SKILL.md is ≤ 400 lines after refactor

### Phase 2 — Description improvements (MEDIUM priority)
For each skill below, improve the `description` field by adding negative triggers and enriching trigger phrases. Model after production-hardening and security-auditor which already comply.

- [ ] 2a. **context7-docs** — Add "DO NOT use for general web search, non-library questions, or internal/proprietary APIs"
- [ ] 2b. **github-ops** — Add "DO NOT use for local-only git operations, non-GitHub remotes (GitLab, Bitbucket), or repository content that can be read with standard file tools"
- [ ] 2c. **mcporter** — Rewrite description with imperative "Use when" phrasing + add "DO NOT use when a dedicated skill exists (e.g., github-ops for GitHub, context7-docs for library docs)"
- [ ] 2d. **planning-doc** — Expand with trigger phrases ("make a plan", "project plan", "roadmap", "track progress") + add "DO NOT use for todo lists, issue tracking, or general documentation"
- [ ] 2e. **skill-creator** — Add "DO NOT use for general coding tasks, non-skill file creation, or editing files unrelated to skill development"

### Phase 3 — Add `compatibility` field to all skills (MEDIUM priority)
- [ ] 3a. Add `compatibility: "OpenCode, Codex CLI, GitHub Copilot (tri-harness). Requires Bash."` to all 8 skills
  - Adapt per-skill if specific dependencies exist (e.g., agent-browser needs npx/agent-browser CLI, security-auditor needs trivy/semgrep, context7-docs needs npx/Context7)

### Phase 4 — github-ops progressive disclosure (LOW priority)
- [ ] 4a. Extract 12-domain script detail listing from SKILL.md into `references/script-domains.md`
- [ ] 4b. Keep only the Quick Reference table (domain names + 1-line descriptions) in SKILL.md
- [ ] 4c. Add conditional loading cue: "Read `references/script-domains.md` for detailed script parameters and examples"
- [ ] 4d. Validate SKILL.md drops below 350 lines

### Phase 5 — Validation
- [ ] 5a. Run `wc -l` on all SKILL.md files — all must be ≤ 500 lines
- [ ] 5b. Verify all descriptions are ≤ 1024 characters
- [ ] 5c. Verify all descriptions have both positive ("Use when") and negative ("DO NOT") triggers
- [ ] 5d. Verify `compatibility` field present in all 8 skills
- [ ] 5e. Run existing smoke tests (`scripts/test-battery.sh` or per-skill `tests/smoke.sh`) to ensure no breakage
- [ ] 5f. Spot-check that reference file loading cues use conditional pattern ("Read X if Y")

## Decisions

- 2026-03-16 — Keep `allowed-tools` and `context: fork` in frontmatter — these are tri-harness requirements not in the Anthropic spec, but essential for OpenCode/Codex sandboxing
- 2026-03-16 — Skip `license` field — not needed for internal/personal skills
- 2026-03-16 — Skip `metadata` field — version tracking not worth the overhead for 8 skills
- 2026-03-16 — Target ≤ 400 lines for agent-browser (not just ≤ 500) to leave headroom for future additions
- 2026-03-16 — Do NOT touch production-hardening or security-auditor descriptions — they already comply and serve as the reference model

## Discoveries

- 2026-03-16 — Anthropic's PDF says "code is deterministic; language interpretation isn't" — bundle validation scripts for critical checks rather than relying on prose instructions. Our skills already do this well (production-hardening/scan.sh, security-auditor/audit.sh).
- 2026-03-16 — Anthropic's spec lists `allowed-tools` as "experimental" — but it's essential for our tri-harness. Keep it.
- 2026-03-16 — agent-browser is the only skill missing `context: fork` in its frontmatter.
- 2026-03-16 — asu-discover directory does not exist (referenced in AGENTS.md as disabled but the directory itself is absent).
- 2026-03-16 — Anthropic's description optimization guide recommends testing with ~20 eval queries (8-10 should-trigger, 8-10 should-not-trigger) with train/validation splits. Consider adding trigger evals in a future pass.

## Status Updates (newest first)

### 2026-03-16 (implementation complete)
- **Change:** All 5 phases executed and validated
- **State now:** All 8 skills aligned with Anthropic Agent Skills standard. Tri-harness compatibility preserved.
- **Validate:**
  - `wc -l skills/*/SKILL.md` → all ≤ 500 lines (agent-browser=240, github-ops=143)
  - `bash scripts/test-battery.sh` → 7/7 smoke tests pass
  - All descriptions have positive + negative triggers, ≤ 1024 chars
  - All frontmatter has `compatibility` field

**Results:**
| Phase | What | Outcome |
|-------|------|---------|
| 1 | agent-browser refactor | 632→240 lines, 3 reference files created |
| 2 | Description improvements | 5 skills got DO NOT triggers |
| 3 | Compatibility field | All 8 skills updated |
| 4 | github-ops disclosure | 472→143 lines, 1 reference file created |
| 5 | Validation | 8/8 checks pass, 7/7 smoke tests pass |

### 2026-03-16
- **Change:** Initial plan created from gap analysis
- **State now:** Plan ready for review. No code changes yet.
- **Validate:** `cat docs/plans/feat/skill-refinement/PLAN.md` → plan exists
