# Performance Levers

Use these levers to make Chrome DevTools MCP faster and less token-heavy on macOS.

## 1. Prefer the repo-managed default for standalone runs

The repo-managed default adds `--headless` for spawned Chrome runs. That removes visible-browser overhead and avoids focus stealing on macOS.

- Use the default when you need Chrome DevTools tools but **not** the user's current Chrome profile.
- Use `--chrome-devtools-headed` only when you explicitly need to watch the spawned browser.

## 2. Use `--chrome-devtools-auto-connect` for real current-Chrome work

If the task depends on the user's real logged-in session, do not simulate it with a fresh headless run.

- `--chrome-devtools-auto-connect` is the repo-managed path for attaching to the running local Chrome session.
- Auto-connect is for **live-session context**, not for generic speed.
- Auto-connect and the default headless launch are different workflows.

## 3. Use `--chrome-devtools-slim` only for narrow basic verification

`--slim` exposes only 3 tools: navigation, script execution, and screenshots.

Use it when:

- you only need basic page loading
- you only need simple script assertions
- you do not need console, network, Lighthouse, performance, memory, or extension tools

Do **not** use slim mode as the general default for this skill.

## 4. Prefer `fill_form` and `includeSnapshot: true`

- `fill_form` beats repeated `fill` calls for turn count and reliability.
- `includeSnapshot: true` removes an extra `take_snapshot` call after actions.

This is the single most important way to stop the agent from looping between action and snapshot.

## 5. Prefer `evaluate_script` over extra snapshots for state checks

Use `evaluate_script` when you can ask one direct question such as:

- did the count increment?
- is the modal open?
- did the record ID change?
- does local app state show success?

Use `take_snapshot` when you need fresh uids or visible UI structure.

## 6. Keep snapshots non-verbose

`take_snapshot` defaults to non-verbose output. Keep it that way unless you truly need the full a11y tree.

- Non-verbose snapshots are usually enough for uids and visible labels.
- `verbose: true` increases context size substantially.

## 7. Send heavy outputs to files

Follow the upstream "reference over value" rule for heavy data:

- screenshots -> `filePath`
- network bodies -> `requestFilePath`, `responseFilePath`
- traces -> `filePath`
- heapsnapshots -> `filePath`

Prefer a file path over returning large payloads inline.

## 8. Use a deliberate viewport and executable when needed

- `--viewport` helps keep responsive checks consistent.
- `--executable-path` lets you pin a specific Chrome build if behavior differs across channels.

Use these only when the test actually depends on them. Do not add knobs by default.

## 9. Warm-server pattern for repeated work

If you are doing many repeated Chrome DevTools MCP checks outside the repo-managed setup flow, start the server once and reuse it instead of respawning via `npx` for every run.

That avoids repeated startup cost and is especially useful for:

- repeated local repro loops
- multiple manual debugging passes
- batched Chrome-specific validation on the same machine

## 10. Use `--experimentalPageIdRouting` when one server is shared across concurrent agents

This matters when multiple agents or subagents share the same server instance.

- It exposes `pageId` on page-scoped tools.
- It reduces tab-selection ambiguity across concurrent sessions.

If each conversation gets its own server, this is less important.

## 11. Treat `--isolated` as optional guidance, not the repo default

`--isolated` creates a temporary user-data-dir and is useful when:

- multiple independent sessions would otherwise share the default profile
- you want a truly disposable Chrome state for one run

It is **not** the default repo posture because this skill still needs to preserve a first-class live-session path.
