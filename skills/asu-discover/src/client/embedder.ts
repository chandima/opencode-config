/**
 * Jina v2 Embedding Client
 * Uses Transformers.js to generate 768-dimensional embeddings locally
 */

import { pipeline, type FeatureExtractionPipeline } from '@huggingface/transformers';
import { existsSync, mkdirSync } from 'fs';
import { loadConfig } from './config.js';

let embedder: FeatureExtractionPipeline | null = null;
let isLoading = false;
let loadingPromise: Promise<FeatureExtractionPipeline> | null = null;

/**
 * Get or initialize the embedding model
 * Thread-safe - multiple concurrent calls will wait for the same load
 */
export async function getEmbedder(): Promise<FeatureExtractionPipeline> {
  if (embedder) return embedder;

  // If already loading, wait for that promise
  if (isLoading && loadingPromise) {
    return loadingPromise;
  }

  isLoading = true;
  loadingPromise = initializeEmbedder();

  try {
    embedder = await loadingPromise;
    return embedder;
  } finally {
    isLoading = false;
    loadingPromise = null;
  }
}

async function initializeEmbedder(): Promise<FeatureExtractionPipeline> {
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

  const model = await pipeline(
    'feature-extraction',
    config.model.name,
    { dtype: 'fp32' }
  );

  console.error('Embedding model loaded.');
  return model;
}

/**
 * Generate embedding for text
 * Returns normalized 768-dimensional vector
 */
export async function embed(text: string): Promise<number[]> {
  const model = await getEmbedder();
  const output = await model(text, { pooling: 'mean', normalize: true });
  return Array.from(output.data as Float32Array);
}

/**
 * Check if the model is already cached
 */
export function isModelCached(): boolean {
  const config = loadConfig();
  // Check if the model directory exists and has content
  if (!existsSync(config.model.cache_dir)) {
    return false;
  }
  // A more thorough check would look for specific model files,
  // but this is a reasonable approximation
  return true;
}

/**
 * Reset the embedder (useful for testing)
 */
export function resetEmbedder(): void {
  embedder = null;
  isLoading = false;
  loadingPromise = null;
}
