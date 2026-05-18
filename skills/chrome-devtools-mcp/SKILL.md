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

Use the official Chrome DevTools MCP server when Chrome DevTools context matters more than lightweight browser automation.

## When to Use

- Debug a page in an existing Chrome session
- Inspect the currently selected element in Chrome DevTools
- Investigate Chrome console errors or network requests
- Run Lighthouse audits against a live page
- Capture memory snapshots or performance traces
- Debug Chrome extension behavior with DevTools-native tooling

## When NOT to Use

- General browser automation in Chrome or Chromium
- Simple screenshots, page scraping, or form submission flows
- Routine login flows where `agent-browser` already fits
- Firefox, WebKit/Safari-class, Edge, or cross-browser verification
- Shell-driven command generation for the `chrome-devtools` CLI

## Prerequisite

This skill depends on the repo-managed Chrome DevTools MCP setup:

```bash
./setup.sh opencode --with-chrome-devtools-mcp
./setup.sh codex --with-chrome-devtools-mcp
./setup.sh copilot --with-chrome-devtools-mcp
./setup.sh kiro --with-chrome-devtools-mcp
```

For live-session attachment to a running local Chrome profile, opt in explicitly:

```bash
./setup.sh opencode --with-chrome-devtools-mcp --chrome-devtools-auto-connect
./setup.sh codex --with-chrome-devtools-mcp --chrome-devtools-auto-connect
./setup.sh copilot --with-chrome-devtools-mcp --chrome-devtools-auto-connect
./setup.sh kiro --with-chrome-devtools-mcp --chrome-devtools-auto-connect
```

If Chrome DevTools MCP is not configured for the current harness, do not improvise a replacement workflow. Tell the user the integration is not installed yet.

## Server Name

The repo wires one Chrome DevTools MCP server:

| Purpose | MCP server name |
|---|---|
| Chrome DevTools debugging | `chrome-devtools` |

## Selection Guidance

1. If the request is about a live Chrome session, a DevTools-selected element, Chrome console or network state, Lighthouse, performance, memory, or Chrome extension debugging, use `chrome-devtools`.
2. If the request is just "open the page", "fill the form", "take a screenshot", or similar Chromium-friendly automation, stop and use `agent-browser` instead.
3. If the request is Firefox, WebKit/Safari-class, Edge, or cross-browser verification, stop and use `playwright-mcp` instead.

## Live-session guidance

- Repo-managed config disables Chrome DevTools MCP usage statistics by default with `--no-usage-statistics`.
- Repo-managed config does **not** enable `--auto-connect` unless the user explicitly opts in with `--chrome-devtools-auto-connect`.
- If the MCP server is installed without auto-connect or `--browser-url`, do not claim it is attached to the user's existing Chrome session.

## Operational guardrails

- Verify tool availability once at session start, then proceed without re-enumerating tools mid-task.
- Do not re-introspect tool schemas mid-task unless a tool call fails with an explicit capability error.
- Prefer the smallest evidence set that answers the question.
- Prefer reading app state with `evaluate_script` when available; fall back to `take_snapshot` when no reliable client-side state is exposed.
- When request or response bodies are large, prefer `requestFilePath` / `responseFilePath` over inlining them into context.

## Live interaction and write-testing workflow

- Use this workflow for live interaction checks, not for Lighthouse, performance, memory, or console-only debugging.
- Start with `list_pages`, `select_page`, and `take_snapshot`.
- Use `evaluate_script` for baseline state when available.
- Prefer `fill_form` over repeated `fill` calls when the page structure allows it.
- For mutation checks, capture only:
  1. baseline UI/app state
  2. the specific write request/response when applicable
  3. the resulting UI/app state
- In live write testing, stop on 4xx/5xx responses, unexpected redirects, inability to verify the target record before submission, missing state changes, or new console errors.
- In read-only or diagnostic workflows, unexpected responses are findings to inspect and report, not automatic stop conditions.

### Default interaction sequence

Use this only when you are already attached to a live Chrome session and need to verify behavior in its real browser or authenticated state, not as a general automation workflow.

1. `list_pages`
2. `select_page`
3. `take_snapshot`
4. `evaluate_script` for baseline app state when available; otherwise read the baseline from the snapshot
5. `fill_form` when the flow is form-shaped; otherwise use `click`, `fill`, or `navigate_page` as needed
6. `list_network_requests`
7. `get_network_request` for the specific write or verification request that matters
8. `list_console_messages` for runtime health checks
9. Confirm the resulting UI/app state

For WebSocket- or SSE-driven flows, network capture may not be sufficient evidence on its own. Confirm the final state with `evaluate_script` or a fresh `take_snapshot`.

### Example: logged-in Chrome validation

1. `list_pages` and `select_page` to attach to the live tab.
2. `take_snapshot` to anchor the current UI and locate the target control.
3. `evaluate_script` to read the current count, selection, or store-backed state when available.
4. `fill_form` or `click` to perform the interaction.
5. `list_network_requests` and `get_network_request` to inspect the targeted write request and response.
6. `list_console_messages` to catch runtime errors introduced by the change.
7. `evaluate_script` or a fresh `take_snapshot` to confirm the updated UI/app state.

## Performance and Lighthouse workflow notes

- `lighthouse_audit` is for accessibility, SEO, best practices, and agentic browsing audits; it excludes performance.
- For performance work, use `performance_start_trace`, `performance_stop_trace`, then `performance_analyze_insight`.
- Treat the trace output as the source of truth for `insightName` and `insightSetId` before calling `performance_analyze_insight`.
- For console-only, memory, or extension-debugging tasks, jump directly to the relevant DevTools tools instead of following the interaction workflow above.

## Live-session state separation

- Use `new_page` with `isolatedContext` only when intentionally separating state for an additional flow.

## Notes

- This skill is MCP-first. It should not switch to the `chrome-devtools` CLI as part of the default workflow.
- The CLI can still be useful for advanced shell-driven tasks, but that is a docs-only secondary path in this repo.
- Chrome DevTools MCP is Chrome-specific. Keep routine Chromium automation with `agent-browser` and browser-engine coverage with `playwright-mcp`.
