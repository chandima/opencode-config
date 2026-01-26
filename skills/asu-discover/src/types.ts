/**
 * ASU-Discover RAG Client Types
 * Matches the GitHub RAG Backend API contract
 */

// API Request/Response Types

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

export type ChunkType = 
  | 'function' 
  | 'class' 
  | 'module' 
  | 'readme' 
  | 'terraform' 
  | 'config' 
  | 'other';

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

// Configuration Types

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

// Search Options (client-side)

export interface SearchOptions {
  limit?: number;
  chunkTypes?: ChunkType[];
  repos?: string[];
}
