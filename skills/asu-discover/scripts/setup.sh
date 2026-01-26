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
