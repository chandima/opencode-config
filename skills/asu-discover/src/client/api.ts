/**
 * RAG API Client
 * Communicates with the GitHub RAG backend for semantic search
 */

import { loadConfig } from './config.js';
import { embed } from './embedder.js';
import type {
  KeywordsRequest,
  KeywordsResponse,
  SearchRequest,
  SearchResponse,
  HealthResponse,
  SearchOptions,
} from '../types.js';

/**
 * RAG API Client class
 * Handles communication with the GitHub RAG backend
 */
export class RAGClient {
  private config = loadConfig();

  /**
   * Check backend health and get index stats
   */
  async health(): Promise<HealthResponse> {
    const response = await fetch(`${this.config.api.url}/health`, {
      method: 'GET',
      signal: AbortSignal.timeout(this.config.api.timeout_ms),
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`Health check failed: ${response.status} - ${error}`);
    }

    return response.json() as Promise<HealthResponse>;
  }

  /**
   * Extract keywords from natural language text
   * Uses server-side TF-IDF extraction
   */
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

    return response.json() as Promise<KeywordsResponse>;
  }

  /**
   * Perform hybrid semantic + keyword search
   * Extracts keywords and generates embedding, then calls search API
   */
  async search(query: string, options: SearchOptions = {}): Promise<SearchResponse> {
    // Extract keywords and generate embedding in parallel
    const [keywordsResult, embedding] = await Promise.all([
      this.extractKeywords(query),
      embed(query),
    ]);

    return this.searchRaw(embedding, keywordsResult.keywords, options);
  }

  /**
   * Perform search with pre-computed embedding and keywords
   * Lower-level API for advanced use cases
   */
  async searchRaw(
    embedding: number[],
    keywords: string,
    options: SearchOptions = {}
  ): Promise<SearchResponse> {
    const request: SearchRequest = {
      embedding,
      keywords,
      limit: options.limit ?? this.config.defaults.limit,
    };

    if (options.chunkTypes || options.repos) {
      request.filters = {};
      if (options.chunkTypes) {
        request.filters.chunk_types = options.chunkTypes;
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

    return response.json() as Promise<SearchResponse>;
  }
}

// Default client instance
export const client = new RAGClient();
