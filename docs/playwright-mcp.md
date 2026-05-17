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

Each server uses `npx -y @playwright/mcp@latest --browser=<engine> --headless` by default.

## Browser mapping

| Browser target | MCP server name | Launch args (default) |
|---|---|---|
| Firefox | `playwright-firefox` | `--browser=firefox --headless` |
| WebKit / Safari-class | `playwright-webkit` | `--browser=webkit --headless` |
| Microsoft Edge | `playwright-msedge` | `--browser=msedge --headless` |

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

To keep the browser visible for debugging, opt into headed mode explicitly:

```bash
./setup.sh opencode --with-playwright-mcp --playwright-headed
./setup.sh codex --with-playwright-mcp --playwright-headed
./setup.sh copilot --with-playwright-mcp --playwright-headed
./setup.sh kiro --with-playwright-mcp --playwright-headed
```

## First-run browser install

The MCP server configuration is installed by `setup.sh`, but the browser engine itself may still need a one-time download. If the first WebKit/Firefox/Edge run says the browser is missing, install the engine once before retrying:

```bash
npx @playwright/mcp@latest install-browser webkit
npx @playwright/mcp@latest install-browser firefox
npx @playwright/mcp@latest install-browser msedge
```

For Safari-class verification specifically, the WebKit install is the important one:

```bash
npx @playwright/mcp@latest install-browser webkit
```

## Verify

```bash
grep -n 'playwright-firefox' ~/.config/opencode/opencode.json
grep -n 'playwright-webkit' ~/.codex/config.toml
grep -n 'playwright-msedge' ~/.copilot/mcp-config.json
grep -n 'playwright-firefox' ~/.kiro/settings/mcp.json
```

## Performance tips

The official Playwright MCP docs expose several levers that matter when runs feel slow:

1. **Default to headless; switch to headed only when you need to watch the browser**

   Official docs say Playwright MCP is headed by default. This repo intentionally overrides that by configuring the managed MCP servers in headless mode unless you pass `--playwright-headed`. Headless avoids window-management overhead and prevents visible WebKit windows from lingering after agent runs.

   Example server args:

   ```json
   ["-y", "@playwright/mcp@latest", "--browser=webkit", "--headless"]
   ```

2. **Preinstall browsers once**

   First-run downloads are expensive. Installing the needed engine ahead of time removes that startup penalty.

3. **Use a standalone warm server for repeated runs**

   Official docs support starting Playwright MCP separately with HTTP transport:

   ```bash
   npx @playwright/mcp@latest --browser=webkit --headless --port 8931
   ```

   Then point your client at:

   ```json
   {
     "mcpServers": {
       "playwright-webkit": {
         "url": "http://localhost:8931/mcp"
       }
     }
   }
   ```

   This avoids repeated `npx` + server startup overhead between sessions. The official docs also support `--shared-browser-context` when multiple HTTP clients should reuse one context.

4. **Prefer direct routes and batched assertions**

   For agent prompts, deep-link straight to the page under test when possible and prefer one compact `browser_run_code_unsafe` assertion over many small click/snapshot turns.

5. **Avoid extra evidence collection unless needed**

   Screenshots, full snapshots, console dumps, and network captures are best treated as debugging follow-ups, not the default for every happy-path verification.

6. **Reuse profile state intentionally**

   Persistent profiles or a custom `--user-data-dir` can avoid repeated setup/login work. If parallel clients conflict, official docs recommend `--isolated` or distinct profile directories instead.

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
