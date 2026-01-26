---
name: asu-discover
description: "Semantic search across 760+ ASU GitHub repositories via RAG. Use for finding code patterns, integrations, SDKs, and ASU-specific conventions. Domains: PeopleSoft, EDNA, DPL, Terraform, EEL, Vault, CI/CD. Use BEFORE starting ASU integration tasks."
allowed-tools: Bash(node:*) Bash(npx:*) Bash(pnpm:*) Bash(./scripts/*) Read Glob Grep
context: fork
---

# ASU Domain Discovery Skill (v2)

Semantic search across Arizona State University's GitHub organization using hybrid RAG (Retrieval-Augmented Generation).

**Announce at start:** "I'm using the asu-discover skill to search ASU repositories."

## Architecture

This skill is a client to the GitHub RAG backend that indexes 760+ ASU repositories:

- **Embedding Model:** Jina v2 (768 dimensions) - runs locally
- **Keyword Extraction:** Server-side TF-IDF via `/keywords` endpoint
- **Search:** Hybrid RRF (70% semantic + 30% keyword)
- **Backend:** Lambda API with sqlite-vec + FTS5

## Quick Reference

| Command | Description |
|---------|-------------|
| `ask "<question>"` | Natural language search |
| `search --query "<terms>"` | Structured search with filters |
| `health` | Check backend status |
| `clear-cache` | Clear cached results |
| `cache-stats` | Show cache statistics |

## How to Use

### Natural Language (Conversational)

```bash
cd {base_directory}

# Ask questions in natural language
./scripts/discover.sh ask "How do I publish events to EEL?"
./scripts/discover.sh ask "Show me EDNA authorization patterns in TypeScript"
./scripts/discover.sh ask "What's the pattern for PeopleSoft to DPL sync?"
```

### Structured Search

```bash
# Search with filters
./scripts/discover.sh search --query "checkAccess" --type function
./scripts/discover.sh search --query "terraform aurora" --type config
./scripts/discover.sh search --query "kafka publisher" --repo evbr-enterprise-event-lake

# Output as JSON
./scripts/discover.sh ask "vault secrets" --json
```

### Health Check

```bash
./scripts/discover.sh health
# Shows: repos indexed, chunks indexed, last update time, cache stats
```

## Options

| Option | Description |
|--------|-------------|
| `-l, --limit <n>` | Maximum results (default: 10, max: 50) |
| `-t, --type <types>` | Filter by chunk type: function, class, module, readme, terraform, config |
| `-r, --repo <repos>` | Filter to specific repositories |
| `--no-cache` | Skip result cache |
| `--json` | Output as JSON |

## First-Time Setup

The embedding model (~500MB) downloads on first use. To pre-download:

```bash
./scripts/setup.sh
```

## Domains Covered

| Domain | Examples |
|--------|----------|
| PeopleSoft | Integration Broker, ServiceOperation, IBRequest |
| EDNA | checkAccess, hasPermission, entitlements |
| DPL | Data Potluck, principal lookup, emplid |
| EEL | Kafka, Confluent, Avro, event publishing |
| Terraform | dco-terraform modules, vpc-core, aurora |
| Vault | hvac, secrets, AppRole, AWS IAM auth |
| CI/CD | Jenkins shared library, GitHub Actions |

## Caching

Results are cached locally for 24 hours to improve repeat query performance:
- Cache location: `~/.cache/opencode/asu-discover/cache.json`
- Use `--no-cache` to bypass
- Use `clear-cache` command to clear

## Files

```
skills/asu-discover/
├── SKILL.md                    # This file
├── package.json                # Dependencies
├── src/
│   ├── client/                 # RAG client implementation
│   │   ├── api.ts              # API client
│   │   ├── embedder.ts         # Jina v2 embedding
│   │   ├── cache.ts            # Result caching
│   │   └── config.ts           # Config loader
│   └── cli.ts                  # Commander CLI
├── scripts/
│   ├── discover.sh             # Entry point
│   └── setup.sh                # Model download
├── config/
│   └── settings.yaml           # API endpoint config
└── tests/
    └── smoke.sh                # Smoke tests
```

## Troubleshooting

### "Model not found" or slow first query
The embedding model downloads on first use (~500MB). Run setup to pre-download:
```bash
./scripts/setup.sh
```

### API errors
Check backend health:
```bash
./scripts/discover.sh health
```

### Stale results
Clear the cache:
```bash
./scripts/discover.sh clear-cache
```

### Network timeouts
The backend may have cold starts. Try again after a few seconds, or increase timeout in `config/settings.yaml`.

---

**Note:** This skill provides semantic search across ASU's GitHub organization. For general GitHub operations (issues, PRs, etc.), use the `github-ops` skill.
