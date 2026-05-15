# OpenCode Configuration Repository

This repository contains shared configuration, skills, evals, and setup utilities for OpenCode, Codex CLI, GitHub Copilot, and Kiro CLI.

**This is not application code.** Treat it as a CLI configuration and skill distribution repo. Most tasks involve skill authoring, setup flows, CLI-specific config, or eval and smoke-test maintenance. Setup commands, runtime layout, and install examples live in `README.md`.

## Core Repository Rules

- `skills/` contains reusable skills shared across the supported CLIs.
- `.opencode/commands/` is OpenCode-only. Codex, Copilot, and Kiro use their own native command or instruction surfaces.
- Top-level `scripts/` are for repo setup, testing, and eval tooling. Skills cannot access them at runtime.

## Symlink Installation Model

Skills are symlinked individually into each CLI's skills directory, for example `~/.copilot/skills/context7-docs/ -> <repo>/skills/context7-docs/`. At runtime, each skill directory stands alone.

**Iron rule:** never reference files outside the skill directory.

- Allowed: `$SCRIPT_DIR/helper.sh`
- Allowed: `$SCRIPT_DIR/../config/defaults.yaml`
- Not allowed: `$SCRIPT_DIR/../../scripts/shared.sh`
- Not allowed: `$SCRIPT_DIR/../other-skill/lib.sh`

If two skills need the same helper, duplicate it inside each skill rather than creating cross-skill dependencies.

## Supported CLIs

This repo supports **OpenCode**, **Codex CLI**, **GitHub Copilot**, and **Kiro CLI**.

Keep changes aligned with the target CLI's native conventions:

- OpenCode uses `opencode.json` and `.opencode/commands/`
- Codex uses `.codex/config.toml` and `.codex/rules/`
- Copilot and Kiro consume `SKILL.md` directly via the Agent Skills format

Use `README.md` for setup commands, runtime paths, and installation details.

## Skill Authoring Conventions

- Use lowercase-kebab-case for skill directory names.
- Each skill lives under `skills/<skill-name>/` and must include `SKILL.md`.
- Keep skill scripts and config inside the skill directory tree, typically under local `scripts/` or `config/` subdirectories.
- In `SKILL.md`, keep `name` aligned with the directory name and make `description` describe both purpose and trigger conditions.
- Follow the existing patterns in `skills/github-ops/SKILL.md` and `skills/agent-md-tuner/SKILL.md` when choosing `allowed-tools`, structure, and context.

### Script Standards

- Start Bash scripts with `#!/usr/bin/env bash` and `set -euo pipefail`.
- Use functions for non-trivial logic.
- Add `|| true` to `grep` commands that may legitimately return no matches.
- Prefer explicit, local paths rooted in the skill directory.

## Testing and Validation

- After changing a skill's scripts or configuration, run its smoke test when `skills/<skill-name>/tests/smoke.sh` exists.
- All relevant smoke tests should pass before committing.
- Because skills are installed by symlink, verify changed paths still work from the installed skill directory, not just from the repo root.
- Repo-level setup, eval, and battery commands are documented in `README.md`.

## GitHub Operations

Use the `gh` CLI for GitHub operations.

- Use `gh api` for REST API calls.
- Use `gh search` for code, repo, issue, or PR search.
- Use `gh pr`, `gh issue`, and `gh repo` for common workflows.

## Working Method

### Debugging

Do not propose or ship speculative fixes. Reproduce the issue, gather evidence, trace the failure to a root cause, and verify the hypothesis before changing code.

### Test Discipline

For non-trivial logic changes and bug fixes, prefer test-first work: capture the failing behavior, implement the smallest fix that makes it pass, then refactor while tests stay green. You can skip this for typos, comments, formatting-only edits, and pure config text changes.

## Commit and Push

- Stage changes before committing.
- If the commit message is obvious, commit without asking. If it is ambiguous, ask first.
- Push only after explicit user approval.
