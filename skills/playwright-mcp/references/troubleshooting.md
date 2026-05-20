# Troubleshooting

## Browser engine missing on first run

If Firefox, WebKit, or Edge is missing, install the engine once and retry:

```bash
npx @playwright/mcp@latest install-browser firefox
npx @playwright/mcp@latest install-browser webkit
npx @playwright/mcp@latest install-browser msedge
```

## Headed browser on a headless host

Repo-managed setup is headless by default. If you explicitly enabled `--playwright-headed` on a headless host, expect display-related failures unless the host provides a display server.

## Missing capability-specific tools

If a tool is missing, check whether the server was started with the right repo-managed opt-in:

- missing trace/video helpers -> `--playwright-caps-devtools`
- missing storage helpers -> `--playwright-caps-storage`
- missing route/offline helpers -> `--playwright-caps-network`

Do not keep retrying the same tool call if the capability was never enabled.

## Parallel profile conflicts

If concurrent clients fight over browser state:

- switch to `--playwright-isolated`, or
- use distinct profile directories in a manual setup

Pair isolated mode with storage-state files when you still need seeded auth.

## Sandbox issues

Upstream Playwright MCP supports `--no-sandbox` for environments that require it. Treat that as an advanced/manual-only workaround.

## Artifact location confusion

If traces, videos, or screenshots land in an unexpected location, use `--playwright-output-dir PATH` so the output path is explicit and predictable.
