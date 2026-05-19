# PLAN — chrome-devtools-mcp UI testing improvements

## Goal

Improve the `chrome-devtools-mcp` skill for macOS UI verification by making it faster and more decision-oriented **without weakening the live-session / DevTools debugging workflows that distinguish it from `agent-browser`**. The plan should prove config behavior and routing boundaries first, then expand the skill's reference surface.

## Background

- Official Chrome DevTools MCP exposes 43+ tools across 9 categories (Input automation 10, Navigation 6, Emulation 2, Performance 3, Network 2, Debugging 8, Memory 5, Extensions 5 opt-in, Third-party 2 opt-in, WebMCP 2 opt-in). Source: upstream `docs/tool-reference.md`. Most third-party blogs still cite 29.
- Chrome DevTools MCP is **headed by default**. The repo's managed config currently does not pass `--headless`, so macOS runs open a visible Chrome window and steal focus.
- `--slim` exposes only 3 tools (`navigate_page`, `evaluate_script`, `take_screenshot`) and is only appropriate for narrow UI-verification workflows.
- `--isolated` uses a temp user-data-dir per run and cleans up on exit, which may help speed/reliability, but it also changes the state model relative to live-session debugging.
- `--experimentalPageIdRouting` adds `pageId` for concurrent agents on shared servers.
- `fill_form` is explicitly recommended by upstream over multiple `fill` calls.
- `includeSnapshot: true` piggybacks a fresh snapshot onto an action response (click, fill, fill_form, hover, press_key, upload_file, drag), removing a separate `take_snapshot` round-trip.
- Heavy assets (network bodies, traces, screenshots) should use `filePath` / `requestFilePath` / `responseFilePath` per upstream design principles.
- The official upstream repo ships bundled skills (`a11y-debugging`, `debug-optimize-lcp`, `memory-leak-debugging`, `troubleshooting`, `chrome-devtools`, `chrome-devtools-cli`), confirming the multi-doc structure is a valid pattern.
- macOS gotchas: Chrome can crash on Web Bluetooth permission prompts (TCC); `--autoConnect` requires Chrome 144+ with `chrome://inspect/#remote-debugging` enabled and may time out with hundreds of tabs.

## Acceptance Criteria

- Repo-managed config behavior is explicit and tested across OpenCode, Codex, Copilot, and Kiro:
  - default args include `--headless`
  - headed opt-out works
  - `--chrome-devtools-slim` opt-in works
  - `--chrome-devtools-auto-connect` composes correctly
  - `--isolated` vs persistent-profile behavior is deliberately chosen and covered by exact assertions
- OpenCode changes are wired through `setup.sh` **and** `scripts/context-mode-config.py`; Codex/Copilot/Kiro paths receive the same intended Chrome DevTools MCP args.
- At least one stable UI-verification recipe is demonstrated in `<=4` MCP calls using `fill_form` and/or `includeSnapshot: true`.
- Skill-loading evals prove routing boundaries between `chrome-devtools-mcp`, `agent-browser`, and `playwright-mcp`.
- A specific use-case matrix is documented and enforced in evals:
  - `chrome-devtools-mcp` for live logged-in Chrome sessions, DevTools-selected element inspection, Chrome console/network investigation, Lighthouse/performance/memory work, and Chrome-specific debugging where DevTools context matters
  - `agent-browser` for routine Chrome/Chromium UI automation, headed or headless form flows, screenshots, scraping, and general interaction testing that does not require DevTools context
  - `playwright-mcp` for Firefox, WebKit/Safari-class, Edge, and cross-browser verification
- Live-session / auto-connect workflow remains first-class and explicitly validated; no docs or defaults may imply that isolated fresh-profile mode replaces it.
- All new `references/*.md` links resolve from the installed symlinked skill directory.

## Plan

- [ ] **Task 1 — Lock the behavior and config matrix first.** Define the exact managed-args matrix for default, headed, slim, auto-connect, and any isolated/persistent-profile mode. Do not pre-commit to `--isolated` as the default until the live-session path is validated. Smoke-test criteria: setup smoke test assertions cover every supported combination.
- [ ] **Task 2 — Wire the real config surfaces.** Update `setup.sh` and `scripts/context-mode-config.py`; update `scripts/codex-config.py` only if merge behavior requires it. Ensure OpenCode, Codex, Copilot, and Kiro all emit the intended Chrome DevTools MCP args. Smoke-test criteria: inspect generated config files for each harness.
- [ ] **Task 3 — Extend setup validation before doc work.** Expand `scripts/test-chrome-devtools-mcp-setup.sh` to cover install -> remove -> reinstall, default/headed/slim/auto-connect combinations, and whichever isolated/persistent-profile decision ships. Keep existing `--no-usage-statistics` and `--auto-connect` behavior under test.
- [ ] **Task 4 — `references/tool-inventory.md`.** Author the in-skill source of truth for the 43+ tools, grouped by the 9 official categories, with one-line descriptions, required vs optional params, token-cost notes, and "prefer X over Y" hints. Call out which tools support the core Chrome-specific testing use cases versus generic UI work that should route elsewhere.
- [ ] **Task 5 — `references/ui-testing-recipes.md` + `references/performance-levers.md`.** Add 2-5 high-value recipes and the macOS speed guide first. Recipes must show compact `<=4`-call paths using `fill_form`, `includeSnapshot: true`, `evaluate_script`, and non-verbose snapshots where appropriate.
- [ ] **Task 6 — Rewrite `SKILL.md` as a decision-first front door.** Make the first branch explicit: live-session / DevTools debugging vs routine Chrome/Chromium UI automation vs cross-browser testing. Include a concise "which skill for which testing job" matrix so agents route to `chrome-devtools-mcp`, `agent-browser`, or `playwright-mcp` based on the use case instead of browser name alone. Reference only the core `references/*.md` files until the core workflows are proven.
- [ ] **Task 7 — Add skill-loading evals for routing boundaries.** Add explicit, implicit, near-miss, and negative cases for `chrome-devtools-mcp`, `agent-browser`, and `playwright-mcp`. Cover concrete testing scenarios: selected element in DevTools, Chrome console errors after submit, Lighthouse in current Chrome session, routine Chrome form automation, basic screenshot capture, Firefox-only repro, WebKit/Safari verification, Edge verification, and cross-browser comparison.
- [ ] **Task 8 — Add secondary reference docs if core behavior is proven.** Add `references/live-session.md`, `references/lighthouse-and-traces.md`, and `references/troubleshooting.md` after the config matrix, core recipes, and routing evals are green.
- [ ] **Task 9 — Update `docs/chrome-devtools-mcp.md` and `README.md` if needed.** Document final flag names, the actual default behavior, and the live-session vs isolated guidance that ships.
- [ ] **Task 10 — Final end-to-end validation.** Run `scripts/test-chrome-devtools-mcp-setup.sh`, the skill-loading eval runner, `scripts/test-battery.sh`, one compact local-site UI-verification recipe, and one explicit live-session / auto-connect walkthrough.

## Status Updates (newest first)

### 2026-05-19
- **Change:** Plan revised after a GPT-5.4 rubber-duck review. Accepted updates: add explicit acceptance criteria, move config/runtime validation ahead of doc expansion, widen setup work to include `scripts/context-mode-config.py`, and treat the `--isolated` default as conditional pending live-session validation.
- **State now:** No code changes. PLAN.md remains at `docs/plans/feat/chrome-devtools-mcp-ui-testing/PLAN.md`. The plan now proves config semantics and routing before expanding the full reference-doc surface.

### 2026-05-19
- **Change:** Plan originally authored on `main` after research into upstream `chrome-devtools-mcp` tool reference, README, design principles, and troubleshooting docs; comparison against `skills/agent-browser` and `skills/playwright-mcp`; review of repo `setup.sh` Chrome DevTools MCP wiring and `scripts/test-chrome-devtools-mcp-setup.sh`.
- **State now:** No code changes. Initial problem framing and research findings remain valid, but task ordering and default assumptions have been revised.
- **Validate:** `bash scripts/plan-path.sh --feature chrome-devtools-mcp-ui-testing --check` -> exits 0.

## Decisions

- 2026-05-19 — **Headless ON by default remains the leading proposal; add `--chrome-devtools-headed` opt-out.** — Biggest likely speed win on macOS and low risk to the skill boundary.
- 2026-05-19 — **Do not pre-commit to `--isolated` as the default.** — Validate it against live-session / auto-connect workflows first. If it blurs the `agent-browser` boundary or weakens the skill's differentiator, ship it as opt-in or as documented performance guidance instead.
- 2026-05-19 — **`--chrome-devtools-slim` stays opt-in only.** — Slim hides most of the tool surface and is inappropriate as a repo-wide default for a skill that still claims console/network/Lighthouse/perf/debugging coverage.
- 2026-05-19 — **Prioritize core docs before the full reference set.** — Tool inventory, core recipes, performance guidance, and SKILL routing come first; live-session/lighthouse/troubleshooting references follow once behavior is proven.
- 2026-05-19 — **Add skill-loading evals and use them as a routing guardrail.** — The main regression risk is misrouting between `chrome-devtools-mcp`, `agent-browser`, and `playwright-mcp`.
- 2026-05-19 — **Preserve a three-skill testing contract.** — The plan must explicitly align testing use cases across `chrome-devtools-mcp`, `agent-browser`, and `playwright-mcp` so Chrome DevTools workflows do not absorb routine automation and Playwright remains reserved for non-Chromium or cross-browser checks.
- 2026-05-19 — **Keep MCP-first; CLI stays docs-only.** — Matches the existing repo policy in `docs/chrome-devtools-mcp.md` and `skills/chrome-devtools-mcp/SKILL.md`.
- 2026-05-19 — **Plan path uses logical slug `chrome-devtools-mcp-ui-testing` on `main`.** — The existing `docs/plans/feat/chrome-devtools-mcp-skill/PLAN.md` covers the original skill bring-up; this is a follow-up effort and should keep its own plan file.

## Discoveries

- 2026-05-19 — Upstream `chrome-devtools-mcp` actually exposes **43+ tools across 9 categories**, not 29. Most third-party blog posts cite the older count. Authoritative source: upstream `docs/tool-reference.md`.
- 2026-05-19 — `chrome-devtools-mcp` is **headed by default**. The repo's managed config does not currently set `--headless`, which is a likely source of slow macOS runs.
- 2026-05-19 — Action tools (`click`, `fill`, `fill_form`, `hover`, `press_key`, `upload_file`, `drag`) accept an `includeSnapshot: true` parameter that piggybacks a fresh snapshot onto the response. The current `SKILL.md` default interaction sequence issues a separate `take_snapshot` per step and doubles tool turns unnecessarily.
- 2026-05-19 — `fill_form` is explicitly recommended by upstream over multiple `fill` calls and should be elevated into the main recipes, not buried in passing mention.
- 2026-05-19 — `take_snapshot` defaults to non-verbose; `verbose: true` returns the full a11y tree and bloats context.
- 2026-05-19 — Heavy assets (network bodies, screenshots, traces) should use `filePath` / `requestFilePath` / `responseFilePath` to keep them out of agent context.
- 2026-05-19 — `--experimentalPageIdRouting` is the upstream pattern for concurrent agents/subagents sharing a single MCP server. It belongs in performance/live-session guidance if those docs ship.
- 2026-05-19 — macOS Chrome can crash on Web Bluetooth permission prompts (TCC); `--autoConnect` requires Chrome 144+ with remote debugging enabled and may time out if too many tabs are loaded. These are high-value troubleshooting cases if the secondary docs ship.
- 2026-05-19 — The official upstream repo ships its own bundled skills directory (`skills/a11y-debugging`, `skills/debug-optimize-lcp`, `skills/memory-leak-debugging`, `skills/troubleshooting`, `skills/chrome-devtools`, `skills/chrome-devtools-cli`). This confirms the multi-doc structure is valid prior art, but not proof that every reference doc belongs in the first implementation pass.
- 2026-05-19 — OpenCode's managed MCP overlay is generated through `scripts/context-mode-config.py`, so setup work must cover that file rather than only `setup.sh` / Codex merge logic.
- 2026-05-19 — `agent-browser` ships a large reference surface and `playwright-mcp` has explicit performance guidance; `chrome-devtools-mcp` currently has neither, which contributes to looping once the skill loads.
- 2026-05-19 — The plan needs to enforce not just "better chrome-devtools docs" but also a clear testing-use-case split: Chrome DevTools context -> `chrome-devtools-mcp`; routine Chromium automation -> `agent-browser`; browser-engine coverage -> `playwright-mcp`.
- 2026-05-19 — The original plan mostly proved file presence and headings; the revised plan needs exact arg-matrix and routing validation to prove the user-visible behavior actually improved.
