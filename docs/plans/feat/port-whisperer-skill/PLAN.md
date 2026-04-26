# Port Whisperer Skill

## Problem

Orphaned dev server processes accumulate during development — hogging ports, refusing to die, and causing "port already in use" errors. Diagnosing which process owns a port requires manual `lsof` incantations, and cleaning up orphans means hunting PIDs by hand. AI coding agents currently have no skill for port/process management, forcing users to context-switch to a terminal.

A comprehensive search of all major skill registries (VoltAgent/awesome-agent-skills with 1100+ skills, tech-leads-club/agent-skills with 200+ skills, and this repo's 8 existing skills) found **zero** port management or dev process cleanup skills anywhere in the ecosystem.

## Research Summary

### port-whisperer CLI

[port-whisperer](https://github.com/LarsenCundric/port-whisperer) (`npm: port-whisperer`, command: `ports`) is a CLI tool that provides:

| Command | Purpose |
|---------|---------|
| `ports` | Show dev server ports (filtered, no system apps) |
| `ports --all` | Show all listening ports including system services |
| `ports ps` | Show all running dev processes (not just port-bound) |
| `ports <number>` | Detailed info: process tree, repo path, git branch, memory |
| `ports kill <n>` | Kill by port, PID, or range; `-f` for SIGKILL |
| `ports clean` | Find and kill orphaned/zombie dev server processes |
| `ports logs <n>` | Tail process logs (auto-discovers log files via lsof) |
| `ports watch` | Real-time monitoring of port start/stop events |

**How it works:** Three shell calls (~0.2s): `lsof -iTCP -sTCP:LISTEN` → batched `ps` → batched `lsof -d cwd`. Docker ports resolved via `docker ps`. Framework detection via `package.json` and command-line inspection.

**Platform:** macOS + Linux supported.

### Dependency Strategy

Surveyed all skills in this repo for CLI dependency patterns:

| Skill | CLI | Strategy |
|-------|-----|----------|
| `mcporter` | mcporter | **Always npx** — `npx --yes mcporter` |
| `context7-docs` | mcporter | **Always npx** — `npx --yes mcporter` |
| `github-ops` | gh, git | **Require install**, fail with message |
| `security-auditor` | trivy, semgrep | **Auto-install** via brew/apt/pip |
| `agent-browser` | agent-browser | **Require install**, also allows npx |

For npm-based CLIs, the established convention is **always npx with local-install preference**: check `command -v ports` first (faster), fall back to `npx --yes port-whisperer`. This matches the mcporter/context7-docs pattern exactly.

## Proposed Approach

Create `skills/port-whisperer/` with:
- `SKILL.md` — frontmatter, quick reference, safety rules for destructive commands
- `scripts/ports.sh` — thin wrapper that detects `ports` on PATH or falls back to npx, strips ANSI codes for agent-friendly output
- `tests/smoke.sh` — validates help, list, and ps commands

### Safety Rules

Based on user requirements:
- **Read-only commands** (`list`, `list-all`, `ps`, `inspect`, `logs`): freely available, no confirmation needed
- **`ports kill <specific-port>`**: OK if user explicitly asked to kill that port; otherwise confirm
- **`ports clean`**: ALWAYS ask user before running (bulk destructive operation)

### Architecture

```
Agent receives "what's on port 3000?" or "kill orphaned processes"
  └─ Skill triggers via description keywords
       └─ scripts/ports.sh <action> [args]
            ├─ Detects: command -v ports → use directly (fast)
            └─ Fallback: npx --yes port-whisperer (no install needed)
                 └─ Strips ANSI codes → clean text output for agent
```

## Todos

### 1. Create SKILL.md
Create `skills/port-whisperer/SKILL.md` with:
- Frontmatter: `name: port-whisperer`, description with trigger keywords, `allowed-tools: Bash(npx:*) Bash(./scripts/*) Read Glob Grep`, `context: fork`
- Quick reference table mapping actions to script commands
- Safety section encoding kill/clean confirmation rules
- Prerequisites: Node.js 18+ (for npx), no global install required

### 2. Create scripts/ports.sh
Create `skills/port-whisperer/scripts/ports.sh`:
- CLI detection: prefer `ports` on PATH, fall back to `npx --yes port-whisperer`
- Action router: `list`, `list-all`, `ps`, `inspect`, `kill`, `clean`, `logs`, `help`
- Strip ANSI color codes from output
- Standard shebang + `set -euo pipefail`

### 3. Create tests/smoke.sh
Create `skills/port-whisperer/tests/smoke.sh`:
- Test help command exits 0
- Test list command exits 0
- Test ps command exits 0

### 4. Validate
- Name matches directory
- No `../` path escapes
- Scripts have proper shebang and error handling
- SKILL.md under 5000 tokens
- Smoke tests pass

## Notes

- `port-whisperer` can be installed globally via `npm install -g port-whisperer`, `mise use -g npm:port-whisperer`, or run ad-hoc via `npx`. The skill does not require any pre-installation.
- Output includes ANSI color codes (green=healthy, yellow=orphaned, red=zombie). The wrapper strips these for agent consumption.
- This skill aligns with the user's preference for CLI-first skills over MCP-based approaches.
