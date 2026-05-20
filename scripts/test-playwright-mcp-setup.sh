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

assert_server_args() {
    local path="$1"
    local kind="$2"
    local server="$3"
    shift 3
    python3 - "$path" "$kind" "$server" "$@" <<'PY'
import ast
import json
import re
import sys

path, kind, server, *expected = sys.argv[1:]
if kind == "toml":
    with open(path, "r", encoding="utf-8") as fh:
        content = fh.read()
    pattern = rf"^\[mcp_servers\.{re.escape(server)}\]\n(?:.*\n)*?args = (\[.*\])$"
    match = re.search(pattern, content, re.MULTILINE)
    if not match:
        raise SystemExit(f"Could not find args for {server} in {path}")
    actual = ast.literal_eval(match.group(1))
elif kind == "opencode":
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
    actual = data["mcp"][server]["command"]
    if actual and actual[0] == "npx":
        actual = actual[1:]
elif kind == "json":
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
    actual = data["mcpServers"][server]["args"]
else:
    raise SystemExit(f"Unknown config kind: {kind}")

if actual != expected:
    raise SystemExit(f"{server} args mismatch in {path}\nexpected: {expected}\nactual:   {actual}")
PY
}

assert_playwright_servers_present() {
    local path="$1"
    assert_file_contains "$path" 'playwright-firefox'
    assert_file_contains "$path" 'playwright-webkit'
    assert_file_contains "$path" 'playwright-msedge'
}

assert_playwright_mode() {
    local path="$1"
    local kind="$2"
    local caps="$3"
    local headed="$4"
    local isolated="$5"
    local output_dir="${6:-}"

    local -a firefox=(-y @playwright/mcp@latest --browser=firefox)
    local -a webkit=(-y @playwright/mcp@latest --browser=webkit)
    local -a msedge=(-y @playwright/mcp@latest --browser=msedge)

    if [[ "$headed" -eq 0 ]]; then
        firefox+=(--headless)
        webkit+=(--headless)
        msedge+=(--headless)
    fi

    firefox+=("--caps=$caps")
    webkit+=("--caps=$caps")
    msedge+=("--caps=$caps")

    if [[ "$isolated" -eq 1 ]]; then
        firefox+=(--isolated)
        webkit+=(--isolated)
        msedge+=(--isolated)
    fi

    if [[ -n "$output_dir" ]]; then
        firefox+=("--output-dir=$output_dir")
        webkit+=("--output-dir=$output_dir")
        msedge+=("--output-dir=$output_dir")
    fi

    assert_server_args "$path" "$kind" playwright-firefox "${firefox[@]}"
    assert_server_args "$path" "$kind" playwright-webkit "${webkit[@]}"
    assert_server_args "$path" "$kind" playwright-msedge "${msedge[@]}"
}

assert_default_args() {
    local path="$1"
    local kind="$2"
    assert_playwright_servers_present "$path"
    assert_playwright_mode "$path" "$kind" "testing" 0 0
}

assert_headed_args() {
    local path="$1"
    local kind="$2"
    assert_playwright_mode "$path" "$kind" "testing" 1 0
}

assert_caps_devtools_args() {
    local path="$1"
    local kind="$2"
    assert_playwright_mode "$path" "$kind" "testing,devtools" 0 0
}

assert_caps_storage_args() {
    local path="$1"
    local kind="$2"
    assert_playwright_mode "$path" "$kind" "testing,storage" 0 0
}

assert_caps_network_args() {
    local path="$1"
    local kind="$2"
    assert_playwright_mode "$path" "$kind" "testing,network" 0 0
}

assert_isolated_args() {
    local path="$1"
    local kind="$2"
    assert_playwright_mode "$path" "$kind" "testing" 0 1
}

assert_output_dir_args() {
    local path="$1"
    local kind="$2"
    local output_dir="$3"
    assert_playwright_mode "$path" "$kind" "testing" 0 0 "$output_dir"
}

assert_chrome_devtools_args() {
    local path="$1"
    local kind="$2"
    shift 2
    assert_server_args "$path" "$kind" chrome-devtools "$@"
}

test_opencode() {
    local config_file="$HOME/.config/opencode/opencode.json"
    local output_dir="$HOME/playwright outputs/opencode"

    run_setup opencode
    assert_symlink_target "$config_file" "$REPO_ROOT/opencode.json"
    assert_file_contains "$REPO_ROOT/opencode.json" '"playwright-mcp": "deny"'

    run_setup opencode --with-playwright-mcp
    [[ ! -L "$config_file" ]] || fail "Expected managed OpenCode config file"
    assert_file_contains "$config_file" '"playwright-mcp": "allow"'
    assert_default_args "$config_file" opencode

    run_setup opencode --with-playwright-mcp --playwright-headed
    assert_headed_args "$config_file" opencode

    run_setup opencode --remove
    assert_symlink_target "$config_file" "$REPO_ROOT/opencode.json"

    run_setup opencode --with-playwright-mcp --playwright-caps-devtools
    assert_caps_devtools_args "$config_file" opencode

    run_setup opencode --remove
    assert_symlink_target "$config_file" "$REPO_ROOT/opencode.json"

    run_setup opencode --with-playwright-mcp --playwright-caps-storage
    assert_caps_storage_args "$config_file" opencode

    run_setup opencode --remove
    assert_symlink_target "$config_file" "$REPO_ROOT/opencode.json"

    run_setup opencode --with-playwright-mcp --playwright-caps-network
    assert_caps_network_args "$config_file" opencode

    run_setup opencode --remove
    assert_symlink_target "$config_file" "$REPO_ROOT/opencode.json"

    run_setup opencode --with-playwright-mcp --playwright-isolated
    assert_isolated_args "$config_file" opencode

    run_setup opencode --remove
    assert_symlink_target "$config_file" "$REPO_ROOT/opencode.json"

    run_setup opencode --with-playwright-mcp --playwright-output-dir "$output_dir"
    assert_output_dir_args "$config_file" opencode "$output_dir"

    run_setup opencode --remove
    assert_symlink_target "$config_file" "$REPO_ROOT/opencode.json"
}

test_codex() {
    local skill_dir="$HOME/.codex/skills/playwright-mcp"
    local config_file="$HOME/.codex/config.toml"

    run_setup codex
    assert_not_exists "$skill_dir"
    rm -rf "$HOME/.codex"

    run_setup codex --with-playwright-mcp
    assert_symlink_exists "$skill_dir"
    assert_default_args "$config_file" toml

    run_setup codex --with-playwright-mcp --playwright-caps-devtools
    assert_caps_devtools_args "$config_file" toml

    run_setup codex --remove
    [[ -f "$config_file" ]] || fail "Expected Codex base config to remain after remove"
    assert_file_not_contains "$config_file" '[mcp_servers.playwright-firefox]'

    run_setup codex --with-playwright-mcp --playwright-caps-storage
    assert_caps_storage_args "$config_file" toml

    run_setup codex --remove
    [[ -f "$config_file" ]] || fail "Expected Codex base config to remain after remove"
    assert_file_not_contains "$config_file" '[mcp_servers.playwright-firefox]'

    run_setup codex --with-playwright-mcp --playwright-caps-network
    assert_caps_network_args "$config_file" toml

    run_setup codex --remove
    [[ -f "$config_file" ]] || fail "Expected Codex base config to remain after remove"
    assert_file_not_contains "$config_file" '[mcp_servers.playwright-firefox]'

    run_setup codex --with-playwright-mcp --playwright-isolated
    assert_isolated_args "$config_file" toml

    run_setup codex --remove
    [[ -f "$config_file" ]] || fail "Expected Codex base config to remain after remove"
    assert_file_not_contains "$config_file" '[mcp_servers.playwright-firefox]'
}

test_copilot() {
    local skill_dir="$HOME/.copilot/skills/playwright-mcp"
    local config_file="$HOME/.copilot/mcp-config.json"

    run_setup copilot
    assert_not_exists "$skill_dir"
    rm -rf "$HOME/.copilot"

    run_setup copilot --with-playwright-mcp
    assert_symlink_exists "$skill_dir"
    assert_default_args "$config_file" json

    run_setup copilot --with-playwright-mcp --playwright-headed
    assert_headed_args "$config_file" json

    run_setup copilot --remove
    assert_not_exists "$config_file"

    run_setup copilot --with-playwright-mcp --playwright-caps-devtools
    assert_caps_devtools_args "$config_file" json

    run_setup copilot --remove
    assert_not_exists "$config_file"

    run_setup copilot --with-playwright-mcp --playwright-caps-storage
    assert_caps_storage_args "$config_file" json

    run_setup copilot --remove
    assert_not_exists "$config_file"

    run_setup copilot --with-playwright-mcp --playwright-caps-network
    assert_caps_network_args "$config_file" json

    run_setup copilot --remove
    assert_not_exists "$config_file"

    run_setup copilot --with-playwright-mcp --with-chrome-devtools-mcp --playwright-caps-devtools --chrome-devtools-slim
    assert_caps_devtools_args "$config_file" json
    assert_chrome_devtools_args "$config_file" json -y chrome-devtools-mcp@latest --no-usage-statistics --headless --slim

    run_setup copilot --remove
    assert_not_exists "$config_file"
}

test_kiro() {
    local skill_dir="$HOME/.kiro/skills/playwright-mcp"
    local config_file="$HOME/.kiro/settings/mcp.json"

    run_setup kiro
    assert_not_exists "$skill_dir"
    rm -rf "$HOME/.kiro"

    run_setup kiro --with-playwright-mcp
    assert_symlink_exists "$skill_dir"
    assert_default_args "$config_file" json

    run_setup kiro --with-playwright-mcp --playwright-isolated
    assert_isolated_args "$config_file" json

    run_setup kiro --remove
    assert_not_exists "$config_file"

    run_setup kiro --with-playwright-mcp --playwright-caps-network
    assert_caps_network_args "$config_file" json

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

    echo "PASS: Playwright MCP setup smoke test"
}

main "$@"
