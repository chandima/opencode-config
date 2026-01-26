# GitHub RAG Service Implementation Plan

**Goal:** Build a hybrid RAG service that indexes ~800 ASU GitHub repositories for semantic code search, deployed as a lightweight Lambda with bundled SQLite database.

**Architecture:** Single TypeScript package with two modules: `indexer` (build-time CLI with embedding model) and `server` (runtime Lambda API without embedding model). The server receives pre-computed embedding vectors from an external OpenCode skill and performs hybrid search using sqlite-vec + FTS5 with Reciprocal Rank Fusion.

**Tech Stack:** Node.js 22, TypeScript, sqlite-vec, FTS5, jina-embeddings-v2-base-code (indexer only), code-chopper, custom TF-IDF keywords, Hono, SST v3

**Sources:** `archive/sources.md` | [SRC-001], [SRC-002], [SRC-003]

---

## Key Decisions

| Decision | Choice | Rationale | Source |
|----------|--------|-----------|--------|
| Package Structure | Single package with modules | Simpler dependency management, shared types | SRC-003 |
| Embedding Model | jina-embeddings-v2-base-code | 8k context, Apache 2.0, code-optimized | SRC-002 |
| Embedding Location | Indexer only (build-time) | Server stays lightweight, fast cold starts | SRC-003 |
| Server Input | Embedding vector + keywords | External skill handles embedding, server does search | SRC-003 |
| Vector DB | sqlite-vec + FTS5 | Single file, hybrid search, no runtime dependencies | SRC-002 |
| Chunking | code-chopper (Tree-sitter) | AST-based preserves logical units | SRC-002 |
| Keywords | Custom TF-IDF | Statistical, fast, no ML model, ESM-compatible | SRC-002 |
| Deployment | ZIP (not container) | No model = smaller package, fits 250MB limit | SRC-003 |
| Memory | 512MB-1GB | Sufficient without embedding model | SRC-003 |
| API Style | REST only (no MCP) | External skill handles MCP integration | SRC-003 |
| Delta Indexing | Full delta with stale check | Only re-index changed repos, warn before deploy | SRC-003 |

---

## Dependencies

```json
{
  "dependencies": {
    "better-sqlite3": "^11.7.0",
    "sqlite-vec": "^0.1.6",
    "@huggingface/transformers": "^3.4.1",
    "code-chopper": "^0.3.1",
    "hono": "^4.7.4",
    "@hono/node-server": "^1.14.0",
    "@hono/zod-openapi": "^0.16.0",
    "@hono/swagger-ui": "^0.5.1",
    "commander": "^13.1.0",
    "zod": "^3.24.2",
    "octokit": "^4.1.2"
  },
  "devDependencies": {
    "@types/better-sqlite3": "^7.6.12",
    "@types/node": "^22.13.4",
    "typescript": "^5.7.3",
    "tsx": "^4.19.2",
    "esbuild": "^0.25.0",
    "vitest": "^3.1.3",
    "dotenv": "^16.5.0"
  }
}
```

**Note:** sqlite-vec requires `BigInt` for rowid values in prepared statements when using better-sqlite3.

---

## TypeScript Configuration

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "lib": ["ES2022"],
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "declaration": true,
    "resolveJsonModule": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "data"]
}
```

---

## Implementation Patterns

### Embedder (Transformers.js + Jina v2)

```typescript
// src/indexer/embedding/embedder.ts
import { pipeline, FeatureExtractionPipeline } from '@huggingface/transformers';

let embedder: FeatureExtractionPipeline | null = null;

export async function getEmbedder(): Promise<FeatureExtractionPipeline> {
  if (!embedder) {
    embedder = await pipeline(
      'feature-extraction',
      'jinaai/jina-embeddings-v2-base-code',
      { dtype: 'fp32' }  // Use fp32 for accuracy; quantized available if needed
    );
  }
  return embedder;
}

export async function embed(text: string): Promise<Float32Array> {
  const model = await getEmbedder();
  const output = await model(text, { pooling: 'mean', normalize: true });
  return new Float32Array(output.data);
}
```

### sqlite-vec Loading

```typescript
// src/indexer/db/client.ts
import Database from 'better-sqlite3';
import * as sqliteVec from 'sqlite-vec';

export function createDatabase(dbPath: string): Database.Database {
  const db = new Database(dbPath);
  sqliteVec.load(db);  // Load vector extension
  
  // Enable WAL mode for better write performance during indexing
  db.pragma('journal_mode = WAL');
  
  return db;
}

// src/server/services/db.ts (read-only for Lambda)
export function openDatabase(dbPath: string): Database.Database {
  const db = new Database(dbPath, { readonly: true });
  sqliteVec.load(db);
  return db;
}
```

### Vector Insert/Query

```typescript
// Insert embedding - note BigInt for rowid and Buffer for vector
const insertVec = db.prepare(`
  INSERT INTO vec_chunks (rowid, embedding) VALUES (?, ?)
`);
const buffer = Buffer.from(embedding.buffer);  // Float32Array → Buffer
insertVec.run(BigInt(chunkId), buffer);

// Query with vector (sqlite-vec uses MATCH syntax)
const searchVec = db.prepare(`
  SELECT chunk_id, distance 
  FROM vec_chunks 
  WHERE embedding MATCH ? AND k = ?
`);
const queryBuffer = Buffer.from(queryEmbedding.buffer);
const results = searchVec.all(queryBuffer, limit);
```

### Code Chunking (code-splitter)

```typescript
// src/indexer/chunking/code-chunker.ts
import { splitCode } from 'code-splitter';

export interface CodeChunk {
  content: string;
  lineStart: number;
  lineEnd: number;
  type: 'function' | 'class' | 'module' | 'other';
}

export function chunkCode(
  code: string,
  language: string,
  maxChunkSize = 2000
): CodeChunk[] {
  const chunks = splitCode(code, {
    language,
    maxChunkSize,
    overlap: 100  // Overlap for context continuity
  });
  
  return chunks.map(chunk => ({
    content: chunk.content,
    lineStart: chunk.startLine,
    lineEnd: chunk.endLine,
    type: inferChunkType(chunk)
  }));
}

function inferChunkType(chunk: any): CodeChunk['type'] {
  if (chunk.type === 'function' || chunk.type === 'method') return 'function';
  if (chunk.type === 'class') return 'class';
  if (chunk.type === 'module') return 'module';
  return 'other';
}
```

### Keyword Extraction (Custom TF-IDF)

```typescript
// src/indexer/keywords/extractor.ts
// Custom TF-IDF implementation (replaced YAKE! due to ESM issues)

export function extractKeywords(text: string, topN = 10): string[] {
  const words = tokenize(text);
  const tf = computeTermFrequency(words);
  const idf = computeIDF(words);
  
  const scores = new Map<string, number>();
  for (const [term, freq] of tf) {
    scores.set(term, freq * (idf.get(term) ?? 1));
  }
  
  return [...scores.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, topN)
    .map(([term]) => term);
}

export function keywordsToFtsQuery(keywords: string[]): string {
  return keywords.join(' OR ');
}
```

### GitHub Client (Octokit)

```typescript
// src/indexer/github/client.ts
import { Octokit } from 'octokit';

export function createGitHubClient(token: string): Octokit {
  return new Octokit({ auth: token });
}

export async function* listOrgRepos(
  client: Octokit,
  org: string
): AsyncGenerator<Repository> {
  const iterator = client.paginate.iterator(
    client.rest.repos.listForOrg,
    { org, per_page: 100, sort: 'pushed', direction: 'desc' }
  );
  
  for await (const { data: repos } of iterator) {
    for (const repo of repos) {
      yield {
        name: repo.name,
        fullName: repo.full_name,
        description: repo.description,
        defaultBranch: repo.default_branch,
        topics: repo.topics ?? [],
        language: repo.language,
        pushedAt: repo.pushed_at
      };
    }
  }
}

export async function getRepoContent(
  client: Octokit,
  owner: string,
  repo: string,
  path: string
): Promise<string | null> {
  try {
    const { data } = await client.rest.repos.getContent({
      owner, repo, path, mediaType: { format: 'raw' }
    });
    return data as unknown as string;
  } catch {
    return null;
  }
}
```

### Hono Lambda Handler

```typescript
// src/server/index.ts
import { Hono } from 'hono';
import { handle } from 'hono/aws-lambda';
import { searchRoute } from './routes/search';
import { healthRoute } from './routes/health';

const app = new Hono();

app.route('/search', searchRoute);
app.route('/health', healthRoute);

// Lambda handler export
export const handler = handle(app);

// Local dev server
if (process.env.NODE_ENV === 'development') {
  const { serve } = await import('@hono/node-server');
  serve({ fetch: app.fetch, port: 3000 });
  console.log('Server running at http://localhost:3000');
}
```

### Request Validation (Zod)

```typescript
// src/server/routes/search.ts
import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';

const searchSchema = z.object({
  embedding: z.array(z.number()).length(768),
  keywords: z.string().min(1),
  limit: z.number().min(1).max(50).default(10),
  filters: z.object({
    chunk_types: z.array(z.enum([
      'function', 'class', 'module', 'readme', 'terraform', 'config'
    ])).optional(),
    repos: z.array(z.string()).optional()
  }).optional()
});

export const searchRoute = new Hono();

searchRoute.post('/', zValidator('json', searchSchema), async (c) => {
  const body = c.req.valid('json');
  const results = await hybridSearch(body);
  return c.json(results);
});
```

---

## Project Structure

```
apps/github-rag/                    # Single package
├── .opencode/docs/
│   ├── PLANNING.md                 # This file
│   └── archive/                    # Source documents
├── src/
│   ├── indexer/                    # Build-time module (HAS embedding model)
│   │   ├── index.ts                # Exports
│   │   ├── cli.ts                  # Commander CLI
│   │   ├── pipeline.ts             # Orchestrates indexing
│   │   ├── github/
│   │   │   └── client.ts           # GitHub API wrapper
│   │   ├── chunking/
│   │   │   └── code-chunker.ts     # Tree-sitter chunking
│   │   ├── keywords/
│   │   │   └── index.ts            # Re-exports from shared
│   │   ├── embedding/
│   │   │   └── embedder.ts         # Transformers.js + Jina v2
│   │   └── db/
│   │       ├── schema.sql
│   │       └── client.ts           # SQLite write client
│   ├── server/                     # Runtime module (NO embedding model)
│   │   ├── index.ts                # OpenAPIHono app + Lambda handler
│   │   ├── schemas.ts              # OpenAPI Zod schemas
│   │   ├── routes/
│   │   │   ├── search.ts           # POST /search (OpenAPI)
│   │   │   ├── keywords.ts         # POST /keywords (OpenAPI)
│   │   │   └── health.ts           # GET /health (OpenAPI)
│   │   └── services/
│   │       ├── search.ts           # Hybrid RRF search
│   │       └── db.ts               # SQLite read-only client
│   └── shared/
│       ├── types.ts                # Shared types
│       ├── keywords.ts             # TF-IDF keyword extraction (shared)
│       └── schema.ts               # Schema constants
├── data/                           # Build artifacts (gitignored)
│   ├── embeddings.db               # Built by indexer
│   └── last-run.json               # Delta tracking
├── sst.config.ts
├── package.json
└── tsconfig.json
```

---

## API Contract

The API is documented via OpenAPI 3.1 spec, available at `/openapi.json` (JSON) and `/docs` (Swagger UI in non-prod).

### Usage Flow

1. **Extract keywords**: `POST /keywords` with raw query text → get FTS5 query string
2. **Generate embedding**: Client-side with Jina v2 model (768 dimensions)
3. **Search**: `POST /search` with embedding + keywords → get ranked results

### POST /keywords

Extracts keywords from raw text using TF-IDF scoring. Returns an FTS5-formatted query string.

**Request:**
```typescript
interface KeywordsRequest {
  text: string;       // Raw text to extract keywords from
  limit?: number;     // Max keywords (1-50, default 10)
}
```

**Response:**
```typescript
interface KeywordsResponse {
  keywords: string;   // FTS5-formatted query (e.g., "terraform OR modules OR bucket")
  extracted: string[]; // Individual keyword terms
}
```

### POST /search

Receives pre-computed embedding vector and keywords from external caller.

**Request:**
```typescript
interface SearchRequest {
  embedding: number[];        // 768-dim vector (Jina v2 format)
  keywords: string;           // FTS5 query (use /keywords to generate)
  limit?: number;             // Default 10, max 50
  filters?: {
    chunk_types?: ('function' | 'class' | 'module' | 'readme' | 'terraform' | 'config' | 'other')[];
    repos?: string[];         // Filter by repo names
  };
}
```

**Response:**
```typescript
interface SearchResponse {
  results: {
    repo_name: string;
    file_path: string;
    content: string;
    language: string;
    chunk_type: string;
    line_start: number;
    line_end: number;
    score: number;
  }[];
  meta: {
    search_ms: number;
    vector_matches: number;
    keyword_matches: number;
  };
}
```

### GET /health

**Response:**
```typescript
interface HealthResponse {
  status: 'ok';
  db_chunks: number;
  db_repos: number;
  last_indexed: string | null;  // ISO timestamp
}
```

### GET /openapi.json

Returns OpenAPI 3.1 JSON specification. Always available.

### GET /docs

Swagger UI for interactive API documentation. **Non-prod environments only** (development, sandbox, staging).

In production, returns 404 to reduce attack surface.

---

## Database Schema

Create at `src/shared/schema.sql`:

```sql
-- Source table: stores code chunks and metadata
CREATE TABLE IF NOT EXISTS code_chunks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    repo_name TEXT NOT NULL,
    file_path TEXT NOT NULL,
    content TEXT NOT NULL,
    language TEXT,
    chunk_type TEXT,
    keywords TEXT,
    line_start INTEGER,
    line_end INTEGER,
    commit_sha TEXT,
    indexed_at TEXT
);

-- Vector index: sqlite-vec (768 dims for Jina v2)
CREATE VIRTUAL TABLE IF NOT EXISTS vec_chunks USING vec0(
    chunk_id INTEGER PRIMARY KEY,
    embedding FLOAT[768]
);

-- Keyword index: FTS5 (external content mode saves space)
CREATE VIRTUAL TABLE IF NOT EXISTS fts_chunks USING fts5(
    content,
    keywords,
    content='code_chunks',
    content_rowid='id',
    tokenize="unicode61"
);

-- Keep FTS5 in sync with inserts
CREATE TRIGGER IF NOT EXISTS code_chunks_ai AFTER INSERT ON code_chunks BEGIN
    INSERT INTO fts_chunks(rowid, content, keywords) 
    VALUES (new.id, new.content, new.keywords);
END;

-- Keep FTS5 in sync with deletes (for delta re-indexing)
CREATE TRIGGER IF NOT EXISTS code_chunks_ad AFTER DELETE ON code_chunks BEGIN
    INSERT INTO fts_chunks(fts_chunks, rowid, content, keywords) 
    VALUES ('delete', old.id, old.content, old.keywords);
END;

-- Repository metadata
CREATE TABLE IF NOT EXISTS repos (
    name TEXT PRIMARY KEY,
    full_name TEXT,
    description TEXT,
    default_branch TEXT,
    topics TEXT,
    language TEXT,
    pushed_at TEXT,
    indexed_at TEXT,
    chunk_count INTEGER
);

-- Build tracking
CREATE TABLE IF NOT EXISTS build_info (
    id INTEGER PRIMARY KEY,
    started_at TEXT,
    completed_at TEXT,
    repos_processed INTEGER,
    chunks_created INTEGER,
    status TEXT
);

CREATE INDEX IF NOT EXISTS idx_chunks_repo ON code_chunks(repo_name);
CREATE INDEX IF NOT EXISTS idx_chunks_type ON code_chunks(chunk_type);
CREATE INDEX IF NOT EXISTS idx_repos_pushed ON repos(pushed_at);
```

---

## Hybrid Search (RRF) Query

70% vector weight, 30% keyword weight:

```sql
WITH vector_matches AS (
    SELECT chunk_id, row_number() OVER (ORDER BY distance) as rank_number
    FROM vec_chunks
    WHERE embedding MATCH ?1 AND k = 20
),
keyword_matches AS (
    SELECT rowid as chunk_id, row_number() OVER (ORDER BY rank) as rank_number
    FROM fts_chunks
    WHERE fts_chunks MATCH ?2
    LIMIT 20
)
SELECT c.repo_name, c.file_path, c.content, c.language, c.chunk_type,
    c.line_start, c.line_end,
    (COALESCE(1.0 / (60 + v.rank_number), 0.0) * 0.7 + 
     COALESCE(1.0 / (60 + k.rank_number), 0.0) * 0.3) AS score
FROM code_chunks c
LEFT JOIN vector_matches v ON c.id = v.chunk_id
LEFT JOIN keyword_matches k ON c.id = k.chunk_id
WHERE v.chunk_id IS NOT NULL OR k.chunk_id IS NOT NULL
ORDER BY score DESC
LIMIT ?3;
```

---

## Delta Indexing Logic

### last-run.json Format

```typescript
interface LastRun {
  timestamp: string;          // ISO timestamp of last run
  repos: {
    [repoName: string]: {
      indexedAt: string;      // When we indexed it
      pushedAt: string;       // GitHub pushed_at at index time (for reference)
      commitSha: string;      // Default branch commit SHA at index time
      treeSha: string;        // Git tree SHA (file content hash)
      chunkCount: number;
    };
  };
}
```

### Delta Detection Strategy

**Problem:** With 760 repos, using `pushedAt` causes false positives - any push to ANY branch marks repo as stale, but we only index the default branch.

**Solution:** Use GraphQL to batch-fetch commit SHA + tree SHA for all repos, compare against stored values.

| Approach | Stale Check API Calls | Precision |
|----------|----------------------|-----------|
| `pushedAt` (old) | 8 (list repos) | Low - any branch triggers |
| `commitSha` | 8 + 760 REST calls | High - default branch only |
| **GraphQL batch** | 8 + 8 GraphQL | High - 100 repos per query |

### GraphQL Query for Batch Repo Info

```graphql
query RepoCommitInfo($owner: String!) {
  organization(login: $owner) {
    repositories(first: 100, after: $cursor) {
      pageInfo { hasNextPage, endCursor }
      nodes {
        name
        defaultBranchRef {
          name
          target {
            oid  # commit SHA
            ... on Commit {
              tree { oid }  # tree SHA - changes only when files change
            }
          }
        }
      }
    }
  }
}
```

**Efficiency:** 760 repos = 8 GraphQL calls (vs 760 REST calls)

### Stale Detection Algorithm

```typescript
function isRepoStale(repo: RepoInfo, indexed: RepoIndexInfo | undefined): boolean {
  if (!indexed) return true;                    // New repo
  if (!indexed.treeSha) return true;            // Legacy entry without treeSha
  if (repo.treeSha !== indexed.treeSha) return true;  // Files changed
  return false;
}
```

**Tree SHA vs Commit SHA:**
- Commit SHA changes on any commit (even commit message edits, rebases)
- Tree SHA only changes when actual file content changes
- Tree SHA is more precise for detecting "do we need to re-index?"

---

## CLI Commands

### pnpm run index

```bash
# Delta index (default) - only changed repos
pnpm run index

# Full rebuild - all repos
pnpm run index --full

# Single repo
pnpm run index --repo ASU/eda-analytics-sync-flows

# Limit number of repos (for testing)
pnpm run index --limit 20
```

### pnpm run check-stale

```bash
# Check if any repos need re-indexing
pnpm run check-stale

# Output:
# ✓ 780 repos up to date
# ⚠ 20 repos need re-indexing:
#   - ASU/repo-1 (pushed 2h ago, indexed 1d ago)
#   - ASU/repo-2 (pushed 30m ago, indexed 1d ago)
#   ...
# Run `pnpm run index` to update.
```

### pnpm run deploy

```bash
# Deploy to sandbox (includes stale check)
pnpm run deploy:sandbox

# Deploy to production
pnpm run deploy:production

# If stale:
# ⚠ Warning: 20 repos are stale. Run `pnpm run index` first.
# Continue anyway? [y/N]
```

---

## Implementation Phases

### Phase 1: Package Setup + Indexer Foundation ✅ COMPLETE

**Goal:** Single package structure with CLI that can index a single repository.

**Status:** Complete. All components implemented and tested.

**Implemented:**
1. ✅ Package with package.json, tsconfig.json, vitest.config.ts
2. ✅ Shared types in `src/shared/types.ts`
3. ✅ Database schema (`src/shared/schema.sql`) and client (`src/indexer/db/client.ts`)
4. ✅ Code chunker via code-chopper (`src/indexer/chunking/code-chunker.ts`)
5. ✅ Custom TF-IDF keyword extractor (`src/indexer/keywords/extractor.ts`)
6. ✅ Embedder with Jina v2 (`src/indexer/embedding/embedder.ts`)
7. ✅ GitHub client (`src/indexer/github/client.ts`)
8. ✅ CLI with Commander (`src/indexer/cli.ts`)
9. ✅ Pipeline orchestration (`src/indexer/pipeline.ts`)

**Tests:** 56 unit tests + 8 integration tests passing

**Key Implementation Notes:**
- YAKE! replaced with custom TF-IDF due to ESM compatibility issues
- sqlite-vec requires `BigInt` for rowid in prepared statements
- sqlite-vec requires `Buffer.from(embedding.buffer)` for vector insertion
- Volta bypass needed due to Node version conflicts (`VOLTA_BYPASS=1`)

**Test Criteria:**
```bash
# Run tests
pnpm test:unit         # 56 tests
pnpm test:integration  # 8 tests (requires GH_TOKEN in .env.local)
```

---

### Phase 2: Full Indexer Pipeline ✅ COMPLETE

**Goal:** Batch indexing with delta detection and stale check.

**Status:** Complete. GraphQL-based delta detection for 760+ repo scale.

**Implemented:**
1. ✅ Delta tracking with `last-run.json` (`src/indexer/delta/tracker.ts`)
2. ✅ Batch indexing pipeline with progress events (`src/indexer/pipeline/batch.ts`)
3. ✅ CLI commands: `check-stale`, batch `index` with `--limit`/`--full`
4. ✅ GraphQL client for batch repo info (`src/indexer/github/graphql.ts`)
5. ✅ Tree SHA-based stale detection (precise file change detection)
6. ✅ Test separation: `pnpm test` (unit) vs `pnpm test:integration`
7. ✅ Rate limit detection in integration tests

**Key Implementation Notes:**
- GraphQL fetches 100 repos per query (760 repos = 8 API calls vs 760 REST calls)
- Tree SHA only changes when actual file content changes (more precise than commit SHA)
- `pushedAt` still stored for reference but not used for stale detection
- Legacy entries without `treeSha` treated as stale (one-time migration)
- ProgressEvent uses discriminated union for type safety

**Tests:** 88 unit tests + 11 integration tests

**Test Criteria:**
```bash
# Run unit tests (fast, no API)
pnpm test

# Run integration tests (requires GH_TOKEN, checks rate limit)
pnpm test:integration

# Check stale repos
GH_TOKEN=$GH_TOKEN pnpm run check-stale

# Batch index with limit
GH_TOKEN=$GH_TOKEN pnpm run index --limit 20

# Full rebuild
GH_TOKEN=$GH_TOKEN pnpm run index --full
```

---

### Phase 3: Server Module ✅ COMPLETE

**Goal:** Hono server with hybrid search that receives pre-computed vectors.

**Status:** Complete. All server components implemented with TDD.

**Implemented:**
1. ✅ Test fixtures with pre-computed embeddings (`src/server/__tests__/fixtures/`)
2. ✅ Read-only DB client (`src/server/services/db.ts`)
3. ✅ RRF search service with vector, keyword, and hybrid search (`src/server/services/search.ts`)
4. ✅ POST /search route with Zod validation (`src/server/routes/search.ts`)
5. ✅ GET /health route (`src/server/routes/health.ts`)
6. ✅ Zod input validation (768-dim embedding, keywords, filters)
7. ✅ Integration test with local dev server

**Tests:** 128 unit tests passing

**Test Criteria:**
```bash
# Run unit tests
pnpm test

# Start dev server
NODE_ENV=development DB_PATH=data/embeddings.db pnpm exec tsx src/server/index.ts

# Test search (with 768-dim embedding)
curl -X POST http://localhost:3000/search \
  -H "Content-Type: application/json" \
  -d '{"embedding": [0.01, ...768 values...], "keywords": "authentication", "limit": 5}'

# Test health
curl http://localhost:3000/health
```

---

### Phase 4: ZIP Deploy ✅ COMPLETE

**Goal:** Deploy server to Lambda via SST with bundled DB and shared resource tags.

**Status:** Complete. Lambda deployed and serving requests.

**Implemented:**
1. ✅ Added `@iden-components/shared` dependency for resource tags
2. ✅ Created `sst.config.ts` with Lambda function + API Gateway
3. ✅ Pre-deploy stale check command (`pnpm run pre-deploy`)
4. ✅ Docker-based native module cross-compilation in `hook.postbuild`
5. ✅ Deploy scripts: `deploy:sandbox`, `deploy:production`
6. ✅ Deployed to sandbox, endpoints verified working

**Files Created:**
- `sst.config.ts` - SST v3 configuration with resource tags and Docker postbuild

**Scripts Added:**
- `pre-deploy` - Verifies database exists, warns about stale repos
- `deploy:sandbox` - Runs pre-deploy + SST deploy to sandbox
- `deploy:production` - Runs pre-deploy (fails on stale) + SST deploy to production
- `sst:dev` - SST dev mode for local development

**Deployed Endpoints (sandbox):**
- API: `https://x6qxzhvbd9.execute-api.us-west-2.amazonaws.com`
- GET /health - Returns `{status: "ok", db_chunks, db_repos, last_indexed}`
- POST /search - Hybrid RRF search with pre-computed embedding
- **Baseline indexed repository:** `ASU/eda-analytics-sync-flows` (420 chunks)

**Deployment Lessons Learned:**

1. **Native Module Cross-Compilation:** SST's `nodejs.install` compiles on the local machine (macOS), not for Lambda target. Solution: Use `hook.postbuild` with Docker (`node:22-slim --platform linux/arm64`) to rebuild `better-sqlite3` and `sqlite-vec` for Linux ARM64.

2. **WAL Journal Mode:** SQLite WAL mode requires `-wal` and `-shm` files that can't be bundled. Lambda's read-only filesystem prevents creating them. Solution: Convert to DELETE mode before deployment with `PRAGMA journal_mode=DELETE; VACUUM;`

3. **Architecture Choice:** Using ARM64 (Graviton) for ~20% better price/performance. Requires explicitly installing `sqlite-vec-linux-arm64` platform package (only available from `0.1.7-alpha.1+`).

4. **File Bundling:** SST's `copyFiles` can be unreliable. Using `hook.postbuild` to manually copy files ensures they're included in the artifact.

**Resource Tags:**
Import shared resource tags from `@iden-components/shared` (same pattern as coolify app):
```typescript
const { resourceTags } = await import("@iden-components/shared");
// Applied to: Lambda function, API Gateway
```

**Deployment Commands:**
```bash
# Run all tests
pnpm test

# Pre-deploy check (verifies DB, warns about stale)
pnpm run pre-deploy

# Deploy to sandbox
pnpm run deploy:sandbox

# Deploy to production (fails if stale repos)
pnpm run deploy:production

# Test deployed endpoint
curl -X POST https://<api-url>/search \
  -H "Content-Type: application/json" \
  -d '{"embedding": [...], "keywords": "Peoplesoft", "limit": 5}'
```

### AWS Authentication

The deployment scripts handle AWS SSO login automatically via the root `.env` file.

**Prerequisites:**
1. Configure `AWS_PROFILE` in the root `.env` file (at repo root, not in apps/github-rag):
   ```bash
   # ../../.env (relative to apps/github-rag)
   AWS_PROFILE=your-sso-profile-name
   ```

2. Ensure your AWS SSO profile is configured in `~/.aws/config`

**How it works:**
- `aws:login` - Uses `dotenv -e ../../.env` to read `AWS_PROFILE` and runs `aws sso login`
- `deploy:*` - Chains: `aws:login` → `pre-deploy` → `copy-db` → `sst deploy`
- All SST/AWS commands use `dotenv -e ../../.env` to pick up the AWS_PROFILE

**Troubleshooting AWS Access:**
```bash
# Login to AWS manually
pnpm run aws:login

# Verify your profile is set correctly
cat ../../.env | grep AWS_PROFILE

# Test AWS access after login
npx dotenv-cli -e ../../.env -- aws sts get-caller-identity

# View Lambda logs
npx dotenv-cli -e ../../.env -- aws logs tail /aws/lambda/github-rag-<stage>-SearchFunctionFunction-* --since 10m
```

---

### Phase 5: GitHub Actions Pipeline ✅ COMPLETE

**Goal:** Automated daily builds and deployments.

**Status:** Complete. Workflow created and ready for use.

**Implemented:**
1. ✅ Created `.github/workflows/github-rag-deploy.yml`
2. ✅ OIDC authentication for AWS (no static credentials)
3. ✅ Stale check with pre-deploy command
4. ✅ Delta indexing with database caching between runs
5. ✅ Deployment verification via health check
6. ✅ QEMU setup for ARM64 cross-compilation on x86_64 GHA runners

**Workflow Features:**
- **Schedule:** Daily at 2 AM UTC (7 PM MST)
- **Manual trigger:** With stage selection and force full index option
- **Delta indexing:** Only re-indexes changed repos using tree SHA comparison
- **Database caching:** Embeddings database cached between runs for delta support
- **Stale check:** Warns on sandbox, fails on production
- **Verification:** Health check after deployment
- **ARM64 cross-compile:** Uses QEMU + Docker Buildx for native module builds

**Required Setup:**
```bash
# Repository Variables (Settings → Secrets and variables → Actions → Variables)
AWS_ACCOUNT_ID=<your-account-id>
AWS_ROLE_NAME=<your-oidc-role-name>

# Repository Secrets (Settings → Secrets and variables → Actions → Secrets)
GH_TOKEN=<github-pat-with-org-read>
```

**Usage:**
```bash
# Trigger manually
gh workflow run github-rag-deploy.yml -f stage=sandbox

# Trigger with full re-index
gh workflow run github-rag-deploy.yml -f stage=sandbox -f force_full_index=true

# View runs
gh run list --workflow=github-rag-deploy.yml
```

---

### Phase 6: E2E Smoke Tests ✅ COMPLETE

**Goal:** Add post-deployment verification tests to ensure deployed Lambda is operational.

**Status:** Complete. E2E smoke tests implemented and integrated into CI/CD workflow.

**Implemented:**
1. ✅ Created `vitest.e2e.config.ts` - Separate config for E2E tests
2. ✅ Added `test:e2e` script to package.json
3. ✅ Created `src/server/__tests__/smoke.e2e.test.ts` - E2E tests using real HTTP with `fetch()`
4. ✅ Updated GitHub Actions workflow to run E2E tests after deployment

**Files Created:**
- `vitest.e2e.config.ts` - E2E test configuration with 30s timeout for cold starts
- `src/server/__tests__/smoke.e2e.test.ts` - 5 smoke tests

**Files Modified:**
- `package.json` - Added `test:e2e` script
- `.github/workflows/github-rag-deploy.yml` - Replaced curl with structured E2E tests
- `AGENTS.md` - Updated test documentation

**Test Coverage:**
| Test | Purpose |
|------|---------|
| Health returns ok | Validates DB bundled, sqlite-vec loads |
| Health has indexed data | Verifies chunks/repos > 0 |
| Health responds < 5s | Catches cold start issues |
| Search with fixture | Proves hybrid search works end-to-end |
| Search validation errors | API rejects invalid requests (missing embedding, keywords, wrong dimensions) |

**Test Strategy:**
- Uses fixture embeddings from `test-data.json` for search test
- Tests against `API_URL` environment variable
- Uses real `fetch()` calls (not Hono's in-process testing)
- Verifies response shape, status codes, and latency thresholds

**Test Criteria:**
```bash
# Run E2E tests locally against deployed endpoint
API_URL=https://x6qxzhvbd9.execute-api.us-west-2.amazonaws.com pnpm test:e2e

# Tests verify:
# - Health endpoint returns 200 with status "ok"
# - Health endpoint shows db_chunks > 0 and db_repos > 0  
# - Search endpoint returns 200 with valid embedding
# - Search endpoint returns 400 for missing embedding/keywords
# - Search endpoint returns 400 for wrong embedding dimensions
# - Both endpoints respond within 5 seconds
```

**TDD Compliance:**
- RED: Tests failed correctly without API_URL environment variable
- GREEN: All 5 tests passed with deployed API URL
- REFACTOR: Extracted common patterns, added proper TypeScript types

---

## SST Configuration

```typescript
/// <reference path="./.sst/platform/config.d.ts" />

export default $config({
  app(input) {
    return {
      name: "github-rag",
      removal: input?.stage === "production" ? "retain" : "remove",
      protect: ["production"].includes(input?.stage),
      home: "aws",
      providers: { aws: { region: "us-west-2" } }
    };
  },
  async run() {
    const { resourceTags } = await import("@iden-components/shared");

    const searchFn = new sst.aws.Function("SearchFunction", {
      handler: "src/server/index.handler",
      runtime: "nodejs22.x",
      architecture: "arm64",  // ARM64 for better price/performance (~20% cheaper)
      memory: "1 GB",
      timeout: "30 seconds",
      dev: false,  // Disable Live mode - native modules don't work with it
      environment: {
        DB_PATH: "embeddings.db",
        NODE_ENV: "production"
      },
      nodejs: {
        install: ["better-sqlite3", "sqlite-vec"]  // Installed locally, rebuilt in postbuild
      },
      copyFiles: [
        { from: "data/embeddings.db", to: "embeddings.db" }
      ],
      hook: {
        // Rebuild native modules for Linux ARM64 using Docker
        postbuild: async (dir) => {
          const { copyFileSync, existsSync } = await import("fs");
          const { join } = await import("path");
          const { execSync } = await import("child_process");
          
          // 1. Copy the embeddings database (backup for copyFiles)
          const src = "data/embeddings.db";
          const dest = join(dir, "embeddings.db");
          if (existsSync(src)) {
            copyFileSync(src, dest);
            console.log(`postbuild: Copied ${src} to ${dest}`);
          }
          
          // 2. Rebuild native modules for Linux ARM64 using Docker
          // Must explicitly install sqlite-vec-linux-arm64 (only available from 0.1.7-alpha.1+)
          console.log("postbuild: Rebuilding native modules for Linux ARM64...");
          execSync(`
            docker run --rm --platform linux/arm64 \
              -v "${dir}:/build" \
              -w /build \
              node:22-slim \
              sh -c "
                rm -rf node_modules/better-sqlite3 node_modules/sqlite-vec node_modules/sqlite-vec-* && \
                npm install better-sqlite3@11.10.0 sqlite-vec@0.1.7-alpha.2 sqlite-vec-linux-arm64@0.1.7-alpha.2 --omit=dev && \
                echo 'Native modules rebuilt for Linux ARM64'
              "
          `, { stdio: "inherit", cwd: dir });
          console.log("postbuild: Native modules rebuilt successfully");
        }
      },
      tags: resourceTags
    });

    const api = new sst.aws.ApiGatewayV2("Api", {
      cors: {
        allowOrigins: ["*"],
        allowMethods: ["GET", "POST", "OPTIONS"],
        allowHeaders: ["Content-Type", "Authorization"]
      },
      tags: resourceTags
    });

    api.route("POST /search", searchFn.arn);
    api.route("POST /keywords", searchFn.arn);
    api.route("GET /health", searchFn.arn);
    api.route("GET /openapi.json", searchFn.arn);
    api.route("GET /docs", searchFn.arn);

    return { api: api.url, function: searchFn.name };
  }
});
```

**Key Configuration Notes:**

1. **`architecture: "arm64"`** - Using ARM64 (Graviton) for ~20% better price/performance. Requires explicit installation of `sqlite-vec-linux-arm64` platform package.

2. **`dev: false`** - Disables SST Live mode which doesn't work with native modules.

3. **`hook.postbuild`** - Uses Docker to rebuild `better-sqlite3` and `sqlite-vec` for Linux ARM64. This is required because `nodejs.install` compiles on the local machine.

4. **`sqlite-vec` ARM64 note** - The `sqlite-vec-linux-arm64` package is only available from version `0.1.7-alpha.1+`. Must explicitly install the platform package as npm doesn't auto-resolve it in Docker.

5. **`copyFiles`** - Bundles the embeddings database. Also copied in postbuild as backup.

6. **Database must be in DELETE journal mode** - WAL mode fails on Lambda's read-only filesystem. The `copy-db` script handles this automatically, but can be run manually:
   ```bash
   sqlite3 data/embeddings.db "PRAGMA journal_mode=DELETE; VACUUM;"
   ```

---

## Common Issues & Solutions

### SQLITE_CANTOPEN in Lambda

**Symptom:** `/health` and `/search` endpoints return 500 with `SQLITE_CANTOPEN` error.

**Root Cause:** SQLite database is in WAL (Write-Ahead Logging) mode. WAL mode requires creating `-wal` and `-shm` files at runtime, which fails on Lambda's read-only filesystem.

**Solution:** Convert database to DELETE journal mode before deployment:
```bash
sqlite3 data/embeddings.db "PRAGMA journal_mode=DELETE; VACUUM;"
```

**Prevention:** The `copy-db` script in `package.json` now runs this automatically before copying the database. Always use `pnpm run deploy:sandbox` or `pnpm run deploy:production` which include this step.

**Verification:** Check journal mode with:
```bash
sqlite3 data/embeddings.db "PRAGMA journal_mode;"
# Should output: delete
```

### E2E Tests Failing After Deployment

**Symptom:** E2E tests pass locally but fail after deployment with 500 errors.

**Checklist:**
1. Check if database was converted to DELETE journal mode (see above)
2. Verify Lambda logs for errors:
   ```bash
   npx dotenv-cli -e ../../.env -- aws logs tail /aws/lambda/github-rag-<stage>-SearchFunctionFunction-* --since 10m
   ```
3. Check if native modules were rebuilt for ARM64 (postbuild hook should run Docker)
4. Verify database file is included in Lambda package (check `.sst/artifacts/`)

### Native Module Cross-Compilation Issues

**Symptom:** Lambda crashes with module loading errors for `better-sqlite3` or `sqlite-vec`.

**Root Cause:** Native modules compiled on macOS don't work on Linux Lambda.

**Solution:** The `hook.postbuild` in `sst.config.ts` uses Docker to rebuild for Linux ARM64. Ensure Docker is running before deployment.

**Note:** Must explicitly install `sqlite-vec-linux-arm64` package (only available from `0.1.7-alpha.1+`) as npm doesn't auto-resolve platform packages in Docker.

---

## Cost Estimates

| Component | Monthly Cost |
|-----------|--------------|
| Lambda (10k queries, 200ms avg) | ~$0.50 |
| API Gateway (10k requests) | ~$0.04 |
| CloudWatch (minimal) | ~$0.50 |
| **Total** | **~$1-2/month** |

Reduced from ~$3/month due to:
- Smaller Lambda (no embedding model)
- Lower memory (1GB vs 2GB)
- Faster execution (no model inference)

---

## Verification Commands

```bash
# Phase 1: Single repo
GH_TOKEN=$GH_TOKEN pnpm run index --repo ASU/eda-analytics-sync-flows
sqlite3 data/embeddings.db "SELECT COUNT(*) FROM code_chunks"

# Phase 2: Batch + delta
GH_TOKEN=$GH_TOKEN pnpm run index --limit 20
pnpm run check-stale

# Phase 3: Local server
pnpm run dev:server
curl http://localhost:3000/health

# Phase 4: Deploy
pnpm run deploy:sandbox
curl https://<api-url>/health

# Phase 5: GHA
gh workflow run build-and-deploy.yml
```

---

## Future Optimizations

### AST-Aware Keyword Extraction
Current implementation uses plain TF-IDF on code text. Future enhancement:
1. Use Tree-sitter AST to extract function names, class names, imports
2. Split camelCase/snake_case identifiers
3. Filter language keywords (function, const, class)
4. Weight by structural importance (exports > locals)

This would improve search relevance for code queries.

---

## References

- [sqlite-vec](https://github.com/asg017/sqlite-vec) - Vector extension for SQLite
- [jina-embeddings-v2-base-code](https://huggingface.co/jinaai/jina-embeddings-v2-base-code) - Code embedding model
- [Transformers.js](https://huggingface.co/docs/transformers.js) - Run models in Node.js
- [code-chopper](https://github.com/context-labs/code-chopper) - Tree-sitter based chunking
- [YAKE!](https://github.com/LIAAD/yake) - Keyword extraction
- [SST v3](https://sst.dev) - Serverless infrastructure
- [Hono](https://hono.dev) - Lightweight web framework
