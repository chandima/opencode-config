/**
 * Integration Tests
 * Tests against the deployed GitHub RAG API
 * 
 * Run with: pnpm test:integration
 * Requires: network access, embedding model
 */

import { describe, it, expect, beforeAll } from 'vitest';
import { client } from '../src/client/index.js';

describe('integration tests', () => {
  beforeAll(async () => {
    // Verify API is available
    const health = await client.health();
    expect(health.status).toBe('ok');
  });

  describe('health endpoint', () => {
    it('returns valid response', async () => {
      const health = await client.health();
      
      expect(health.status).toBe('ok');
      expect(typeof health.db_chunks).toBe('number');
      expect(typeof health.db_repos).toBe('number');
      expect(health.db_chunks).toBeGreaterThan(0);
    });

    it('responds within 5 seconds', async () => {
      const start = Date.now();
      await client.health();
      const elapsed = Date.now() - start;
      
      expect(elapsed).toBeLessThan(5000);
    });
  });

  describe('search endpoint', () => {
    it('returns results for known query', async () => {
      const response = await client.search('TypeScript function', { limit: 5 });
      
      expect(response.results).toBeDefined();
      expect(Array.isArray(response.results)).toBe(true);
      expect(response.meta).toBeDefined();
      expect(response.meta.search_ms).toBeGreaterThan(0);
    });

    it('includes all required fields in results', async () => {
      const response = await client.search('code', { limit: 1 });
      
      if (response.results.length > 0) {
        const result = response.results[0];
        expect(result.repo_name).toBeDefined();
        expect(result.file_path).toBeDefined();
        expect(result.content).toBeDefined();
        expect(result.language).toBeDefined();
        expect(result.chunk_type).toBeDefined();
        expect(typeof result.line_start).toBe('number');
        expect(typeof result.line_end).toBe('number');
        expect(typeof result.score).toBe('number');
      }
    });

    it('respects limit option', async () => {
      const response = await client.search('test', { limit: 3 });
      
      expect(response.results.length).toBeLessThanOrEqual(3);
    });

    it('supports chunk type filtering', async () => {
      const response = await client.search('TypeScript function implementation', {
        limit: 5,
        chunkTypes: ['function'],
      });
      
      // All results should be functions (if any returned)
      for (const result of response.results) {
        expect(result.chunk_type).toBe('function');
      }
    });
  });

  describe('keywords endpoint', () => {
    it('extracts keywords from text', async () => {
      const response = await client.extractKeywords('How do I authenticate with EDNA?');
      
      expect(response.keywords).toBeDefined();
      expect(typeof response.keywords).toBe('string');
      expect(response.keywords.length).toBeGreaterThan(0);
      expect(response.extracted).toBeDefined();
      expect(Array.isArray(response.extracted)).toBe(true);
    });

    it('returns FTS5 query format', async () => {
      const response = await client.extractKeywords('EDNA authentication TypeScript');
      
      // Should contain OR for FTS5 query
      if (response.extracted.length > 1) {
        expect(response.keywords).toContain(' OR ');
      }
    });
  });
});
