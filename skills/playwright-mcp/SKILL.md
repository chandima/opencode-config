---
name: playwright-mcp
description: |
  Browser automation via the official Playwright MCP servers. Use for Firefox,
  WebKit/Safari-class, Microsoft Edge, cross-browser comparison, Playwright
  trace/video capture, browser-side network mocking, or Playwright TypeScript
  test generation when Chromium-only automation is not enough. Triggers include
  requests to "use playwright-mcp", "reproduce this bug in Firefox",
  "compare this flow across Firefox, WebKit, and Edge and tell me where it
  behaves differently", "record a Playwright trace and video", or "turn this
  exploratory browser flow into generated Playwright TypeScript test code". DO NOT use for:
  routine Chrome/Chromium automation, one-off screenshots or scraping
  that `agent-browser` already handles well, or live Chrome DevTools debugging
  in the user's current Chrome session (use `chrome-devtools-mcp` instead).
compatibility: "OpenCode, Codex CLI, GitHub Copilot, Kiro. Requires Playwright MCP servers configured by setup.sh or client-native MCP config."
---

# Playwright MCP

Use the official Playwright MCP servers when **browser-engine coverage or Playwright-specific test features** matter more than lightweight Chromium automation.

## Use This Skill or Another One?

| Testing job | Use this skill? | Why |
| --- | --- | --- |
| Firefox-only bug | **Yes** | Repo-managed Playwright provides a dedicated Firefox server |
| WebKit / Safari-class repro | **Yes** | WebKit coverage is a Playwright-specific differentiator |
| Edge-specific behavior | **Yes** | Repo-managed Playwright provides a dedicated Edge server |
| Cross-engine compare across Firefox / WebKit / Edge | **Yes** | This skill is the repo's cross-engine front door |
| Mobile emulation, network mocking, generated Playwright code, trace/video artifacts | **Yes** | These are Playwright-specific workflows, not generic browser driving |
| Routine Chrome/Chromium form flow, screenshots, scraping | **No — use `agent-browser`** | Faster and simpler for routine Chromium automation |
| Live Chrome session, DevTools-selected element, console/network/Lighthouse/performance in current Chrome | **No — use `chrome-devtools-mcp`** | Those are Chrome DevTools workflows, not Playwright workflows |

## Prerequisite

Install the MCP servers via the repo-managed setup:

```bash
./setup.sh opencode --with-playwright-mcp
./setup.sh codex --with-playwright-mcp
./setup.sh copilot --with-playwright-mcp
./setup.sh kiro --with-playwright-mcp
```

Repo-managed defaults:

| Mode | Setup flag | Availability | Result |
| --- | --- | --- | --- |
| Default | `--with-playwright-mcp` | Repo-managed default | Firefox / WebKit / Edge servers with `--headless --caps=testing` |
| Visible browser | `--playwright-headed` | Repo-managed opt-in | Removes `--headless` |
| Trace / video helpers | `--playwright-caps-devtools` | Repo-managed opt-in | Adds `--caps=devtools` |
| Storage helpers | `--playwright-caps-storage` | Repo-managed opt-in | Adds `--caps=storage` |
| Network mocking | `--playwright-caps-network` | Repo-managed opt-in | Adds `--caps=network` |
| Isolated profile | `--playwright-isolated` | Repo-managed opt-in | Adds `--isolated` |
| Predictable artifacts | `--playwright-output-dir PATH` | Repo-managed opt-in | Adds `--output-dir=PATH` |

If Playwright MCP is not configured for the current harness, do not improvise a replacement workflow. Tell the user the integration is not installed yet.

## Server Names

| Browser target | MCP server name |
| --- | --- |
| Firefox | `playwright-firefox` |
| WebKit / Safari-class | `playwright-webkit` |
| Microsoft Edge | `playwright-msedge` |

One Playwright MCP server instance maps to one browser engine. For cross-engine checks, use more than one configured Playwright MCP server instead of trying to switch engines mid-session.

## Decision Flow

1. If the ask is **Firefox**, **WebKit/Safari-class**, **Edge**, or a **cross-engine comparison**, use the matching Playwright MCP server or multiple Playwright MCP servers.
2. If the ask is **mobile emulation**, **network mocking**, **trace/video evidence**, or **generated Playwright code**, use this skill if the required capability is repo-managed or explicitly configured.
3. If the ask is just **open the page**, **fill the form**, **click through**, **take a screenshot**, or similar routine Chromium automation, stop and use `agent-browser`.
4. If the ask is about the user's **current Chrome session**, **DevTools context**, **console/network investigation**, **Lighthouse**, or **performance** in Chrome, stop and use `chrome-devtools-mcp`.

## 60-Second Quickstart

### Fast single-engine verification (4 calls)

Use this when one non-Chromium engine is the main question.

1. `browser_navigate`
2. `browser_snapshot`
3. `browser_click` or `browser_fill_form`
4. `browser_verify_text_visible`, `browser_verify_element_visible`, or `browser_run_code_unsafe`

### Cross-engine fan-out (5 calls total per engine group)

Use this when the user wants Firefox / WebKit / Edge comparison, not a Chrome workflow.

1. Start with one Playwright MCP server per target engine
2. `browser_navigate` on each engine
3. `browser_snapshot` on each engine
4. `browser_run_code_unsafe` or `browser_verify_*` on each engine
5. Report only the engine-specific differences

Keep the verification logic identical across engines so the diff is meaningful.

## Operational Rules

- **Prefer `browser_fill_form` over repeated `browser_type` loops** for forms.
- **Prefer `browser_run_code_unsafe` for compact deterministic assertions** when you can express the whole check in one scripted step.
- **Prefer `browser_snapshot` over `browser_take_screenshot`** for actions. Use screenshots when the user explicitly needs image evidence.
- **Use the repo-managed default `verify_*` tools first** for cross-engine confirmation. They are available because the repo enables `--caps=testing` by default.
- **Do not assume gated tools exist.** `browser_route*`, trace/video helpers, and storage helpers only exist when the corresponding repo-managed opt-in cap was configured.
- **Treat mobile emulation and extension/CDP attachment as capability-specific workflows**, not as the default mode of this skill.
- **Do not imply Chromium coverage through Playwright in this repo.** The repo does not configure a Playwright Chromium server.

## Workflow Boundaries

### Cross-engine verification workflow

1. Pick the exact Playwright MCP server(s) for Firefox, WebKit, or Edge.
2. Navigate directly to the page under test.
3. Interact once with `browser_fill_form`, `browser_click`, or a compact `browser_run_code_unsafe`.
4. Confirm with `browser_verify_*` or one deterministic script assertion.
5. Report only the differences between engines.

### QA artifact workflow

- Use `--playwright-caps-devtools` only when the user explicitly needs Playwright trace/video artifacts.
- If artifact files need a predictable location, also use `--playwright-output-dir PATH`.
- Keep trace/video collection opt-in; it is heavier than the default verification path.

### Network mocking workflow

- Use `--playwright-caps-network` when the ask requires `browser_route`, `browser_route_list`, `browser_unroute`, or offline simulation.
- If network mocking is not enabled, say so instead of pretending the tools exist.

## Capability Availability

- **Repo-managed default:** `--headless`, `--caps=testing`
- **Repo-managed opt-in:** `--playwright-caps-devtools`, `--playwright-caps-storage`, `--playwright-caps-network`, `--playwright-isolated`, `--playwright-output-dir`
- **Upstream/manual-only unless the user configured them separately:** `--device`, `--storage-state`, `--init-page`, `--init-script`, `--extension`, `--cdp-endpoint`, `--save-session`, `--shared-browser-context`

Read the references before depending on a capability that is not repo-managed by default.

## Deep-Dive References

| Reference | When to Read It |
| --- | --- |
| [references/tool-inventory.md](references/tool-inventory.md) | Tool categories, core vs gated tools, and preferred tool choices |
| [references/cross-browser-recipes.md](references/cross-browser-recipes.md) | Compact Playwright-only recipes for WebKit, Edge, fan-out, mocking, and codegen |
| [references/capabilities-and-flags.md](references/capabilities-and-flags.md) | Repo-managed defaults, opt-in caps, and upstream/manual-only flags |
| [references/emulation-and-state.md](references/emulation-and-state.md) | Device emulation, viewport/state setup, isolated mode, and storage state |
| [references/cdp-and-extension.md](references/cdp-and-extension.md) | Playwright extension/CDP attachment and the boundary with `chrome-devtools-mcp` |
| [references/troubleshooting.md](references/troubleshooting.md) | Missing browsers, headed-mode issues, profile conflicts, sandbox, and missing capability tools |

## Notes

- This skill is MCP-first. Do not switch to a generic browser CLI unless the task no longer needs Playwright-specific value.
- WebKit is the closest Safari-class engine available here, but it is not identical to every Safari environment detail.
- Keep routine Chromium automation with `agent-browser`, and keep live Chrome DevTools workflows with `chrome-devtools-mcp`.
