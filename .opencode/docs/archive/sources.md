# Source Documents

Research and reference documents used in planning.

| ID | Title | Type | Date | Key Findings |
|----|-------|------|------|--------------|
| SRC-001 | GitHub RAG Backend Planning | reference | 2026-01-26 | Backend API contract (POST /search, POST /keywords, GET /health); Jina v2 768-dim embeddings; Hybrid RRF search (70% vector + 30% keyword); sqlite-vec + FTS5 storage |

## Document Details

### SRC-001: GitHub RAG Backend Planning

**File:** `2026-01-26-github-rag-backend-planning.md`

**Key excerpts:**
- API endpoints: `/search`, `/keywords`, `/health`, `/openapi.json`
- Embedding: `jinaai/jina-embeddings-v2-base-code` (768 dimensions)
- Search: Hybrid RRF with 70% vector weight, 30% keyword weight
- Backend URL: `https://x6qxzhvbd9.execute-api.us-west-2.amazonaws.com`

**Used in:**
- `.opencode/docs/PLANNING.md` - ASU-Discover RAG Client implementation
