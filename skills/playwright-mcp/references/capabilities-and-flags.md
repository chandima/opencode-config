# Capabilities and flags

This file separates **repo-managed defaults**, **repo-managed opt-ins**, and **upstream/manual-only** settings.

## Repo-managed defaults

| Flag / behavior | Availability | Why it exists |
| --- | --- | --- |
| `--headless` | Default | Faster multi-engine runs and cleaner automation on macOS |
| `--caps=testing` | Default | Exposes `browser_generate_locator` and `browser_verify_*` for assertion-grade cross-engine checks |

## Repo-managed opt-ins

| Setup flag | Upstream flag | Effect | When to enable |
| --- | --- | --- | --- |
| `--playwright-headed` | remove `--headless` | Keeps the browser visible | Only when visual observation matters |
| `--playwright-caps-devtools` | `--caps=devtools` | Trace/video and related QA helpers | Artifact-heavy debugging or QA evidence |
| `--playwright-caps-storage` | `--caps=storage` | Cookie, localStorage, sessionStorage, storage-state tools | Explicit state setup or replay workflows |
| `--playwright-caps-network` | `--caps=network` | Request mocking and offline simulation | Browser-side network tests |
| `--playwright-isolated` | `--isolated` | In-memory isolated profiles | Parallel test sessions or disposable auth state |
| `--playwright-output-dir PATH` | `--output-dir PATH` | Predictable artifact location | Trace/video/screenshot files need stable paths |

## Upstream/manual-only settings

These are valid upstream capabilities, but the repo does not wire them by default:

| Upstream flag | Why it matters | Repo status |
| --- | --- | --- |
| `--device "iPhone 15"` | Mobile device emulation | Manual-only |
| `--storage-state <path>` | Seed isolated sessions with auth/state | Manual-only |
| `--init-page` | Preconfigure page object before navigation | Manual-only |
| `--init-script` | Override runtime before page scripts run | Manual-only |
| `--extension` | Connect to running Edge/Chrome via Playwright Extension | Manual-only |
| `--cdp-endpoint` | Connect to a Chromium-family browser over CDP | Manual-only |
| `--save-session` | Save the MCP session to the output directory | Manual-only |
| `--shared-browser-context` | Share one browser context across HTTP clients | Manual-only |

## Rollout notes

- The repo intentionally does **not** add a Playwright Chromium server.
- The repo intentionally keeps `devtools`, `storage`, `network`, `isolated`, and `output-dir` opt-in.
- If a task depends on a manual-only flag, say that the capability exists upstream but is not part of the repo-managed default.
