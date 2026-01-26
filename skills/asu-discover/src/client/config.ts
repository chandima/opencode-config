/**
 * Configuration loader for asu-discover skill
 */

import { readFileSync, existsSync } from 'fs';
import { parse } from 'yaml';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import type { Config } from '../types.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
const CONFIG_PATH = join(__dirname, '../../config/settings.yaml');

let cachedConfig: Config | null = null;

/**
 * Load and parse configuration from settings.yaml
 * Caches the result for subsequent calls
 */
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

/**
 * Get the path to the config file
 */
export function getConfigPath(): string {
  return CONFIG_PATH;
}

/**
 * Reset cached config (useful for testing)
 */
export function resetConfig(): void {
  cachedConfig = null;
}
