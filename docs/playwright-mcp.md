# Playwright MCP integration

This repo can optionally configure the official [`@playwright/mcp`](https://github.com/microsoft/playwright-mcp) server for the supported harnesses.

## Integration model

- **OpenCode**: opt-in global setup via `./setup.sh opencode --with-playwright-mcp`
- **Codex**: opt-in global setup via `./setup.sh codex --with-playwright-mcp`
- **GitHub Copilot**: opt-in global setup via `./setup.sh copilot --with-playwright-mcp`
- **Kiro**: opt-in global setup via `./setup.sh kiro --with-playwright-mcp`

`@playwright/mcp` is treated as an external MCP dependency, not as a skill in `skills/`.

## Why this is separate from agent-browser

`agent-browser` remains the default skill for Chrome/Chromium browser automation.

Playwright MCP is reserved for cases where browser-engine coverage matters:

- Firefox
- WebKit / Safari-class issues
- Microsoft Edge
- Cross-browser verification

This repo intentionally configures only non-Chromium Playwright servers so the routing boundary stays clear.

## What setup does

When `--with-playwright-mcp` is enabled:

- OpenCode: writes a managed `~/.config/opencode/opencode.json` that preserves the repo config, enables the `playwright-mcp` skill permission, and adds three MCP entries:
  - `playwright-firefox`
  - `playwright-webkit`
  - `playwright-msedge`
- Codex: merges the same three servers into `~/.codex/config.toml`
- GitHub Copilot: writes the same three servers into `~/.copilot/mcp-config.json`
- Kiro: writes the same three servers into `~/.kiro/settings/mcp.json`

Each server uses `npx -y @playwright/mcp@latest --browser=<engine>`.

## Browser mapping

| Browser target | MCP server name | Launch args |
|---|---|---|
| Firefox | `playwright-firefox` | `--browser=firefox` |
| WebKit / Safari-class | `playwright-webkit` | `--browser=webkit` |
| Microsoft Edge | `playwright-msedge` | `--browser=msedge` |

One server entry maps to one browser engine. Cross-browser checks should use multiple configured servers rather than trying to switch engines inside one Playwright MCP session.

## Install

```bash
./setup.sh opencode --with-playwright-mcp
./setup.sh codex --with-playwright-mcp
./setup.sh copilot --with-playwright-mcp
./setup.sh kiro --with-playwright-mcp
./setup.sh all --with-playwright-mcp
```

You can combine this with context-mode if needed:

```bash
./setup.sh all --with-context-mode --with-playwright-mcp
```

## Verify

```bash
grep -n 'playwright-firefox' ~/.config/opencode/opencode.json
grep -n 'playwright-webkit' ~/.codex/config.toml
grep -n 'playwright-msedge' ~/.copilot/mcp-config.json
grep -n 'playwright-firefox' ~/.kiro/settings/mcp.json
```

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
- Copilot and Kiro remove only the repo-managed Playwright MCP server entries and restore a backed-up config if the file becomes empty

## Limitations

- Playwright MCP is an MCP server entrypoint, not a lightweight browser CLI like `agent-browser`.
- WebKit is the closest Playwright engine for Safari-class debugging, but it is not identical to every Safari environment detail.
- This repo does not configure Playwright Chromium by default; Chrome/Chromium automation should continue to use `agent-browser`.
