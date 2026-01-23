---
name: asu-discover
description: "Smart discovery across ASU's 760+ GitHub repositories. Use for finding ASU repos, code patterns, integrations, and SDKs. Domains: PeopleSoft, EDNA, DPL, Terraform, Salesforce, Auth, CI/CD. Use BEFORE starting ASU integration tasks."
allowed-tools: Bash(gh:*) Bash(./scripts/*) Read Glob Grep
context: fork
---

# ASU Domain Discovery Skill

Intelligent search and discovery across Arizona State University's GitHub organization (760+ repositories). This skill provides domain-aware search with local caching to work within GitHub's rate limits.

**Requirements:** `gh` CLI authenticated with access to ASU org (`gh auth login`)

## Architecture

```
┌─────────────────────────────────────────┐
│          User Query                     │
│   "How do I integrate with EDNA?"       │
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│     Domain Detection & Expansion        │
│  Detected: edna                         │
│  Expanded: checkAccess, hasPermission   │
└─────────────────────────────────────────┘
                    │
        ┌───────────┴───────────┐
        ▼                       ▼
┌───────────────┐      ┌───────────────────┐
│   Tier 1      │      │     Tier 2        │
│ Local SQLite  │      │  GitHub API       │
│ (instant)     │      │  (rate limited)   │
│               │      │                   │
│ FTS5 search   │      │ gh search code    │
│ 760+ repos    │      │ 10 req/min        │
│ No rate limit │      │ 24h cache         │
└───────────────┘      └───────────────────┘
        │                       │
        └───────────┬───────────┘
                    ▼
           Merged Results
```

## Quick Reference

| Action | Description | Rate Limited |
|--------|-------------|--------------|
| `search` | Two-tier search (local + API) | API tier only |
| `repos` | Find repos by domain/prefix | No |
| `code` | Search code with caching | Yes (10/min) |
| `context` | Build integration context | Partial |
| `patterns` | Find integration patterns between systems | Yes |
| `pattern` | Show design pattern details (e.g., EEL) | No |
| `index` | Manage local index | No |

## How to Use

### Basic Discovery

```bash
cd {base_directory}

# Search with automatic domain detection
./scripts/discover.sh search --query "PeopleSoft integration"

# Search within a specific domain  
./scripts/discover.sh search --query "check access" --domain edna

# Find repos by team prefix
./scripts/discover.sh repos --prefix crm --limit 20

# Find repos by domain
./scripts/discover.sh repos --domain dpl
```

### Code Search (Rate Limited)

```bash
# Search code (checks cache first, rate limited)
./scripts/discover.sh code --query "checkAccess" --language typescript

# Use only cached results (no API calls)
./scripts/discover.sh code --query "DplClient" --cached-only

# Local-only search (no API at all)
./scripts/discover.sh search --query "terraform module" --local-only
```

### Building Integration Context

```bash
# Get full context for an integration task
./scripts/discover.sh context --query "sync employee data from PeopleSoft to DPL"

# Find patterns between two systems
./scripts/discover.sh patterns --source peoplesoft --target dpl
```

### Managing the Index

```bash
# Build full index (first time, ~30 seconds)
./scripts/discover.sh index build

# Refresh with recent changes
./scripts/discover.sh index refresh

# View statistics
./scripts/discover.sh index stats

# Re-classify domains
./scripts/discover.sh index classify
```

### Using Design Patterns

Design patterns are architectural templates with implementation guidance. They go beyond simple domain search by providing boilerplate code, best practices, and real-world examples.

```bash
# List available design patterns
./scripts/discover.sh pattern --list

# Show full pattern overview
./scripts/discover.sh pattern --name eel

# Get publisher examples by language
./scripts/discover.sh pattern --name eel --type publisher

# Get subscriber examples
./scripts/discover.sh pattern --name eel --type subscriber

# Get boilerplate repo for starting a new handler
./scripts/discover.sh pattern --name eel --type boilerplate
```

The `context` action auto-suggests relevant patterns when your query matches pattern triggers (e.g., "real-time", "event-driven", "publish", "kafka").

## Design Patterns

### EEL (Enterprise Event Lake)

ASU's real-time, Kafka-based event-driven architecture backbone. Use for decoupled, asynchronous communication between services.

| Aspect | Details |
|--------|---------|
| Platform | Confluent Cloud (Managed Apache Kafka) |
| Schema Format | Apache Avro |
| Delivery | At-least-once |
| Infrastructure | `ASU/evbr-enterprise-event-lake` |

**When to use:**
- Real-time data sync across systems
- Loose coupling (publishers don't know subscribers)
- Event-driven workflows and notifications
- Fan-out scenarios (one event, many consumers)
- Audit trails and event sourcing

**Key Repositories:**

| Type | Repository | Description |
|------|------------|-------------|
| Boilerplate | `evbr-enterprise-event-lake-event-handler-boilerplate` | Start here for new handlers |
| Java Publisher | `edna` → `EELClient.java` | Identity/entitlement events |
| Python Publisher | `iden-identity-resolution-service-api` → `eel_client.py` | Lambda-based publishing |
| JS Publisher | `cremo-credid` | JavaScript integration example |
| Python Subscriber | `sisfa-peoplesoft-financial-aid-module-event-listeners` | Financial Aid events |
| Python Subscriber | `siscc-peoplesoft-campus-community-module-event-listeners` | Campus Community events |

**Pattern triggers** (auto-detected in `context` action):
`event-driven`, `real-time`, `publish`, `subscribe`, `kafka`, `confluent`, `avro`, `async`, `decoupled`, `fanout`

## Domains

| Domain | Triggers | Team Prefixes | Key Repos |
|--------|----------|---------------|-----------|
| `peoplesoft` | ps, psft, integration broker, ib | ps, aiml | aiml-peoplesoft-ib |
| `edna` | edna, entitlement, checkAccess, authz | edna, eadv | edna-sdk, edna-*-client |
| `dpl` | dpl, data potluck, principal, emplid | dpl | dpl-python-sdk |
| `serviceauth` | serviceauth, jwt, token | authn | serviceauth-client |
| `auth` | authn, sso, saml, oidc | authn, auth | auth-service |
| `identity` | identity, unity, unityid | iden, unity | unity-identity |
| `salesforce` | salesforce, crm, sfdc, apex | crm, sf | salesforce-integrations |
| `terraform` | terraform, tf, iac, hcl | tf, infra | terraform-modules |
| `cicd` | cicd, pipeline, workflow, actions | cicd | reusable-workflows |
| `cloudflare` | cloudflare, cf, worker | cf | cloudflare-workers |
| `ml` | ml, ai, machine learning, model | aiml | ml-models |
| `eel` | eel, event lake, kafka, confluent, avro | evbr | evbr-enterprise-event-lake |
| `logging` | logging, observability, cribl, kafkabahn | eli5 | eli5-kafkabahn |

## Team Prefixes

Based on ASU org analysis:

| Prefix | Count | Domain |
|--------|-------|--------|
| crm | 66 | salesforce |
| eadv | 38 | edna |
| authn | 15 | auth |
| aiml | 12 | ml |
| edna | 11 | edna |
| iden | 10 | identity |
| eli5 | 9 | logging |
| evbr | 2 | eel |
| tf | - | terraform |
| infra | - | infrastructure |

## Rate Limiting

GitHub code search is limited to **10 requests per minute**. This skill handles rate limits by:

1. **Local Index First** - Searches SQLite FTS5 index (instant, no limit)
2. **24h Caching** - Caches code search results for 24 hours
3. **Rate Tracking** - Waits 6 seconds between API calls
4. **`--cached-only`** - Option to skip API entirely
5. **`--local-only`** - Search only local index

## Common Options

| Option | Description |
|--------|-------------|
| `--query QUERY` | Search query (natural language or keywords) |
| `--domain DOMAIN` | Filter to specific domain |
| `--prefix PREFIX` | Filter by team prefix |
| `--language LANG` | Filter by programming language |
| `--limit N` | Maximum results (default: 30) |
| `--no-expand` | Disable keyword expansion |
| `--local-only` | Only search local index |
| `--cached-only` | Only use cached API results |
| `--json` | JSON output format |
| `--verbose` | Show debug information |

## Examples

### Finding EDNA Integration Patterns

```bash
# Step 1: Find relevant repos
./scripts/discover.sh repos --domain edna

# Step 2: Search for checkAccess usage
./scripts/discover.sh code --query "checkAccess" --language typescript

# Step 3: Get full context
./scripts/discover.sh context --query "implement EDNA authorization in Node.js API"
```

### Discovering PeopleSoft Integrations

```bash
# Find all PS-related repos
./scripts/discover.sh repos --prefix ps

# Search for Integration Broker code
./scripts/discover.sh search --query "ServiceOperation IBRequest"

# Find PS-to-DPL integration patterns
./scripts/discover.sh patterns --source peoplesoft --target dpl
```

### Working with Terraform Modules

```bash
# Find terraform repos
./scripts/discover.sh repos --prefix tf
./scripts/discover.sh repos --domain terraform

# Search for specific module patterns
./scripts/discover.sh code --query "aws_lambda_function" --language HCL
```

## Files

```
skills/asu-discover/
├── SKILL.md                 # This file
├── config/
│   └── domains.yaml         # Domain taxonomy and synonyms
├── data/
│   ├── .gitignore           # Ignore generated files
│   └── asu-repos.db         # SQLite index (generated)
└── scripts/
    ├── lib/
    │   └── db.sh            # SQLite helper functions
    └── discover.sh          # Main script
```

## Troubleshooting

### "Index not found" 
The index will auto-build on first use. To manually build:
```bash
./scripts/discover.sh index build
```

### Rate limit errors
Use `--cached-only` or `--local-only` to avoid API calls:
```bash
./scripts/discover.sh search --query "..." --local-only
```

### No results
Try broader terms or check domain spelling:
```bash
./scripts/discover.sh expand --query "your query"  # Debug expansion
```

---

**Note:** This skill is optimized for ASU's GitHub organization. For general GitHub operations, use the `github-ops` skill instead.
