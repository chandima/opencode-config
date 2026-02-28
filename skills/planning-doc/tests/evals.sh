#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
SKILL_MD="$SKILL_DIR/SKILL.md"
TEMPLATE_MD="$SKILL_DIR/references/plan-template.md"

passed=0
failed=0

pass() {
    echo "[PASS] $1"
    passed=$((passed + 1))
}

fail() {
    echo "[FAIL] $1"
    failed=$((failed + 1))
}

echo "=== Planning Doc Eval Tests ==="

if grep -q "## Error Protocol" "$SKILL_MD" && grep -qi "three-strike" "$SKILL_MD"; then
    pass "skill includes three-strike error protocol guidance"
else
    fail "skill missing three-strike error protocol guidance"
fi

if grep -q "resumed session" "$SKILL_MD" && grep -q "git diff --stat" "$SKILL_MD"; then
    pass "skill includes resumed-session recovery guidance"
else
    fail "skill missing resumed-session recovery guidance"
fi

if grep -q "## Goal" "$TEMPLATE_MD"; then
    pass "template includes Goal section"
else
    fail "template missing Goal section"
fi

if grep -q "## Status Updates" "$TEMPLATE_MD"; then
    pass "template includes Status Updates section"
else
    fail "template missing Status Updates section"
fi

if grep -q "## Decisions" "$TEMPLATE_MD"; then
    pass "template includes Decisions section"
else
    fail "template missing Decisions section"
fi

echo "Results: $passed passed, $failed failed"
if [[ $failed -gt 0 ]]; then
    exit 1
fi
