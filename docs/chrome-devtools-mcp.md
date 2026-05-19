# Chrome DevTools MCP integration

This repo can optionally configure the official [`chrome-devtools-mcp`](https://github.com/ChromeDevTools/chrome-devtools-mcp) server for the supported harnesses.

## Purpose of this document

This file is the **repo-level integration guide** for Chrome DevTools MCP.

Use it for:

- what `setup.sh` installs
- which managed defaults and flags the repo supports
- how to verify or remove the MCP wiring
- how Chrome DevTools MCP fits alongside `agent-browser` and `playwright-mcp`

Do **not** use this file as the main runtime usage guide for the skill itself.

For runtime behavior, routing, compact testing workflows, and tool-usage guidance, read:

- `skills/chrome-devtools-mcp/SKILL.md`
- `skills/chrome-devtools-mcp/references/live-session.md`
- `skills/chrome-devtools-mcp/references/ui-testing-recipes.md`
- `skills/chrome-devtools-mcp/references/tool-inventory.md`

## Integration model

- **OpenCode**: opt-in global setup via `./setup.sh opencode --with-chrome-devtools-mcp`
- **Codex**: opt-in global setup via `./setup.sh codex --with-chrome-devtools-mcp`
- **GitHub Copilot**: opt-in global setup via `./setup.sh copilot --with-chrome-devtools-mcp`
- **Kiro**: opt-in global setup via `./setup.sh kiro --with-chrome-devtools-mcp`

`chrome-devtools-mcp` is treated as an external MCP dependency, not as the skill itself.

## Browser-skill boundary

| Use case | Preferred skill |
| --- | --- |
| Live logged-in Chrome, DevTools-selected element, Chrome console/network, Lighthouse, performance, memory, extension debugging | `chrome-devtools-mcp` |
| Routine Chrome/Chromium automation, screenshots, form submission, scraping | `agent-browser` |
| Firefox, WebKit/Safari-class, Edge, cross-browser verification | `playwright-mcp` |

## Managed defaults

When `--with-chrome-devtools-mcp` is enabled, the repo-managed server uses:

```json
["-y", "chrome-devtools-mcp@latest", "--no-usage-statistics", "--headless"]
```

This means:

- usage statistics are disabled by default
- spawned Chrome runs are headless by default
- live-session attachment remains explicit

The repo-managed setup also supports:

| Setup flag | Effect |
| --- | --- |
| `--chrome-devtools-headed` | Launch spawned Chrome with a visible window instead of `--headless` |
| `--chrome-devtools-auto-connect` | Attach to a running local Chrome session instead of launching headless Chrome |
| `--chrome-devtools-slim` | Expose only the slim 3-tool surface for narrow UI-verification workflows |

## Install

Default headless Chrome DevTools MCP setup:

```bash
./setup.sh opencode --with-chrome-devtools-mcp
./setup.sh codex --with-chrome-devtools-mcp
./setup.sh copilot --with-chrome-devtools-mcp
./setup.sh kiro --with-chrome-devtools-mcp
./setup.sh all --with-chrome-devtools-mcp
```

Visible spawned Chrome:

```bash
./setup.sh all --with-chrome-devtools-mcp --chrome-devtools-headed
```

Live-session attachment to the user's running local Chrome:

```bash
./setup.sh all --with-chrome-devtools-mcp --chrome-devtools-auto-connect
```

Slim mode for narrow basic verification only:

```bash
./setup.sh all --with-chrome-devtools-mcp --chrome-devtools-slim
```

You can combine this with other optional integrations if needed:

```bash
./setup.sh all --with-context-mode --with-chrome-devtools-mcp
./setup.sh all --with-playwright-mcp --with-chrome-devtools-mcp
./setup.sh all --with-context-mode --with-playwright-mcp --with-chrome-devtools-mcp
```

## Verify

Check the server is wired into each harness:

```bash
grep -n 'chrome-devtools' ~/.config/opencode/opencode.json
grep -n 'chrome-devtools' ~/.codex/config.toml
grep -n 'chrome-devtools' ~/.copilot/mcp-config.json
grep -n 'chrome-devtools' ~/.kiro/settings/mcp.json
```

Check the default headless flag:

```bash
grep -n 'headless' ~/.config/opencode/opencode.json
grep -n 'headless' ~/.codex/config.toml
grep -n 'headless' ~/.copilot/mcp-config.json
grep -n 'headless' ~/.kiro/settings/mcp.json
```

If you opted into auto-connect, verify the config contains:

```bash
grep -n 'auto-connect' ~/.config/opencode/opencode.json
grep -n 'auto-connect' ~/.codex/config.toml
grep -n 'auto-connect' ~/.copilot/mcp-config.json
grep -n 'auto-connect' ~/.kiro/settings/mcp.json
```

If you opted into slim mode, verify the config contains:

```bash
grep -n 'slim' ~/.config/opencode/opencode.json
grep -n 'slim' ~/.codex/config.toml
grep -n 'slim' ~/.copilot/mcp-config.json
grep -n 'slim' ~/.kiro/settings/mcp.json
```

## Runtime guidance lives in the skill

Once the MCP server is installed, the runtime guidance is intentionally kept with the skill:

- `skills/chrome-devtools-mcp/SKILL.md` explains **when** to load this skill
- `skills/chrome-devtools-mcp/SKILL.md` and its references explain **how** to use it effectively
- `docs/chrome-devtools-mcp.md` stays focused on **integration, defaults, verification, and removal**

## Live-session attachment (integration view)

The repo-managed default does **not** attach to the user's current Chrome session. For that, opt into `--chrome-devtools-auto-connect`.

Auto-connect requires:

1. Chrome 144+ already running
2. remote debugging enabled in `chrome://inspect/#remote-debugging`
3. the remote debugging prompt accepted in Chrome

For runtime workflows and more explicit attachment flows such as `--browser-url`, `--ws-endpoint`, and `--ws-headers`, see `skills/chrome-devtools-mcp/references/live-session.md`.

## MCP vs CLI

This repo treats **MCP** as the primary workflow and the **CLI** as an optional advanced path.

Use **MCP** for:

- live authenticated Chrome sessions
- DevTools element inspection
- console or network investigation
- Lighthouse or performance work
- Chrome-specific debugging flows that need DevTools context

Use the **CLI** only as an advanced secondary path for:

- shell-driven scripting
- repeatable command-line workflows
- cases where a scripted audit is more useful than an agentic debugging flow

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
- Slim mode intentionally removes most DevTools workflows and should not be treated as the general default.
- Chrome DevTools MCP is Chrome-specific and should not replace `playwright-mcp` for non-Chromium or cross-browser work.
