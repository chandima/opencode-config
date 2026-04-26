---
name: agent-browser
description: "Browser automation CLI for AI agents. Use when the user needs to interact with websites, including navigating pages, filling forms, clicking buttons, taking screenshots, extracting data, testing web apps, or automating any browser task. Triggers include requests to \"open a website\", \"fill out a form\", \"click a button\", \"take a screenshot\", \"scrape data from a page\", \"test this web app\", \"login to a site\", \"automate browser actions\", or any task requiring programmatic web interaction. DO NOT use for: API testing without a browser, direct HTTP requests (use curl/fetch instead), or static content scraping that doesn't require JavaScript rendering."
allowed-tools: Bash(npx agent-browser:*), Bash(agent-browser:*)
context: fork
compatibility: "OpenCode, Codex CLI, GitHub Copilot. Requires npx and agent-browser CLI."
---

# Browser Automation with agent-browser

The CLI uses Chrome/Chromium via CDP directly. Install via `npm i -g agent-browser`, `brew install agent-browser`, or `cargo install agent-browser`. Run `agent-browser install` to download Chrome. Update with `agent-browser upgrade`.

## AI Chat Mode

Natural language browser control — useful for quick one-off tasks:

```bash
agent-browser chat "go to example.com and screenshot the homepage"  # Single-shot
agent-browser chat                                                   # Interactive REPL
```

## Core Workflow

Every browser automation follows this pattern:

1. **Navigate**: `agent-browser open <url>`
2. **Snapshot**: `agent-browser snapshot -i` (get element refs like `@e1`, `@e2`)
3. **Interact**: Use refs to click, fill, select
4. **Re-snapshot**: After navigation or DOM changes, get fresh refs

```bash
agent-browser open https://example.com/form
agent-browser snapshot -i
# Output: @e1 [input type="email"], @e2 [input type="password"], @e3 [button] "Submit"

agent-browser fill @e1 "user@example.com"
agent-browser fill @e2 "password123"
agent-browser click @e3
agent-browser wait --load networkidle
agent-browser snapshot -i  # Check result
```

## Command Chaining

Commands can be chained with `&&` in a single shell invocation. The browser persists between commands via a background daemon, so chaining is safe and more efficient than separate calls.

```bash
# Chain open + wait + snapshot in one call
agent-browser open https://example.com && agent-browser wait --load networkidle && agent-browser snapshot -i

# Chain multiple interactions
agent-browser fill @e1 "user@example.com" && agent-browser fill @e2 "password123" && agent-browser click @e3

# Navigate and capture
agent-browser open https://example.com && agent-browser wait --load networkidle && agent-browser screenshot page.png
```

**When to chain:** Use `&&` when you don't need to read the output of an intermediate command before proceeding (e.g., open + wait + screenshot). Run commands separately when you need to parse the output first (e.g., snapshot to discover refs, then interact using those refs).

## Batch Execution

Execute multiple commands in a single invocation — avoids per-command process startup overhead:

```bash
# Argument mode: each quoted argument is a full command
agent-browser batch "open https://example.com" "snapshot -i" "screenshot"

# Stop on first error
agent-browser batch --bail "open https://example.com" "click @e1" "screenshot"

# Stdin mode: pipe commands as JSON
echo '[["open", "https://example.com"], ["snapshot", "-i"], ["click", "@e1"]]' | agent-browser batch --json
```

**When to use batch vs chaining:** Batch is faster (single process) and supports `--bail` for error handling. Use `&&` chaining when you need shell features between commands.

## Handling Authentication

For quick tasks, connect to the user's running Chrome (`--auto-connect`) or use a persistent profile (`--profile`). For recurring automation, use the auth vault or session names to persist credentials securely.

Read `references/auth-patterns.md` if the target site requires authentication or login. This covers state files, profiles, session names, auth vault, and OAuth hints.

See also [references/authentication.md](references/authentication.md) for OAuth, 2FA, cookie-based auth, and token refresh patterns.

## Essential Commands

```bash
# Navigation
agent-browser open <url>              # Navigate (aliases: goto, navigate)
agent-browser close                   # Close browser

# Snapshot
agent-browser snapshot -i             # Interactive elements with refs (recommended)
agent-browser snapshot -i -C          # Include cursor-interactive elements (divs with onclick, cursor:pointer)
agent-browser snapshot -s "#selector" # Scope to CSS selector

# Interaction (use @refs from snapshot)
agent-browser click @e1               # Click element
agent-browser click @e1 --new-tab     # Click and open in new tab
agent-browser fill @e2 "text"         # Clear and type text
agent-browser type @e2 "text"         # Type without clearing
agent-browser select @e1 "option"     # Select dropdown option
agent-browser check @e1               # Check checkbox
agent-browser press Enter             # Press key
agent-browser keyboard type "text"    # Type at current focus (no selector)
agent-browser keyboard inserttext "text"  # Insert without key events
agent-browser scroll down 500         # Scroll page
agent-browser scroll down 500 --selector "div.content"  # Scroll within a specific container

# Get information
agent-browser get text @e1            # Get element text
agent-browser get url                 # Get current URL
agent-browser get title               # Get page title
agent-browser get cdp-url             # Get CDP WebSocket URL

# Wait
agent-browser wait @e1                # Wait for element
agent-browser wait --load networkidle # Wait for network idle
agent-browser wait --url "**/page"    # Wait for URL pattern
agent-browser wait 2000               # Wait milliseconds
agent-browser wait --text "Welcome"    # Wait for text to appear (substring match)
agent-browser wait --fn "!document.body.innerText.includes('Loading...')"  # Wait for text to disappear
agent-browser wait "#spinner" --state hidden  # Wait for element to disappear

# Downloads
agent-browser download @e1 ./file.pdf          # Click element to trigger download
agent-browser wait --download ./output.zip     # Wait for any download to complete
agent-browser --download-path ./downloads open <url>  # Set default download directory

# Viewport & Device Emulation
agent-browser set viewport 1920 1080          # Set viewport size (default: 1280x720)
agent-browser set viewport 1920 1080 2        # 2x retina (same CSS size, higher res screenshots)
agent-browser set device "iPhone 14"          # Emulate device (viewport + user agent)

# Browser Settings
agent-browser set useragent "Mozilla/5.0..."  # Custom user agent string
agent-browser set timezone "America/New_York" # Override timezone
agent-browser set locale "fr-FR"              # Override locale
agent-browser set cookie "name=val" "https://example.com"  # Set cookie
agent-browser set storage '{"key":"val"}' "https://example.com"  # Set localStorage
agent-browser set geo 37.7749 -122.4194       # Set geolocation
agent-browser set offline on                  # Toggle offline mode

# Runtime Streaming
agent-browser stream enable                   # Start WebSocket streaming
agent-browser stream enable --port 9223       # Stream on specific port
agent-browser stream status                   # Show streaming state
agent-browser stream disable                  # Stop streaming

# Capture
agent-browser screenshot              # Screenshot to temp dir
agent-browser screenshot --full       # Full page screenshot
agent-browser screenshot --annotate   # Annotated screenshot with numbered element labels
agent-browser screenshot --screenshot-dir ./shots  # Save to custom directory
agent-browser screenshot --screenshot-format jpeg --screenshot-quality 80
agent-browser pdf output.pdf          # Save as PDF

# Clipboard
agent-browser clipboard read                      # Read text from clipboard
agent-browser clipboard write "Hello, World!"     # Write text to clipboard
agent-browser clipboard copy                      # Copy current selection
agent-browser clipboard paste                     # Paste from clipboard

# Diff (compare page states)
agent-browser diff snapshot                          # Compare current vs last snapshot
agent-browser diff snapshot --baseline before.txt    # Compare current vs saved file
agent-browser diff screenshot --baseline before.png  # Visual pixel diff
agent-browser diff url <url1> <url2>                 # Compare two pages
agent-browser diff url <url1> <url2> --wait-until networkidle  # Custom wait strategy
agent-browser diff url <url1> <url2> --selector "#main"  # Scope to element
```

## Common Patterns

### Form Submission

```bash
agent-browser open https://example.com/signup
agent-browser snapshot -i
agent-browser fill @e1 "Jane Doe"
agent-browser fill @e2 "jane@example.com"
agent-browser select @e3 "California"
agent-browser check @e4
agent-browser click @e5
agent-browser wait --load networkidle
```

### Data Extraction

```bash
agent-browser open https://example.com/products
agent-browser snapshot -i
agent-browser get text @e5           # Get specific element text
agent-browser get text body > page.txt  # Get all page text

# JSON output for parsing
agent-browser snapshot -i --json
agent-browser get text @e1 --json
```

### Basic Auth Flow

```bash
# Login once and save state
agent-browser open https://app.example.com/login
agent-browser snapshot -i
agent-browser fill @e1 "$USERNAME"
agent-browser fill @e2 "$PASSWORD"
agent-browser click @e3
agent-browser wait --url "**/dashboard"
agent-browser state save auth.json

# Reuse in future sessions
agent-browser state load auth.json
agent-browser open https://app.example.com/dashboard
```

Read `references/advanced.md` for session persistence, parallel sessions, connecting to existing Chrome, viewport/responsive testing, visual debugging, local file access, iOS simulator, and more patterns.

## Timeouts and Slow Pages

The default timeout is 25 seconds. Override with `AGENT_BROWSER_DEFAULT_TIMEOUT` (milliseconds). For slow pages, use explicit waits:

```bash
agent-browser wait --load networkidle       # Wait for network to settle
agent-browser wait "#content"               # Wait for element
agent-browser wait --url "**/dashboard"     # Wait for URL pattern
agent-browser wait --fn "document.readyState === 'complete'"  # JS condition
agent-browser wait 5000                     # Fixed delay (last resort)
```

Use `wait --load networkidle` after `open` for consistently slow sites. Wait for specific elements with `wait <selector>` or `wait @ref`.

## Ref Lifecycle

Refs (`@e1`, `@e2`, etc.) are invalidated when the page changes. Always re-snapshot after clicking links/buttons that navigate, form submissions, or dynamic content loading (dropdowns, modals).

```bash
agent-browser click @e5              # Navigates to new page
agent-browser snapshot -i            # MUST re-snapshot
agent-browser click @e1              # Use new refs
```

## Security

By default, agent-browser imposes no restrictions. For AI agent workflows, consider enabling content boundaries, domain allowlists, and action policies.

Read `references/security.md` for content boundary configuration, domain allowlists, action policies, and output limits.

## Advanced Features

Read `references/advanced.md` for diffing, session management, annotated screenshots, semantic locators, JavaScript evaluation, configuration files, browser engine selection, and more.

## Deep-Dive Documentation

| Reference                                                            | When to Use                                                          |
| -------------------------------------------------------------------- | -------------------------------------------------------------------- |
| [references/commands.md](references/commands.md)                     | Full command reference with all options                               |
| [references/snapshot-refs.md](references/snapshot-refs.md)           | Ref lifecycle, invalidation rules, troubleshooting                   |
| [references/session-management.md](references/session-management.md) | Parallel sessions, state persistence, concurrent scraping            |
| [references/authentication.md](references/authentication.md)         | Login flows, OAuth, 2FA handling, state reuse                        |
| [references/auth-patterns.md](references/auth-patterns.md)           | Authentication variants: state files, profiles, sessions, auth vault |
| [references/security.md](references/security.md)                     | Content boundaries, domain allowlists, action policies               |
| [references/advanced.md](references/advanced.md)                     | Diffing, JS eval, browser engines, iOS, and more                     |
| [references/video-recording.md](references/video-recording.md)       | Recording workflows for debugging and documentation                  |
| [references/profiling.md](references/profiling.md)                   | Chrome DevTools profiling for performance analysis                   |
| [references/proxy-support.md](references/proxy-support.md)           | Proxy configuration, geo-testing, rotating proxies                   |

## Ready-to-Use Templates

| Template                                                                 | Description                         |
| ------------------------------------------------------------------------ | ----------------------------------- |
| [templates/form-automation.sh](templates/form-automation.sh)             | Form filling with validation        |
| [templates/authenticated-session.sh](templates/authenticated-session.sh) | Login once, reuse state             |
| [templates/capture-workflow.sh](templates/capture-workflow.sh)           | Content extraction with screenshots |

```bash
./templates/form-automation.sh https://example.com/form
./templates/authenticated-session.sh https://app.example.com/login
./templates/capture-workflow.sh https://example.com ./output
```
