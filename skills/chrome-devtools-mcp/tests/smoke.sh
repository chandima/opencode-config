#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_FILE="$SKILL_DIR/SKILL.md"
PASS=0
FAIL=0

pass() { ((PASS++)); echo "  ✅ $1"; }
fail() { ((FAIL++)); echo "  ❌ $1"; }

echo "=== chrome-devtools-mcp smoke tests ==="

echo "--- Frontmatter checks ---"
[[ -f "$SKILL_FILE" ]] && pass "SKILL.md exists" || fail "SKILL.md missing"
grep -q '^name: chrome-devtools-mcp$' "$SKILL_FILE" && pass "name matches directory" || fail "name mismatch"
grep -q 'DO NOT use for:' "$SKILL_FILE" && pass "negative triggers present" || fail "missing negative triggers"

echo "--- Self-containment checks ---"
if grep -qE '\.\./\.\.' "$SKILL_FILE"; then
    fail "contains ../../ path escape"
else
    pass "no path escapes in SKILL.md"
fi

echo "--- Reference checks ---"
for ref in \
    tool-inventory.md \
    ui-testing-recipes.md \
    performance-levers.md \
    live-session.md \
    lighthouse-and-traces.md \
    troubleshooting.md
do
    if [[ -f "$SKILL_DIR/references/$ref" ]]; then
        pass "reference exists: $ref"
    else
        fail "reference missing: $ref"
    fi
    if grep -Fq "references/$ref" "$SKILL_FILE"; then
        pass "SKILL links: $ref"
    else
        fail "SKILL missing link: $ref"
    fi
done

echo "--- Content checks ---"
for marker in \
    "Use This Skill or Another One?" \
    "60-Second Quickstart" \
    "Workflow Boundaries" \
    "Live-Session Guidance"
do
    grep -Fq "$marker" "$SKILL_FILE" && pass "section: $marker" || fail "missing section: $marker"
done

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
(( FAIL == 0 )) && exit 0 || exit 1
