# Playwright MCP tool inventory

This reference groups the Playwright MCP surface by **repo-managed default**, **repo-managed opt-in**, and **upstream/manual-only** availability.

## Repo-managed default (`--with-playwright-mcp`)

The repo always enables `--caps=testing`, so these tools are the safe baseline to assume:

### Core navigation and interaction

- `browser_navigate`
- `browser_navigate_back`
- `browser_snapshot`
- `browser_click`
- `browser_type`
- `browser_fill_form`
- `browser_wait_for`
- `browser_take_screenshot`

### Compact scripted checks

- `browser_run_code_unsafe`

Use `browser_run_code_unsafe` when one deterministic scripted assertion is cleaner than a long sequence of clicks and snapshots.

### Assertion-grade testing tools

- `browser_generate_locator`
- `browser_verify_element_visible`
- `browser_verify_list_visible`
- `browser_verify_text_visible`
- `browser_verify_value`

Prefer `browser_verify_element_visible` when you can identify a stable element. Use `browser_verify_text_visible` for plain text checks. Use `browser_generate_locator` when you want to promote an exploratory run into a more stable test.

## Repo-managed opt-in: devtools (`--playwright-caps-devtools`)

Use these only when the server was configured with the devtools cap:

- trace start / stop tools
- video start / stop tools
- video chapter helpers
- annotation / highlight helpers

This cap is for QA evidence and artifact workflows, not the default happy path.

## Repo-managed opt-in: storage (`--playwright-caps-storage`)

Use these only when storage helpers were configured:

### Cookies

- `browser_cookie_list`
- `browser_cookie_get`
- `browser_cookie_set`
- `browser_cookie_delete`
- `browser_cookie_clear`

### localStorage

- `browser_localstorage_list`
- `browser_localstorage_get`
- `browser_localstorage_set`
- `browser_localstorage_delete`
- `browser_localstorage_clear`

### sessionStorage

- `browser_sessionstorage_list`
- `browser_sessionstorage_get`
- `browser_sessionstorage_set`
- `browser_sessionstorage_delete`
- `browser_sessionstorage_clear`

### Storage state files

- `browser_storage_state`
- `browser_set_storage_state`

Use these for deliberate state replay, not as a substitute for `chrome-devtools-mcp` live-session workflows.

## Repo-managed opt-in: network (`--playwright-caps-network`)

Use these only when network helpers were configured:

- `browser_network_state_set`
- `browser_route`
- `browser_route_list`
- `browser_unroute`

This is the Playwright-specific path for browser-side request mocking and offline simulation.

## Upstream/manual-only categories not repo-managed by default

These upstream capabilities exist, but the repo does not enable them by default:

- `vision` cap for coordinate-based tools
- `pdf` cap for PDF generation
- `config` cap for configuration inspection
- device emulation flags such as `--device`
- extension / CDP flags such as `--extension` and `--cdp-endpoint`

## Preferred tool choices

- Prefer `browser_fill_form` over repeated `browser_type` calls for forms.
- Prefer `browser_snapshot` over `browser_take_screenshot` when you need to act on the page.
- Prefer `browser_run_code_unsafe` for compact deterministic checks.
- Prefer `browser_verify_*` tools over improvised DOM assertions when the testing cap is available.
