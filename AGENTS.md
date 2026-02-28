# OpenCode Configuration Repository

This repository contains custom skills and configuration for OpenCode, Codex CLI, and GitHub Copilot. It is symlinked to extend all three CLIs' capabilities.

**This is NOT application code** - it contains AI agent skills, commands, and templates.

## CLI Support

This repository supports **OpenCode**, **Codex CLI**, and **GitHub Copilot**:

| Aspect | OpenCode | Codex | Copilot |
|--------|----------|-------|---------|
| Config directory | `~/.config/opencode/` | `~/.codex/` | `~/.copilot/` |
| Config file | `opencode.json` (JSON) | `config.toml` (TOML) | VS Code settings |
| Skills directory | `~/.config/opencode/skills/` | `~/.codex/skills/` | `~/.copilot/skills/` |
| Setup script | `./setup.sh` or `./setup.sh opencode` | `./setup.sh codex` | `./setup.sh copilot` |
| System skills | None | `.system/` subdirectory | Built-in tools |
| Skill format | `SKILL.md` (YAML frontmatter) | `SKILL.md` (YAML frontmatter) | `SKILL.md` ([Agent Skills standard](https://agentskills.io/)) |

### OpenCode Setup (Automated)

Run the setup script to automatically configure OpenCode:

```bash
./setup.sh
```

This creates symlinks for `opencode.json` and `skills/` in `~/.config/opencode/`.

### Codex Setup

Run the setup script with the `codex` target:

```bash
./setup.sh codex
```

This symlinks individual skills to `~/.codex/skills/` and merges Codex config.

**Important:** Do NOT symlink the entire `skills/` directory to `~/.codex/skills/`, as this will hide Codex's system skills in `.system/`.

**Configuration:** Codex uses `config.toml` (TOML format), not `opencode.json`. Manage your Codex configuration separately.

### Copilot Setup

Run the setup script with the `copilot` target:

```bash
./setup.sh copilot
```

This symlinks individual skill directories to `~/.copilot/skills/`. Copilot natively supports the same `SKILL.md` format via the [Agent Skills standard](https://agentskills.io/) — no conversion needed.

Copilot discovers skills automatically. You can also configure additional search locations in VS Code `settings.json`:

```json
{
  "chat.agentSkillsLocations": [
    { "path": "~/.copilot/skills" }
  ]
}
```

### All Targets

```bash
./setup.sh all    # Install for OpenCode, Codex, and Copilot
```

## Repository Structure

```
opencode-config/
├── skills/                # Custom skills (works with OpenCode, Codex, Copilot)
│   ├── agent-browser/     # Browser automation via agent-browser CLI
│   ├── asu-discover/      # ASU GitHub org semantic search (disabled)
│   ├── context7-docs/     # Library documentation via Context7 MCP
│   ├── github-ops/        # GitHub operations via gh CLI
│   ├── mcporter/          # Direct MCP access via MCPorter
│   ├── planning-doc/      # Planning document management
│   ├── production-hardening/ # Resilience anti-pattern scanning
│   ├── security-auditor/  # Pre-deployment security audit
│   └── skill-creator/     # AI-assisted skill creation
├── evals/                 # Evaluation framework
│   └── skill-loading/     # Skill-loading eval suite
├── scripts/               # Top-level utility scripts
│   ├── codex-config.py    # Codex config TOML merging
│   ├── list-fails.sh      # List failed eval case IDs
│   ├── plan-path.sh       # Derive PLAN.md path from branch
│   ├── retest-fails.sh    # Retest failed eval cases
│   └── test-battery.sh    # Run all skill smoke tests
├── docs/                  # Documentation and plans
│   └── plans/             # Branch-derived planning documents
├── .opencode/             # OpenCode commands and config
│   └── commands/          # Custom slash commands
├── .codex/                # Codex CLI config and rules
│   ├── config.toml        # Codex configuration (TOML)
│   ├── rules/             # Codex safety rules
│   └── skills/            # Codex skill eval commands
├── setup.sh               # Setup script (OpenCode, Codex, Copilot)
└── opencode.json          # Provider configuration (LiteLLM)
```

## Skill Conventions

### Naming
- **Directory**: `lowercase-kebab-case` (e.g., `github-ops`, `asu-discover`)
- **Scripts**: `lowercase.sh` in `scripts/` subdirectory
- **Config**: YAML files in `config/` subdirectory

### Required Frontmatter (SKILL.md)

```yaml
---
name: skill-name
description: "Concise description. When to use this skill."
allowed-tools: Bash(gh:*) Bash(./scripts/*) Read Glob Grep
context: fork
---
```

| Field | Purpose |
|-------|---------|
| `name` | Matches directory name, lowercase-kebab-case |
| `description` | Explains purpose AND when to use (triggers skill loading) |
| `allowed-tools` | Whitelist of tools the skill can use |
| `context` | Use `fork` to run in isolated context |

### Skill Management

Skills can be enabled or disabled via permissions in `opencode.json` (OpenCode) or `config.toml` (Codex):

**OpenCode (`opencode.json`):**
```json
{
  "permission": {
    "skill": {
      "*": "allow",
      "asu-discover": "deny",
      "experimental-*": "ask"
    }
  }
}
```

**Codex (`~/.codex/config.toml`):**
```toml
[permission.skill]
"*" = "allow"
asu-discover = "deny"
"experimental-*" = "ask"
```

| Permission | Behavior |
|------------|----------|
| `allow` | Skill loads immediately |
| `deny` | Skill hidden from agent, access rejected |
| `ask` | User prompted for approval before loading |

**Note:** Disabled skills remain in the `skills/` directory but are not available to the CLI.

#### Currently Disabled Skills

- **asu-discover**: Disabled pending server-side implementation refactor. The original design was inadequate and requires architectural changes to the backend integration.

### Script Standards

```bash
#!/usr/bin/env bash
set -euo pipefail

# Script implementation
```

- Always use `set -euo pipefail` for safety
- Use functions for complex logic
- Add `|| true` to grep commands that may have no matches

### Testing

Skills with a `tests/` directory must have smoke tests run after modifications:

```bash
# Run smoke tests for a skill
./skills/<skill-name>/tests/smoke.sh
```

- Run smoke tests after any changes to skill scripts or configuration
- All tests must pass before committing
- Smoke tests should complete in <30 seconds

## Available Commands

| Command | Purpose |
|---------|---------|
| `/new-skill <name> [--quick]` | Create a new skill (AI-assisted, or `--quick` for scaffold only) |
| `/skill-evals-run [options]` | Run the skill-loading eval suite |
| `/skill-evals-optimize [options]` | Triage and fix failed eval cases (2-iteration cap) |

## Reference Files

For detailed examples, see:
- `@skills/github-ops/SKILL.md` - Multi-script skill with 12 domains
- `@skills/skill-creator/SKILL.md` - AI-assisted skill creation workflow
- `@skills/production-hardening/SKILL.md` - Multi-phase analysis and implementation skill
- `@skills/security-auditor/SKILL.md` - Tool-integrated audit with gating logic
- `@skills/planning-doc/SKILL.md` - Document management with branch-derived paths

## GitHub Operations

All GitHub operations should use the `gh` CLI, not WebFetch:
- Use `gh api` for REST API calls
- Use `gh search` for code/repo/issue search
- Use `gh pr`, `gh issue`, `gh repo` for common operations

## Key Patterns

### Domain Configuration (YAML)

```yaml
domains:
  domain-name:
    types:
      type-name:
        description: "What this type does"
        patterns: [search, patterns]
        # Additional type-specific fields
```

### Script with Actions

```bash
ACTION="${1:-help}"
case "$ACTION" in
    action1) do_action1 "$@" ;;
    action2) do_action2 "$@" ;;
    help|*) show_help ;;
esac
```

## Utility Scripts

Top-level `scripts/` contains shared utilities:

| Script | Purpose |
|--------|---------|
| `codex-config.py` | Merges repo `.codex/config.toml` into `~/.codex/config.toml` (used by `setup.sh codex`) |
| `plan-path.sh` | Derives `PLAN.md` path from current git branch using planning-doc rules |
| `list-fails.sh` | Lists failed case IDs from the latest eval results |
| `retest-fails.sh` | Re-runs only failed eval cases with the eval runner |
| `test-battery.sh` | Discovers and runs all skill smoke tests (`tests/smoke.sh`, `tests/evals.sh`) |

## Planning Documents (Execution Mode)

- If a planning document exists at the location derived by the `skills/planning-doc/` rules for the current git branch, keep it updated even when the user did not request planning.
- Derive the plan path using the same rules as the planning-doc skill: get the branch with `git rev-parse --abbrev-ref HEAD`, map `^(feat|fix|chore)/(.+)$` to `docs/plans/<prefix>/<feature>/PLAN.md`, otherwise use `docs/plans/feat/<branch>/PLAN.md`.
- Only update if the file already exists; do not create a new plan unless the user explicitly asks for planning.
- When updating, follow the planning-doc steering: read `PLAN.md` before changes, append a new **STATUS UPDATES** entry after meaningful work, add **DECISIONS**/**DISCOVERIES / GOTCHAS** entries when relevant, and record validation in **TEST RESULTS** when run.

## Methodology Protocols

### Debugging Protocol (BEFORE proposing any fix)

**Iron Law:** No fix without confirmed root cause. Fixes based on guesses create new bugs.

**4-Phase Process:**

1. **Investigate** — Gather evidence before theorizing
   - Reproduce the bug with minimal steps
   - Collect: error messages, stack traces, logs, state at failure
   - Identify: when did it last work? What changed?

2. **Analyze** — Find the root cause
   - Trace execution path to failure point
   - Check: data flow, state mutations, race conditions, edge cases
   - If 3+ hypotheses fail → question architecture, not just code

3. **Verify** — Confirm root cause before fixing
   - Can you predict the bug's behavior from your theory?
   - Can you make it worse/better by changing the suspected code?
   - Write a failing test that captures the bug

4. **Fix** — Minimal change that addresses root cause
   - Fix the cause, not the symptom
   - Run the failing test → must pass
   - Run full test suite → no regressions

**Red Flags (stop and reassess):**
- "Let me try this..." without understanding why
- Fixing symptoms instead of causes
- Same area breaks repeatedly

### TDD Protocol (for medium+ complexity tasks)

**Iron Law:** No production code without a failing test first.

**Red-Green-Refactor Cycle:**

1. **RED** — Write ONE failing test
   - Test describes desired behavior, not implementation
   - Run it → must fail (proves test works)
   - Failure must be "feature missing," not syntax/import error

2. **GREEN** — Write minimal code to pass
   - Just enough to make the test pass
   - No extra features, no "while I'm here" improvements
   - Resist urge to write "real" implementation

3. **REFACTOR** — Clean up while green
   - Remove duplication
   - Improve names
   - Extract helpers
   - Tests must stay green throughout

4. **REPEAT** — Next behavior, next test

**Rationalizations to Reject:**
- "I'll write tests after" → No. Test first or delete the code.
- "This is too simple to test" → Then the test is simple too. Write it.
- "I know this works" → Prove it. Write the test.
- "Tests slow me down" → Debugging untested code is slower.

**When to Apply:**
- New functions/methods with logic
- Bug fixes (write failing test that reproduces bug first)
- Refactors (ensure test coverage before changing)
- API changes

**Skip TDD for:** Typos, comments, config changes, pure formatting.

---

## Commit and Push

- Stage changes before committing.
- If the commit message is obvious, compose it and commit without asking.
- If the commit message is ambiguous, propose a message and wait for approval before committing.
- Push only after explicit user approval (or when the user explicitly asks to push in the current request).
- Do not auto-push as part of session completion unless requested.
