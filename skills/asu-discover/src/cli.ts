#!/usr/bin/env node
/**
 * ASU-Discover CLI
 * Semantic search across ASU GitHub repositories
 */

import { Command } from 'commander';
import { client, getCached, setCache, clearCache, getCacheStats } from './client/index.js';
import type { SearchResult, SearchOptions, ChunkType } from './types.js';

const program = new Command();

program
  .name('asu-discover')
  .description('Semantic search across 760+ ASU GitHub repositories')
  .version('2.0.0');

// Health check
program
  .command('health')
  .description('Check RAG backend health and index stats')
  .action(async () => {
    try {
      const health = await client.health();
      console.log(`Status: ${health.status}`);
      console.log(`Indexed: ${health.db_repos} repos, ${health.db_chunks} chunks`);
      console.log(`Last indexed: ${health.last_indexed}`);
      
      // Also show cache stats
      const cacheStats = getCacheStats();
      console.log(`\nCache: ${cacheStats.enabled ? 'enabled' : 'disabled'} (${cacheStats.entries} entries)`);
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
  .action(async (queryParts: string[], options) => {
    const query = queryParts.join(' ');
    await executeSearch(query, options);
  });

// Structured search
program
  .command('search')
  .description('Structured search with filters')
  .requiredOption('-q, --query <query>', 'Search query')
  .option('-l, --limit <n>', 'Maximum results', '10')
  .option('-t, --type <types...>', 'Chunk types (function, class, readme, terraform, config, module)')
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

// Cache stats
program
  .command('cache-stats')
  .description('Show cache statistics')
  .action(() => {
    const stats = getCacheStats();
    console.log(`Enabled: ${stats.enabled}`);
    console.log(`Entries: ${stats.entries}`);
    console.log(`Path: ${stats.path}`);
  });

interface CLIOptions {
  limit: string;
  cache?: boolean;
  json?: boolean;
  type?: string[];
  repo?: string[];
}

async function executeSearch(query: string, options: CLIOptions): Promise<void> {
  try {
    const searchOptions: SearchOptions = {
      limit: parseInt(options.limit, 10),
      chunkTypes: options.type as ChunkType[] | undefined,
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

    // Execute search
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

function formatResults(results: SearchResult[], meta: { search_ms: number; vector_matches: number; keyword_matches: number }): void {
  console.log(`Found ${results.length} results (${meta.search_ms}ms)`);
  console.log(`Vector: ${meta.vector_matches} | Keyword: ${meta.keyword_matches}\n`);
  console.log('─'.repeat(80));

  if (results.length === 0) {
    console.log('\nNo results found.');
    return;
  }

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
