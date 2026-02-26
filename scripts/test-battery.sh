#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── Options ───────────────────────────────────────────────────
FILTER=""        # skill name substring filter
JUNIT_OUT=""     # JUnit XML output path (optional)
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --filter)   FILTER="$2"; shift 2;;
        --junit)    JUNIT_OUT="$2"; shift 2;;
        --verbose)  VERBOSE=true; shift;;
        --help|-h)
            cat <<'EOF'
Usage: test-battery.sh [options]
  --filter <name>   Only run tests for skills matching <name>
  --junit <path>    Write JUnit XML results to <path>
  --verbose         Show test output even on pass
  --help            Show this help
EOF
            exit 0;;
        *) echo "Unknown argument: $1" >&2; exit 2;;
    esac
done

# ── Counters ──────────────────────────────────────────────────
total=0
passed=0
failed=0
skipped=0
fail_labels=()

# ── Test runner ───────────────────────────────────────────────
junit_cases=""

run_test() {
    local label="$1"
    local script="$2"

    # Apply filter
    if [[ -n "$FILTER" ]] && [[ "$label" != *"$FILTER"* ]]; then
        return 0
    fi

    total=$((total + 1))
    echo
    echo "--- $label ---"

    if [[ ! -f "$script" ]]; then
        echo "[SKIP] $label (script not found: $script)"
        skipped=$((skipped + 1))
        junit_cases+="    <testcase name=\"${label}\" classname=\"skills\"><skipped message=\"script not found\"/></testcase>\n"
        return 0
    fi

    local output
    local rc=0
    output="$(bash "$script" 2>&1)" || rc=$?

    if [[ $rc -eq 0 ]]; then
        echo "[PASS] $label"
        passed=$((passed + 1))
        if [[ "$VERBOSE" == "true" ]]; then
            echo "$output"
        fi
        junit_cases+="    <testcase name=\"${label}\" classname=\"skills\"/>\n"
    else
        echo "[FAIL] $label (exit code $rc)"
        echo "$output"
        failed=$((failed + 1))
        fail_labels+=("$label")
        local escaped_output
        escaped_output="$(echo "$output" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')"
        junit_cases+="    <testcase name=\"${label}\" classname=\"skills\"><failure message=\"exit code ${rc}\">${escaped_output}</failure></testcase>\n"
    fi
}

# ── Discover and run tests ────────────────────────────────────
echo "=== Skill Test Battery ==="

# Auto-discover all smoke.sh and evals.sh files
while IFS= read -r test_script; do
    # Extract skill name and test type from path: skills/<name>/tests/<type>.sh
    skill_name="$(echo "$test_script" | sed 's|^skills/||; s|/tests/.*||')"
    test_type="$(basename "$test_script" .sh)"
    run_test "${skill_name} ${test_type}" "$ROOT_DIR/$test_script"
done < <(find "$ROOT_DIR/skills" -path "*/tests/smoke.sh" -o -path "*/tests/evals.sh" | sort | sed "s|^$ROOT_DIR/||")

# ── Summary ───────────────────────────────────────────────────
echo
echo "========================================"
echo "Results: $passed passed, $failed failed, $skipped skipped ($total total)"
echo "========================================"

if [[ ${#fail_labels[@]} -gt 0 ]]; then
    echo "Failed:"
    for label in "${fail_labels[@]}"; do
        echo "  - $label"
    done
fi

# ── JUnit output ──────────────────────────────────────────────
if [[ -n "$JUNIT_OUT" ]]; then
    mkdir -p "$(dirname "$JUNIT_OUT")"
    cat > "$JUNIT_OUT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="skill-test-battery" tests="$total" failures="$failed" skipped="$skipped">
$(echo -e "$junit_cases")  </testsuite>
</testsuites>
EOF
    echo "JUnit results written to $JUNIT_OUT"
fi

if [[ $failed -gt 0 ]]; then
    exit 1
fi
