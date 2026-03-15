#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOTIFY_SCRIPT="$SCRIPT_DIR/../ntfy_notify.sh"

PASS=0
FAIL=0

pass() {
    PASS=$((PASS + 1))
    echo "  ✓ $1"
}

fail() {
    FAIL=$((FAIL + 1))
    echo "  ✗ $1" >&2
}

echo "Copilot ntfy_notify.sh smoke tests"
echo "==================================="

# --- Prerequisites ---
[[ -f "$NOTIFY_SCRIPT" ]] || { echo "FATAL: Script not found: $NOTIFY_SCRIPT"; exit 1; }
[[ -x "$NOTIFY_SCRIPT" ]] || { echo "FATAL: Script not executable: $NOTIFY_SCRIPT"; exit 1; }
command -v jq &>/dev/null || { echo "FATAL: jq not installed"; exit 1; }

# Use a fake curl to avoid real network calls
FAKE_BIN="$(mktemp -d)"
trap 'rm -rf "$FAKE_BIN"' EXIT

cat > "$FAKE_BIN/curl" <<'FAKECURL'
#!/usr/bin/env bash
# Capture what would be sent and exit successfully
echo "CURL_CALLED"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -H) echo "HEADER: $2"; shift 2 ;;
        -d) echo "BODY: $2"; shift 2 ;;
        *)  echo "ARG: $1"; shift ;;
    esac
done
FAKECURL
chmod +x "$FAKE_BIN/curl"

run_notify() {
    local input="$1"
    echo "$input" | PATH="$FAKE_BIN:$PATH" bash "$NOTIFY_SCRIPT" 2>/dev/null
}

# --- Test 1: agentStop payload (no reason field) ---
echo ""
echo "Test 1: agentStop payload"
output="$(run_notify '{"timestamp":1704614800000,"cwd":"/Users/test/myproject"}')"
if echo "$output" | grep -q 'Title: Copilot CLI: myproject'; then
    pass "Title includes project name"
else
    fail "Title should include project name, got: $output"
fi
if echo "$output" | grep -q 'BODY: Task complete'; then
    pass "Body is 'Task complete' for agentStop"
else
    fail "Body should be 'Task complete', got: $output"
fi

# --- Test 2: sessionEnd with reason=complete ---
echo ""
echo "Test 2: sessionEnd (complete)"
output="$(run_notify '{"timestamp":1704618000000,"cwd":"/path/to/project","reason":"complete"}')"
if echo "$output" | grep -q 'BODY: Session completed'; then
    pass "Body reflects 'complete' reason"
else
    fail "Body should be 'Session completed', got: $output"
fi

# --- Test 3: sessionEnd with reason=error ---
echo ""
echo "Test 3: sessionEnd (error)"
output="$(run_notify '{"timestamp":1704618000000,"cwd":"/path/to/project","reason":"error"}')"
if echo "$output" | grep -q 'BODY: Session ended with error'; then
    pass "Body reflects 'error' reason"
else
    fail "Body should be 'Session ended with error', got: $output"
fi

# --- Test 4: sessionEnd with reason=timeout ---
echo ""
echo "Test 4: sessionEnd (timeout)"
output="$(run_notify '{"timestamp":1704618000000,"cwd":"/path/to/project","reason":"timeout"}')"
if echo "$output" | grep -q 'BODY: Session timed out'; then
    pass "Body reflects 'timeout' reason"
else
    fail "Body should be 'Session timed out', got: $output"
fi

# --- Test 5: Empty input exits cleanly ---
echo ""
echo "Test 5: Empty input"
echo '' | PATH="$FAKE_BIN:$PATH" bash "$NOTIFY_SCRIPT" 2>/dev/null
if [[ $? -eq 0 ]]; then
    pass "Empty input exits 0"
else
    fail "Empty input should exit 0"
fi

# --- Test 6: Minimal JSON (no cwd) ---
echo ""
echo "Test 6: Minimal JSON"
output="$(run_notify '{}')"
if echo "$output" | grep -q 'Title: Copilot CLI'; then
    pass "Title falls back to 'Copilot CLI' with no cwd"
else
    fail "Title should be 'Copilot CLI', got: $output"
fi

# --- Test 7: Env var overrides ---
echo ""
echo "Test 7: Env var overrides"
output="$(NTFY_TOPIC=custom-topic NTFY_URL=https://custom.ntfy.sh run_notify '{"timestamp":1,"cwd":"/x"}')"
if echo "$output" | grep -q 'https://custom.ntfy.sh/custom-topic'; then
    pass "NTFY_TOPIC and NTFY_URL env vars respected"
else
    fail "Env var overrides not applied, got: $output"
fi

# --- Test 8: Hook JSON is valid ---
echo ""
echo "Test 8: Hook config JSON"
HOOKS_JSON="$SCRIPT_DIR/../hooks/copilot-ntfy.json"
if [[ -f "$HOOKS_JSON" ]] && jq . "$HOOKS_JSON" >/dev/null 2>&1; then
    pass "copilot-ntfy.json is valid JSON"
else
    fail "copilot-ntfy.json missing or invalid"
fi
if jq -e '.hooks.agentStop' "$HOOKS_JSON" >/dev/null 2>&1; then
    pass "agentStop hook defined"
else
    fail "agentStop hook missing"
fi
if jq -e '.hooks.sessionEnd' "$HOOKS_JSON" >/dev/null 2>&1; then
    pass "sessionEnd hook defined"
else
    fail "sessionEnd hook missing"
fi

# --- Summary ---
echo ""
echo "==================================="
echo "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
echo "All tests passed!"
