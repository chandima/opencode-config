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
    assert_file_contains "$REPO_ROOT/opencode.json" '"playwright-mcp": "deny"'

    bash "$REPO_ROOT/setup.sh" opencode --with-playwright-mcp
    [[ ! -L "$HOME/.config/opencode/opencode.json" ]] || fail "Expected managed OpenCode config file"
    assert_file_contains "$HOME/.config/opencode/opencode.json" '"playwright-mcp": "allow"'
    assert_file_contains "$HOME/.config/opencode/opencode.json" '"playwright-firefox"'
    assert_file_contains "$HOME/.config/opencode/opencode.json" '"playwright-webkit"'
    assert_file_contains "$HOME/.config/opencode/opencode.json" '"playwright-msedge"'
    assert_file_contains "$HOME/.config/opencode/opencode.json" '"--headless"'

    bash "$REPO_ROOT/setup.sh" opencode --remove
    assert_symlink_target "$HOME/.config/opencode/opencode.json" "$REPO_ROOT/opencode.json"

    bash "$REPO_ROOT/setup.sh" opencode --with-playwright-mcp --playwright-headed
    assert_file_not_contains "$HOME/.config/opencode/opencode.json" '"--headless"'

    bash "$REPO_ROOT/setup.sh" opencode --remove
    assert_symlink_target "$HOME/.config/opencode/opencode.json" "$REPO_ROOT/opencode.json"

    bash "$REPO_ROOT/setup.sh" codex
    assert_not_exists "$HOME/.codex/skills/playwright-mcp"
    rm -rf "$HOME/.codex"

    bash "$REPO_ROOT/setup.sh" codex --with-playwright-mcp
    assert_symlink_exists "$HOME/.codex/skills/playwright-mcp"
    assert_file_contains "$HOME/.codex/config.toml" '[mcp_servers.playwright-firefox]'
    assert_file_contains "$HOME/.codex/config.toml" '[mcp_servers.playwright-webkit]'
    assert_file_contains "$HOME/.codex/config.toml" '[mcp_servers.playwright-msedge]'
    assert_file_contains "$HOME/.codex/config.toml" '--headless'

    bash "$REPO_ROOT/setup.sh" codex --remove
    assert_not_exists "$HOME/.codex/config.toml"

    bash "$REPO_ROOT/setup.sh" codex --with-playwright-mcp --playwright-headed
    assert_file_not_contains "$HOME/.codex/config.toml" '--headless'

    bash "$REPO_ROOT/setup.sh" codex --remove
    assert_not_exists "$HOME/.codex/config.toml"

    COPILOT_SKIP_JS_HOOK_SETUP=1 bash "$REPO_ROOT/setup.sh" copilot
    assert_not_exists "$HOME/.copilot/skills/playwright-mcp"
    rm -rf "$HOME/.copilot"

    COPILOT_SKIP_JS_HOOK_SETUP=1 bash "$REPO_ROOT/setup.sh" copilot --with-playwright-mcp
    assert_symlink_exists "$HOME/.copilot/skills/playwright-mcp"
    assert_file_contains "$HOME/.copilot/mcp-config.json" '"playwright-firefox"'
    assert_file_contains "$HOME/.copilot/mcp-config.json" '"playwright-webkit"'
    assert_file_contains "$HOME/.copilot/mcp-config.json" '"playwright-msedge"'
    assert_file_contains "$HOME/.copilot/mcp-config.json" '"--headless"'

    COPILOT_SKIP_JS_HOOK_SETUP=1 bash "$REPO_ROOT/setup.sh" copilot --remove
    assert_not_exists "$HOME/.copilot/mcp-config.json"

    COPILOT_SKIP_JS_HOOK_SETUP=1 bash "$REPO_ROOT/setup.sh" copilot --with-playwright-mcp --playwright-headed
    assert_file_not_contains "$HOME/.copilot/mcp-config.json" '"--headless"'

    COPILOT_SKIP_JS_HOOK_SETUP=1 bash "$REPO_ROOT/setup.sh" copilot --remove
    assert_not_exists "$HOME/.copilot/mcp-config.json"

    bash "$REPO_ROOT/setup.sh" kiro
    assert_not_exists "$HOME/.kiro/skills/playwright-mcp"
    rm -rf "$HOME/.kiro"

    bash "$REPO_ROOT/setup.sh" kiro --with-playwright-mcp
    assert_symlink_exists "$HOME/.kiro/skills/playwright-mcp"
    assert_file_contains "$HOME/.kiro/settings/mcp.json" '"playwright-firefox"'
    assert_file_contains "$HOME/.kiro/settings/mcp.json" '"playwright-webkit"'
    assert_file_contains "$HOME/.kiro/settings/mcp.json" '"playwright-msedge"'
    assert_file_contains "$HOME/.kiro/settings/mcp.json" '"--headless"'

    bash "$REPO_ROOT/setup.sh" kiro --remove
    assert_not_exists "$HOME/.kiro/settings/mcp.json"

    bash "$REPO_ROOT/setup.sh" kiro --with-playwright-mcp --playwright-headed
    assert_file_not_contains "$HOME/.kiro/settings/mcp.json" '"--headless"'

    bash "$REPO_ROOT/setup.sh" kiro --remove
    assert_not_exists "$HOME/.kiro/settings/mcp.json"

    echo "PASS: Playwright MCP setup smoke test"
}

main "$@"
