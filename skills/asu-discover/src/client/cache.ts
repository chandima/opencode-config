/**
 * Result Cache
 * Lightweight JSON-based caching for search results
 */

import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs';
import { dirname } from 'path';
import { createHash } from 'crypto';
import { loadConfig } from './config.js';
import type { SearchResponse, SearchOptions } from '../types.js';

interface CacheEntry {
  query: string;
  options: string;
  response: SearchResponse;
  timestamp: number;
}

interface CacheData {
  version: number;
  entries: Record<string, CacheEntry>;
}

const CACHE_VERSION = 1;
const MAX_ENTRIES = 100;

/**
 * Generate cache key from query and options
 */
function getCacheKey(query: string, options: SearchOptions): string {
  const data = JSON.stringify({ query, options });
  return createHash('md5').update(data).digest('hex');
}

/**
 * Load cache from disk
 */
function loadCache(): CacheData {
  const config = loadConfig();
  if (!config.cache.enabled) {
    return { version: CACHE_VERSION, entries: {} };
  }

  try {
    if (existsSync(config.cache.path)) {
      const content = readFileSync(config.cache.path, 'utf-8');
      const cache = JSON.parse(content) as CacheData;
      
      // Check version compatibility
      if (cache.version !== CACHE_VERSION) {
        return { version: CACHE_VERSION, entries: {} };
      }
      
      return cache;
    }
  } catch {
    // Corrupted cache, start fresh
  }
  
  return { version: CACHE_VERSION, entries: {} };
}

/**
 * Save cache to disk
 */
function saveCache(cache: CacheData): void {
  const config = loadConfig();
  if (!config.cache.enabled) return;

  const dir = dirname(config.cache.path);
  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true });
  }

  writeFileSync(config.cache.path, JSON.stringify(cache, null, 2));
}

/**
 * Get cached search result if available and not expired
 */
export function getCached(query: string, options: SearchOptions): SearchResponse | null {
  const config = loadConfig();
  if (!config.cache.enabled) return null;

  const cache = loadCache();
  const key = getCacheKey(query, options);
  const entry = cache.entries[key];

  if (!entry) return null;

  // Check TTL
  const ttlMs = config.cache.ttl_hours * 60 * 60 * 1000;
  if (Date.now() - entry.timestamp > ttlMs) {
    // Expired - remove entry
    delete cache.entries[key];
    saveCache(cache);
    return null;
  }

  return entry.response;
}

/**
 * Cache a search result
 */
export function setCache(query: string, options: SearchOptions, response: SearchResponse): void {
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

  // Prune old entries if over limit
  const entries = Object.entries(cache.entries);
  if (entries.length > MAX_ENTRIES) {
    entries.sort((a, b) => b[1].timestamp - a[1].timestamp);
    cache.entries = Object.fromEntries(entries.slice(0, MAX_ENTRIES));
  }

  saveCache(cache);
}

/**
 * Clear all cached results
 */
export function clearCache(): void {
  const config = loadConfig();
  const cache: CacheData = { version: CACHE_VERSION, entries: {} };
  
  const dir = dirname(config.cache.path);
  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true });
  }
  
  saveCache(cache);
}

/**
 * Get cache statistics
 */
export function getCacheStats(): { entries: number; path: string; enabled: boolean } {
  const config = loadConfig();
  const cache = loadCache();
  
  return {
    entries: Object.keys(cache.entries).length,
    path: config.cache.path,
    enabled: config.cache.enabled,
  };
}
