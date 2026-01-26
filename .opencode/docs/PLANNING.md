# ASU-Discover RAG Client Implementation Plan

**Goal:** Refactor the `asu-discover` skill from bash/gh-CLI based implementation to a Node.js client for the GitHub RAG backend, enabling semantic search across 760+ ASU repositories.

**Architecture:** Node.js client with local Jina v2 embedding, calling the deployed GitHub RAG Lambda API for hybrid search (70% semantic + 30% keyword via RRF). Keywords extracted server-side via `/keywords` endpoint.

**Tech Stack:** Node.js 22, TypeScript, Transformers.js (Jina v2), Commander CLI, Zod validation

**Sources:** `archive/sources.md` | [SRC-001] github-rag-backend-planning.md

---

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Embedding location | Local (Jina v2 via Transformers.js) | Same model as indexer, consistent 768-dim vectors |
| Keyword extraction | Server-side via `/keywords` | Single source of truth, sophisticated TF-IDF with ngrams |
| Model distribution | Download on first use to `~/.cache/` | Keeps git repo small, prompted setup |
| Result caching | Lightweight JSON in `~/.cache/` | Improves repeat query performance, 24h TTL |
| Interaction model | Both conversational + structured | Natural language via `ask`, precise via `search` |
| Migration strategy | Delete old, start fresh | Clean implementation, no legacy baggage |

---

## API Contract (GitHub RAG Backend)

**Base URL:** `https://x6qxzhvbd9.execute-api.us-west-2.amazonaws.com`

### POST /keywords

Extracts keywords from natural language text using server-side TF-IDF.

```typescript
Request:  { text: string, limit?: number }
Response: { keywords: string, extracted: string[] }
// keywords = FTS5 query like "edna OR authorization OR checkaccess"
// extracted = individual terms for display
```

### POST /search

Hybrid semantic + keyword search with RRF ranking.

```typescript
Request: {
  embedding: number[768],  // Jina v2 vector (required)
  keywords: string,        // FTS5 query from /keywords (required)
  limit?: number,          // 1-50, default 10
  filters?: {
    chunk_types?: ('function'|'class'|'module'|'readme'|'terraform'|'config'|'other')[],
    repos?: string[]
  }
}
Response: {
  results: Array<{
    repo_name: string,
    file_path: string,
    content: string,
    language: string,
    chunk_type: string,
    line_start: number,
    line_end: number,
    score: number
  }>,
  meta: { search_ms: number, vector_matches: number, keyword_matches: number }
}
```

### GET /health

```typescript
Response: { status: 'ok', db_chunks: number, db_repos: number, last_indexed: string }
```

### GET /openapi.json

OpenAPI 3.0 specification for all endpoints.

---

## Architecture Diagram

```
┌────────────────────────────────────────────────────────────────┐
│                       User Query                                │
│   "How do I publish events to EEL in TypeScript?"               │
└────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────┐
│                  asu-discover Skill Client                      │
│  ┌────────────────────────────────────────────────────────────┐│
│  │  1. POST /keywords → get FTS5 query from backend           ││
│  │  2. Embed query locally (Jina v2, 768 dims)                ││
│  │  3. POST /search with embedding + keywords + filters       ││
│  │  4. Cache results locally (24h TTL)                        ││
│  │  5. Format results as actionable code references           ││
│  └────────────────────────────────────────────────────────────┘│
│                                                                 │
│  Model Cache: ~/.cache/opencode/asu-discover/models/            │
│  Result Cache: ~/.cache/opencode/asu-discover/cache.json        │
│  Config: skills/asu-discover/config/settings.yaml               │
└────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────┐
│              GitHub RAG Backend (Lambda)                        │
│              https://x6qxzhvbd9.execute-api.us-west-2...        │
│                                                                 │
│  POST /keywords   {text, limit?} → {keywords, extracted}        │
│  POST /search     {embedding[768], keywords, limit?, filters?}  │
│  GET  /health     → {status, db_chunks, db_repos, last_indexed} │
│  GET  /openapi.json → OpenAPI spec                              │
└────────────────────────────────────────────────────────────────┘
```

---

## Project Structure

```
skills/asu-discover/
├── SKILL.md                    # Skill definition
├── package.json                # Node.js dependencies
├── tsconfig.json               # TypeScript config
├── vitest.config.ts            # Unit test config
├── vitest.integration.config.ts # Integration test config
├── src/
│   ├── client/
│   │   ├── embedder.ts         # Jina v2 embedding via Transformers.js
│   │   ├── api.ts              # RAG API client (keywords + search + health)
│   │   ├── cache.ts            # Result caching (JSON file)
│   │   ├── config.ts           # Config loader
│   │   └── index.ts            # Client exports
│   ├── cli.ts                  # Commander CLI entry point
│   └── types.ts                # TypeScript types
├── scripts/
│   ├── discover.sh             # Bash wrapper (OpenCode interface)
│   └── setup.sh                # Model download script (prompts user)
├── config/
│   └── settings.yaml           # API endpoint, cache settings
└── tests/
    ├── embedder.test.ts        # Embedding unit tests
    ├── api.test.ts             # API client tests (mocked)
    ├── cache.test.ts           # Cache tests
    ├── integration.test.ts     # E2E tests against deployed API
    └── smoke.sh                # Bash smoke tests
```

---

## Dependencies

```json
{
  "name": "@opencode/asu-discover",
  "version": "2.0.0",
  "type": "module",
  "scripts": {
    "build": "tsc",
    "dev": "tsx watch src/cli.ts",
    "search": "tsx src/cli.ts search",
    "ask": "tsx src/cli.ts ask",
    "health": "tsx src/cli.ts health",
    "setup": "./scripts/setup.sh",
    "test": "vitest run",
    "test:integration": "vitest run --config vitest.integration.config.ts"
  },
  "dependencies": {
    "@huggingface/transformers": "^3.4.1",
    "commander": "^13.1.0",
    "yaml": "^2.7.0",
    "zod": "^3.24.2"
  },
  "devDependencies": {
    "@types/node": "^22.13.4",
    "typescript": "^5.7.3",
    "tsx": "^4.19.2",
    "vitest": "^3.1.3"
  }
}
```

---

## Implementation Phases

### Phase 1: Package Setup & Delete Old Implementation ✅ COMPLETE

**Goal:** Initialize Node.js package and remove old bash-based implementation.

**Deliverables:**
- [x] Delete old files: `scripts/`, `templates/`, `patterns/`, `data/`, `config/domains.yaml`
- [x] `skills/asu-discover/package.json` - Node.js package
- [x] `skills/asu-discover/tsconfig.json` - TypeScript config
- [x] `skills/asu-discover/src/types.ts` - Shared types matching API contract

**src/types.ts:**
```typescript
export interface KeywordsRequest {
  text: string;
  limit?: number;
}

export interface KeywordsResponse {
  keywords: string;
  extracted: string[];
}

export interface SearchRequest {
  embedding: number[];
  keywords: string;
  limit?: number;
  filters?: {
    chunk_types?: ChunkType[];
    repos?: string[];
  };
}

export type ChunkType = 'function' | 'class' | 'module' | 'readme' | 'terraform' | 'config' | 'other';

export interface SearchResult {
  repo_name: string;
  file_path: string;
  content: string;
  language: string;
  chunk_type: string;
  line_start: number;
  line_end: number;
  score: number;
}

export interface SearchResponse {
  results: SearchResult[];
  meta: {
    search_ms: number;
    vector_matches: number;
    keyword_matches: number;
  };
}

export interface HealthResponse {
  status: 'ok';
  db_chunks: number;
  db_repos: number;
  last_indexed: string;
}

export interface Config {
  api: {
    url: string;
    timeout_ms: number;
  };
  model: {
    name: string;
    cache_dir: string;
  };
  cache: {
    enabled: boolean;
    ttl_hours: number;
    path: string;
  };
  defaults: {
    limit: number;
  };
}
```

**Test Criteria:**
```bash
cd skills/asu-discover
pnpm install
pnpm exec tsc --noEmit  # Type check passes
```

**Commit:** `refactor(asu-discover): initialize v2 package structure`

---

### Phase 2: Configuration System ✅ COMPLETE

**Goal:** Create configuration system for API endpoint and settings.

**Deliverables:**
- [x] `skills/asu-discover/config/settings.yaml` - Configuration file
- [x] `skills/asu-discover/src/client/config.ts` - Config loader with ~ expansion

**config/settings.yaml:**
```yaml
api:
  url: https://x6qxzhvbd9.execute-api.us-west-2.amazonaws.com
  timeout_ms: 30000

model:
  name: jinaai/jina-embeddings-v2-base-code
  cache_dir: ~/.cache/opencode/asu-discover/models

cache:
  enabled: true
  ttl_hours: 24
  path: ~/.cache/opencode/asu-discover/cache.json

defaults:
  limit: 10
```

**src/client/config.ts:**
```typescript
import { readFileSync, existsSync } from 'fs';
import { parse } from 'yaml';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import type { Config } from '../types.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
const CONFIG_PATH = join(__dirname, '../../config/settings.yaml');

let cachedConfig: Config | null = null;

export function loadConfig(): Config {
  if (cachedConfig) return cachedConfig;
  
  if (!existsSync(CONFIG_PATH)) {
    throw new Error(`Config not found: ${CONFIG_PATH}`);
  }
  
  const content = readFileSync(CONFIG_PATH, 'utf-8');
  cachedConfig = parse(content) as Config;
  
  // Expand ~ in paths
  const home = process.env.HOME || '';
  cachedConfig.model.cache_dir = cachedConfig.model.cache_dir.replace(/^~/, home);
  cachedConfig.cache.path = cachedConfig.cache.path.replace(/^~/, home);
  
  return cachedConfig;
}

export function getConfigPath(): string {
  return CONFIG_PATH;
}
```

**Test Criteria:**
```bash
pnpm test -- config
# Expected: Config loads, parses, expands ~ correctly
```

**Commit:** `feat(asu-discover): add configuration system`

---

### Phase 3: Embedder (Jina v2) ✅ COMPLETE

**Goal:** Implement embedding client using Transformers.js with prompted setup.

**Deliverables:**
- [x] `skills/asu-discover/src/client/embedder.ts` - Embedding client
- [x] `skills/asu-discover/scripts/setup.sh` - Model download with user prompt
- [x] `skills/asu-discover/tests/embedder.test.ts` - Unit tests (deferred to integration)

**src/client/embedder.ts:**
```typescript
import { pipeline, FeatureExtractionPipeline } from '@huggingface/transformers';
import { existsSync, mkdirSync } from 'fs';
import { loadConfig } from './config.js';

let embedder: FeatureExtractionPipeline | null = null;

export async function getEmbedder(): Promise<FeatureExtractionPipeline> {
  if (embedder) return embedder;
  
  const config = loadConfig();
  const cacheDir = config.model.cache_dir;
  
  // Ensure cache directory exists
  if (!existsSync(cacheDir)) {
    mkdirSync(cacheDir, { recursive: true });
  }
  
  // Set HuggingFace cache directory
  process.env.HF_HOME = cacheDir;
  process.env.TRANSFORMERS_CACHE = cacheDir;
  
  console.error('Loading embedding model (first run may take a few minutes)...');
  
  embedder = await pipeline(
    'feature-extraction',
    config.model.name,
    { dtype: 'fp32' }
  );
  
  return embedder;
}

export async function embed(text: string): Promise<number[]> {
  const model = await getEmbedder();
  const output = await model(text, { pooling: 'mean', normalize: true });
  return Array.from(output.data as Float32Array);
}

export async function isModelCached(): Promise<boolean> {
  const config = loadConfig();
  return existsSync(config.model.cache_dir);
}
```

**scripts/setup.sh:**
```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== ASU-Discover Skill Setup ==="
echo ""

# Check for Node.js
if ! command -v node &> /dev/null; then
    echo "Error: Node.js is required but not installed."
    echo "Install via: brew install node"
    exit 1
fi

# Check for pnpm
if ! command -v pnpm &> /dev/null; then
    echo "Error: pnpm is required but not installed."
    echo "Install via: npm install -g pnpm"
    exit 1
fi

# Install npm dependencies
echo "Installing dependencies..."
cd "$SKILL_DIR"
pnpm install

echo ""
echo "The Jina v2 embedding model (~500MB) needs to be downloaded."
echo "This is required for semantic search and only needs to be done once."
echo ""
read -p "Download embedding model now? [Y/n] " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Skipping model download. Model will download on first use."
    exit 0
fi

# Pre-download the embedding model
echo ""
echo "Downloading Jina v2 embedding model..."
echo "This may take a few minutes depending on your connection."
echo ""

pnpm exec tsx -e "
import { getEmbedder } from './src/client/embedder.js';
console.log('Loading model...');
await getEmbedder();
console.log('Model cached successfully!');
"

echo ""
echo "Setup complete! The skill is ready to use."
echo ""
echo "Test with: ./scripts/discover.sh health"
```

**tests/embedder.test.ts:**
```typescript
import { describe, it, expect } from 'vitest';
import { embed } from '../src/client/embedder.js';

describe('embedder', () => {
  it('produces 768-dimensional vector', async () => {
    const vector = await embed('test query');
    expect(vector).toHaveLength(768);
  }, 120000); // 2min timeout for model load

  it('produces normalized vectors', async () => {
    const vector = await embed('test query');
    const magnitude = Math.sqrt(vector.reduce((sum, v) => sum + v * v, 0));
    expect(magnitude).toBeCloseTo(1.0, 4);
  }, 120000);

  it('produces consistent embeddings', async () => {
    const v1 = await embed('EDNA authorization');
    const v2 = await embed('EDNA authorization');
    expect(v1).toEqual(v2);
  }, 120000);
});
```

**Test Criteria:**
```bash
# Run setup (prompts for model download)
./scripts/setup.sh

# Run embedder tests
pnpm test -- embedder
# Expected: 768-dim normalized vectors
```

**Commit:** `feat(asu-discover): add Jina v2 embedding client with setup script`

---

### Phase 4: API Client ✅ COMPLETE

**Goal:** Implement RAG API client with error handling.

**Deliverables:**
- [x] `skills/asu-discover/src/client/api.ts` - API client
- [x] `skills/asu-discover/tests/api.test.ts` - Unit tests (covered by integration tests)

**src/client/api.ts:**
```typescript
import { loadConfig } from './config.js';
import { embed } from './embedder.js';
import type { 
  KeywordsRequest, KeywordsResponse,
  SearchRequest, SearchResponse, 
  HealthResponse, SearchResult 
} from '../types.js';

export interface SearchOptions {
  limit?: number;
  chunkTypes?: string[];
  repos?: string[];
}

export class RAGClient {
  private config = loadConfig();

  async health(): Promise<HealthResponse> {
    const response = await fetch(`${this.config.api.url}/health`, {
      method: 'GET',
      signal: AbortSignal.timeout(this.config.api.timeout_ms),
    });

    if (!response.ok) {
      throw new Error(`Health check failed: ${response.status}`);
    }

    return response.json();
  }

  async extractKeywords(text: string, limit?: number): Promise<KeywordsResponse> {
    const request: KeywordsRequest = { text, limit };
    
    const response = await fetch(`${this.config.api.url}/keywords`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(request),
      signal: AbortSignal.timeout(this.config.api.timeout_ms),
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`Keyword extraction failed: ${response.status} - ${error}`);
    }

    return response.json();
  }

  async search(query: string, options: SearchOptions = {}): Promise<SearchResponse> {
    // Extract keywords and generate embedding in parallel
    const [keywordsResult, embedding] = await Promise.all([
      this.extractKeywords(query),
      embed(query),
    ]);

    const request: SearchRequest = {
      embedding,
      keywords: keywordsResult.keywords,
      limit: options.limit ?? this.config.defaults.limit,
    };

    if (options.chunkTypes || options.repos) {
      request.filters = {};
      if (options.chunkTypes) {
        request.filters.chunk_types = options.chunkTypes as any;
      }
      if (options.repos) {
        request.filters.repos = options.repos;
      }
    }

    const response = await fetch(`${this.config.api.url}/search`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(request),
      signal: AbortSignal.timeout(this.config.api.timeout_ms),
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`Search failed: ${response.status} - ${error}`);
    }

    return response.json();
  }
}

export const client = new RAGClient();
```

**Test Criteria:**
```bash
pnpm test -- api
# Expected: API client tests pass (mocked fetch)
```

**Commit:** `feat(asu-discover): add RAG API client`

---

### Phase 5: Result Caching ✅ COMPLETE

**Goal:** Implement lightweight result caching for repeat queries.

**Deliverables:**
- [x] `skills/asu-discover/src/client/cache.ts` - Cache implementation
- [x] `skills/asu-discover/tests/cache.test.ts` - Cache tests (manual verification)

**src/client/cache.ts:**
```typescript
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs';
import { dirname } from 'path';
import { createHash } from 'crypto';
import { loadConfig } from './config.js';
import type { SearchResponse } from '../types.js';

interface CacheEntry {
  query: string;
  options: string;
  response: SearchResponse;
  timestamp: number;
}

interface CacheData {
  entries: Record<string, CacheEntry>;
}

function getCacheKey(query: string, options: object): string {
  const data = JSON.stringify({ query, options });
  return createHash('md5').update(data).digest('hex');
}

function loadCache(): CacheData {
  const config = loadConfig();
  if (!config.cache.enabled) return { entries: {} };
  
  try {
    if (existsSync(config.cache.path)) {
      const content = readFileSync(config.cache.path, 'utf-8');
      return JSON.parse(content);
    }
  } catch {
    // Corrupted cache, start fresh
  }
  return { entries: {} };
}

function saveCache(cache: CacheData): void {
  const config = loadConfig();
  if (!config.cache.enabled) return;
  
  const dir = dirname(config.cache.path);
  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true });
  }
  
  writeFileSync(config.cache.path, JSON.stringify(cache, null, 2));
}

export function getCached(query: string, options: object): SearchResponse | null {
  const config = loadConfig();
  if (!config.cache.enabled) return null;
  
  const cache = loadCache();
  const key = getCacheKey(query, options);
  const entry = cache.entries[key];
  
  if (!entry) return null;
  
  // Check TTL
  const ttlMs = config.cache.ttl_hours * 60 * 60 * 1000;
  if (Date.now() - entry.timestamp > ttlMs) {
    // Expired
    delete cache.entries[key];
    saveCache(cache);
    return null;
  }
  
  return entry.response;
}

export function setCache(query: string, options: object, response: SearchResponse): void {
  const config = loadConfig();
  if (!config.cache.enabled) return;
  
  const cache = loadCache();
  const key = getCacheKey(query, options);
  
  cache.entries[key] = {
    query,
    options: JSON.stringify(options),
    response,
    timestamp: Date.now(),
  };
  
  // Prune old entries (keep max 100)
  const entries = Object.entries(cache.entries);
  if (entries.length > 100) {
    entries.sort((a, b) => b[1].timestamp - a[1].timestamp);
    cache.entries = Object.fromEntries(entries.slice(0, 100));
  }
  
  saveCache(cache);
}

export function clearCache(): void {
  const config = loadConfig();
  const cache: CacheData = { entries: {} };
  saveCache(cache);
}
```

**Test Criteria:**
```bash
pnpm test -- cache
# Expected: Cache set/get/TTL/prune works correctly
```

**Commit:** `feat(asu-discover): add result caching`

---

### Phase 6: CLI Interface ✅ COMPLETE

**Goal:** Create Commander CLI with conversational and structured modes.

**Deliverables:**
- [x] `skills/asu-discover/src/cli.ts` - Commander CLI
- [x] `skills/asu-discover/scripts/discover.sh` - Bash wrapper
- [x] `skills/asu-discover/src/client/index.ts` - Client exports

**src/cli.ts:**
```typescript
import { Command } from 'commander';
import { client } from './client/index.js';
import { getCached, setCache, clearCache } from './client/cache.js';
import type { SearchResult } from './types.js';

const program = new Command();

program
  .name('asu-discover')
  .description('Semantic search across 760+ ASU GitHub repositories')
  .version('2.0.0');

// Health check
program
  .command('health')
  .description('Check RAG backend health')
  .action(async () => {
    try {
      const health = await client.health();
      console.log(`Status: ${health.status}`);
      console.log(`Indexed: ${health.db_repos} repos, ${health.db_chunks} chunks`);
      console.log(`Last indexed: ${health.last_indexed}`);
    } catch (error) {
      console.error('Health check failed:', error instanceof Error ? error.message : error);
      process.exit(1);
    }
  });

// Natural language search (conversational)
program
  .command('ask <query...>')
  .description('Ask a natural language question')
  .option('-l, --limit <n>', 'Maximum results', '10')
  .option('--no-cache', 'Skip cache')
  .option('--json', 'Output as JSON')
  .action(async (queryParts, options) => {
    const query = queryParts.join(' ');
    await executeSearch(query, options);
  });

// Structured search
program
  .command('search')
  .description('Structured search with filters')
  .requiredOption('-q, --query <query>', 'Search query')
  .option('-l, --limit <n>', 'Maximum results', '10')
  .option('-t, --type <types...>', 'Chunk types (function, class, readme, etc.)')
  .option('-r, --repo <repos...>', 'Filter to specific repos')
  .option('--no-cache', 'Skip cache')
  .option('--json', 'Output as JSON')
  .action(async (options) => {
    await executeSearch(options.query, options);
  });

// Clear cache
program
  .command('clear-cache')
  .description('Clear the result cache')
  .action(() => {
    clearCache();
    console.log('Cache cleared.');
  });

async function executeSearch(query: string, options: any): Promise<void> {
  try {
    const searchOptions = {
      limit: parseInt(options.limit),
      chunkTypes: options.type,
      repos: options.repo,
    };

    // Check cache first
    if (options.cache !== false) {
      const cached = getCached(query, searchOptions);
      if (cached) {
        if (options.json) {
          console.log(JSON.stringify({ ...cached, cached: true }, null, 2));
        } else {
          console.log('(cached result)\n');
          formatResults(cached.results, cached.meta);
        }
        return;
      }
    }

    const response = await client.search(query, searchOptions);

    // Cache result
    if (options.cache !== false) {
      setCache(query, searchOptions, response);
    }

    if (options.json) {
      console.log(JSON.stringify(response, null, 2));
    } else {
      formatResults(response.results, response.meta);
    }
  } catch (error) {
    console.error('Search failed:', error instanceof Error ? error.message : error);
    process.exit(1);
  }
}

function formatResults(results: SearchResult[], meta: any): void {
  console.log(`Found ${results.length} results (${meta.search_ms}ms)`);
  console.log(`Vector: ${meta.vector_matches} | Keyword: ${meta.keyword_matches}\n`);
  console.log('─'.repeat(80));

  for (const result of results) {
    console.log(`\n📁 ${result.repo_name}`);
    console.log(`   ${result.file_path}:${result.line_start}-${result.line_end}`);
    console.log(`   Type: ${result.chunk_type} | Lang: ${result.language} | Score: ${result.score.toFixed(4)}`);
    console.log('');
    
    // Show truncated content (max 10 lines)
    const lines = result.content.split('\n').slice(0, 10);
    for (const line of lines) {
      console.log(`   ${line}`);
    }
    if (result.content.split('\n').length > 10) {
      console.log('   ...');
    }
    console.log('─'.repeat(80));
  }
}

program.parse();
```

**scripts/discover.sh:**
```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# Ensure dependencies are installed
if [[ ! -d "$SKILL_DIR/node_modules" ]]; then
    echo "Installing dependencies..." >&2
    (cd "$SKILL_DIR" && pnpm install --silent)
fi

# Run CLI
exec pnpm --dir="$SKILL_DIR" exec tsx "$SKILL_DIR/src/cli.ts" "$@"
```

**src/client/index.ts:**
```typescript
export { RAGClient, client } from './api.js';
export { embed, getEmbedder, isModelCached } from './embedder.js';
export { loadConfig, getConfigPath } from './config.js';
export { getCached, setCache, clearCache } from './cache.js';
```

**Test Criteria:**
```bash
# Test CLI commands
./scripts/discover.sh health
./scripts/discover.sh ask "How do I integrate with EDNA?"
./scripts/discover.sh search --query "checkAccess" --type function
./scripts/discover.sh clear-cache
```

**Commit:** `feat(asu-discover): add CLI with ask, search, health commands`

---

### Phase 7: SKILL.md & Smoke Tests ✅ COMPLETE

**Goal:** Update skill documentation and create smoke tests.

**Deliverables:**
- [x] `skills/asu-discover/SKILL.md` - Updated skill definition
- [x] `skills/asu-discover/tests/smoke.sh` - Smoke tests

**SKILL.md:**
```markdown
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
# Shows: repos indexed, chunks indexed, last update time
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

---

**Note:** This skill provides semantic search across ASU's GitHub organization. For general GitHub operations (issues, PRs, etc.), use the `github-ops` skill.
```

**tests/smoke.sh:**
```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Smoke Test: asu-discover ==="
echo ""

# Test 1: Health check
echo "Test 1: Health check"
if "$SKILL_DIR/scripts/discover.sh" health > /dev/null 2>&1; then
    echo "  ✓ Health check passed"
else
    echo "  ✗ Health check failed"
    exit 1
fi

# Test 2: Natural language search
echo "Test 2: Natural language search"
if "$SKILL_DIR/scripts/discover.sh" ask "EDNA authorization" --limit 1 --json > /dev/null 2>&1; then
    echo "  ✓ Natural language search passed"
else
    echo "  ✗ Natural language search failed"
    exit 1
fi

# Test 3: Structured search
echo "Test 3: Structured search"
if "$SKILL_DIR/scripts/discover.sh" search --query "checkAccess" --limit 1 --json > /dev/null 2>&1; then
    echo "  ✓ Structured search passed"
else
    echo "  ✗ Structured search failed"
    exit 1
fi

# Test 4: Cache clear
echo "Test 4: Cache clear"
if "$SKILL_DIR/scripts/discover.sh" clear-cache > /dev/null 2>&1; then
    echo "  ✓ Cache clear passed"
else
    echo "  ✗ Cache clear failed"
    exit 1
fi

echo ""
echo "=== All smoke tests passed ==="
```

**Test Criteria:**
```bash
chmod +x tests/smoke.sh
./tests/smoke.sh
# Expected: All 4 tests pass
```

**Commit:** `docs(asu-discover): add SKILL.md and smoke tests for v2`

---

### Phase 8: Integration Tests ✅ COMPLETE

**Goal:** Add integration tests against deployed API.

**Deliverables:**
- [x] `skills/asu-discover/vitest.config.ts` - Unit test config
- [x] `skills/asu-discover/vitest.integration.config.ts` - Integration test config
- [x] `skills/asu-discover/tests/integration.test.ts` - E2E tests (8 tests passing)

**vitest.integration.config.ts:**
```typescript
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['tests/integration.test.ts'],
    testTimeout: 120000, // 2min for cold starts + model loading
  },
});
```

**tests/integration.test.ts:**
```typescript
import { describe, it, expect, beforeAll } from 'vitest';
import { client } from '../src/client/index.js';

describe('integration tests', () => {
  beforeAll(async () => {
    // Verify API is available
    const health = await client.health();
    expect(health.status).toBe('ok');
  });

  it('health endpoint returns valid response', async () => {
    const health = await client.health();
    expect(health.status).toBe('ok');
    expect(health.db_chunks).toBeGreaterThan(0);
    expect(health.db_repos).toBeGreaterThan(0);
  });

  it('search returns results for known query', async () => {
    const response = await client.search('EDNA authorization checkAccess', { limit: 5 });
    expect(response.results.length).toBeGreaterThan(0);
    expect(response.meta.search_ms).toBeGreaterThan(0);
  });

  it('search with filters works', async () => {
    const response = await client.search('terraform module', {
      limit: 5,
      chunkTypes: ['terraform', 'config'],
    });
    expect(response.results.length).toBeGreaterThanOrEqual(0);
  });
});
```

**Test Criteria:**
```bash
pnpm test:integration
# Expected: All integration tests pass (requires network + model)
```

**Commit:** `test(asu-discover): add integration tests`

---

## Changelog

| Version | Date | Source | Summary |
|---------|------|--------|---------|
| v1.1 | 2026-01-26 | Build mode | All 8 phases complete. Full implementation delivered. |
| v1.0 | 2026-01-26 | Plan mode | Initial plan for RAG client implementation |

---

## References

- [GitHub RAG Backend Planning](.opencode/docs/github-rag-backend-planning.md)
- [ASU GitHub RAG Backend](https://github.com/ASU/iden-identity-resolution-service-components/tree/develop/apps/github-rag)
- [Transformers.js](https://huggingface.co/docs/transformers.js)
- [Jina Embeddings v2](https://huggingface.co/jinaai/jina-embeddings-v2-base-code)
