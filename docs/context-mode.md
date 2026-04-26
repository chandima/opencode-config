# context-mode integration

This repo can optionally configure [`context-mode`](https://github.com/mksglu/context-mode) for OpenCode and Codex CLI.

## Integration model

- **OpenCode**: opt-in global setup via `./setup.sh opencode --with-context-mode`
- **Codex**: opt-in global setup via `./setup.sh codex --with-context-mode`
- **Copilot**: plugin install via `./setup.sh copilot --with-context-mode` (uses `copilot plugin install`)
- **Kiro**: not yet supported — Kiro uses agent JSON for MCP server config; manual setup required (see Limitations)

`context-mode` is treated as an external runtime dependency, not as a skill in `skills/`.

## What setup does

When `--with-context-mode` is enabled:

- installs or verifies the `context-mode` binary with `scripts/install-context-mode.sh`
- OpenCode: writes a managed `~/.config/opencode/opencode.json` that preserves the repo config and adds:
  - `plugin: ["context-mode"]`
  - `mcp["context-mode"] = { type = "local", command = ["context-mode"] }`
- Codex: merges `[mcp_servers.context-mode]` into `~/.codex/config.toml`
- Copilot: installs context-mode as a Copilot CLI plugin via `copilot plugin install mksglu/context-mode`, which registers the MCP server and 6 skills automatically

context-mode handles workspace-level concerns (routing instructions, `AGENTS.md`, `copilot-instructions.md`) automatically on first server startup.

## Copilot setup

When `--with-context-mode` is used with the `copilot` target, setup.sh runs `copilot plugin install mksglu/context-mode`. This installs:
- The MCP server (sandbox tools: `ctx_execute`, `ctx_search`, etc.)
- 6 skills (context-mode, ctx-doctor, ctx-stats, ctx-upgrade, ctx-cloud-setup, ctx-cloud-status)

If the `copilot` CLI is not available, setup.sh skips the plugin install and prints a message. You can install manually:

```bash
copilot plugin install mksglu/context-mode
```

**Note:** context-mode's plugin manifest does not yet include hooks. For full enforcement (PreToolUse/PostToolUse interception), you can manually add `.github/hooks/context-mode.json` to your workspace — copy from `node_modules/context-mode/configs/vscode-copilot/hooks.json`. See the [context-mode README](https://github.com/mksglu/context-mode#readme) for details.

## OpenCode and DCP

This repo keeps `@tarquinen/opencode-dcp` in the base `opencode.json`.

If you enable `context-mode`, the managed OpenCode config adds `context-mode` alongside DCP rather than replacing it. That keeps the integration additive and reversible. If you later decide to standardize on one approach, remove the other plugin deliberately.

## Install

```bash
./setup.sh opencode --with-context-mode
./setup.sh codex --with-context-mode
./setup.sh copilot --with-context-mode
./setup.sh all --with-context-mode
```

## Verify

```bash
command -v context-mode
grep -n 'context-mode' ~/.config/opencode/opencode.json
grep -n 'context-mode' ~/.codex/config.toml
```

## Update

```bash
./setup.sh opencode --with-context-mode
./setup.sh codex --with-context-mode
```

To upgrade the binary itself:

```bash
./scripts/install-context-mode.sh upgrade
```

## Remove

```bash
./setup.sh opencode --remove
./setup.sh codex --remove
./setup.sh copilot --remove
```

Removal is conservative:

- OpenCode restores the prior file or symlink only if the managed file is unchanged
- Codex removal preserves user-modified values that no longer match the repo-managed state
- Copilot uninstalls the context-mode plugin via `copilot plugin uninstall`

## Limitations

- **Kiro**: No automated `--with-context-mode` support yet. Kiro uses agent JSON files for MCP server configuration, which differs from OpenCode/Codex/Copilot. To use context-mode with Kiro manually, add an MCP server entry to your agent's JSON config pointing to the `context-mode` binary.
- Codex has no hook support, so its `context-mode` usage depends on `AGENTS.md` routing instructions (~60% compliance).
- Copilot plugin install requires the `copilot` CLI. If not available, install manually with `copilot plugin install mksglu/context-mode`.
- context-mode's plugin manifest does not yet declare hooks; full PreToolUse/PostToolUse enforcement requires manual `.github/hooks/context-mode.json` in the workspace.
