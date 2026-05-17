---
name: playwright-mcp
description: |
  Browser automation via the official Playwright MCP server. Use for Firefox,
  WebKit/Safari-class, Microsoft Edge, or cross-browser verification when a
  Chromium-only tool is not enough. Triggers include requests to "test in
  Firefox", "reproduce in Safari", "check WebKit", "verify in Edge", "run
  this across browsers", or "compare behavior in all browsers". DO NOT use
  for: ordinary Chrome/Chromium browsing, one-off screenshots, generic form
  filling, or routine site interaction that agent-browser already supports.
compatibility: "OpenCode, Codex CLI, GitHub Copilot, Kiro. Requires Playwright MCP servers configured by setup.sh or client-native MCP config."
---

# Playwright MCP

Use the official Playwright MCP servers when browser-engine coverage matters more than lightweight Chrome/Chromium automation.

## When to Use

- Firefox-only bugs
- WebKit or Safari-class issues
- Microsoft Edge-specific behavior
- Cross-browser verification across multiple engines
- Requests that explicitly say Firefox, WebKit, Safari, Edge, or "all browsers"

## When NOT to Use

- General browser automation in Chrome or Chromium
- Simple screenshots or page scraping
- Routine login/form-submission flows that do not require browser-engine comparisons
- Cases where `agent-browser` already fits

## Prerequisite

This skill depends on the repo-managed Playwright MCP setup:

```bash
./setup.sh opencode --with-playwright-mcp
./setup.sh codex --with-playwright-mcp
./setup.sh copilot --with-playwright-mcp
./setup.sh kiro --with-playwright-mcp
```

If the MCP servers are not configured, do not improvise a replacement workflow. Tell the user that Playwright MCP is not installed for the current harness yet.

## Server Names

The repo wires three browser-specific MCP servers:

| Browser target | MCP server name |
|---|---|
| Firefox | `playwright-firefox` |
| WebKit / Safari-class | `playwright-webkit` |
| Microsoft Edge | `playwright-msedge` |

One Playwright MCP server instance is bound to one browser engine at startup. For cross-browser checks, use more than one of the configured Playwright MCP servers rather than trying to switch engines mid-session.

## Selection Guidance

1. If the user explicitly names a browser, use the matching Playwright MCP server.
2. If the user asks for "cross-browser", "all browsers", or a comparison across engines, use multiple Playwright MCP servers and report browser-specific differences.
3. If the request is just "open the page", "fill the form", "take a screenshot", or similar Chromium-friendly automation, stop and use `agent-browser` instead.

## Performance Guidance

- **Expect the repo-managed servers to be headless by default**. If a user explicitly wants to watch the browser, the setup repo should be invoked with `--playwright-headed`.
- **Install the browser once before the first run** when the harness reports that an engine is missing. For WebKit, that is:

  ```bash
  npx @playwright/mcp@latest install-browser webkit
  ```

- **Prefer direct routes over full app chrome traversal**. If the target flow lives at a stable deep link, navigate there directly instead of spending MCP turns opening sidebars or stepping through unrelated UI.
- **Prefer one compact scripted assertion over many tiny tool calls**. For deterministic checks, use the unsafe code path to batch navigation, setup, clicks, and assertions in one Playwright run instead of long click/snapshot loops.
- **Avoid extra evidence collection unless needed**. Accessibility snapshots, screenshots, console dumps, and network inspection are useful for debugging but add latency. Use them after the core assertion fails or when the user explicitly asks for evidence.
- **Use headless mode when visual observation is not required**. Official Playwright MCP docs note that the default is headed mode; headed WebKit runs are slower and leave visible browser windows behind.
- **For repeated runs, prefer a warm server process**. Official docs support starting Playwright MCP separately with `--port`; this avoids repeated process startup costs and can be paired with `--shared-browser-context` when appropriate.
- **Reuse state deliberately**. Persistent profiles or an explicit `--user-data-dir` can save time on repeated authenticated flows. If parallel clients are fighting over a profile, switch to `--isolated` or separate `--user-data-dir` paths.

## Notes

- WebKit is the closest Playwright engine for Safari-class issues, but it is not a perfect substitute for every Safari-specific environment detail.
- The repo intentionally does **not** configure a Playwright Chromium server by default, so the routing boundary stays clear: Chromium goes to `agent-browser`; non-Chromium or multi-browser work goes here.
- Official Playwright guidance also notes that CLI/skill-style workflows can be more token-efficient than MCP for coding agents. If browser-engine coverage is not the reason for the task, prefer a lighter workflow.
