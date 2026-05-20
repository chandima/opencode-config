# CDP and extension boundaries

## Playwright extension attachment

Upstream Playwright MCP supports `--extension` for connecting to a running Edge/Chrome browser that has the Playwright Extension installed.

Important boundary:

- This is **not** the repo's default workflow
- This is **not** a replacement for `chrome-devtools-mcp`
- This does **not** mean Playwright becomes the live Chrome DevTools skill

## CDP endpoint attachment

Upstream Playwright MCP also supports `--cdp-endpoint` and related headers/timeouts for connecting to a Chromium-family browser over CDP.

Treat this as **manual-only** in this repo unless the user explicitly configured it.

## When to use `chrome-devtools-mcp` instead

Use `chrome-devtools-mcp` for:

- the user's current Chrome session
- DevTools-selected element inspection
- Chrome console or network debugging
- Lighthouse, performance, and memory workflows
- Chrome extension debugging where DevTools context matters

## When Playwright still fits

Playwright remains the right tool when the goal is:

- Firefox / WebKit / Edge coverage
- cross-engine comparison
- Playwright trace/video artifacts
- network mocking
- generated Playwright test code

Do not route a generic “current Edge session” request to `chrome-devtools-mcp` unless the repo explicitly adds support for that workflow.
