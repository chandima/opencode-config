# Live Session Attachment

Use this reference when the request is about the user's **current Chrome session**, existing cookies, or a tab they already have open.

## Preferred repo-managed path: auto-connect

Install with:

```bash
./setup.sh opencode --with-chrome-devtools-mcp --chrome-devtools-auto-connect
./setup.sh codex --with-chrome-devtools-mcp --chrome-devtools-auto-connect
./setup.sh copilot --with-chrome-devtools-mcp --chrome-devtools-auto-connect
./setup.sh kiro --with-chrome-devtools-mcp --chrome-devtools-auto-connect
```

Auto-connect requires:

1. Chrome 144+ already running
2. Remote debugging enabled in `chrome://inspect/#remote-debugging`
3. The remote debugging connection prompt accepted in Chrome

## Explicit running-browser attachment: `--browser-url`

Use `--browser-url=http://127.0.0.1:9222` when you want the MCP server to attach to a specific debuggable Chrome instance.

Typical pattern:

1. Start Chrome with remote debugging enabled
2. Point Chrome DevTools MCP at that URL

This is the right fallback when the MCP client sandbox cannot launch Chrome itself.

## Direct WebSocket attachment: `--ws-endpoint`

Use `--ws-endpoint` when you already have the browser WebSocket debugger URL.

Typical source:

- `http://127.0.0.1:9222/json/version` -> `webSocketDebuggerUrl`

## Custom headers: `--ws-headers`

Use `--ws-headers` only with `--ws-endpoint`, for example when the WebSocket endpoint requires authentication headers.

## Live-session workflow

1. `list_pages`
2. `select_page`
3. `take_snapshot`
4. Continue with `click`, `fill_form`, `evaluate_script`, `list_console_messages`, or `list_network_requests`

## Important boundary

- If the setup did **not** include auto-connect, do not claim to be attached to the user's existing Chrome profile.
- If the task does **not** need the current Chrome session, prefer the default spawned-browser workflow instead.
