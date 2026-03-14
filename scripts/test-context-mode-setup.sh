#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_file_contains() {
    local path="$1"
    local needle="$2"
    grep -Fq "$needle" "$path" || fail "Expected '$needle' in $path"
}

assert_not_exists() {
    local path="$1"
    [[ ! -e "$path" ]] || fail "Expected $path to be absent"
}

assert_symlink_target() {
    local path="$1"
    local expected="$2"
    [[ -L "$path" ]] || fail "Expected $path to be a symlink"
    local actual
    actual="$(readlink "$path")"
    [[ "$actual" == "$expected" ]] || fail "Expected $path -> $expected, got $actual"
}

make_fake_context_mode() {
    local fakebin="$1"
    mkdir -p "$fakebin"

    cat > "$fakebin/context-mode" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "--help" ]]; then
    exit 0
fi
exit 0
EOF
    chmod +x "$fakebin/context-mode"
}

run_phase() {
    local label="$1"
    shift
    echo "==> $label"
    "$@"
}

main() {
    temp_home="$(mktemp -d)"
    fakebin="$(mktemp -d)"

    trap 'rm -rf "$temp_home" "$fakebin"' EXIT

    make_fake_context_mode "$fakebin"

    export HOME="$temp_home"
    export PATH="$fakebin:$PATH"
    export CONTEXT_MODE_SKIP_INSTALL=1

    run_phase "baseline opencode setup" \
        bash "$REPO_ROOT/setup.sh" opencode
    assert_symlink_target "$HOME/.config/opencode/opencode.json" "$REPO_ROOT/opencode.json"

    run_phase "opencode context-mode overlay" \
        bash "$REPO_ROOT/setup.sh" opencode --with-context-mode
    [[ ! -L "$HOME/.config/opencode/opencode.json" ]] || fail "Expected managed OpenCode config file"
    assert_file_contains "$HOME/.config/opencode/opencode.json" '"context-mode"'
    assert_file_contains "$HOME/.config/opencode/opencode.json" '"mcp"'
    assert_file_contains "$HOME/.config/opencode/opencode.json" '"command": ['

    run_phase "remove opencode overlay" \
        bash "$REPO_ROOT/setup.sh" opencode --remove
    assert_symlink_target "$HOME/.config/opencode/opencode.json" "$REPO_ROOT/opencode.json"

    run_phase "codex context-mode setup" \
        bash "$REPO_ROOT/setup.sh" codex --with-context-mode
    assert_file_contains "$HOME/.codex/config.toml" '[mcp_servers.context-mode]'
    assert_file_contains "$HOME/.codex/config.toml" 'command = "context-mode"'

    run_phase "codex removal" \
        bash "$REPO_ROOT/setup.sh" codex --remove
    assert_not_exists "$HOME/.codex/config.toml"

    echo "PASS: context-mode setup smoke test"
}

main "$@"
