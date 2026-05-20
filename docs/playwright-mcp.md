# Playwright MCP integration

This repo can optionally configure the official [`@playwright/mcp`](https://github.com/microsoft/playwright-mcp) servers for the supported harnesses.

## Purpose of this document

This file is the **repo-level integration guide** for Playwright MCP.

Use it for:

- what `setup.sh` installs
- which managed defaults and flags the repo supports
- how to verify or remove the MCP wiring
- how Playwright MCP fits alongside `agent-browser` and `chrome-devtools-mcp`

Do **not** use this file as the main runtime usage guide for the skill itself.

For runtime behavior, recipes, capability guidance, and workflow boundaries, read:

- `skills/playwright-mcp/SKILL.md`
- `skills/playwright-mcp/references/tool-inventory.md`
- `skills/playwright-mcp/references/cross-browser-recipes.md`
- `skills/playwright-mcp/references/capabilities-and-flags.md`

## Integration model

- **OpenCode**: opt-in global setup via `./setup.sh opencode --with-playwright-mcp`
- **Codex**: opt-in global setup via `./setup.sh codex --with-playwright-mcp`
- **GitHub Copilot**: opt-in global setup via `./setup.sh copilot --with-playwright-mcp`
- **Kiro**: opt-in global setup via `./setup.sh kiro --with-playwright-mcp`

`@playwright/mcp` is treated as an external MCP dependency, not as the skill itself.

## Browser-skill boundary

| Use case | Preferred skill |
| --- | --- |
| Firefox, WebKit/Safari-class, Edge, cross-engine comparison | `playwright-mcp` |
| Routine Chrome/Chromium automation, screenshots, scraping, simple form flows | `agent-browser` |
| Live Chrome session, DevTools-selected element, console/network/Lighthouse/performance/memory in Chrome | `chrome-devtools-mcp` |

This repo intentionally does **not** configure a Playwright Chromium server.

## Managed defaults

When `--with-playwright-mcp` is enabled, each repo-managed Playwright server uses:

```json
["-y", "@playwright/mcp@latest", "--browser=<engine>", "--headless", "--caps=testing"]
```

This means:

- Firefox / WebKit / Edge servers are headless by default
- assertion-grade `verify_*` and `browser_generate_locator` tools are enabled by default
- Playwright-specific artifact, storage, and network helpers stay opt-in

The repo-managed setup also supports:

| Setup flag | Effect |
| --- | --- |
| `--playwright-headed` | Launch the configured Playwright engines without `--headless` |
| `--playwright-caps-devtools` | Add `--caps=devtools` for trace/video and related QA helpers |
| `--playwright-caps-storage` | Add `--caps=storage` for cookie/localStorage/sessionStorage helpers |
| `--playwright-caps-network` | Add `--caps=network` for request mocking and offline simulation |
| `--playwright-isolated` | Add `--isolated` for in-memory isolated browser profiles |
| `--playwright-output-dir PATH` | Add `--output-dir=PATH` for predictable artifact output |

## Browser mapping

| Browser target | MCP server name | Launch args (default) |
| --- | --- | --- |
| Firefox | `playwright-firefox` | `--browser=firefox --headless --caps=testing` |
| WebKit / Safari-class | `playwright-webkit` | `--browser=webkit --headless --caps=testing` |
| Microsoft Edge | `playwright-msedge` | `--browser=msedge --headless --caps=testing` |

One server entry maps to one browser engine. Cross-engine checks should use multiple configured servers rather than trying to switch engines mid-session.

## Install

Default Playwright MCP setup:

```bash
./setup.sh opencode --with-playwright-mcp
./setup.sh codex --with-playwright-mcp
./setup.sh copilot --with-playwright-mcp
./setup.sh kiro --with-playwright-mcp
./setup.sh all --with-playwright-mcp
```

Visible browsers:

```bash
./setup.sh all --with-playwright-mcp --playwright-headed
```

Trace/video helpers:

```bash
./setup.sh all --with-playwright-mcp --playwright-caps-devtools
```

Storage helpers:

```bash
./setup.sh all --with-playwright-mcp --playwright-caps-storage
```

Network mocking helpers:

```bash
./setup.sh all --with-playwright-mcp --playwright-caps-network
```

Isolated profiles with a predictable artifact directory:

```bash
./setup.sh all --with-playwright-mcp --playwright-isolated --playwright-output-dir "./playwright-artifacts"
```

You can combine this with other optional integrations if needed:

```bash
./setup.sh all --with-context-mode --with-playwright-mcp
./setup.sh all --with-playwright-mcp --with-chrome-devtools-mcp
./setup.sh all --with-context-mode --with-playwright-mcp --with-chrome-devtools-mcp
```

## First-run browser install

The MCP server configuration is installed by `setup.sh`, but the browser engine itself may still need a one-time download. If the first run says the engine is missing, install it once before retrying:

```bash
npx @playwright/mcp@latest install-browser firefox
npx @playwright/mcp@latest install-browser webkit
npx @playwright/mcp@latest install-browser msedge
```

## Verify

Check the server wiring:

```bash
grep -n 'playwright-firefox' ~/.config/opencode/opencode.json
grep -n 'playwright-webkit' ~/.codex/config.toml
grep -n 'playwright-msedge' ~/.copilot/mcp-config.json
grep -n 'playwright-firefox' ~/.kiro/settings/mcp.json
```

Check the default testing capability:

```bash
grep -n 'caps=testing' ~/.config/opencode/opencode.json
grep -n 'caps=testing' ~/.codex/config.toml
grep -n 'caps=testing' ~/.copilot/mcp-config.json
grep -n 'caps=testing' ~/.kiro/settings/mcp.json
```

If you opted into devtools, storage, or network helpers, verify the config contains:

```bash
grep -n 'caps=testing,devtools' ~/.config/opencode/opencode.json
grep -n 'caps=testing,storage' ~/.codex/config.toml
grep -n 'caps=testing,network' ~/.copilot/mcp-config.json
```

If you opted into isolated mode or a custom output directory, verify the config contains:

```bash
grep -n 'isolated' ~/.config/opencode/opencode.json
grep -n 'output-dir' ~/.config/opencode/opencode.json
```

## Runtime guidance lives in the skill

Once the MCP servers are installed, the runtime guidance is intentionally kept with the skill:

- `skills/playwright-mcp/SKILL.md` explains **when** to load this skill
- `skills/playwright-mcp/SKILL.md` and its references explain **how** to use it effectively
- `docs/playwright-mcp.md` stays focused on **integration, defaults, verification, and removal**

## Upstream/manual-only capabilities

The upstream Playwright MCP server also supports flags such as:

- `--device`
- `--storage-state`
- `--init-page`
- `--init-script`
- `--extension`
- `--cdp-endpoint`
- `--save-session`

Those capabilities are **not** part of the repo-managed default setup. Read `skills/playwright-mcp/references/capabilities-and-flags.md` and `skills/playwright-mcp/references/cdp-and-extension.md` before treating them as available.

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

- This repo does not configure a Playwright Chromium server; Chrome/Chromium automation still belongs to `agent-browser`.
- WebKit is the closest Safari-class engine available here, but it is not identical to every Safari environment detail.
- Gated tools such as trace/video, storage helpers, and network mocking do not exist unless the matching repo-managed opt-in flag was used.
