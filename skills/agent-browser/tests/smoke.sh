#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
WRAPPER="$SKILL_DIR/scripts/agent-browser.sh"

echo "=== Agent Browser Skill Smoke Tests ==="
echo ""

echo "Test 1: Wrapper script is executable"
if [[ -x "$WRAPPER" ]]; then
    echo "  PASS: Wrapper is executable"
else
    echo "  FAIL: Wrapper is not executable"
    exit 1
fi

echo "Test 2: Runtime availability (agent-browser or npx)"
if command -v agent-browser >/dev/null 2>&1 || command -v npx >/dev/null 2>&1; then
    echo "  PASS: Runtime command available"
else
    echo "  FAIL: Neither agent-browser nor npx found"
    exit 1
fi

echo "Test 3: Help command"
if "$WRAPPER" --help >/dev/null 2>&1; then
    echo "  PASS: Help command works"
else
    echo "  WARN: Help command failed (may need package install or network for npx)"
fi

echo ""
echo "=== Smoke tests completed ==="
