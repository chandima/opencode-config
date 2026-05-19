---
name: chrome-devtools-mcp
description: |
  Chrome-specific debugging via the official Chrome DevTools MCP server. Use for
  live logged-in Chrome sessions, DevTools-selected element inspection, Chrome
  console or network investigation, Lighthouse audits, deep performance tracing,
  memory debugging, or Chrome extension debugging when DevTools context matters.
  Triggers include requests to "inspect the selected element in DevTools",
  "debug this in my current Chrome session", "check Chrome console errors",
  "inspect network requests in Chrome", "run Lighthouse on this logged-in page",
  or "profile this page in Chrome". DO NOT use for: routine Chrome/Chromium
  browsing, simple screenshots or form filling, general scraping, shell-command
  workflows with the `chrome-devtools` CLI, or Firefox/WebKit/Edge/cross-browser
  checks.
compatibility: "OpenCode, Codex CLI, GitHub Copilot, Kiro. Requires Chrome DevTools MCP configured by setup.sh or client-native MCP config."
---

# Chrome DevTools MCP

Use the official Chrome DevTools MCP server when **Chrome DevTools context** matters more than generic browser automation.

## Use This Skill or Another One?

| Testing job | Use this skill? | Why |
| --- | --- | --- |
| Live logged-in Chrome session | **Yes** | Attach to the real Chrome context the user already has open |
| DevTools-selected element inspection | **Yes** | The selected element comes from DevTools, not generic page automation |
| Chrome console / network debugging | **Yes** | These are DevTools-native workflows |
| Lighthouse / performance / memory in Chrome | **Yes** | These require Chrome DevTools tooling |
| Routine Chrome form flow, screenshots, scraping | **No — use `agent-browser`** | Faster and simpler for Chromium automation |
| Firefox / WebKit / Edge / cross-browser testing | **No — use `playwright-mcp`** | That skill is for browser-engine coverage |

## Prerequisite

Install the MCP server via the repo-managed setup:

```bash
./setup.sh opencode --with-chrome-devtools-mcp
./setup.sh codex --with-chrome-devtools-mcp
./setup.sh copilot --with-chrome-devtools-mcp
./setup.sh kiro --with-chrome-devtools-mcp
```

Repo-managed defaults:

| Mode | Setup flag | Result |
| --- | --- | --- |
| Default | `--with-chrome-devtools-mcp` | Launches Chrome DevTools MCP with `--headless` and usage statistics disabled |
| Live session | `--chrome-devtools-auto-connect` | Attaches to a running local Chrome session instead of launching headless Chrome |
| Visible browser | `--chrome-devtools-headed` | Keeps spawned Chrome visible for debugging |
| Narrow UI verification | `--chrome-devtools-slim` | Shrinks the tool surface to basic navigation / eval / screenshot only |

If Chrome DevTools MCP is not configured for the current harness, do not improvise a replacement workflow. Tell the user the integration is not installed yet.

## Server Name

| Purpose | MCP server name |
| --- | --- |
| Chrome DevTools debugging | `chrome-devtools` |

## Decision Flow

1. If the user wants **their current Chrome session**, a **DevTools-selected element**, **console/network state**, **Lighthouse**, **performance**, **memory**, or **Chrome extension debugging**, use `chrome-devtools`.
2. If the ask is just **open the page**, **fill the form**, **click around**, **take a screenshot**, or similar routine Chromium automation, stop and use `agent-browser`.
3. If the ask is **Firefox**, **WebKit/Safari-class**, **Edge**, or **cross-browser**, stop and use `playwright-mcp`.

## 60-Second Quickstart

### Fast standalone Chrome-specific check (4 calls)

Use this when DevTools tooling matters but you do **not** need the user's existing Chrome profile.

1. `new_page` with the target URL
2. `take_snapshot`
3. `fill_form` or `click` with `includeSnapshot: true`
4. `evaluate_script` or `list_console_messages` for the one thing you need to verify

### Fast live-session check (4 calls)

Use this when the user explicitly wants their current Chrome state.

1. `list_pages`
2. `select_page`
3. `take_snapshot`
4. `fill_form` or `click` with `includeSnapshot: true`

Use one extra call only if you still need console/network evidence after the action.

## Operational Rules

- **Verify tool availability once**, then stop re-enumerating tools mid-task unless a call fails with a capability error.
- **Prefer `fill_form` over repeated `fill` calls** for forms.
- **Prefer `includeSnapshot: true`** on `click`, `fill`, `fill_form`, `hover`, `press_key`, `upload_file`, and `drag` so you do not spend an extra turn on `take_snapshot`.
- **Prefer `evaluate_script` for deterministic state checks** when the app exposes state cleanly. Use `take_snapshot` when you need UI structure or uids.
- **Keep snapshots non-verbose by default**. Only use `verbose: true` when you genuinely need the full a11y tree.
- **Use file outputs for heavy assets**: `filePath`, `requestFilePath`, `responseFilePath`, trace outputs, screenshots, and heapsnapshots.
- **Do not treat this as a generic browser-driving skill.** If DevTools context stops mattering, switch to `agent-browser`.

## Workflow Boundaries

### Live Chrome / write-validation workflow

Use this only when you are intentionally validating behavior in a real Chrome session or in Chrome-specific state.

1. Establish page context (`list_pages` + `select_page`, or `new_page` for a standalone run).
2. Get the current UI anchor with `take_snapshot`.
3. Perform the interaction with `fill_form`, `click`, `press_key`, or `navigate_page`, preferably with `includeSnapshot: true`.
4. Confirm exactly one of:
   - resulting UI state (`take_snapshot` result or returned snapshot)
   - app state (`evaluate_script`)
   - network mutation (`list_network_requests` + `get_network_request`)
   - runtime health (`list_console_messages`)

### Performance / Lighthouse workflow

- Use `lighthouse_audit` for accessibility, SEO, best practices, and agentic browsing audits.
- Use `performance_start_trace` -> `performance_stop_trace` -> `performance_analyze_insight` for performance work.
- Treat the trace output as the source of truth for `insightName` and `insightSetId`.

### Memory / extension workflow

- Use heapsnapshot tools for memory-leak investigations.
- Use extension tools only when the server was started with the extensions category enabled.

## Live-Session Guidance

- Repo-managed config disables usage statistics with `--no-usage-statistics`.
- Repo-managed config is **headless by default** only for spawned Chrome runs.
- `--chrome-devtools-auto-connect` is the explicit path for attaching to a running Chrome profile.
- If the server was installed without `--chrome-devtools-auto-connect`, do not claim you are attached to the user's existing Chrome session.

## Deep-Dive References

| Reference | When to Read It |
| --- | --- |
| [references/tool-inventory.md](references/tool-inventory.md) | Full tool inventory grouped by category, including slim-mode constraints |
| [references/ui-testing-recipes.md](references/ui-testing-recipes.md) | Compact 2-4-call UI verification flows |
| [references/performance-levers.md](references/performance-levers.md) | Speed and token-efficiency guidance for macOS and repeated runs |
| [references/live-session.md](references/live-session.md) | Auto-connect, `--browser-url`, `--ws-endpoint`, and current-Chrome workflows |
| [references/lighthouse-and-traces.md](references/lighthouse-and-traces.md) | Lighthouse modes plus trace/insight analysis flows |
| [references/troubleshooting.md](references/troubleshooting.md) | Bluetooth TCC, auto-connect timeouts, sandbox, WSL, and Windows fixes |

## Notes

- This skill is MCP-first. Do not switch to the `chrome-devtools` CLI as the default workflow.
- `--chrome-devtools-slim` is only for narrow UI-verification projects. It intentionally removes most DevTools workflows.
- Chrome DevTools MCP is Chrome-specific. Keep routine Chromium automation with `agent-browser` and engine coverage with `playwright-mcp`.
