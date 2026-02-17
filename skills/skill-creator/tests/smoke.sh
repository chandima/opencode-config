#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
VALIDATOR="$SKILL_DIR/scripts/validate-runtime.sh"

echo "=== Skill Creator Smoke Tests ==="
echo ""

# Test 1: Validator help should work
echo "Test 1: Validator help"
if bash "$VALIDATOR" --help > /dev/null 2>&1; then
    echo "  PASS: Help command works"
else
    echo "  FAIL: Help command failed"
    exit 1
fi

# Test 2: Current skill validates for opencode runtime
echo "Test 2: Validate skill-creator (opencode)"
if bash "$VALIDATOR" "$SKILL_DIR" --runtime opencode > /dev/null 2>&1; then
    echo "  PASS: Runtime validation passed"
else
    echo "  FAIL: Runtime validation failed"
    exit 1
fi

# Test 3: Invalid runtime should fail with clear message
echo "Test 3: Invalid runtime handling"
if bash "$VALIDATOR" "$SKILL_DIR" --runtime invalid > /tmp/skill-creator-smoke.out 2>&1; then
    echo "  FAIL: Invalid runtime unexpectedly succeeded"
    rm -f /tmp/skill-creator-smoke.out
    exit 1
else
    if grep -q "Invalid runtime" /tmp/skill-creator-smoke.out; then
        echo "  PASS: Invalid runtime rejected correctly"
    else
        echo "  WARN: Invalid runtime failed but expected message not found"
    fi
fi
rm -f /tmp/skill-creator-smoke.out

echo ""
echo "=== Smoke tests completed ==="
