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

## Notes

- WebKit is the closest Playwright engine for Safari-class issues, but it is not a perfect substitute for every Safari-specific environment detail.
- The repo intentionally does **not** configure a Playwright Chromium server by default, so the routing boundary stays clear: Chromium goes to `agent-browser`; non-Chromium or multi-browser work goes here.
