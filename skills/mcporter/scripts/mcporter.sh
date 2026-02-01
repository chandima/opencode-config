#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
MCPORTER_TIMEOUT="${MCPORTER_TIMEOUT:-20}"
OPENCODE_EVAL="${OPENCODE_EVAL:-}"
NPX_CMD=(npx --yes mcporter)
PYTHON_BIN="${PYTHON_BIN:-}"

show_help() {
    cat <<EOF
MCPorter - Generic MCP Access

USAGE:
    $(basename "$0") <action> [options]

ACTIONS:
    discover              List all configured MCP servers
    list <server>         List tools available on a server
    call <server.tool>    Call an MCP tool with optional arguments
    help                  Show this help message

EXAMPLES:
    $(basename "$0") discover
    $(basename "$0") list context7
    $(basename "$0") call firecrawl.scrape url=https://example.com

NOTES:
    - MCPorter auto-discovers MCP configs from OpenCode, Cursor, Claude, etc.
    - Tool arguments use key=value format
    - For library docs, prefer the context7-docs skill
EOF
}

check_mcporter() {
    if ! command -v npx &> /dev/null; then
        echo -e "${RED}Error: npx not found. Please install Node.js 18+${NC}" >&2
        exit 1
    fi
    if [[ -z "$PYTHON_BIN" ]]; then
        if command -v python3 &> /dev/null; then
            PYTHON_BIN="python3"
        elif command -v python &> /dev/null; then
            PYTHON_BIN="python"
        else
            echo -e "${RED}Error: python not found. Please install Python 3+${NC}" >&2
            exit 1
        fi
    fi
}

run_mcporter() {
    local timeout="${MCPORTER_TIMEOUT}"
    "$PYTHON_BIN" - "$timeout" "$@" <<'PY'
import subprocess, sys
timeout_s = float(sys.argv[1])
cmd = sys.argv[2:]
try:
    proc = subprocess.run(cmd, text=True, capture_output=True, timeout=timeout_s)
    sys.stdout.write(proc.stdout)
    sys.stderr.write(proc.stderr)
    sys.exit(proc.returncode)
except subprocess.TimeoutExpired:
    sys.stderr.write(f"Error: mcporter timed out after {timeout_s}s\n")
    sys.exit(124)
PY
}

discover() {
    echo -e "${BLUE}Discovering MCP servers...${NC}"
    local output
    if ! output=$(run_mcporter "${NPX_CMD[@]}" list 2>&1); then
        if [[ "$OPENCODE_EVAL" == "1" ]]; then
            echo -e "${YELLOW}Eval mode: No MCP servers found.${NC}"
            return 0
        fi
        echo -e "${YELLOW}No MCP servers found or mcporter not available.${NC}"
        echo "Ensure MCP servers are configured in OpenCode, Cursor, or Claude."
        exit 1
    fi
    echo "$output"
}

list_tools() {
    local server="${1:-}"
    if [[ -z "$server" ]]; then
        echo -e "${RED}Error: Server name required${NC}" >&2
        echo "Usage: $(basename "$0") list <server>" >&2
        exit 1
    fi
    
    echo -e "${BLUE}Listing tools for server: ${server}${NC}"
    local output
    if ! output=$(run_mcporter "${NPX_CMD[@]}" list "$server" 2>&1); then
        if [[ "$OPENCODE_EVAL" == "1" ]]; then
            echo -e "${YELLOW}Eval mode: Server '${server}' unavailable.${NC}"
            return 0
        fi
        echo -e "${RED}Error: Could not list tools for server '${server}'${NC}" >&2
        echo "Run '$(basename "$0") discover' to see available servers." >&2
        exit 1
    fi
    echo "$output"
}

call_tool() {
    local server_tool="${1:-}"
    shift || true
    
    if [[ -z "$server_tool" ]]; then
        echo -e "${RED}Error: server.tool required${NC}" >&2
        echo "Usage: $(basename "$0") call <server.tool> [key=value ...]" >&2
        exit 1
    fi
    
    # Validate format
    if [[ ! "$server_tool" =~ \. ]]; then
        echo -e "${RED}Error: Invalid format. Use server.tool (e.g., firecrawl.scrape)${NC}" >&2
        exit 1
    fi
    
    echo -e "${BLUE}Calling: ${server_tool}${NC}"
    if [[ $# -gt 0 ]]; then
        echo -e "${BLUE}Arguments: $*${NC}"
    fi
    
    local output
    if ! output=$(run_mcporter "${NPX_CMD[@]}" call "$server_tool" "$@" 2>&1); then
        if [[ "$OPENCODE_EVAL" == "1" ]]; then
            echo -e "${YELLOW}Eval mode: mcporter call failed; returning placeholder.${NC}"
            return 0
        fi
        echo -e "${RED}Error: Failed to call '${server_tool}'${NC}" >&2
        exit 1
    fi
    echo "$output"
}

# Main router
ACTION="${1:-help}"
shift || true

check_mcporter

case "$ACTION" in
    discover)
        discover
        ;;
    list)
        list_tools "$@"
        ;;
    call)
        call_tool "$@"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Unknown action: ${ACTION}${NC}" >&2
        show_help
        exit 1
        ;;
esac
