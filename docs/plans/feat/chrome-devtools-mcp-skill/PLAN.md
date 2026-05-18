# PLAN - chrome devtools mcp skill

## GOAL
Add an opt-in Chrome DevTools MCP integration plus a narrowly routed skill for Chrome-specific debugging workflows that are a better fit than `agent-browser` or `playwright-mcp`, especially live logged-in sessions, DevTools-selected element inspection, and Chrome DevTools analysis such as console, network, Lighthouse, and memory workflows.

## PURPOSE
Keep the current browser-tooling split clear:
- `agent-browser` stays the default for general Chrome/Chromium automation.
- `playwright-mcp` stays reserved for Firefox, WebKit/Safari-class, Edge, and cross-browser coverage.
- The new Chrome DevTools addition should activate only when the request is specifically about Chrome DevTools context, a running Chrome session, or deeper Chrome-specific debugging that benefits from DevTools-native inspection.

## REFERENCES
- `setup.sh`
- `README.md`
- `docs/playwright-mcp.md`
- `skills/agent-browser/SKILL.md`
- `skills/playwright-mcp/SKILL.md`
- upstream repo: `ChromeDevTools/chrome-devtools-mcp`
- upstream skill: `skills/chrome-devtools-cli/SKILL.md`
- upstream docs: `README.md`, `docs/cli.md`

## SCOPE
In scope:
- Define the repo-managed install/config model for the official Chrome DevTools MCP server across OpenCode, Codex CLI, GitHub Copilot, and Kiro.
- Design a new skill with positive triggers centered on live logged-in Chrome debugging, selected-element inspection, console/network inspection, Lighthouse/performance analysis, and other Chrome DevTools-first workflows.
- Refine `skills/agent-browser/SKILL.md` so it explicitly yields Chrome DevTools-specific debugging to the new skill while remaining the default for routine Chromium automation.
- Refine `skills/playwright-mcp/SKILL.md` so it explicitly yields Chrome-specific DevTools workflows while keeping its non-Chromium and cross-browser role unchanged.
- Update implementation collateral including `setup.sh`, `README.md`, any dedicated docs, and supporting config-generation paths needed for the new optional integration.
- Define validation coverage for setup wiring, routing boundaries, install/remove flows, and privacy-sensitive defaults, including smoke tests and any eval/test collateral needed for skill differentiation.

Out of scope:
- Replacing `agent-browser` for generic browsing, screenshots, form filling, or lightweight Chrome automation.
- Replacing `playwright-mcp` for Firefox, WebKit, Edge, or cross-browser verification.
- Shipping the upstream skill unchanged if its routing language remains broader than this repo's browser-tooling model.
- Broad browser-testing guidance unrelated to the routing boundary among the three browser skills.

## CURRENT BASELINE
- `agent-browser` is the repo's default Chrome/Chromium browser automation skill.
- `playwright-mcp` is already scoped to Firefox, WebKit/Safari-class, Edge, and cross-browser verification.
- This repo already supports optional MCP integrations through `setup.sh`, README guidance, per-harness config wiring, and smoke coverage.
- The Chrome DevTools upstream project now supports MCP configuration for major agent harnesses and also ships an experimental CLI/skill layer.
- The primary value for this repo is not general browser automation; it is debugging a live Chrome session with authenticated state and DevTools-native inspection context.

## STATUS UPDATES (append-only; newest first)
### 2026-05-17
Change:
- Incorporated external reference research from upstream and third-party Chrome DevTools skill material.
- Added follow-up plan items for Lighthouse-versus-performance wording, performance trace sequencing, and token-efficient network inspection.
- Captured a repo-specific note to avoid broad browser-automation framing or isolated-profile defaults that would weaken the live attached-session workflow.

Behavior now:
- The plan now distinguishes Chrome DevTools performance tracing from Lighthouse audits more explicitly.
- The follow-up guidance now includes a few Chrome DevTools MCP gotchas that are likely to prevent agent confusion during real debugging sessions.

Validate:
- `rg -n "lighthouse_audit|performance_start_trace|responseFilePath|isolatedContext|isolated=true" docs/plans/feat/chrome-devtools-mcp-skill/PLAN.md` -> research-driven refinements are visible.

### 2026-05-17
Change:
- Refined the follow-up planning guidance using rubber-duck feedback.
- Split universal operational guardrails from the scoped live interaction/write-testing workflow.
- Clarified that unexpected error responses remain findings in diagnostic workflows instead of universal abort conditions.

Behavior now:
- The plan no longer treats a CRUD-style network-verification sequence as the default for every Chrome DevTools task.
- The follow-up guidance now preserves direct paths for Lighthouse, performance, memory, console-only, and other non-interaction investigations.

Validate:
- `rg -n "Operational guardrails|Live interaction and write-testing workflow|4xx/5xx" docs/plans/feat/chrome-devtools-mcp-skill/PLAN.md` -> refined guidance is visible.

### 2026-05-17
Change:
- Added follow-up planning guidance for tightening the `chrome-devtools-mcp` skill after live-session use in GitHub Copilot.
- Captured concrete improvements aimed at preventing tool-schema rediscovery loops and making live Chrome validation more procedural and evidence-driven.
- Defined a recommended default workflow for page selection, snapshotting, interaction, network inspection, and request-level verification.

Behavior now:
- The current skill is usable for live Chrome inspection, but it would benefit from stronger operational guardrails once the core DevTools tools are known.
- The plan now explicitly calls for anti-loop guidance, mutation-verification recipes, minimum-evidence rules, and abort criteria so the skill drives execution rather than repeated MCP introspection.

Validate:
- `test -f docs/plans/feat/chrome-devtools-mcp-skill/PLAN.md` -> exits 0.

### 2026-05-17
Change:
- Implemented opt-in Chrome DevTools MCP wiring in `setup.sh` for OpenCode, Codex, GitHub Copilot, and Kiro behind `--with-chrome-devtools-mcp`.
- Added explicit `--chrome-devtools-auto-connect` support so live-session attachment remains opt-in, and disabled upstream usage statistics by default in repo-managed config.
- Added `skills/chrome-devtools-mcp/`, `docs/chrome-devtools-mcp.md`, and `scripts/test-chrome-devtools-mcp-setup.sh`.
- Refined `skills/agent-browser/SKILL.md` and `skills/playwright-mcp/SKILL.md` so the browser-tool routing boundary is explicit.
- Updated `README.md`, `opencode.json`, and the OpenCode managed-config generator to cover the new optional integration and its MCP-versus-CLI split.

Behavior now:
- The repo now ships an MCP-only `chrome-devtools-mcp` skill plus opt-in Chrome DevTools MCP config wiring for OpenCode, Codex, GitHub Copilot, and Kiro.
- Repo-managed config uses `chrome-devtools-mcp@latest` with `--no-usage-statistics` by default and only adds `--auto-connect` when explicitly requested.
- The repo documentation now treats the CLI as an advanced secondary path, not part of the core skill workflow.

Validate:
- `bash scripts/test-chrome-devtools-mcp-setup.sh` -> exits 0.
- `bash scripts/test-playwright-mcp-setup.sh` -> exits 0.
- `bash scripts/test-context-mode-setup.sh` -> exits 0.

### 2026-05-17
Change:
- Created the implementation plan for adding Chrome DevTools MCP to the repo as an opt-in integration with a narrow routing boundary relative to `agent-browser` and `playwright-mcp`.
- Captured the intended best-fit scenarios: live logged-in Chrome sessions, selected-element inspection, console/network/Lighthouse/memory analysis, and Chrome-specific debugging where DevTools context matters more than general automation.
- Identified the planned metadata refinements needed so `agent-browser` remains the default for routine Chromium automation and `playwright-mcp` remains the path for non-Chromium or cross-browser work.

Behavior now:
- No Chrome DevTools MCP integration or Chrome DevTools-specific skill exists in this repo yet.
- The plan path follows the planning-doc branch convention at `docs/plans/feat/chrome-devtools-mcp-skill/PLAN.md`, even though the repo is intentionally remaining on `main` for this planning step.

Validate:
- `test -f docs/plans/feat/chrome-devtools-mcp-skill/PLAN.md` -> exits 0.

## FOLLOW-UP SKILL REFINEMENTS

### Skill-body guidance to add
- Split the additions into **universal operational guardrails** and a **live interaction/write-testing workflow** so the skill does not force Lighthouse, performance, memory, console-only, or extension-debugging tasks through a mutation-testing path.
- Add a **single tool-discovery / anti-loop rule**: one initial discovery pass is acceptable, but once the core tools are known the agent should stop rediscovering schemas and proceed unless a real capability failure forces re-checking.
- Add a **choose-the-smallest-path principle** so the skill favors the shortest linear sequence that proves one behavior and avoids unnecessary snapshots or network dumps from a live authenticated session.
- Add guidance to **prefer app state over DOM scraping** when the page exposes reliable client-side state, e.g. via `evaluate_script` against a global store, with `take_snapshot` as the fallback when no reliable app state is exposed.
- Add a **default workflow for live interaction and network verification**:
  1. `list_pages`
  2. `select_page`
  3. `take_snapshot`
  4. `evaluate_script` for baseline app state when available; otherwise read the baseline from the snapshot
  5. `fill_form` when the workflow is form-shaped; otherwise `click` / `fill` / `navigate_page` as needed
  6. `list_network_requests`
  7. `get_network_request` for the specific write or verification request that matters
  8. `list_console_messages` for runtime health checks
  9. confirm the resulting UI/app state
- Add **non-interaction workflow guidance** so Lighthouse, performance, memory, and console-only debugging can jump directly to the relevant tools instead of following the interaction workflow above.
- Add a **Lighthouse scope note** so the skill says `lighthouse_audit` covers accessibility, SEO, and best-practices style checks, but **not** performance profiling.
- Add a **performance-trace workflow** that explicitly uses:
  1. `performance_start_trace`
  2. `performance_stop_trace`
  3. `performance_analyze_insight`
  and notes that insight analysis depends on the `insightName` and `insightSetId` returned by the trace output.
- Add a **live mutation verification recipe**:
  - capture baseline UI/app state
  - perform the exact UI interaction sequence
  - inspect the resulting write request/response (`POST` / `PUT` / `PATCH` or GraphQL mutation)
  - confirm the final UI/app state change
  - note that WebSocket or SSE-driven flows may require app-state verification even when a single network request is not sufficient evidence
- Add a **minimum evidence rule** so the skill prefers:
  - baseline state
  - the specific write request/response when applicable
  - the resulting UI/app state
  instead of collecting repeated snapshots or excessive tool output.
- Add a **network-body token-economics note** so large request or response bodies are written to `requestFilePath` / `responseFilePath` instead of being inlined into context when the tool supports it.
- Add **abort criteria for live write testing**:
  - 4xx/5xx response
  - unexpected redirect
  - missing expected UI/app state change
  - new console errors
  - inability to verify the selected record before submission
- Add a note that in **read-only or diagnostic workflows**, unexpected responses are findings to inspect and report, not automatic stop conditions.
- Add a **small end-to-end example** for a logged-in Chrome validation flow that uses `evaluate_script` first for state reads, falls back to `take_snapshot` if needed, performs the interaction, inspects the targeted network request, and confirms the final UI/app state.
- Add a **live-session isolation note**: use `new_page` with `isolatedContext` only when intentionally separating state for a second flow; do not recommend server-level `--isolated=true` as the default repo posture because it conflicts with the skill's live attached-session use case.
- Keep the skill **routing-oriented rather than tool-catalog-oriented**; do not copy upstream's broad "browser automation" framing or a full inventory of tools into this repo skill.

### Suggested wording block for the skill
```md
## Operational guardrails

- Confirm core tools once, then act.
- Do not re-introspect tool schemas mid-task unless a tool call fails with an
  explicit capability error.
- Prefer the smallest evidence set that answers the question.
- Prefer reading app state with `evaluate_script` when available; fall back to
  `take_snapshot` when no reliable client-side state is exposed.
- When request or response bodies are large, prefer `requestFilePath` /
  `responseFilePath` over inlining them into context.

## Live interaction and write-testing workflow

- Use this workflow for live interaction checks, not for Lighthouse, performance,
  memory, or console-only debugging.
- Start with `list_pages`, `select_page`, and `take_snapshot`.
- Use `evaluate_script` for baseline state when available.
- Prefer `fill_form` over multiple `fill` calls when the page structure allows it.
- For mutation checks, capture only:
  1. baseline UI/app state
  2. the specific write request/response when applicable
  3. the resulting UI/app state
- In live write testing, stop on 4xx/5xx responses, unexpected redirects,
  missing state changes, or new console errors.
- In read-only or diagnostic workflows, unexpected responses are findings to
  inspect and report, not automatic stop conditions.

## Performance and Lighthouse workflow notes

- `lighthouse_audit` is for accessibility, SEO, and best-practices style audits;
  it is not the performance-profiling path.
- For performance work, use `performance_start_trace`,
  `performance_stop_trace`, then `performance_analyze_insight`.
- Treat the trace output as the source of truth for `insightName` and
  `insightSetId` before calling `performance_analyze_insight`.

## Live-session state isolation

- Keep the default repo posture aligned with live attached-session debugging.
- Use `new_page` with `isolatedContext` only when intentionally separating state
  for an additional flow.
- Do not recommend server-level `--isolated=true` as the default setup for this
  repo's primary Chrome DevTools skill.
```

## PHASE PLAN

### Phase 1 - Integration contract and privacy posture
Goal: Lock down the correct repo model for the official Chrome DevTools MCP server.
Scope:
- Confirm the official package/runtime shape and the best harness-native registration pattern for OpenCode, Codex CLI, GitHub Copilot, and Kiro.
- Decide the repo naming and opt-in setup surface, likely mirroring the existing optional MCP integration model in `setup.sh`.
- Decide the default server arguments, especially whether repo-managed config should enable live-session helpers such as auto-connect by default or document them as an explicit opt-in.
- Decide the repo privacy posture for upstream defaults such as usage statistics and update checks.
Done when: The install/config contract is explicit, conservative, and aligned with the repo's optional integration model.
Verify: `gh api repos/ChromeDevTools/chrome-devtools-mcp/contents/README.md --jq '.path'` -> returns `README.md`.
Notes: The plan should favor harness-native MCP registration over plugin-specific installation unless a plugin path adds unique value the repo cannot reproduce cleanly.

### Phase 2 - Skill boundary and naming design
Goal: Define a new Chrome DevTools skill with minimal overlap and clear routing.
Scope:
- Choose the repo skill name and scope, likely a Chrome DevTools MCP/debugging guidance layer rather than a verbatim copy of the upstream CLI skill.
- Define positive triggers such as "debug this live logged-in Chrome session", "inspect the selected element in DevTools", "check Chrome console/network errors", "run Lighthouse on this live page", and "inspect memory/performance in Chrome".
- Define explicit negative triggers so the new skill does not absorb generic browsing, screenshots, scraping, or ordinary Chrome automation already covered by `agent-browser`.
- Keep the skill MCP-only in its normal workflow and install assumptions; if the CLI is documented at all, keep it outside the skill's primary instructions as an optional advanced path.
- Make the skill and docs explicitly differentiate MCP-fit versus CLI-fit cases, for example: MCP for live authenticated Chrome sessions and iterative DevTools debugging; CLI only as an optional fast path for shell-driven scripted tasks such as repeatable Lighthouse runs.
- Keep the repo wording narrower than upstream's broad browser-automation framing; this skill should remain routing-oriented rather than becoming a full tool catalog.
Done when: The new skill's trigger language is specific to Chrome DevTools-first workflows and clearly distinct from the existing browser skills.
Verify: `rg -n "Chrome|Chromium|Firefox|WebKit|Safari|Edge|Lighthouse|network|console|logged-in" skills/*/SKILL.md` -> overlap and differentiation are reviewable.
Notes: The repo should not import the upstream skill text unchanged if its current description would trigger on broad browser automation requests.

### Phase 2b - Operational guardrails for the Chrome DevTools skill
Goal: Make the `chrome-devtools-mcp` skill execution-oriented once the tool surface is known.
Scope:
- Add universal operational guardrails that discourage repeated tool-schema rediscovery once core tools are known.
- Add a scoped live interaction/write-testing workflow that moves from page selection to baseline state, interaction, targeted network verification, console review, and final state confirmation.
- Add non-interaction guidance so Lighthouse, performance, memory, and console-only investigations can jump directly to their relevant tools instead of inheriting the interaction workflow.
- Add explicit wording that `lighthouse_audit` is not the performance-profiling path, and that performance analysis should use the trace tools instead.
- Add performance-trace sequencing guidance so `performance_analyze_insight` is only called after the trace output provides the needed `insightName` / `insightSetId`.
- Add mutation-verification guidance that favors a baseline state, one targeted write request inspection when applicable, and a final state check.
- Add minimum-evidence and abort criteria for live write testing while keeping diagnostic failures reportable rather than treating every unexpected response as an automatic stop.
- Add guidance to prefer application state via `evaluate_script` over brittle DOM scraping when a page exposes reliable client-side state.
- Add network-body handling guidance so large payloads can be written to files instead of bloating agent context.
- Add a note that repo guidance should not recommend server-level `--isolated=true` as the default, while still documenting `isolatedContext` for intentional per-page separation.
Done when: The skill can steer an agent through common live Chrome debugging tasks without falling back into MCP surface exploration or forcing unrelated workflows through a CRUD-shaped sequence.
Verify: `rg -n "Operational guardrails|Live interaction and write-testing workflow|lighthouse_audit|performance_start_trace|performance_analyze_insight|responseFilePath|isolatedContext" skills/chrome-devtools-mcp/SKILL.md` -> the new guidance is visible.
Notes: This phase is about skill-body ergonomics, not changing the MCP server itself.

### Phase 3 - Refinements to existing browser skills
Goal: Tighten the routing boundary across all three browser skills.
Scope:
- Update `skills/agent-browser/SKILL.md` to say it is not for DevTools-first inspection of a live Chrome session, selected-element debugging, or Chrome-specific console/network/Lighthouse workflows.
- Update `skills/playwright-mcp/SKILL.md` to say it is not for Chrome-specific DevTools workflows or debugging the user's current Chrome session.
- Ensure each skill description reinforces the split without over-narrowing valid existing use cases.
- Review whether any supporting docs or examples in the skill bodies also need a brief routing reminder, not just the frontmatter descriptions.
Done when: The three browser skills form an explicit, stable routing triangle with minimal ambiguity.
Verify: `rg -n "DO NOT use|When NOT to Use|Chrome DevTools|live Chrome session|cross-browser" skills/agent-browser/SKILL.md skills/playwright-mcp/SKILL.md skills/*/SKILL.md` -> routing boundaries are visible in one search.
Notes: Preserve the current preference order: routine Chromium automation -> `agent-browser`; non-Chromium or comparison work -> `playwright-mcp`; Chrome DevTools-native live debugging -> new Chrome DevTools skill.

### Phase 4 - Implementation surfaces and docs
Goal: Identify the concrete repo changes needed to ship the integration cleanly.
Scope:
- Add `setup.sh` support for an opt-in Chrome DevTools MCP integration for all supported harnesses, including any config-generation or remove-path updates that the new flag requires.
- Update `README.md` so the new integration appears in setup commands, optional integration descriptions, dependency notes, and skill/tool summaries wherever relevant.
- Add dedicated docs covering install, verify, remove, update, privacy posture, and best-fit routing guidance, including a clear MCP-versus-CLI decision guide.
- Add the new skill directory under `skills/` if the guidance layer is justified after Phase 2.
- Update other collateral that must stay in sync with optional MCP integrations, such as smoke scripts, setup docs, and any harness-specific examples or references affected by the new feature.
- Ensure the skill stays self-contained and does not rely on files outside its own directory.
Done when: The files, commands, and ownership boundaries are identified for implementation.
Verify: `rg -n "context-mode|playwright|mcpServers|mcp_servers|setup.sh" README.md docs setup.sh` -> target integration surfaces are identified.
Notes: Keep the integration model consistent with existing optional MCP features rather than inventing a one-off install path.

### Phase 5 - Validation and eval strategy
Goal: Make the future change testable and reversible.
Scope:
- Define smoke coverage for the new setup wiring across supported harnesses, including `setup.sh` install/remove behavior and generated config assertions.
- Define how to verify routing guidance among `agent-browser`, `playwright-mcp`, and the new Chrome DevTools skill.
- Define removal behavior so repo-managed config changes are conservative and reversible.
- Decide whether skill differentiation needs eval coverage or targeted skill-loading coverage in addition to install/config smoke tests.
- Ensure repo-level collateral stays covered, including README/setup command accuracy and any new test script coverage added for the integration.
Done when: There is a concrete validation plan for both config wiring and routing behavior.
Verify: `bash scripts/test-battery.sh` -> baseline repo checks remain green before new coverage is added.
Notes: Because routing quality is a core part of the feature, plan for at least one validation step that checks the skill descriptions rather than only config generation.

## DEFINITION OF DONE
- The repo has a clear opt-in install/config model for Chrome DevTools MCP across supported harnesses.
- A new Chrome DevTools skill exists only if it adds routing guidance beyond raw MCP registration and is scoped to Chrome DevTools-first workflows.
- `agent-browser` explicitly remains the default for routine Chromium automation.
- `playwright-mcp` explicitly remains the path for Firefox, WebKit/Safari-class, Edge, and cross-browser work.
- The new Chrome DevTools integration is clearly documented as the best fit for live logged-in Chrome debugging, selected-element inspection, and Chrome DevTools-native console/network/Lighthouse/performance workflows.
- The skill and docs clearly differentiate MCP-first workflows from any optional CLI-only workflows, including Lighthouse-style scripted audits versus live-session debugging.
- `setup.sh`, `README.md`, dedicated docs, and any other impacted collateral are updated consistently for install, verify, remove, and routing guidance.
- Validation covers both the generated setup/config behavior and the skill-boundary changes.

## OPEN QUESTIONS
- None currently.

## CHANGE LOG
- 2026-05-17 - Created initial plan for Chrome DevTools MCP integration and browser-skill boundary refinements.
- 2026-05-17 - Expanded the plan to explicitly include `setup.sh`, `README.md`, supporting docs/collateral, and testing coverage.
- 2026-05-17 - Reviewed the upstream `chrome-devtools` and `chrome-devtools-cli` skills plus the CLI installation reference and narrowed the initial repo plan to MCP-first guidance with CLI documented as an advanced secondary path.
- 2026-05-17 - Tightened the plan further so the repo skill is MCP-only; any CLI mention belongs only in docs as an optional advanced workflow.
- 2026-05-17 - Updated the plan so the skill/docs must explicitly differentiate MCP-fit workflows from optional CLI-fit workflows such as scripted Lighthouse runs.
- 2026-05-17 - Implemented the Chrome DevTools MCP integration, skill, docs, and smoke coverage with explicit auto-connect opt-in and usage statistics disabled by default.
- 2026-05-17 - Added follow-up planning notes for tightening the `chrome-devtools-mcp` skill with default workflows, anti-loop guidance, mutation-verification recipes, minimum-evidence rules, and abort criteria informed by live-session use.
- 2026-05-17 - Refined the follow-up plan so universal guardrails stay separate from live write-testing workflows, diagnostic failures remain reportable findings, and non-interaction DevTools tasks are not forced through a mutation path.
- 2026-05-17 - Incorporated external reference research to add Lighthouse/performance differentiation, performance trace sequencing, network-body token guidance, and live-session isolation notes to the plan.

## DECISIONS
- 2026-05-17 - Plan around a narrow Chrome DevTools-first workflow boundary rather than importing the upstream skill unchanged, because this repo already has established browser-tooling roles for `agent-browser` and `playwright-mcp`.
- 2026-05-17 - Treat Chrome DevTools MCP as an optional external MCP dependency with a repo-managed setup path, consistent with the existing optional integration model.
- 2026-05-17 - Preserve `agent-browser` as the default for general Chromium automation and `playwright-mcp` as the path for non-Chromium or cross-browser work.
- 2026-05-17 - Use the upstream `chrome-devtools` skill as the closer conceptual template for the repo addition, but rewrite it with a narrower routing boundary; do not add a separate repo `chrome-devtools-cli` skill in the first iteration.
- 2026-05-17 - Keep the repo skill MCP-only; if the CLI is mentioned, mention it only in docs as an advanced secondary workflow, because upstream's CLI skill is shell-command oriented, broader than this repo's routing boundary, and installed independently from the MCP config.
- 2026-05-17 - Document an explicit MCP-vs-CLI split: MCP is the default for live-session and DevTools-iterative work; CLI is optional and docs-only for shell-driven scripted tasks where fewer agent turns may be beneficial.
- 2026-05-17 - Keep live-session attachment explicit opt-in via `--chrome-devtools-auto-connect` rather than enabling auto-connect by default.
- 2026-05-17 - Disable Chrome DevTools MCP usage statistics in repo-managed config by default with `--no-usage-statistics`.
- 2026-05-17 - Use `chrome-devtools-mcp` as the repo skill name and `chrome-devtools` as the MCP server name.
- 2026-05-17 - Keep server-level isolation out of the default repo guidance because the primary skill fit is live attached-session debugging, not disposable-profile automation.

## DISCOVERIES / GOTCHAS
- 2026-05-17 - The upstream `chrome-devtools-cli` skill description is broader than this repo's desired routing boundary and would overlap with `agent-browser` if copied directly.
- 2026-05-17 - The strongest repo-specific fit is live Chrome debugging with existing authenticated state and DevTools-native context, not generic browser automation.
- 2026-05-17 - The upstream project documents both MCP and CLI usage, but the CLI is experimental and its workflow does not exactly match the live auto-connect MCP path highlighted in the video.
- 2026-05-17 - Upstream ships two distinct skills: `chrome-devtools` for MCP tool usage and `chrome-devtools-cli` for shell-command generation; only the MCP-oriented one maps cleanly to this repo's existing "optional MCP config + routing skill" pattern.
- 2026-05-17 - The only upstream CLI reference file is an installation note centered on global npm install and PATH troubleshooting, which reinforces that the CLI is a separate operator-facing tool rather than the core MCP integration model.
- 2026-05-17 - Mixing MCP and CLI in one repo skill would blur the install story and increase overlap with `agent-browser`, so the plan now treats CLI material as docs-only collateral.
- 2026-05-17 - CLI workflows may be more efficient for certain scripted tasks, including repeatable Lighthouse-style audits, but that efficiency gain does not outweigh MCP as the primary fit for live authenticated Chrome debugging.
- 2026-05-17 - The Chrome DevTools MCP itself appears adequate for live-session inspection, but the repo skill would benefit from stronger operational guardrails so agents do not get stuck re-discovering tool schemas mid-task.
- 2026-05-17 - Live Chrome validation works better when the skill tells the agent to prove behavior with the smallest evidence set possible: baseline state, one targeted network request/response, and final state.
- 2026-05-17 - The live interaction workflow should be scoped to write/verification tasks rather than presented as the universal default for Lighthouse, memory, performance, console-only, or extension-debugging work.
- 2026-05-17 - 4xx/5xx responses are abort conditions for conservative live write testing, but in diagnostic workflows they are often the primary finding and should be inspected rather than treated as an automatic stop.
- 2026-05-17 - Upstream and marketplace references often frame Chrome DevTools MCP as broad browser automation, but this repo should keep a narrower debugging-first routing boundary to avoid overlap with `agent-browser`.
- 2026-05-17 - `lighthouse_audit` does not replace performance tracing; performance debugging needs the trace workflow and follow-up `performance_analyze_insight` calls using IDs returned from the trace output.
- 2026-05-17 - Large network payloads are better handled by writing request and response bodies to files when the tool supports it, which aligns with the plan's minimum-evidence and token-discipline goals.
- 2026-05-17 - Some third-party install guidance recommends server-level `--isolated=true`, but that would undermine this repo's live authenticated-session use case; page-level `isolatedContext` is the safer scoped note to document instead.
