---
name: agent-browser
description: "Browser automation via agent-browser CLI. Use when the user asks to open websites, click/fill forms, capture screenshots/PDFs, scrape page content, test UI flows, or automate web interactions."
allowed-tools: Bash(agent-browser:*) Bash(npx agent-browser:*) Bash(./scripts/*) Read Glob Grep
context: fork
---

# Agent Browser

Browser automation skill for repeatable web workflows using `agent-browser`.

## When to Use

- Website navigation and interaction (`open`, `click`, `fill`, `select`, `press`)
- UI testing and verification (snapshot refs, waits, assertions)
- Content extraction (text, structure, metadata)
- Evidence capture (screenshots, PDF, optional recording)

## Requirements

- Preferred: global install (`npm install -g agent-browser`)
- Alternative: `npx agent-browser` (slower; fetches on demand)
- First-time setup may require browser install: `agent-browser install`

Use the wrapper in this skill to auto-fallback from `agent-browser` to `npx agent-browser`.

## Core Workflow

1. Navigate: `agent-browser open <url>`
2. Snapshot: `agent-browser snapshot -i`
3. Interact with refs: `agent-browser click @e1`, `fill @e2 "value"`
4. Re-snapshot after page/DOM changes
5. Wait explicitly when needed: `agent-browser wait --load networkidle`

```bash
bash scripts/agent-browser.sh open https://example.com
bash scripts/agent-browser.sh snapshot -i
bash scripts/agent-browser.sh click @e1
bash scripts/agent-browser.sh wait --load networkidle
bash scripts/agent-browser.sh snapshot -i
```

## Recommended Commands

```bash
# Navigation and state
bash scripts/agent-browser.sh open https://example.com
bash scripts/agent-browser.sh close

# Snapshot and interaction
bash scripts/agent-browser.sh snapshot -i
bash scripts/agent-browser.sh fill @e1 "user@example.com"
bash scripts/agent-browser.sh click @e2

# Data and capture
bash scripts/agent-browser.sh get text body
bash scripts/agent-browser.sh screenshot --full
bash scripts/agent-browser.sh pdf output.pdf

# Waits and resilient timing
bash scripts/agent-browser.sh wait --url "**/dashboard"
bash scripts/agent-browser.sh wait --load networkidle
```

## Reliability Rules

- Re-snapshot after each navigation/major DOM change; old refs can become invalid.
- Prefer semantic locators (`find role|text|label`) if refs are unstable.
- For complex JS, use `eval --stdin` or `eval -b` to avoid shell quoting issues.
- Always close sessions after completion.

## Wrapper Script

Use `scripts/agent-browser.sh` for all invocations in this repo:

- Chooses `agent-browser` if installed
- Falls back to `npx agent-browser` if missing
- Preserves all arguments as-is

## References

- Upstream docs: `https://github.com/vercel-labs/agent-browser`
- Installation: `agent-browser --help` and `agent-browser install`
