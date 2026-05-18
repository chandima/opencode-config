# Chrome DevTools MCP integration

This repo can optionally configure the official [`chrome-devtools-mcp`](https://github.com/ChromeDevTools/chrome-devtools-mcp) server for the supported harnesses.

## Integration model

- **OpenCode**: opt-in global setup via `./setup.sh opencode --with-chrome-devtools-mcp`
- **Codex**: opt-in global setup via `./setup.sh codex --with-chrome-devtools-mcp`
- **GitHub Copilot**: opt-in global setup via `./setup.sh copilot --with-chrome-devtools-mcp`
- **Kiro**: opt-in global setup via `./setup.sh kiro --with-chrome-devtools-mcp`

`chrome-devtools-mcp` is treated as an external MCP dependency, not as the skill itself.

## Why this is separate from agent-browser and Playwright MCP

- `agent-browser` remains the default skill for routine Chrome/Chromium automation.
- `playwright-mcp` remains reserved for Firefox, WebKit/Safari-class, Edge, and cross-browser verification.
- Chrome DevTools MCP is for Chrome-specific debugging where DevTools context matters:
  - live logged-in Chrome sessions
  - selected-element inspection from DevTools
  - console and network investigation
  - Lighthouse, performance, and memory workflows
  - Chrome extension debugging

## What setup does

When `--with-chrome-devtools-mcp` is enabled:

- OpenCode: writes a managed `~/.config/opencode/opencode.json` that preserves the repo config, enables the `chrome-devtools-mcp` skill permission, and adds one MCP entry:
  - `chrome-devtools`
- Codex: merges the same MCP server into `~/.codex/config.toml`
- GitHub Copilot: writes the same server into `~/.copilot/mcp-config.json`
- Kiro: writes the same server into `~/.kiro/settings/mcp.json`

The repo-managed server uses:

```json
["-y", "chrome-devtools-mcp@latest", "--no-usage-statistics"]
```

Usage statistics are disabled by default in the managed config.

## Auto-connect is explicit opt-in

By default, the repo-managed MCP server does **not** enable `--auto-connect`.

That keeps the default install conservative: Chrome DevTools MCP is available, but it does not automatically attach to a running local Chrome profile unless you explicitly request that behavior.

To opt in:

```bash
./setup.sh opencode --with-chrome-devtools-mcp --chrome-devtools-auto-connect
./setup.sh codex --with-chrome-devtools-mcp --chrome-devtools-auto-connect
./setup.sh copilot --with-chrome-devtools-mcp --chrome-devtools-auto-connect
./setup.sh kiro --with-chrome-devtools-mcp --chrome-devtools-auto-connect
```

Auto-connect requires Chrome remote debugging to be enabled in Chrome itself.

## Install

```bash
./setup.sh opencode --with-chrome-devtools-mcp
./setup.sh codex --with-chrome-devtools-mcp
./setup.sh copilot --with-chrome-devtools-mcp
./setup.sh kiro --with-chrome-devtools-mcp
./setup.sh all --with-chrome-devtools-mcp
```

You can combine this with other optional integrations if needed:

```bash
./setup.sh all --with-context-mode --with-chrome-devtools-mcp
./setup.sh all --with-playwright-mcp --with-chrome-devtools-mcp
./setup.sh all --with-context-mode --with-playwright-mcp --with-chrome-devtools-mcp
```

## Verify

```bash
grep -n 'chrome-devtools' ~/.config/opencode/opencode.json
grep -n 'chrome-devtools' ~/.codex/config.toml
grep -n 'chrome-devtools' ~/.copilot/mcp-config.json
grep -n 'chrome-devtools' ~/.kiro/settings/mcp.json
```

If you opted into auto-connect, also verify the config contains:

```bash
grep -n 'auto-connect' ~/.config/opencode/opencode.json
grep -n 'auto-connect' ~/.codex/config.toml
grep -n 'auto-connect' ~/.copilot/mcp-config.json
grep -n 'auto-connect' ~/.kiro/settings/mcp.json
```

## MCP vs CLI

This repo treats **MCP** as the primary workflow and the **CLI** as an optional advanced path.

Use **MCP** for:

- live authenticated Chrome sessions
- iterative DevTools debugging
- selected-element inspection from DevTools
- console or network investigation in the same debugging flow
- Lighthouse or performance work as part of a broader live-session workflow

Use the **CLI** only as an advanced secondary path for:

- shell-driven scripting
- repeatable command-line workflows
- cases where a scripted Lighthouse-style audit benefits from fewer agent turns

The repo does **not** install or route through the CLI by default.

## Optional CLI path

If you explicitly want the CLI, upstream documents npm installation:

```bash
npm i -g chrome-devtools-mcp@latest
chrome-devtools status
```

Homebrew also currently has a `chrome-devtools-mcp` formula:

```bash
brew install chrome-devtools-mcp
```

This remains outside the repo-managed default workflow.

## Remove

```bash
./setup.sh opencode --remove
./setup.sh codex --remove
./setup.sh copilot --remove
./setup.sh kiro --remove
```

Removal is conservative:

- OpenCode restores the prior file or symlink only if the managed file is unchanged
- Codex removal preserves user-modified values that no longer match the repo-managed state
- Copilot and Kiro remove only the repo-managed Chrome DevTools MCP server entry and restore a backed-up config if the file becomes empty

## Limitations

- The repo skill is MCP-only; CLI workflows are docs-only collateral here.
- Auto-connect is not enabled by default, so a plain install does not automatically attach to a running local Chrome profile.
- Live-session attachment still requires Chrome remote debugging to be enabled in Chrome itself.
- Chrome DevTools MCP is Chrome-specific and should not replace `playwright-mcp` for non-Chromium or cross-browser work.
