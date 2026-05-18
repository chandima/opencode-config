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

main() {
    temp_home="$(mktemp -d)"
    trap 'rm -rf "$temp_home"' EXIT

    export HOME="$temp_home"

    bash "$REPO_ROOT/setup.sh" opencode
    assert_symlink_target "$HOME/.config/opencode/opencode.json" "$REPO_ROOT/opencode.json"
    assert_file_contains "$REPO_ROOT/opencode.json" '"chrome-devtools-mcp": "deny"'

    bash "$REPO_ROOT/setup.sh" opencode --with-chrome-devtools-mcp
    [[ ! -L "$HOME/.config/opencode/opencode.json" ]] || fail "Expected managed OpenCode config file"
    assert_file_contains "$HOME/.config/opencode/opencode.json" '"chrome-devtools-mcp": "allow"'
    assert_file_contains "$HOME/.config/opencode/opencode.json" '"chrome-devtools"'
    assert_file_contains "$HOME/.config/opencode/opencode.json" '"chrome-devtools-mcp@latest"'
    assert_file_contains "$HOME/.config/opencode/opencode.json" '"--no-usage-statistics"'
    assert_file_not_contains "$HOME/.config/opencode/opencode.json" '"--auto-connect"'

    bash "$REPO_ROOT/setup.sh" opencode --remove
    assert_symlink_target "$HOME/.config/opencode/opencode.json" "$REPO_ROOT/opencode.json"

    bash "$REPO_ROOT/setup.sh" opencode --with-chrome-devtools-mcp --chrome-devtools-auto-connect
    assert_file_contains "$HOME/.config/opencode/opencode.json" '"--auto-connect"'

    bash "$REPO_ROOT/setup.sh" opencode --remove
    assert_symlink_target "$HOME/.config/opencode/opencode.json" "$REPO_ROOT/opencode.json"

    bash "$REPO_ROOT/setup.sh" codex
    assert_not_exists "$HOME/.codex/skills/chrome-devtools-mcp"
    rm -rf "$HOME/.codex"

    bash "$REPO_ROOT/setup.sh" codex --with-chrome-devtools-mcp
    assert_symlink_exists "$HOME/.codex/skills/chrome-devtools-mcp"
    assert_file_contains "$HOME/.codex/config.toml" '[mcp_servers.chrome-devtools]'
    assert_file_contains "$HOME/.codex/config.toml" '--no-usage-statistics'
    assert_file_not_contains "$HOME/.codex/config.toml" '--auto-connect'

    bash "$REPO_ROOT/setup.sh" codex --remove
    assert_not_exists "$HOME/.codex/config.toml"

    bash "$REPO_ROOT/setup.sh" codex --with-chrome-devtools-mcp --chrome-devtools-auto-connect
    assert_file_contains "$HOME/.codex/config.toml" '--auto-connect'

    bash "$REPO_ROOT/setup.sh" codex --remove
    assert_not_exists "$HOME/.codex/config.toml"

    COPILOT_SKIP_JS_HOOK_SETUP=1 bash "$REPO_ROOT/setup.sh" copilot
    assert_not_exists "$HOME/.copilot/skills/chrome-devtools-mcp"
    rm -rf "$HOME/.copilot"

    COPILOT_SKIP_JS_HOOK_SETUP=1 bash "$REPO_ROOT/setup.sh" copilot --with-chrome-devtools-mcp
    assert_symlink_exists "$HOME/.copilot/skills/chrome-devtools-mcp"
    assert_file_contains "$HOME/.copilot/mcp-config.json" '"chrome-devtools"'
    assert_file_contains "$HOME/.copilot/mcp-config.json" '"chrome-devtools-mcp@latest"'
    assert_file_contains "$HOME/.copilot/mcp-config.json" '"--no-usage-statistics"'
    assert_file_not_contains "$HOME/.copilot/mcp-config.json" '"--auto-connect"'

    COPILOT_SKIP_JS_HOOK_SETUP=1 bash "$REPO_ROOT/setup.sh" copilot --remove
    assert_not_exists "$HOME/.copilot/mcp-config.json"

    COPILOT_SKIP_JS_HOOK_SETUP=1 bash "$REPO_ROOT/setup.sh" copilot --with-chrome-devtools-mcp --chrome-devtools-auto-connect
    assert_file_contains "$HOME/.copilot/mcp-config.json" '"--auto-connect"'

    COPILOT_SKIP_JS_HOOK_SETUP=1 bash "$REPO_ROOT/setup.sh" copilot --remove
    assert_not_exists "$HOME/.copilot/mcp-config.json"

    bash "$REPO_ROOT/setup.sh" kiro
    assert_not_exists "$HOME/.kiro/skills/chrome-devtools-mcp"
    rm -rf "$HOME/.kiro"

    bash "$REPO_ROOT/setup.sh" kiro --with-chrome-devtools-mcp
    assert_symlink_exists "$HOME/.kiro/skills/chrome-devtools-mcp"
    assert_file_contains "$HOME/.kiro/settings/mcp.json" '"chrome-devtools"'
    assert_file_contains "$HOME/.kiro/settings/mcp.json" '"chrome-devtools-mcp@latest"'
    assert_file_contains "$HOME/.kiro/settings/mcp.json" '"--no-usage-statistics"'
    assert_file_not_contains "$HOME/.kiro/settings/mcp.json" '"--auto-connect"'

    bash "$REPO_ROOT/setup.sh" kiro --remove
    assert_not_exists "$HOME/.kiro/settings/mcp.json"

    bash "$REPO_ROOT/setup.sh" kiro --with-chrome-devtools-mcp --chrome-devtools-auto-connect
    assert_file_contains "$HOME/.kiro/settings/mcp.json" '"--auto-connect"'

    bash "$REPO_ROOT/setup.sh" kiro --remove
    assert_not_exists "$HOME/.kiro/settings/mcp.json"

    echo "PASS: Chrome DevTools MCP setup smoke test"
}

main "$@"
