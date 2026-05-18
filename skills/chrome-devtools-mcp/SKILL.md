---
name: chrome-devtools-mcp
description: |
  Chrome-specific debugging via the official Chrome DevTools MCP server. Use for
  live logged-in Chrome sessions, DevTools-selected element inspection, Chrome
  console or network investigation, Lighthouse or performance analysis, memory
  debugging, or Chrome extension debugging when DevTools context matters.
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
- Run Lighthouse or performance analysis against a live page
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

## Notes

- This skill is MCP-first. It should not switch to the `chrome-devtools` CLI as part of the default workflow.
- The CLI can still be useful for advanced shell-driven tasks, but that is a docs-only secondary path in this repo.
- Chrome DevTools MCP is Chrome-specific. Keep routine Chromium automation with `agent-browser` and browser-engine coverage with `playwright-mcp`.
