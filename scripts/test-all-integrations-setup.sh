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

assert_not_exists() {
    local path="$1"
    [[ ! -e "$path" ]] || fail "Expected $path to be absent"
}

assert_file_not_contains() {
    local path="$1"
    local needle="$2"
    if grep -Fq -- "$needle" "$path"; then
        fail "Did not expect '$needle' in $path"
    fi
}

assert_symlink_exists() {
    local path="$1"
    [[ -L "$path" ]] || fail "Expected $path to be a symlink"
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

make_fake_copilot() {
    local fakebin="$1"

    cat > "$fakebin/copilot" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
    plugin)
        case "${2:-}" in
            list|install|uninstall)
                exit 0
                ;;
        esac
        ;;
esac

exit 0
EOF
    chmod +x "$fakebin/copilot"
}

write_preexisting_mcp_configs() {
    mkdir -p "$HOME/.copilot" "$HOME/.kiro/settings"

    cat > "$HOME/.copilot/mcp-config.json" <<'EOF'
{
  "mcpServers": {
    "custom-preserved": {
      "type": "local",
      "command": "preserved-copilot"
    }
  }
}
EOF

    cat > "$HOME/.kiro/settings/mcp.json" <<'EOF'
{
  "mcpServers": {
    "custom-preserved": {
      "command": "preserved-kiro"
    }
  }
}
EOF
}

assert_all_integrations_installed() {
    [[ ! -L "$HOME/.config/opencode/opencode.json" ]] || fail "Expected managed OpenCode config file"
    assert_file_contains "$HOME/.config/opencode/opencode.json" '"context-mode"'
    assert_file_contains "$HOME/.config/opencode/opencode.json" '"playwright-firefox"'
    assert_file_contains "$HOME/.config/opencode/opencode.json" '"chrome-devtools"'
    assert_file_contains "$HOME/.config/opencode/opencode.json" '"playwright-mcp": "allow"'
    assert_file_contains "$HOME/.config/opencode/opencode.json" '"chrome-devtools-mcp": "allow"'

    assert_symlink_exists "$HOME/.codex/skills/playwright-mcp"
    assert_symlink_exists "$HOME/.codex/skills/chrome-devtools-mcp"
    assert_file_contains "$HOME/.codex/config.toml" '[mcp_servers.context-mode]'
    assert_file_contains "$HOME/.codex/config.toml" '[mcp_servers.playwright-firefox]'
    assert_file_contains "$HOME/.codex/config.toml" '[mcp_servers.chrome-devtools]'

    assert_symlink_exists "$HOME/.copilot/skills/playwright-mcp"
    assert_symlink_exists "$HOME/.copilot/skills/chrome-devtools-mcp"
    assert_file_contains "$HOME/.copilot/mcp-config.json" '"playwright-firefox"'
    assert_file_contains "$HOME/.copilot/mcp-config.json" '"chrome-devtools"'

    assert_symlink_exists "$HOME/.kiro/skills/playwright-mcp"
    assert_symlink_exists "$HOME/.kiro/skills/chrome-devtools-mcp"
    assert_file_contains "$HOME/.kiro/settings/mcp.json" '"context-mode"'
    assert_file_contains "$HOME/.kiro/settings/mcp.json" '"playwright-firefox"'
    assert_file_contains "$HOME/.kiro/settings/mcp.json" '"chrome-devtools"'
}

assert_all_integrations_removed() {
    assert_not_exists "$HOME/.config/opencode/opencode.json"
    assert_not_exists "$HOME/.codex/config.toml"
    assert_not_exists "$HOME/.copilot/mcp-config.json"
    assert_not_exists "$HOME/.kiro/settings/mcp.json"
}

main() {
    local temp_home
    local fakebin
    temp_home="$(mktemp -d)"
    fakebin="$(mktemp -d)"
    trap "rm -rf '$temp_home' '$fakebin'" EXIT

    make_fake_context_mode "$fakebin"
    make_fake_copilot "$fakebin"

    export HOME="$temp_home"
    export PATH="$fakebin:$PATH"
    export CONTEXT_MODE_SKIP_INSTALL=1
    export COPILOT_SKIP_JS_HOOK_SETUP=1

    bash "$REPO_ROOT/setup.sh" all --with-all-integrations

    assert_all_integrations_installed

    bash "$REPO_ROOT/setup.sh" all --remove

    assert_all_integrations_removed

    write_preexisting_mcp_configs

    bash "$REPO_ROOT/setup.sh" all --with-all-integrations

    assert_all_integrations_installed
    assert_file_contains "$HOME/.copilot/mcp-config.json" '"custom-preserved"'
    assert_file_contains "$HOME/.kiro/settings/mcp.json" '"custom-preserved"'

    bash "$REPO_ROOT/setup.sh" all --remove

    assert_not_exists "$HOME/.config/opencode/opencode.json"
    assert_not_exists "$HOME/.codex/config.toml"
    assert_file_contains "$HOME/.copilot/mcp-config.json" '"custom-preserved"'
    assert_file_not_contains "$HOME/.copilot/mcp-config.json" '"playwright-firefox"'
    assert_file_not_contains "$HOME/.copilot/mcp-config.json" '"chrome-devtools"'
    assert_file_contains "$HOME/.kiro/settings/mcp.json" '"custom-preserved"'
    assert_file_not_contains "$HOME/.kiro/settings/mcp.json" '"context-mode"'
    assert_file_not_contains "$HOME/.kiro/settings/mcp.json" '"playwright-firefox"'
    assert_file_not_contains "$HOME/.kiro/settings/mcp.json" '"chrome-devtools"'
    assert_not_exists "$HOME/.copilot/.opencode-config-backups/mcp-config.json"
    assert_not_exists "$HOME/.copilot/.opencode-config-backups/mcp-config.repo-managed"
    assert_not_exists "$HOME/.kiro/.opencode-config-backups/mcp.json"
    assert_not_exists "$HOME/.kiro/.opencode-config-backups/mcp.json.repo-managed"

    echo "PASS: all-integrations setup smoke test"
}

main "$@"
