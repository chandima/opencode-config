# PLAN — playwright-mcp multi-browser efficacy improvements

## Goal

Make `playwright-mcp` clearly the right tool for cross-engine browser testing **without weakening the three-skill contract** (`chrome-devtools-mcp` for live Chrome/DevTools, `agent-browser` for routine Chromium automation, `playwright-mcp` for non-Chromium and cross-engine work). Today the skill is one ~150-line `SKILL.md` with no `references/`, no `tests/`, and the repo-managed servers do not enable any `--caps`, so the most differentiating Playwright MCP capabilities (assertion-grade verification, trace/video, locator generation, network mocking, mobile device emulation) are invisible to the agent. This plan adds a structured reference set, raises the most useful caps to default, and makes the cross-engine fan-out workflow first-class while explicitly preserving the routing boundary against the other two skills.

## Background

- Upstream `microsoft/playwright-mcp@latest` ships ~60+ tools across 8 categories. Default ("core") set is ~22 tools (navigation, click, fill_form, snapshot, evaluate, network_request, run_code_unsafe, etc.). The rest are gated behind `--caps`.
- `--caps` values: `vision` (~6 mouse_*_xy tools), `pdf` (`browser_pdf_save`), `devtools` (annotate, highlight, trace start/stop, video start/stop, video_chapter, resume), `testing` (generate_locator, verify_element_visible, verify_list_visible, verify_text_visible, verify_value), `storage` (~15 cookie/localStorage/sessionStorage/storage_state tools), `network` (network_state_set, route, route_list, unroute), `config` (browser_get_config).
- Playwright MCP is **headed by default** upstream. The repo overrides this with `--headless` already.
- Playwright-only differentiators vs the other two skills: cross-engine (chromium/firefox/webkit/msedge), `--device "iPhone 15"` mobile emulation, `--caps=testing` for assertion-grade verification and locator emission, `--caps=devtools` for Playwright trace + video QA artifacts, `browser_route` for network mocking, `--codegen=typescript` for emitting test code, `--storage-state` for ephemeral auth replay, `--init-page` / `--init-script` for geolocation/permissions/viewport seeding, `--secrets` for response redaction, `--shared-browser-context` + `--port` for HTTP-transport server reuse, `--extension` for connecting to a running browser, `--save-session` for full session replay.
- Repo-managed args today are minimal: `["-y", "@playwright/mcp@latest", "--browser=X", "--headless"]`. **None** of the `--caps` are wired, so even when the user asks for "verify in WebKit" or "record a trace", the agent will not see those tools.
- Upstream README is explicit that MCP is for "specialized agentic loops" — exploratory automation, self-healing tests, long-running autonomous workflows — while CLI+SKILLs win for routine token-efficient work. Current SKILL.md already echoes this and should keep it.
- Existing eval coverage: 3 cases (`playwright_explicit_firefox`, `playwright_implicit_cross_browser_compare`, `playwright_near_miss_chrome_console_debug`). No coverage for mobile emulation, trace/video requests, locator generation, generated test code, WebKit-specific Safari-class repro, or Edge-specific behavior.

## Acceptance Criteria

- Repo-managed config behavior is explicit and tested across OpenCode, Codex, Copilot, and Kiro:
  - default args include `--headless` (no regression)
  - `--playwright-headed` opt-out works (no regression)
  - `--caps=testing` is included by default (verify_* + generate_locator) so cross-browser verification has assertion-grade tools out of the box
  - `--playwright-caps-devtools` opt-in adds trace + video for QA-artifact workflows
  - `--playwright-caps-storage` opt-in adds cookies/localStorage/sessionStorage tools
  - `--playwright-caps-network` opt-in adds request-mocking and offline-simulation tools
  - `--playwright-isolated` opt-in switches to ephemeral profile mode (paired with `--storage-state` guidance for auth)
  - `--playwright-output-dir` opt-in pins trace/video/screenshot output to a predictable workspace path
  - All three configured browser servers (`playwright-firefox`, `playwright-webkit`, `playwright-msedge`) receive identical args within a given mode
  - No Chromium server is added (preserves the boundary with `agent-browser`)
- OpenCode changes are wired through `setup.sh` **and** `scripts/context-mode-config.py`; Codex/Copilot/Kiro paths receive the same intended args.
- The setup smoke test `scripts/test-playwright-mcp-setup.sh` is refactored into per-target functions (`test_opencode`, `test_codex`, `test_copilot`, `test_kiro`) with shared `assert_default_args` / `assert_headed_args` / `assert_caps_devtools_args` / `assert_caps_storage_args` / `assert_isolated_args` / `assert_output_dir_args` helpers, mirroring the structure used by `scripts/test-chrome-devtools-mcp-setup.sh`.
- Setup validation covers install -> remove -> reinstall paths, one `--playwright-output-dir` path containing spaces, and one combined Playwright + Chrome DevTools install to prove flags do not leak across integrations.
- Runtime validation proves the actual exposed tool surface, not just serialized config text:
  - default mode exposes `verify_*` and `generate_locator`
  - `--playwright-caps-devtools` exposes trace/video tools
  - `--playwright-caps-storage` exposes storage tools
  - `--playwright-caps-network` exposes route/offline tools
- A local `skills/playwright-mcp/tests/smoke.sh` validates frontmatter, no path escapes, references existence and linkage, and key SKILL.md sections — auto-discovered by `scripts/test-battery.sh`.
- At least three concrete Playwright-unique recipes are documented with a clear call budget: single-engine checks stay within <=4 MCP calls, and cross-engine fan-out recipes may use <=5 calls.
- Skill-loading evals enforce routing boundaries with new cases for: WebKit Safari-class repro, Edge-specific behavior, mobile device emulation ("iPhone"), Playwright trace/video request, generated test code request, cross-engine fan-out, network mocking, plus near-miss cases ("test in Chrome" -> agent-browser; "inspect my current Chrome session" -> chrome-devtools-mcp).
- A specific testing use-case matrix is documented and enforced in evals:
  - `playwright-mcp` for Firefox/WebKit/Edge engine coverage, cross-engine comparison, mobile device emulation, Playwright trace/video, assertion-grade `verify_*` and generated TS test code, network mocking, ephemeral isolated sessions with `--storage-state`
  - `agent-browser` for routine Chrome/Chromium automation, screenshots, scraping, simple form flows
  - `chrome-devtools-mcp` for live logged-in Chrome session, DevTools-selected element, Chrome console/network/Lighthouse/performance/memory, Chrome extension debugging
- All new `references/*.md` links resolve from the installed symlinked skill directory.
- `docs/playwright-mcp.md` remains the repo-level integration guide: final flag names, managed defaults, install/verify/remove steps, troubleshooting summary, and a concise boundary matrix. Runtime recipes, operational guidance, and deep troubleshooting live in `skills/playwright-mcp/SKILL.md` plus `references/`, with explicit cross-links from the integration doc.

## Plan

- [ ] **Task 1 — Lock the new arg matrix.** Define exact managed args for: default (with `--caps=testing`), headed, `+devtools`, `+storage`, `+network`, isolated, output-dir, and combinations. Decide whether `--caps=testing` ships as default-on or opt-in (proposed: default-on). Decide isolated default (proposed: opt-in only, preserves persistent profile semantics). Record a rollback criterion for default-on `--caps=testing` if runtime validation or routing evals show tool-surface bloat or selection regressions. Smoke-test criteria: setup smoke covers every supported combination.
- [ ] **Task 2 — Wire the real config surfaces.** Update `setup.sh` (`playwright_args_json`, `playwright_args_toml`, plus new `--playwright-caps-devtools`, `--playwright-caps-storage`, `--playwright-caps-network`, `--playwright-isolated`, `--playwright-output-dir` flags) and `scripts/context-mode-config.py` (`build_playwright_mcp_entries` plus the OpenCode argparse surface). All four CLIs emit identical args within a given mode.
- [ ] **Task 3 — Refactor `scripts/test-playwright-mcp-setup.sh`.** Factor into `run_setup`, `assert_default_args`, `assert_headed_args`, `assert_caps_devtools_args`, `assert_caps_storage_args`, `assert_caps_network_args`, `assert_isolated_args`, and `assert_output_dir_args` helpers plus per-target `test_opencode` / `test_codex` / `test_copilot` / `test_kiro` functions, mirroring `scripts/test-chrome-devtools-mcp-setup.sh`. Cover install -> remove -> reinstall paths, one output-dir path containing spaces, and the existing Playwright + Chrome DevTools combination to ensure flag separation.
- [ ] **Task 4 — `references/tool-inventory.md`.** In-skill source of truth for the full ~60-tool surface, grouped by category and clearly marked with `--caps` gating. Include "prefer X over Y" hints (`browser_fill_form` over multiple `browser_type`, `browser_run_code_unsafe` for one-shot scripted assertions, `browser_snapshot` over `browser_take_screenshot` for actions) and a "core vs gated" split so the agent never asks for a tool that is not currently available.
- [ ] **Task 5 — `references/cross-browser-recipes.md` + `references/capabilities-and-flags.md`.** Recipes must show clear, realistic call budgets and lean on Playwright-unique tools. Required recipes: (a) WebKit Safari-class repro using `--browser=webkit` + `verify_*` in <=4 calls; (b) Mobile device emulation using `--device "iPhone 15"`; (c) Cross-engine fan-out running the same compact `browser_run_code_unsafe` against firefox/webkit/msedge in parallel and diffing results in <=5 calls; (d) Network mocking then verify using `browser_route` + `verify_text_visible`; (e) Promote exploratory run to test using `--codegen=typescript`. Capabilities doc maps every `--caps` value to its tool list, performance cost, and the use case that justifies enabling it.
- [ ] **Task 6 — `references/emulation-and-state.md` + `references/cdp-and-extension.md` + `references/troubleshooting.md`.** Emulation-and-state covers `--device`, `--viewport-size`, `--user-agent`, `--user-data-dir` vs `--isolated` + `--storage-state`, `--init-page` for geolocation/permissions, `--init-script`, `--secrets`. cdp-and-extension covers the boundary with `chrome-devtools-mcp` (Playwright `--extension` is Edge/Chrome only and **does not** replace chrome-devtools-mcp's live-session attachment) and `--cdp-endpoint` for connecting to existing Chromium-family browsers. troubleshooting covers first-run `npx @playwright/mcp@latest install-browser <engine>`, headed-mode-on-headless-host (`--port` + DISPLAY pattern), parallel persistent-profile conflict via `--isolated`, sandbox/`--no-sandbox` workarounds.
- [ ] **Task 7 — Rewrite `SKILL.md` as a decision-first front door.** Sections: announce phrase -> "Use This Skill or Another One?" matrix listing Playwright-unique capabilities (Firefox/WebKit/Edge coverage, mobile emulation, trace/video, verify_*, generated TS code, network mocking, ephemeral isolated state) explicitly -> Decision Flow -> 60-second quickstarts (single-engine 4-call, cross-engine fan-out 5-call) -> Operational Rules (`browser_fill_form` over `browser_type` loops, `browser_run_code_unsafe` for compact assertions, `browser_snapshot` over `browser_take_screenshot` for actions, when to enable `--caps=devtools`/`storage`) -> Workflow Boundaries -> Deep-Dive References table linking all 6 references. Match `skills/chrome-devtools-mcp/SKILL.md` structure. Keep existing routing-to-other-skills text and "MCP vs CLI" guidance, and avoid implying repo-managed Chromium support.
- [ ] **Task 8 — Add `skills/playwright-mcp/tests/smoke.sh`.** Validate: SKILL.md exists, frontmatter `name: playwright-mcp`, `DO NOT use for:` present, no `../../` path escapes, every reference file exists and is linked from SKILL.md, key sections present. Mirror `skills/chrome-devtools-mcp/tests/smoke.sh`. Auto-discoverable by `scripts/test-battery.sh`.
- [ ] **Task 9 — Add skill-loading evals for routing boundaries and Playwright-unique capabilities.** Append to `evals/skill-loading/opencode_skill_loading_eval_dataset.jsonl`:
  - explicit/playwright-mcp WebKit Safari-class repro
  - explicit/playwright-mcp Edge-specific behavior
  - implicit/playwright-mcp mobile device emulation ("test on iPhone 15")
  - implicit/playwright-mcp Playwright trace + video QA artifact request
  - implicit/playwright-mcp generated TypeScript test code request
  - implicit/playwright-mcp network mocking via `browser_route`
  - near-miss/agent-browser "test in Chrome" -> routes to `agent-browser` because the repo does not configure Chromium under playwright-mcp
  - near-miss/chrome-devtools-mcp "inspect my current Chrome session" -> routes to `chrome-devtools-mcp` because Playwright is not the live-session DevTools workflow
  - Each entry uses `must_call_skill: true`, `expected_skills_any_of`, and `forbidden_skills` so any drift is caught.
- [ ] **Task 10 — Update `docs/playwright-mcp.md` and end-to-end validation.** Keep `docs/playwright-mcp.md` as the integration doc: document new `--playwright-caps-devtools` / `--playwright-caps-storage` / `--playwright-isolated` / `--playwright-output-dir` flags, the new default `--caps=testing`, install/verify/remove steps, troubleshooting summary, and the testing-use-case boundary matrix that aligns with `chrome-devtools-mcp` and `agent-browser`; add explicit links back to `skills/playwright-mcp/SKILL.md` and references for runtime guidance. Add `grep -n` verification commands. Run `scripts/test-playwright-mcp-setup.sh`, `scripts/test-battery.sh`, and the skill-loading eval runner. Also perform one runtime tool-surface validation per mode (default, `+devtools`, `+storage`) to prove the expected tools are actually exposed, plus one manual cross-engine recipe walk-through.

## Status Updates (newest first)

### 2026-05-19
- **Change:** Plan revised after GPT-5.4 rubber-duck review.
- **State now:** Replaced the incorrect Edge live-session near-miss with a Chrome-session boundary case, added runtime tool-surface validation, tightened wording around configured engines (Firefox/WebKit/Edge instead of vague all-browser coverage), and clarified that `docs/playwright-mcp.md` stays an integration doc while runtime guidance lives in the skill.
- **Validate:** Re-read plan against current `setup.sh`, `scripts/context-mode-config.py`, `scripts/test-playwright-mcp-setup.sh`, `skills/playwright-mcp/SKILL.md`, and `docs/playwright-mcp.md`.

### 2026-05-19
- **Change:** Plan authored on `main` after research into upstream `microsoft/playwright-mcp@latest` README/tool reference and review of the just-shipped `skills/chrome-devtools-mcp` refactor as the structural template. PLAN.md mirrors `docs/plans/feat/chrome-devtools-mcp-ui-testing/PLAN.md`.
- **State now:** No code changes. PLAN.md created at `docs/plans/feat/playwright-mcp-multi-browser/PLAN.md`. 10 tasks defined with explicit smoke-test criteria. Three-skill differentiation contract preserved: no Chromium server, `chrome-devtools-mcp` retains live-session DevTools, `agent-browser` retains routine Chromium automation, `playwright-mcp` carries cross-engine + Playwright-unique capabilities.
- **Validate:** `bash scripts/plan-path.sh --feature playwright-mcp-multi-browser --check` -> exits 0.

## Decisions

- 2026-05-19 — **Headless ON by default remains.** No change. Matches the repo policy and `chrome-devtools-mcp`.
- 2026-05-19 — **Add `--caps=testing` to the default managed args.** Default-on. 5 tools (`generate_locator`, `verify_element_visible`, `verify_list_visible`, `verify_text_visible`, `verify_value`) directly address the "did this work in WebKit/Firefox/Edge?" question that defines this skill, with negligible runtime overhead.
- 2026-05-19 — **`--caps=devtools` (trace + video) stays opt-in.** Heavy artifacts; mostly useful for QA-evidence flows, not the common cross-engine verification path. Opt-in via `--playwright-caps-devtools`.
- 2026-05-19 — **`--caps=storage` stays opt-in.** First-class cookies/localStorage/sessionStorage tools blur the line with `chrome-devtools-mcp`'s live-session model. Opt-in via `--playwright-caps-storage`.
- 2026-05-19 — **`--caps=network` stays opt-in.** Network mocking is a real Playwright differentiator, but it should stay explicit via `--playwright-caps-network`.
- 2026-05-19 — **`--caps=vision` and `--caps=pdf` stay opt-in.** Narrow utility; not core to the differentiated cross-engine job.
- 2026-05-19 — **Do not pre-commit to `--isolated` as the default.** Same reasoning as the `chrome-devtools-mcp-ui-testing` plan: persistent profile semantics matter for users testing authenticated flows. Ship as opt-in via `--playwright-isolated` and document the `--storage-state` pattern for ephemeral auth replay.
- 2026-05-19 — **Do not add a Playwright Chromium server.** Hard rule. The three-skill contract says Chromium goes to `agent-browser`.
- 2026-05-19 — **Per-browser caps overrides are out of scope.** Three configured servers receive the same caps within a given mode.
- 2026-05-19 — **`--playwright-output-dir` is opt-in.** Lets users pin trace/video/screenshot artifacts to a predictable workspace path. Default behavior (per upstream) is a temp dir.
- 2026-05-19 — **`docs/playwright-mcp.md` remains the integration doc.** It should cover setup, defaults, verification, removal, and boundary summaries; recipes and runtime guidance live in `skills/playwright-mcp/SKILL.md` and `references/`.
- 2026-05-19 — **Preserve the three-skill testing contract.** Routing evals must enforce the boundary in both directions.
- 2026-05-19 — **Plan path uses logical slug `playwright-mcp-multi-browser` on `main`.** The existing `docs/plans/feat/playwright-mcp-skill/PLAN.md` covers the original bring-up; this is a follow-up effort and gets its own plan file.

## Discoveries

- 2026-05-19 — Upstream `playwright-mcp` exposes ~60+ tools across 8 categories. Default core set is ~22; the rest are gated behind `--caps`. The repo's current managed args wire **none** of the caps, so the agent does not even know `verify_*`, trace, video, cookies, route, or pdf tools exist when using this skill.
- 2026-05-19 — `--caps=testing` is the highest-leverage default flip: 5 tools directly map to "did this work in another browser?". Enabling by default solves the "agent does cross-engine verification by improvising" problem at zero runtime cost.
- 2026-05-19 — Upstream documents `--device "iPhone 15"` as the canonical mobile-emulation knob. None of the other two skills offer cross-engine mobile emulation. Playwright-unique capability that should be surfaced in recipes.
- 2026-05-19 — `browser_route` / `browser_unroute` (under `--caps=network`) are network-mocking primitives. Neither `chrome-devtools-mcp` nor `agent-browser` exposes equivalent in-browser request mocking.
- 2026-05-19 — `browser_run_code_unsafe` already lets the agent execute arbitrary Playwright code in a single turn. The new SKILL.md should elevate it into the operational-rules section as the default for deterministic checks rather than long click/snapshot loops.
- 2026-05-19 — `--codegen=typescript` is a Playwright-MCP-only path: emits TypeScript test code from the agent's interactions. Real differentiator for users wanting to promote an exploratory MCP run into a real test; the current SKILL.md never mentions it.
- 2026-05-19 — `--storage-state` + `--isolated` is the canonical "ephemeral session with replayed auth" pattern in the upstream README. The current SKILL.md only says "use `--isolated` if profiles fight." Should be promoted to a recipe.
- 2026-05-19 — `--init-page` and `--init-script` allow setting geolocation, granting permissions, customizing viewport, and overriding browser APIs before any page script runs. None of the other two skills offer this granularity.
- 2026-05-19 — `--shared-browser-context` paired with `--port` is the upstream pattern for HTTP-transport-based parallel agents reusing one browser context. Warm-server-on-steroids; belongs in performance/cross-engine recipes.
- 2026-05-19 — Upstream's `--extension` (Edge/Chrome only) connects to a running browser via the Playwright Extension. **Critical boundary point:** this overlaps superficially with `chrome-devtools-mcp`'s `--auto-connect` but is NOT a substitute for live-session DevTools workflows. `references/cdp-and-extension.md` must spell this out so agents do not misroute.
- 2026-05-19 — The repo currently positions `chrome-devtools-mcp` as **Chrome-specific**, not as a generic live-session tool for every Chromium-family browser. Routing or docs should not imply that “current Edge session” is a normal `chrome-devtools-mcp` use case without explicit repo support.
- 2026-05-19 — `--save-session` records the entire MCP session for replay. Useful for self-healing test loops; underused today.
- 2026-05-19 — Upstream README is explicit that MCP "remains relevant for specialized agentic loops that benefit from persistent state, rich introspection, and iterative reasoning over page structure" while CLI+SKILLs win for routine token-efficient work. Current SKILL.md already reflects this; keep it.
- 2026-05-19 — `scripts/test-playwright-mcp-setup.sh` was authored before `scripts/test-chrome-devtools-mcp-setup.sh` was refactored. It uses inline `bash setup.sh ...` calls and lacks the per-target / per-mode helper structure. Refactor to match for defense-in-depth.
- 2026-05-19 — The repo has zero existing eval coverage for Playwright-unique capabilities (mobile emulation, trace/video, generated test code, network mocking). Today's 3 cases all turn on browser-engine name alone. New evals should turn on capability triggers so routing accuracy improves on requests like "record a video of this in WebKit" or "generate Playwright code for this flow."
- 2026-05-19 — `skills/playwright-mcp/` has no `tests/` directory and is not auto-discovered by `scripts/test-battery.sh` for skill-local smoke tests. `chrome-devtools-mcp` now has one; this should match.
- 2026-05-19 — Config-file greps alone are not enough for this feature. Because the improvement is about exposing new capability-gated tools, the plan needs runtime validation of the actual tool surface in at least the default, `+devtools`, and `+storage` modes.
