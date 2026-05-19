# Troubleshooting

## Chrome crashes on macOS when Web Bluetooth prompts appear

This is a macOS privacy permission (TCC) issue.

Fix:

1. Open `System Settings > Privacy & Security > Bluetooth`
2. Grant Bluetooth permission to the MCP client application
3. Restart the client and start a new session

## `--auto-connect` times out

If tools like `list_pages`, `new_page`, or `navigate_page` time out with auto-connect:

1. Make sure Chrome 144+ is already running
2. Enable remote debugging in `chrome://inspect/#remote-debugging`
3. Accept the remote debugging prompt in Chrome
4. Make sure no other tool is fighting for the same debugging connection

On Chrome versions up to 149, frozen or unloaded tabs can also cause handshake problems. Chrome DevTools MCP forces tabs to load, so this is not a good fit for browser instances with hundreds of tabs open.

## MCP client sandbox cannot launch Chrome

Some clients sandbox the MCP server. When that happens, Chrome may fail to start.

Workarounds:

- disable sandboxing for `chrome-devtools-mcp` in the MCP client
- or start Chrome yourself and connect via `--browser-url`

## VM-to-host remote debugging fails

Chrome may reject the connection because of Host header validation.

Workaround from the VM:

```sh
ssh -N -L 127.0.0.1:9222:127.0.0.1:9222 <user>@<host-ip>
```

Then connect to `http://127.0.0.1:9222`.

## WSL caveats

By default, `chrome-devtools-mcp` in WSL expects Chrome inside the Linux environment.

Possible workarounds:

- install Google Chrome in WSL
- use mirrored networking and attach with `--browser-url http://127.0.0.1:9222`
- use PowerShell or Git Bash instead of WSL

## Windows `cmd /c` fix

If Windows 10 reports `Connection closed` while discovering the server, configure the MCP server through `cmd /c`:

```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "cmd",
      "args": ["/c", "npx", "-y", "chrome-devtools-mcp@latest"]
    }
  }
}
```

This is an upstream workaround for launching `npx` correctly from another host process.
