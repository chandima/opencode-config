# PLAN - context-mode multi-harness integration

## GOAL
Provide a safe, repeatable way to integrate `context-mode` into this repo so OpenCode, Codex CLI, and GitHub Copilot can use it with the right level of automation for each harness.

## PURPOSE
Add repo-managed installation, configuration, and documentation for `context-mode` without violating this repo's self-contained skill model or clobbering user-owned config.

## REFERENCES
- `setup.sh`
- `opencode.json`
- `.codex/config.toml`
- `AGENTS.md`
- `docs/plans/`

## SCOPE
In scope:
- Define the integration model for OpenCode, Codex, and GitHub Copilot.
- Add installer/config scaffolding for `context-mode` as an external runtime dependency.
- Document where global setup ends and per-workspace Copilot bootstrap begins.
- Add validation steps for install, config wiring, and safe removal/update paths.

Out of scope:
- Vendoring `context-mode` into `skills/`.
- Rewriting existing skills to depend on `context-mode`.
- Forcing `context-mode` into target repositories automatically without an explicit bootstrap step.

## CURRENT BASELINE
- `setup.sh` manages OpenCode, Codex, and Copilot setup for repo-owned config and skills.
- `opencode.json` currently enables `@tarquinen/opencode-dcp`; it does not yet register `context-mode`.
- `.codex/config.toml` does not yet register a `context-mode` MCP server.
- Copilot support in this repo is skill-oriented; there is no current project bootstrap for `.vscode/mcp.json`, `.github/hooks/`, or Copilot instruction injection.

## STATUS UPDATES (append-only; newest first)
### 2026-03-14
Change:
- Added Copilot plugin support: `./setup.sh copilot --with-context-mode` now runs
  `copilot plugin install mksglu/context-mode`, which registers the MCP server and
  6 skills automatically. Removal runs `copilot plugin uninstall context-mode`.
- Fixed `install-context-mode.sh` verify step (removed `context-mode --help` which
  started the MCP server on stdio and hung).
- context-mode is now fully supported across all three harnesses via `--with-context-mode`.

Behavior now:
- `./setup.sh copilot --with-context-mode` installs context-mode as a Copilot CLI plugin.
- `./setup.sh copilot --remove` uninstalls the plugin.
- Idempotent: second run detects existing plugin and skips.
- Graceful: if `copilot` CLI not available, prints skip message.

Validate:
- `bash setup.sh copilot --with-context-mode` -> installs plugin.
- `copilot plugin list` -> shows context-mode.
- `bash setup.sh copilot --remove` -> uninstalls plugin.
- `bash scripts/test-context-mode-setup.sh` -> exits 0.

### 2026-03-14
Change:
- Revised integration to config-layer only. Removed workspace bootstrap machinery
  (~500 lines) that duplicated context-mode's native auto-setup.
- Deleted: `templates/context-mode/` (4 files), `scripts/bootstrap-context-mode.sh`.
- Simplified: `scripts/context-mode-config.py` (308→140 lines, OpenCode overlay only),
  `setup.sh` (removed `--context-mode-workspace` flag and workspace functions),
  `scripts/test-context-mode-setup.sh` (removed workspace bootstrap tests).
- Updated `docs/context-mode.md` with config-layer model and manual Copilot guidance.

Rationale:
- context-mode's `start.mjs` auto-detects platforms and writes routing instructions
  (`AGENTS.md`, `copilot-instructions.md`) on first server startup. The repo's
  templates duplicated this and had already drifted (array vs object-style hooks).
- This repo's job is config distribution — wiring MCP servers into harness config.
  Workspace concerns (routing instructions, hooks, instruction files) belong to
  context-mode itself.

Behavior now:
- `./setup.sh opencode --with-context-mode` writes a managed OpenCode config overlay.
- `./setup.sh codex --with-context-mode` merges context-mode MCP server into Codex config.
- Copilot workspace setup is documented (manual) — context-mode handles it natively.
- `--context-mode-workspace` flag is removed; workspace bootstrap is no longer this repo's concern.

Validate:
- `bash scripts/test-context-mode-setup.sh` -> exits 0.

### 2026-03-14
Change:
- Implemented opt-in `context-mode` setup in `setup.sh` for OpenCode and Codex.
- Added `scripts/install-context-mode.sh`, `scripts/context-mode-config.py`, `scripts/bootstrap-context-mode.sh`, and workspace templates under `templates/context-mode/`.
- Added smoke coverage in `scripts/test-context-mode-setup.sh` and documentation in `docs/context-mode.md` and `README.md`.

Behavior now:
- `./setup.sh opencode --with-context-mode` writes a managed OpenCode config that overlays the repo config with the `context-mode` plugin and MCP entry.
- `./setup.sh codex --with-context-mode` merges a managed `context-mode` MCP server into Codex config.
- `./scripts/bootstrap-context-mode.sh install <workspace>` bootstraps managed `AGENTS.md`, `.vscode/mcp.json`, `.github/hooks/context-mode.json`, and `.github/copilot-instructions.md` content for a workspace.
- Removal restores or preserves files conservatively based on managed state and managed-block markers.

Validate:
- `bash scripts/test-context-mode-setup.sh` -> exits 0.

### 2026-03-14
Change:
- Created the initial plan for `context-mode` integration across OpenCode, Codex, and GitHub Copilot.
- Captured the repo fit: installer-managed global config for OpenCode/Codex, plus per-workspace bootstrap for Copilot.

Behavior now:
- No integration is implemented yet; this plan defines the intended rollout shape and constraints.

Validate:
- `test -f docs/plans/feat/context-mode-integration/PLAN.md` -> exits 0.

## PHASE PLAN

### Phase 1 - Integration contract and config shape
Goal: Lock down exactly how `context-mode` should be represented in this repo for each harness.
Scope:
- Confirm required OpenCode `plugin` and MCP entries.
- Confirm required Codex MCP server registration and instruction guidance.
- Define the Copilot bootstrap artifacts and the boundary between global config and per-project files.
- Decide how `context-mode` should coexist with `@tarquinen/opencode-dcp` in OpenCode.
Done when: Required config fragments, ownership boundaries, and compatibility notes are documented.
Verify: `rg -n "context-mode|opencode-dcp|mcp_servers" opencode.json .codex/config.toml AGENTS.md` -> current touchpoints identified.
Notes: Prefer additive config that can be installed, updated, or removed without destructive resets.

### Phase 2 - Installer and config implementation
Goal: Add repo-managed install/config support for OpenCode and Codex, plus a Copilot bootstrap path.
Scope:
- Add an install/update script for the external `context-mode` package.
- Patch `setup.sh` to support an opt-in `context-mode` flow.
- Add or generate OpenCode and Codex config fragments idempotently.
- Add Copilot bootstrap templates/scripts for `.vscode/mcp.json`, `.github/hooks/context-mode.json`, and instruction snippets.
Done when: A user can run the repo's setup flow and get OpenCode/Codex wired globally, with a documented command to bootstrap Copilot in a target workspace.
Verify: `HOME="$(mktemp -d)" ./setup.sh all --with-context-mode` -> completes with managed context-mode wiring for supported global targets.
Notes: Copilot likely needs generation into a chosen workspace path rather than home-directory-only setup.

### Phase 3 - Docs, validation, and removal/update semantics
Goal: Make the integration understandable, testable, and reversible.
Scope:
- Document install, upgrade, verify, and remove flows.
- Add smoke-style validation for config generation and temp-home setup behavior.
- Define safe behavior when `context-mode` is missing, outdated, or already configured by the user.
- Update repo docs so the integration model is discoverable.
Done when: The setup path is documented and verifiable, and managed changes can be updated or removed conservatively.
Verify: `bash -c 'tmp=$(mktemp -d); HOME="$tmp" ./setup.sh opencode --with-context-mode'` -> completes without clobbering unrelated user config.
Notes: Removal must only touch repo-managed or clearly marked blocks/files.

## DEFINITION OF DONE
- OpenCode can use `context-mode` through repo-managed config.
- Codex can use `context-mode` through repo-managed config.
- GitHub Copilot has documented manual setup path; context-mode handles workspace concerns natively.
- Installation and removal are conservative and do not break existing user-owned config.
- Repo docs explain the integration model and harness-specific limitations.

## OPEN QUESTIONS
- None currently. Resolved decisions are captured below.

## CHANGE LOG
- 2026-03-14 - Created initial multi-harness `context-mode` integration plan.
- 2026-03-14 - Implemented the first end-to-end context-mode setup, bootstrap, and smoke-test flow.
- 2026-03-14 - Revised to config-layer only: removed workspace bootstrap (~500 lines), let context-mode handle its own workspace concerns.
- 2026-03-14 - Added Copilot plugin support via `copilot plugin install mksglu/context-mode`.

## DECISIONS
- 2026-03-14 - Treat `context-mode` as an external runtime dependency, not a repo skill - it needs host-level MCP/plugin/hook configuration and should not violate the self-contained skill model.
- 2026-03-14 - Use repo-managed global setup for OpenCode and Codex, and a per-workspace bootstrap path for Copilot - this matches each harness's configuration surface.
- 2026-03-14 - Keep `context-mode` opt-in behind `--with-context-mode` - this avoids changing the default OpenCode/Codex behavior for users who only want the base repo config.
- 2026-03-14 - Let OpenCode coexist with both `@tarquinen/opencode-dcp` and `context-mode` when opted in - the managed overlay is additive and reversible.
- 2026-03-14 - REVISED: Remove workspace bootstrap and let context-mode handle routing instructions, hooks, and workspace files natively. The repo's templates duplicated upstream and had already drifted (hook format mismatch). Config distribution is this repo's job; workspace concerns are context-mode's domain.
- 2026-03-14 - Use Copilot CLI plugin system (`copilot plugin install mksglu/context-mode`) for Copilot integration. context-mode ships `.claude-plugin/plugin.json` which Copilot CLI recognizes natively. This registers MCP server + skills in one command.

## DISCOVERIES / GOTCHAS
- 2026-03-14 - This repo is currently on `main`, so the plan path is not naturally branch-derived; the plan is stored under `docs/plans/feat/context-mode-integration/PLAN.md` as a feature-style planning document.
- 2026-03-14 - Copilot integration for `context-mode` is workspace-local in practice, so it cannot be fully solved by home-directory symlinks alone.
- 2026-03-14 - Copilot CLI reads `.claude-plugin/plugin.json` for plugin manifests — context-mode's existing Claude plugin manifest is fully compatible.
- 2026-03-14 - context-mode's `plugin.json` does not declare a `hooks` field, so PreToolUse/PostToolUse hooks are not auto-installed. Users must manually add `.github/hooks/context-mode.json` for full enforcement.
- 2026-03-14 - `context-mode --help` starts the MCP server on stdio rather than printing help text; removed from verify step in `install-context-mode.sh`.
