#!/usr/bin/env bash
set -euo pipefail

# production-hardening / smoke test
#
# Validates:
# 1. SKILL.md exists and has valid frontmatter
# 2. Config files exist and are valid YAML (basic check)
# 3. scan.sh is executable and runs without error on a dummy project
# 4. No syntax errors in scripts

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

pass() { echo "  ✅ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL + 1)); }

echo "=== production-hardening smoke test ==="
echo "Skill dir: $SKILL_DIR"
echo ""

# 1. SKILL.md structure
echo "--- SKILL.md ---"
if [[ -f "$SKILL_DIR/SKILL.md" ]]; then
  pass "SKILL.md exists"
else
  fail "SKILL.md missing"
fi

# Check frontmatter has required fields
if head -20 "$SKILL_DIR/SKILL.md" | grep -q '^name:'; then
  pass "frontmatter has 'name'"
else
  fail "frontmatter missing 'name'"
fi

if head -20 "$SKILL_DIR/SKILL.md" | grep -q '^description:'; then
  pass "frontmatter has 'description'"
else
  fail "frontmatter missing 'description'"
fi

if head -20 "$SKILL_DIR/SKILL.md" | grep -q '^allowed-tools:'; then
  pass "frontmatter has 'allowed-tools'"
else
  fail "frontmatter missing 'allowed-tools'"
fi

if head -20 "$SKILL_DIR/SKILL.md" | grep -q '^context:'; then
  pass "frontmatter has 'context'"
else
  fail "frontmatter missing 'context'"
fi

# 2. Config files
echo ""
echo "--- Config files ---"
for f in anti-patterns.yaml libraries.yaml; do
  if [[ -f "$SKILL_DIR/config/$f" ]]; then
    pass "config/$f exists"
    # Basic YAML syntax: check for tabs (YAML doesn't allow tabs for indentation)
    if grep -Pn '\t' "$SKILL_DIR/config/$f" > /dev/null 2>&1; then
      fail "config/$f contains tabs (invalid YAML indentation)"
    else
      pass "config/$f has no tab indentation"
    fi
  else
    fail "config/$f missing"
  fi
done

# 3. Scripts
echo ""
echo "--- Scripts ---"
if [[ -f "$SKILL_DIR/scripts/scan.sh" ]]; then
  pass "scripts/scan.sh exists"

  # Check shebang
  if head -1 "$SKILL_DIR/scripts/scan.sh" | grep -q '#!/usr/bin/env bash'; then
    pass "scan.sh has proper shebang"
  else
    fail "scan.sh missing #!/usr/bin/env bash shebang"
  fi

  # Check set -euo pipefail
  if head -5 "$SKILL_DIR/scripts/scan.sh" | grep -q 'set -euo pipefail'; then
    pass "scan.sh has set -euo pipefail"
  else
    fail "scan.sh missing set -euo pipefail"
  fi

  # Make executable and test on dummy project
  chmod +x "$SKILL_DIR/scripts/scan.sh"

  TMPDIR_TEST=$(mktemp -d)
  mkdir -p "$TMPDIR_TEST/src"
  cat > "$TMPDIR_TEST/package.json" << 'EOF'
{
  "name": "test-project",
  "dependencies": {
    "axios": "^1.6.0"
  }
}
EOF
  cat > "$TMPDIR_TEST/src/client.ts" << 'EOF'
import axios from 'axios';
export const fetchData = () => axios.get('https://api.example.com/data');
EOF

  if "$SKILL_DIR/scripts/scan.sh" "$TMPDIR_TEST" > /dev/null 2>&1; then
    pass "scan.sh runs successfully on dummy project"
  else
    fail "scan.sh failed on dummy project"
  fi

  rm -rf "$TMPDIR_TEST"
else
  fail "scripts/scan.sh missing"
fi

# 4. Bash syntax check
echo ""
echo "--- Syntax check ---"
for script in "$SKILL_DIR/scripts/"*.sh; do
  if bash -n "$script" 2>/dev/null; then
    pass "$(basename "$script") syntax OK"
  else
    fail "$(basename "$script") has syntax errors"
  fi
done

# Summary
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
