# Emulation and state

## Device and viewport setup

Upstream Playwright MCP supports device emulation and viewport overrides, including flags such as:

- `--device "iPhone 15"`
- `--viewport-size WIDTHxHEIGHT`
- `--user-agent ...`

These are **upstream/manual-only** in this repo unless the user explicitly configured them.

## Persistent state vs isolated state

There are two distinct patterns:

### Persistent profile

- Default upstream behavior
- Useful for repeated local testing with a saved profile
- Risk: concurrent clients can fight over the same profile

### Isolated profile

- Repo-managed opt-in via `--playwright-isolated`
- Keeps the profile in memory and discards it when the session ends
- Best for disposable test sessions or parallel runs

If you need isolated auth replay, pair isolated mode with upstream `--storage-state <path>`.

## Storage-state workflow

Use storage-state files when you need reproducible auth or seeded local state without relying on a persistent profile:

1. Start in isolated mode
2. Restore storage state
3. Run the scenario
4. Save updated storage state only if the workflow explicitly needs it

## Init hooks and secrets

Upstream/manual-only flags:

- `--init-page` for page-level bootstrap logic
- `--init-script` for early browser runtime overrides
- `--secrets <path>` for secret material used in scripted flows

Treat these as advanced setup knobs, not as repo-managed defaults.
