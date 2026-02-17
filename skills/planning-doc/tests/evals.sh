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

if grep -q "## Error Protocol" "$SKILL_MD" && grep -q "three-strike" "$SKILL_MD"; then
    pass "skill includes three-strike error protocol guidance"
else
    fail "skill missing three-strike error protocol guidance"
fi

if grep -q "resumed session" "$SKILL_MD" && grep -q "git diff --stat" "$SKILL_MD"; then
    pass "skill includes resumed-session recovery guidance"
else
    fail "skill missing resumed-session recovery guidance"
fi

if grep -q "## Anti-patterns to Avoid" "$SKILL_MD"; then
    pass "skill includes anti-pattern section"
else
    fail "skill missing anti-pattern section"
fi

if grep -q "## SESSION RECOVERY" "$TEMPLATE_MD"; then
    pass "template includes SESSION RECOVERY section"
else
    fail "template missing SESSION RECOVERY section"
fi

if grep -q "## ERRORS ENCOUNTERED" "$TEMPLATE_MD"; then
    pass "template includes ERRORS ENCOUNTERED section"
else
    fail "template missing ERRORS ENCOUNTERED section"
fi

echo "Results: $passed passed, $failed failed"
if [[ $failed -gt 0 ]]; then
    exit 1
fi
