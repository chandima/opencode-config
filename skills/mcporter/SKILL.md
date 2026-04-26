---
name: mcporter
description: |
  Direct MCP access via MCPorter. Use when you need to discover available MCP
  servers, list their tools, or call an MCP tool directly (e.g., chrome-devtools
  screenshot, firecrawl scrape). Use this as a fallback when no dedicated skill
  exists for the MCP server.
  DO NOT use when a dedicated skill covers the MCP server (e.g., use github-ops
  for GitHub, context7-docs for library documentation).
allowed-tools: Bash(npx:*) Bash(./scripts/*) Read Glob Grep
context: fork
compatibility: "OpenCode, Codex CLI, GitHub Copilot. Requires npx and at least one configured MCP server."
---

# MCPorter - Generic MCP Access

Use `mcporter` to work with MCP servers directly. MCPorter auto-discovers MCP configurations from OpenCode, Cursor, Claude, and other supported tools.

## Quick Reference

| Action | Command | Description |
|--------|---------|-------------|
| discover | `./scripts/mcporter.sh discover` | List all configured MCP servers |
| list | `./scripts/mcporter.sh list <server>` | List tools available on a server |
| call | `./scripts/mcporter.sh call <server>.<tool> [args...]` | Call an MCP tool |
| help | `./scripts/mcporter.sh help` | Show usage help |

## How to Use

### Natural Language
- "What MCP servers are available?"
- "List tools on the firecrawl server"
- "Call the scrape tool on firecrawl with url=https://example.com"

### Script Commands
```bash
# Discover available MCPs
./scripts/mcporter.sh discover

# List tools on a specific server
./scripts/mcporter.sh list context7
./scripts/mcporter.sh list firecrawl

# Call a tool with arguments (key=value format)
./scripts/mcporter.sh call firecrawl.scrape url=https://example.com
./scripts/mcporter.sh call chrome-devtools.screenshot url=https://example.com
```

### Direct mcporter CLI (advanced)

When the wrapper script is insufficient, use `mcporter` directly:

```bash
# Function syntax
mcporter call "linear.create_issue(title: \"Bug\")"

# Full URL for ad-hoc servers
mcporter call https://api.example.com/mcp.fetch url=https://example.com

# Stdio transport
mcporter call --stdio "bun run ./server.ts" scrape url=https://example.com

# JSON payload
mcporter call <server.tool> --args '{"limit":5}'

# Machine-readable output
mcporter call <server.tool> --output json key=value

# Show log tail after call (useful for debugging)
mcporter call <server.tool> --tail-log key=value
```

### Auth & Config

```bash
# OAuth authentication (opens browser, persists tokens to ~/.mcporter/<server>/)
mcporter auth <server | url> [--reset]

# Config management
mcporter config list|get|add|remove|import|login|logout
```

Config supports `bearerToken` or `bearerTokenEnv` for simple API key auth:

```jsonc
{
  "mcpServers": {
    "my-server": {
      "baseUrl": "https://api.example.com/mcp",
      "bearerTokenEnv": "MY_API_KEY"
    }
  }
}
```

Config auto-merges from Cursor, Claude Code, Claude Desktop, and Codex by default. Set `"imports": []` to disable or `"imports": ["cursor", "codex"]` for specific sources.

### Codegen

```bash
# Generate standalone CLI from MCP server (requires Bun for --compile)
mcporter generate-cli --command https://mcp.context7.com/mcp --compile
# Produces: ./context7 list-tools, ./context7 resolve-library-id react

# From a configured server
mcporter generate-cli --server <name> --compile

# Inspect generated CLI
mcporter inspect-cli <path> [--json]

# Generate TypeScript types
mcporter emit-ts <server> --mode client|types
```

Compiled CLIs embed discovered schemas — subsequent calls skip `listTools` round-trips.

## Prerequisites

- Node.js 18+ installed
- **Option A:** Install MCPorter via Homebrew: `brew tap steipete/tap && brew install mcporter`
- **Option B:** Use via npx (no install required): `npx mcporter`
- MCP servers configured in OpenCode, Cursor, Claude, or other supported tools

## Notes

- For library documentation, prefer the `context7-docs` skill instead
- MCPorter auto-discovers MCP configurations from multiple sources
- Use `discover` first to see what servers are available
- Tool arguments use key=value format
- Prefer `--output json` for machine-readable results
- Config default: `./config/mcporter.json` (override with `--config`)
