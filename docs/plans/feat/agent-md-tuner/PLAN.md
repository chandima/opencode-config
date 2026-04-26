# Agent MD Tuner Skill

## Problem

AI coding agents (OpenCode, Codex, Copilot, Kiro, Claude Code, Cursor) perform dramatically better when projects have well-crafted agent configuration files (AGENTS.md, CLAUDE.md, .cursorrules, etc.). The Karpathy guidelines repo (90.2k stars) proved that four behavioral constraints in 50 lines of markdown measurably reduce overengineering, drive-by refactoring, and silent assumption errors.

But the Karpathy guidelines are **generic** — they don't know your project's test commands, package manager, architecture, or conventions. The groff.dev 3-tier architecture (root config → skills → agent guides) shows that **project-aware, progressively-disclosed context** is what actually moves the needle for long-running episodic coding tasks.

Most projects either have no agent config, a bloated auto-generated one the model ignores, or a copy-pasted Karpathy CLAUDE.md with no project-specific context. There is no skill in this repo or the broader ecosystem (1,340+ skills surveyed via VoltAgent/awesome-agent-skills) that audits a project's agent configuration and produces tailored, project-aware enhancements.

## Research Summary

### Karpathy Guidelines (forrestchang/andrej-karpathy-skills)

- 90.2k GitHub stars, 8.6k forks, MIT license
- Four principles derived from Karpathy's X post on LLM coding pitfalls:
  1. **Think Before Coding** — Surface assumptions, present alternatives, push back, ask when confused
  2. **Simplicity First** — Minimum code, no speculative features, no unnecessary abstractions
  3. **Surgical Changes** — Touch only what's needed, match existing style, don't refactor what isn't broken
  4. **Goal-Driven Execution** — Transform tasks into verifiable goals with success criteria
- Available as CLAUDE.md (50 lines) or Claude Code plugin
- Weakness: generic, no project awareness, no progressive disclosure

### groff.dev 3-Tier Architecture

Best practice for agent configuration documented at groff.dev/blog/implementing-claude-md-agent-skills:

- **Tier 1: Root file** (AGENTS.md/CLAUDE.md) — Universal rules, <100 lines, loaded every session
- **Tier 2: Skills** (.claude/skills/ or skills/) — Task-specific behavior loaded on demand
- **Tier 3: Agent Guides** (docs/agent-guides/) — Deep reference material, loaded only when needed

Key insight: "The context window is a shared public good. Your CLAUDE.md competes with the system prompt, conversation history, and every other piece of context."

### "4 Lines Every CLAUDE.md Needs" (Level Up Coding)

Article analyzing why behavioral constraints beat feature checklists. Key finding: ~65-70% of enterprise code is AI-written in 2026, but the most-starred dev resource is four sentences in a markdown file — proving behavioral constraints are the highest-leverage, lowest-cost intervention.

### Mastering Product Critique

Identifies what Karpathy's guidelines miss for product teams:
- No outcome-driven thinking (shipping the wrong thing well)
- No instrumentation requirements
- No decision logging
- No tradeoff documentation

These gaps are relevant for the auditor's recommendation engine.

### Ecosystem Survey (VoltAgent/awesome-agent-skills, 1,000+ skills)

Related skills found:
- `hqhq1025/skill-optimizer` — Diagnoses and optimizes SKILL.md files (not root config)
- `NeoLabHQ/prompt-engineering` — Prompt engineering techniques (not project-aware)
- `muratcankoylan/context-*` — Context engineering skills (theoretical, not audit-oriented)
- `anthropics/skill-creator` — Creates new skills (not auditing existing config)

**No skill exists that audits a project's agent configuration files and produces project-aware enhancements.** This is a genuine gap.

### This Repo's Existing Patterns

- `security-auditor` — Read project → scan → produce report → gate decision. Closest pattern match.
- `skill-creator` — Interview → generate → validate. Relevant for the generation phase.
- All skills are self-contained, symlinked individually, use native agent tools (Read/Glob/Grep/Write).
- No existing skill references AGENTS.md or CLAUDE.md in target projects.

## Proposed Approach

Create `skills/agent-md-tuner/` — a zero-dependency skill that uses the agent's native file tools to audit any project's agent configuration and produce project-aware enhancements combining Karpathy behavioral principles, groff.dev 3-tier architecture, and ecosystem best practices.

### Design Principles

1. **No scripts needed** — The agent uses native Read/Glob/Grep/Write tools. The SKILL.md contains the audit checklist, reference principles, and generation templates. This keeps the skill maximally portable across all 4 CLIs.
2. **Three operating modes** — Create (no config exists → generate from scratch), Enhance (config exists with gaps → sharpen generic sections with project-specific details, merge missing behavioral constraints into existing structure), Restructure (bloated/disorganized config → propose rewrite following 3-tier architecture). Mode is auto-detected but user can override. All modifications shown as diffs and require user confirmation before writing.
3. **Project-aware** — Reads package.json, Makefile, CI configs, test setup, directory structure, and existing agent config to produce tailored recommendations.
4. **Multi-format output** — Detects which agent config format the project uses (or should use) and produces the right file: AGENTS.md, CLAUDE.md, .cursorrules, or all of them.

### Workflow

```
1. Detect project context
   - Language/framework (package.json, Cargo.toml, go.mod, etc.)
   - Package manager (npm/bun/pnpm/yarn/uv/pip/cargo)
   - Test runner and commands (jest, pytest, cargo test, etc.)
   - Linter/formatter (eslint, ruff, prettier, etc.)
   - Build system (vite, webpack, make, cargo, etc.)
   - CI/CD (GitHub Actions, etc.)
   - Directory structure and architecture patterns

2. Detect existing agent config
   - AGENTS.md, CLAUDE.md, .cursorrules, .github/copilot-instructions.md
   - .claude/skills/, .cursor/rules/
   - docs/agent-guides/
   - Measure: line count, section coverage, specificity

3. Audit against checklist
   - Karpathy behavioral principles (4 principles)
   - Project-specific context (test commands, build commands, conventions)
   - Progressive disclosure (3-tier architecture)
   - Anti-patterns (too long, too generic, duplicated content, linter-as-LLM)

4. Produce gap report
   - What's present, what's missing, what's generic-but-should-be-specific
   - Severity: CRITICAL (no agent config at all), HIGH (missing behavioral
     constraints or project context), MEDIUM (missing progressive disclosure),
     LOW (style/organization improvements)

5. Select operating mode and apply
   - **Create** (no config found): Generate complete project-aware file from scratch
   - **Enhance** (config exists, has gaps): Append missing sections AND sharpen
     generic sections with project-specific details (e.g., replace "run tests"
     with actual `pytest -x --tb=short` detected from project). Merge Karpathy
     behavioral constraints into existing methodology sections rather than
     duplicating. Preserve all project-specific rules.
   - **Restructure** (config >150 lines or disorganized): Propose a rewrite
     following 3-tier architecture — lean root file (<100 lines) with pointers
     to skills/agent-guides for deep content. Show full before/after diff.
   - Mode is auto-detected based on audit findings but user can override
   - All changes shown as diffs, user confirms before any writes
```

### Audit Checklist (embedded in SKILL.md)

The skill carries a reference checklist that the agent evaluates against:

**Behavioral Constraints (Karpathy-derived):**
- [ ] Think Before Coding — explicit assumption surfacing, push-back guidance
- [ ] Simplicity First — anti-overengineering rules, "senior engineer test"
- [ ] Surgical Changes — scope discipline, style matching, orphan cleanup rules
- [ ] Goal-Driven Execution — verifiable success criteria, test-first transformation

**Project Context (must be project-specific, not generic):**
- [ ] Package manager and dependency commands
- [ ] Test runner and test commands (unit, integration, e2e)
- [ ] Linter/formatter commands
- [ ] Build commands
- [ ] Key architectural patterns and conventions
- [ ] Directory structure overview (What/Where)
- [ ] CI/CD validation commands

**Progressive Disclosure (3-tier architecture):**
- [ ] Root file under 100 lines
- [ ] Skills or agent-guides for deep content (if project complexity warrants)
- [ ] Directory-level overrides for distinct subsystems (if monorepo)
- [ ] No duplicated content across tiers

**Anti-Patterns:**
- [ ] Not using CLAUDE.md as a linter (use ruff/eslint/prettier instead)
- [ ] Not stuffing everything into root file
- [ ] No absolute paths
- [ ] No stale/outdated commands

### File Structure

```
skills/agent-md-tuner/
├── SKILL.md          # Frontmatter + audit workflow + checklist + generation templates
└── tests/
    └── smoke.sh      # Validates SKILL.md frontmatter and structure
```

No `scripts/` directory. The agent's native tools (Read, Glob, Grep, Write) do all the work. The SKILL.md is the entire skill — it contains the audit checklist, the Karpathy principles reference, the 3-tier architecture guidance, and the generation templates.

### SKILL.md Frontmatter

```yaml
---
name: agent-md-tuner
description: |
  Audit, enhance, and restructure a project's AI agent configuration files
  (AGENTS.md, CLAUDE.md, .cursorrules). Use when setting up a new project for
  AI-assisted development, when agent behavior is poor, or when asked to "tune
  agent config", "improve AGENTS.md", "set up CLAUDE.md", "configure this
  project for AI coding", or "sharpen agent rules".
  DO NOT use for: editing application code, creating skills (use skill-creator),
  security audits (use security-auditor), or general documentation.
allowed-tools: Read Write Edit Glob Grep
context: fork
compatibility: "OpenCode, Codex CLI, GitHub Copilot, Kiro. No external dependencies."
---
```

### Output Formats

The skill detects what the project already uses and recommends the appropriate format:

| Detected | Action |
|----------|--------|
| Nothing | Create AGENTS.md (works with OpenCode, Codex, Copilot, Kiro) |
| AGENTS.md exists, <150 lines | Enhance: sharpen generic sections + append missing |
| AGENTS.md exists, >150 lines | Restructure: propose lean rewrite + 3-tier split |
| CLAUDE.md exists, <150 lines | Enhance: sharpen generic sections + append missing |
| CLAUDE.md exists, >150 lines | Restructure: propose lean rewrite + 3-tier split |
| Both exist | Audit both, flag any conflicts |
| .cursorrules exists | Audit and enhance, note format differences |
| User requests specific format | Generate that format |

### Scope

**In scope:**
- Audit any project's agent config files against the checklist
- Detect project context (language, tools, conventions) automatically
- Generate project-aware behavioral constraints + project context sections
- Support AGENTS.md, CLAUDE.md, .cursorrules output formats
- Recommend 3-tier architecture for complex projects
- Smoke test for SKILL.md validation

**Out of scope:**
- Creating project-specific skills (use skill-creator for that)
- Modifying application code
- Installing tools or dependencies
- Managing setup.sh integration (the skill is deployed like any other skill)
- Generating Tier 2/3 content (skills, agent-guides) — the auditor recommends the structure but doesn't populate deep content

## Task Breakdown

### Task 1: Create SKILL.md with audit workflow and Karpathy reference

**Objective:** Write the core SKILL.md containing frontmatter, the audit workflow, the embedded Karpathy principles reference, the audit checklist, and the generation templates.

**Implementation guidance:**
- Follow the existing skill conventions (see skill-creator/SKILL.md for the most complex example)
- Embed the 4 Karpathy principles as a reference section within the SKILL.md (not as a separate file — skills must be self-contained)
- Include the full audit checklist as a structured section
- Include generation templates for each output format (AGENTS.md, CLAUDE.md)
- Keep the SKILL.md under 500 lines (Anthropic recommendation)
- The workflow should be: Detect → Audit → Report → Offer Fixes

**Test requirements:**
- SKILL.md has valid YAML frontmatter with name, description, allowed-tools, context, compatibility
- Description includes positive triggers and "DO NOT use for:" negative triggers
- No references to files outside the skill directory

**Demo:** Agent can load the skill and describe what it would do when asked "audit this project's agent config."

### Task 2: Implement project detection logic in SKILL.md

**Objective:** Add the project context detection section that tells the agent how to discover the project's language, tools, test commands, build system, and conventions.

**Implementation guidance:**
- Define a structured discovery sequence: check package.json → Cargo.toml → go.mod → pyproject.toml → Makefile → etc.
- For each detected ecosystem, specify which files to read for test/build/lint commands
- Include CI config detection (read .github/workflows/*.yml for actual validation commands)
- Include directory structure analysis guidance (Glob for src/, lib/, tests/, etc.)
- The agent should produce a "Project Profile" summary before auditing

**Test requirements:**
- The detection sequence covers the major ecosystems (Node/Bun, Python, Rust, Go, Java, Ruby)
- CI config detection is included
- The discovery is read-only (no commands executed, just file reads)

**Demo:** Agent can run the detection phase on a real project and produce a Project Profile summary showing language, package manager, test commands, and directory structure.

### Task 3: Implement gap analysis and report generation

**Objective:** Add the audit logic that compares detected project state + existing agent config against the checklist and produces a structured gap report.

**Implementation guidance:**
- Define severity levels: CRITICAL (no config), HIGH (missing behavioral constraints or project context), MEDIUM (missing progressive disclosure), LOW (style)
- For each checklist item, define what "present" vs "missing" vs "generic" means
- The report should be presented to the user in a clear format before any writes
- Include specific recommendations with example text for each gap

**Test requirements:**
- Gap report covers all 4 checklist categories (behavioral, project context, progressive disclosure, anti-patterns)
- Severity levels are assigned correctly
- Report is human-readable

**Demo:** Agent can audit a project that has a generic CLAUDE.md (e.g., copy-pasted Karpathy file) and produce a gap report showing "behavioral constraints present but generic; project context missing; no progressive disclosure."

### Task 4: Implement fix generation and application

**Objective:** Add the generation templates and the apply-fixes workflow that produces project-specific agent config content and writes it with user confirmation.

**Implementation guidance:**
- Three operating modes, auto-detected but user-overridable:
  - **Create mode:** Generate complete file with all sections using project-specific
    details from detection phase. Use generation templates for behavioral constraints
    (Karpathy-derived), project context (real commands), and progressive disclosure pointers.
  - **Enhance mode:** For each gap found in audit:
    - Missing section → append with project-specific content
    - Generic section (e.g., "run tests before committing") → sharpen by replacing
      with actual detected commands (e.g., `npm test`, `pytest -x --tb=short`)
    - Partial behavioral coverage → merge Karpathy principles into existing
      methodology sections, not as a separate block. Deduplicate overlapping guidance.
    - Preserve all existing project-specific rules and conventions verbatim.
  - **Restructure mode:** For bloated configs (>150 lines or disorganized):
    - Propose a lean root file (<100 lines) following Why/What/How/Progressive Disclosure
    - Identify content that should move to skills/ or docs/agent-guides/
    - Show complete before/after diff
    - This is the most invasive mode — require explicit user confirmation
- All modes: show the user exactly what will change before writing
- All modes: generated content must include actual project-specific commands, not placeholders

**Test requirements:**
- Create mode: generated file includes actual project-specific commands
- Enhance mode: existing content is preserved, generic sections are sharpened with real commands, Karpathy principles are merged (not duplicated) with existing methodology
- Restructure mode: proposed root file is under 100 lines, full diff is shown
- All modes: user confirmation is required before any writes

**Demo:** Agent can operate in all three modes:
- Create: Generate a complete AGENTS.md for a project with no agent config
- Enhance: Take a project with a generic copy-pasted Karpathy CLAUDE.md and sharpen it with real test/build commands + project conventions
- Restructure: Take a bloated 300-line AGENTS.md and propose a lean <100-line root file with pointers to agent-guides/

### Task 5: Add smoke test and validate end-to-end

**Objective:** Create tests/smoke.sh and validate the complete skill works end-to-end.

**Implementation guidance:**
- smoke.sh validates SKILL.md frontmatter (name, description, allowed-tools, context)
- Verify SKILL.md is under 500 lines
- Verify no external file references (self-contained check)
- Run the skill-creator's validate-runtime.sh against the new skill
- Manual end-to-end test: run the skill against this repo itself (opencode-config has an AGENTS.md — the auditor should detect it and produce a meaningful gap report)

**Test requirements:**
- smoke.sh exits 0 on valid skill
- smoke.sh catches missing frontmatter fields
- End-to-end test produces a coherent gap report for a real project

**Demo:** `./skills/agent-md-tuner/tests/smoke.sh` passes. Agent can audit opencode-config itself and produce a gap report noting that AGENTS.md has strong methodology protocols but lacks explicit Karpathy-style behavioral constraints (Think Before Coding, Simplicity First) and project-specific build/test commands.
