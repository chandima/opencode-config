# OpenCode Configuration Repository

This repository contains custom skills and configuration for OpenCode. It is symlinked to `~/.config/opencode/` to extend OpenCode's capabilities.

**This is NOT application code** - it contains AI agent skills, commands, and templates.

## Repository Structure

```
opencode-config/
├── skills/           # Custom OpenCode skills
│   ├── github-ops/   # GitHub operations via gh CLI
│   ├── asu-discover/ # ASU org repository discovery
│   └── skill-creator/ # AI-assisted skill creation
├── .opencode/        # OpenCode commands and config
│   └── commands/     # Custom slash commands
└── opencode.json     # Provider configuration (LiteLLM)
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

## Reference Files

For detailed examples, see:
- `@skills/github-ops/SKILL.md` - Multi-script skill with 12 domains
- `@skills/asu-discover/SKILL.md` - Node.js RAG client skill with TypeScript
- `@skills/skill-creator/SKILL.md` - AI-assisted skill creation workflow

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
