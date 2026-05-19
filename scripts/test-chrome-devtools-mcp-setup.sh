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
    grep -Fq -- "$needle" "$path" || fail "Expected '$needle' in $path"
}

assert_file_not_contains() {
    local path="$1"
    local needle="$2"
    if grep -Fq -- "$needle" "$path"; then
        fail "Did not expect '$needle' in $path"
    fi
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

assert_symlink_exists() {
    local path="$1"
    [[ -L "$path" ]] || fail "Expected $path to be a symlink"
}

run_setup() {
    local target="$1"
    shift
    if [[ "$target" == "copilot" ]]; then
        COPILOT_SKIP_JS_HOOK_SETUP=1 bash "$REPO_ROOT/setup.sh" "$target" "$@"
    else
        bash "$REPO_ROOT/setup.sh" "$target" "$@"
    fi
}

assert_default_args() {
    local path="$1"
    assert_file_contains "$path" 'chrome-devtools-mcp@latest'
    assert_file_contains "$path" '--no-usage-statistics'
    assert_file_contains "$path" '--headless'
    assert_file_not_contains "$path" '--auto-connect'
    assert_file_not_contains "$path" '--slim'
}

assert_headed_args() {
    local path="$1"
    assert_file_contains "$path" 'chrome-devtools-mcp@latest'
    assert_file_contains "$path" '--no-usage-statistics'
    assert_file_not_contains "$path" '--headless'
    assert_file_not_contains "$path" '--auto-connect'
    assert_file_not_contains "$path" '--slim'
}

assert_slim_args() {
    local path="$1"
    assert_file_contains "$path" 'chrome-devtools-mcp@latest'
    assert_file_contains "$path" '--no-usage-statistics'
    assert_file_contains "$path" '--headless'
    assert_file_contains "$path" '--slim'
    assert_file_not_contains "$path" '--auto-connect'
}

assert_auto_connect_args() {
    local path="$1"
    assert_file_contains "$path" 'chrome-devtools-mcp@latest'
    assert_file_contains "$path" '--no-usage-statistics'
    assert_file_contains "$path" '--auto-connect'
    assert_file_not_contains "$path" '--headless'
}

test_opencode() {
    local config_file="$HOME/.config/opencode/opencode.json"

    run_setup opencode
    assert_symlink_target "$config_file" "$REPO_ROOT/opencode.json"
    assert_file_contains "$REPO_ROOT/opencode.json" '"chrome-devtools-mcp": "deny"'

    run_setup opencode --with-chrome-devtools-mcp
    [[ ! -L "$config_file" ]] || fail "Expected managed OpenCode config file"
    assert_file_contains "$config_file" '"chrome-devtools-mcp": "allow"'
    assert_file_contains "$config_file" '"chrome-devtools"'
    assert_default_args "$config_file"

    run_setup opencode --with-chrome-devtools-mcp --chrome-devtools-headed
    assert_headed_args "$config_file"

    run_setup opencode --remove
    assert_symlink_target "$config_file" "$REPO_ROOT/opencode.json"

    run_setup opencode --with-chrome-devtools-mcp --chrome-devtools-slim
    assert_slim_args "$config_file"

    run_setup opencode --remove
    assert_symlink_target "$config_file" "$REPO_ROOT/opencode.json"

    run_setup opencode --with-chrome-devtools-mcp --chrome-devtools-auto-connect
    assert_auto_connect_args "$config_file"

    run_setup opencode --remove
    assert_symlink_target "$config_file" "$REPO_ROOT/opencode.json"
}

test_codex() {
    local skill_dir="$HOME/.codex/skills/chrome-devtools-mcp"
    local config_file="$HOME/.codex/config.toml"

    run_setup codex
    assert_not_exists "$skill_dir"
    rm -rf "$HOME/.codex"

    run_setup codex --with-chrome-devtools-mcp
    assert_symlink_exists "$skill_dir"
    assert_file_contains "$config_file" '[mcp_servers.chrome-devtools]'
    assert_default_args "$config_file"

    run_setup codex --with-chrome-devtools-mcp --chrome-devtools-headed
    assert_headed_args "$config_file"

    run_setup codex --remove
    [[ -f "$config_file" ]] || fail "Expected Codex base config to remain after remove"
    assert_file_not_contains "$config_file" '[mcp_servers.chrome-devtools]'

    run_setup codex --with-chrome-devtools-mcp --chrome-devtools-slim
    assert_slim_args "$config_file"

    run_setup codex --remove
    [[ -f "$config_file" ]] || fail "Expected Codex base config to remain after remove"
    assert_file_not_contains "$config_file" '[mcp_servers.chrome-devtools]'

    run_setup codex --with-chrome-devtools-mcp --chrome-devtools-auto-connect
    assert_auto_connect_args "$config_file"

    run_setup codex --remove
    [[ -f "$config_file" ]] || fail "Expected Codex base config to remain after remove"
    assert_file_not_contains "$config_file" '[mcp_servers.chrome-devtools]'
}

test_copilot() {
    local skill_dir="$HOME/.copilot/skills/chrome-devtools-mcp"
    local config_file="$HOME/.copilot/mcp-config.json"

    run_setup copilot
    assert_not_exists "$skill_dir"
    rm -rf "$HOME/.copilot"

    run_setup copilot --with-chrome-devtools-mcp
    assert_symlink_exists "$skill_dir"
    assert_file_contains "$config_file" '"chrome-devtools"'
    assert_default_args "$config_file"

    run_setup copilot --with-chrome-devtools-mcp --chrome-devtools-headed
    assert_headed_args "$config_file"

    run_setup copilot --remove
    assert_not_exists "$config_file"

    run_setup copilot --with-chrome-devtools-mcp --chrome-devtools-slim
    assert_slim_args "$config_file"

    run_setup copilot --remove
    assert_not_exists "$config_file"

    run_setup copilot --with-chrome-devtools-mcp --chrome-devtools-auto-connect
    assert_auto_connect_args "$config_file"

    run_setup copilot --remove
    assert_not_exists "$config_file"

    run_setup copilot --with-playwright-mcp
    assert_file_contains "$config_file" '"playwright-firefox"'
    run_setup copilot --with-playwright-mcp --with-chrome-devtools-mcp
    assert_file_contains "$config_file" '"playwright-firefox"'
    assert_file_contains "$config_file" '"chrome-devtools"'
    assert_default_args "$config_file"

    run_setup copilot --remove
    assert_not_exists "$config_file"
}

test_kiro() {
    local skill_dir="$HOME/.kiro/skills/chrome-devtools-mcp"
    local config_file="$HOME/.kiro/settings/mcp.json"

    run_setup kiro
    assert_not_exists "$skill_dir"
    rm -rf "$HOME/.kiro"

    run_setup kiro --with-chrome-devtools-mcp
    assert_symlink_exists "$skill_dir"
    assert_file_contains "$config_file" '"chrome-devtools"'
    assert_default_args "$config_file"

    run_setup kiro --with-chrome-devtools-mcp --chrome-devtools-headed
    assert_headed_args "$config_file"

    run_setup kiro --remove
    assert_not_exists "$config_file"

    run_setup kiro --with-chrome-devtools-mcp --chrome-devtools-slim
    assert_slim_args "$config_file"

    run_setup kiro --remove
    assert_not_exists "$config_file"

    run_setup kiro --with-chrome-devtools-mcp --chrome-devtools-auto-connect
    assert_auto_connect_args "$config_file"

    run_setup kiro --remove
    assert_not_exists "$config_file"
}

main() {
    temp_home="$(mktemp -d)"
    trap 'rm -rf "$temp_home"' EXIT

    export HOME="$temp_home"

    test_opencode
    test_codex
    test_copilot
    test_kiro

    echo "PASS: Chrome DevTools MCP setup smoke test"
}

main "$@"
