#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== Skill Test Battery ==="

run_test() {
    local label="$1"
    local command="$2"
    echo
    echo "--- $label ---"
    if eval "$command"; then
        echo "[PASS] $label"
    else
        echo "[FAIL] $label"
        return 1
    fi
}

run_test "security-auditor smoke" "bash '$ROOT_DIR/skills/security-auditor/tests/smoke.sh'"
run_test "security-auditor evals" "bash '$ROOT_DIR/skills/security-auditor/tests/evals.sh'"
run_test "planning-doc evals" "bash '$ROOT_DIR/skills/planning-doc/tests/evals.sh'"

echo
echo "=== All test battery checks passed ==="
