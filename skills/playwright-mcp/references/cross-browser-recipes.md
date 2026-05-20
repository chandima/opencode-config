# Cross-browser recipes

Each recipe calls out whether it is **repo-managed default**, **repo-managed opt-in**, or **upstream/manual-only**.

## 1. WebKit Safari-class verification (repo-managed default, <=4 calls)

Use `playwright-webkit` when the ask is specifically Safari-class behavior.

1. `browser_navigate`
2. `browser_snapshot`
3. `browser_click` or `browser_fill_form`
4. `browser_verify_text_visible` or `browser_verify_element_visible`

## 2. Edge-specific regression check (repo-managed default, <=4 calls)

Use `playwright-msedge` when the user explicitly names Edge.

1. `browser_navigate`
2. `browser_snapshot`
3. `browser_run_code_unsafe`
4. `browser_verify_value`

## 3. Cross-engine fan-out diff (repo-managed default, <=5 calls)

Use `playwright-firefox`, `playwright-webkit`, and `playwright-msedge` together.

1. `browser_navigate` on each engine
2. `browser_snapshot` on each engine
3. Run the same `browser_run_code_unsafe` assertion on each engine
4. Compare results only where they differ
5. Report browser-specific findings

Keep the logic identical across engines or the comparison stops being useful.

## 4. Network mocking before verification (repo-managed opt-in: `--playwright-caps-network`)

This recipe requires the network cap because `browser_route*` is not available by default.

1. `browser_route`
2. `browser_navigate`
3. `browser_snapshot`
4. `browser_verify_text_visible`

If the cap is missing, say so instead of pretending the route tools are available.

## 5. Trace or video evidence (repo-managed opt-in: `--playwright-caps-devtools`)

Use this only when the user asked for Playwright artifacts, not for routine checks.

1. Start trace/video collection
2. `browser_navigate`
3. Run the core interaction
4. Stop trace/video collection

Pair this with `--playwright-output-dir PATH` when the files need a predictable location.

## 6. Mobile emulation (upstream/manual-only unless user configured it)

Upstream Playwright MCP supports flags such as `--device "iPhone 15"`, but the repo does not wire that by default.

Use this recipe only when the user or harness explicitly configured device emulation already:

1. Confirm the server was started with the device override
2. `browser_navigate`
3. `browser_snapshot`
4. `browser_verify_*` or `browser_run_code_unsafe`

## 7. Promote exploration into Playwright code (upstream/manual-only guidance)

Playwright MCP supports TypeScript code generation upstream. Treat this as a Playwright-only differentiator, but do not imply the repo automatically enabled extra codegen setup beyond upstream defaults.

Typical workflow:

1. Reproduce the flow with Playwright MCP
2. Use stable locators where possible
3. Generate or extract TypeScript code
4. Hand off the code as a follow-up artifact
