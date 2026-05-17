# PLAN - playwright mcp skill

## GOAL
Add a repo-managed plan for integrating the official Playwright MCP server and a narrowly scoped Playwright skill that only triggers when `agent-browser` is the wrong tool, especially for Firefox, WebKit/Safari-class, Edge, or broad cross-browser use cases.

## PURPOSE
Keep `agent-browser` as the default browser-automation path while introducing Playwright MCP for browser-engine coverage that Chromium-only automation does not provide. If metadata overlap would cause ambiguous routing, tighten `agent-browser` trigger language only as much as needed to preserve that boundary.

## REFERENCES
- `setup.sh`
- `README.md`
- `docs/context-mode.md`
- `skills/agent-browser/SKILL.md`
- `skills/skill-creator/SKILL.md`
- official package: `@playwright/mcp`
- official repo: `microsoft/playwright-mcp`

## SCOPE
In scope:
- Define how the official Playwright MCP server should be installed in this repo's multi-harness setup model.
- Design a Playwright skill whose trigger conditions are limited to non-Chromium or cross-browser scenarios.
- Audit `skills/agent-browser/SKILL.md` and tighten its metadata only if the current trigger language would cause routing overlap.
- Document validation expectations for install/config wiring and skill differentiation.

Out of scope:
- Replacing `agent-browser` for general browser automation.
- Treating Playwright MCP itself as a repo skill instead of an external MCP dependency.
- Broad browser-testing workflow design unrelated to the routing boundary between the two skills.

## CURRENT BASELINE
- This repo already supports external runtime integration for `context-mode` through harness-specific config wiring in `setup.sh`.
- `agent-browser` is now explicitly described as the default Chrome/Chromium browser automation skill.
- `setup.sh` now supports `--with-playwright-mcp` for OpenCode, Codex CLI, GitHub Copilot, and Kiro.
- The repo now ships a `playwright-mcp` skill plus repo-managed Playwright MCP server wiring for Firefox, WebKit, and Microsoft Edge.
- Upstream Playwright MCP ships as `@playwright/mcp` with an executable entrypoint, but its primary install model remains MCP-server registration rather than a standalone human-facing automation CLI.

## STATUS UPDATES (append-only; newest first)
### 2026-05-16
Change:
- Implemented repo-managed Playwright MCP setup in `setup.sh` for OpenCode, Codex, GitHub Copilot, and Kiro behind `--with-playwright-mcp`.
- Added a new `skills/playwright-mcp/` skill with narrow routing guidance for Firefox, WebKit/Safari-class, Edge, and cross-browser verification.
- Tightened `skills/agent-browser/SKILL.md` metadata so generic Chromium automation stays with `agent-browser`.
- Added `docs/playwright-mcp.md` and `scripts/test-playwright-mcp-setup.sh`, and updated README/install docs.
- Hardened `scripts/codex-config.py`'s Python <3.11 TOML fallback so Codex config merge/remove remains reversible.

Behavior now:
- Playwright MCP is opt-in and configured as three browser-specific MCP servers: `playwright-firefox`, `playwright-webkit`, and `playwright-msedge`.
- The `playwright-mcp` skill is disabled by default in base `opencode.json` and only enabled during `--with-playwright-mcp` setup.
- GitHub Copilot is supported through `~/.copilot/mcp-config.json`, matching the current upstream Playwright MCP README.

Validate:
- `bash scripts/test-playwright-mcp-setup.sh` -> exits 0.
- `bash scripts/test-context-mode-setup.sh` -> exits 0.
- `bash scripts/test-battery.sh` -> exits 0.

### 2026-05-16
Change:
- Created the initial plan for adding Playwright MCP to the repo with a narrow skill boundary relative to `agent-browser`.
- Captured the intended trigger split: `agent-browser` remains the default for generic Chromium-style browser tasks, while Playwright is reserved for Firefox, WebKit/Safari-class, Edge, and cross-browser verification.

Behavior now:
- No Playwright MCP integration or Playwright-specific skill exists yet.
- The implementation must decide whether `agent-browser` metadata already provides enough separation or needs a small negative-trigger update.

Validate:
- `test -f docs/plans/feat/playwright-mcp-skill/PLAN.md` -> exits 0.

## PHASE PLAN

### Phase 1 - Integration contract and install shape
Goal: Lock down the correct repo model for the official Playwright MCP server.
Scope:
- Confirm the official package/runtime shape (`@playwright/mcp`) and supported install patterns.
- Decide how each supported harness should register Playwright MCP in this repo.
- Determine whether this should mirror the existing `context-mode` "external runtime + optional skill layer" pattern.
Done when: The install/config contract is clear for OpenCode, Codex CLI, GitHub Copilot, and Kiro.
Verify: `npm view @playwright/mcp name version bin repository --json` -> confirms official package metadata.
Notes: Prefer harness-native MCP registration over inventing a fake skill-based install model.

### Phase 2 - Skill boundary and metadata audit
Goal: Make Playwright trigger only where `agent-browser` should not.
Scope:
- Define positive triggers for Playwright: Firefox, WebKit, Safari-class issues, Edge, all-browser, and cross-browser verification.
- Define explicit negative triggers so it does not activate for generic site automation already covered by `agent-browser`.
- Audit `skills/agent-browser/SKILL.md` and update its description only if current wording is too broad to preserve the boundary reliably.
Done when: The trigger split is explicit and minimally overlapping.
Verify: `rg -n "Firefox|WebKit|Safari|Edge|cross-browser|browser automation" skills/agent-browser/SKILL.md skills/*/SKILL.md` -> overlap and differentiation are reviewable.
Notes: Keep `agent-browser` as the default path; only narrow it enough to reduce routing ambiguity.

### Phase 3 - Implementation surfaces
Goal: Identify the concrete repo changes needed to add the new integration.
Scope:
- Add `setup.sh` support for Playwright MCP where appropriate.
- Add any repo docs needed for install, verify, update, and remove flows.
- Create a Playwright skill wrapper only if it adds routing guidance beyond raw MCP registration.
- Ensure the skill and setup model stay consistent with the repo's self-contained skill rules.
Done when: The required files, commands, and ownership boundaries are identified for implementation.
Verify: `rg -n "context-mode|playwright|mcpServers|mcp_servers" setup.sh README.md docs` -> target integration surfaces identified.
Notes: The server should be installed as an external MCP dependency; the skill should be a guidance layer, not the transport itself.

### Phase 4 - Validation strategy
Goal: Make the future change testable and reversible.
Scope:
- Define smoke coverage for install/config generation where practical.
- Define how to verify that skill routing prefers `agent-browser` for generic tasks and Playwright only for browser-engine-specific requests.
- Define removal/update expectations so repo-managed changes can be undone conservatively.
Done when: There is a concrete validation path for both MCP wiring and skill differentiation.
Verify: `bash scripts/test-battery.sh` -> existing repo baseline remains green before adding new coverage.
Notes: Skill differentiation may need eval coverage, not just smoke tests.

## DEFINITION OF DONE
- The official Playwright MCP server has a repo-appropriate install/config model.
- A Playwright skill exists only if it adds useful routing guidance on top of MCP registration.
- Playwright skill triggers are clearly limited to Firefox, WebKit/Safari-class, Edge, and cross-browser scenarios.
- `agent-browser` remains the default for generic browser automation, with metadata tightened only if needed.
- Docs and validation steps explain how to install, verify, and reason about the split.

## OPEN QUESTIONS
- None currently.

## CHANGE LOG
- 2026-05-16 - Created initial plan for Playwright MCP integration and skill-boundary design.
- 2026-05-16 - Implemented opt-in Playwright MCP setup, docs, skill wiring, and smoke coverage.

## DECISIONS
- 2026-05-16 - Treat Playwright MCP as an external MCP dependency, not as the skill itself, because the official package is a server runtime and should be installed through harness-native MCP configuration.
- 2026-05-16 - Keep `agent-browser` as the default browser automation skill and reserve Playwright for non-Chromium or cross-browser scenarios.
- 2026-05-16 - Only change `agent-browser` metadata if overlap analysis shows its current description would cause unreliable routing.
- 2026-05-16 - Configure only the non-Chromium Playwright engines (`firefox`, `webkit`, `msedge`) so the routing boundary with `agent-browser` stays explicit.

## DISCOVERIES / GOTCHAS
- 2026-05-16 - The repo is currently on `main`, so this plan is stored under the intended feature branch path `docs/plans/feat/playwright-mcp-skill/PLAN.md` rather than being derived from the checked-out branch.
- 2026-05-16 - Official Playwright MCP documentation presents `@playwright/mcp` as MCP-server configuration (`command: "npx", args: ["@playwright/mcp@latest"]`), not as a peer to `agent-browser`'s user-facing command set.
- 2026-05-16 - Official Playwright MCP documentation now documents GitHub Copilot CLI support via `~/.copilot/mcp-config.json`, so this repo can wire Copilot without relying on a custom plugin path.
