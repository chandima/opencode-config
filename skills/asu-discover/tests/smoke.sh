#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Smoke Test: asu-discover ==="
echo ""

# Ensure dependencies are installed
if [[ ! -d "$SKILL_DIR/node_modules" ]]; then
    echo "Installing dependencies..."
    (cd "$SKILL_DIR" && pnpm install --silent)
fi

# Test 1: Help command
echo "Test 1: Help command"
if "$SKILL_DIR/scripts/discover.sh" --help > /dev/null 2>&1; then
    echo "  ✓ Help command works"
else
    echo "  ✗ Help command failed"
    exit 1
fi

# Test 2: Health check (requires network)
echo "Test 2: Health check"
if "$SKILL_DIR/scripts/discover.sh" health > /dev/null 2>&1; then
    echo "  ✓ Health check passed"
else
    echo "  ✗ Health check failed (network issue or backend down?)"
    exit 1
fi

# Test 3: Cache stats
echo "Test 3: Cache stats"
if "$SKILL_DIR/scripts/discover.sh" cache-stats > /dev/null 2>&1; then
    echo "  ✓ Cache stats passed"
else
    echo "  ✗ Cache stats failed"
    exit 1
fi

# Test 4: Natural language search (requires network + model)
echo "Test 4: Natural language search"
echo "  (This test loads the embedding model - first run may be slow)"
if "$SKILL_DIR/scripts/discover.sh" ask "EDNA authorization" --limit 1 --json > /dev/null 2>&1; then
    echo "  ✓ Natural language search passed"
else
    echo "  ✗ Natural language search failed"
    exit 1
fi

# Test 5: Structured search
echo "Test 5: Structured search"
if "$SKILL_DIR/scripts/discover.sh" search --query "checkAccess" --limit 1 --json > /dev/null 2>&1; then
    echo "  ✓ Structured search passed"
else
    echo "  ✗ Structured search failed"
    exit 1
fi

# Test 6: Clear cache
echo "Test 6: Clear cache"
if "$SKILL_DIR/scripts/discover.sh" clear-cache > /dev/null 2>&1; then
    echo "  ✓ Cache clear passed"
else
    echo "  ✗ Cache clear failed"
    exit 1
fi

echo ""
echo "=== All smoke tests passed ==="
