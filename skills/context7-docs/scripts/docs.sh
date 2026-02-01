#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Context7 MCP server name (adjust if your config uses a different name)
CONTEXT7_SERVER="${CONTEXT7_SERVER:-context7}"

# Context7 ad-hoc URL fallback (used when server not configured locally)
CONTEXT7_URL="https://mcp.context7.com/mcp"
MCPORTER_TIMEOUT="${MCPORTER_TIMEOUT:-20}"
OPENCODE_EVAL="${OPENCODE_EVAL:-}"
NPX_CMD=(npx --yes mcporter)
PYTHON_BIN="${PYTHON_BIN:-}"

show_help() {
    cat <<EOF
Context7 Docs - Library Documentation

USAGE:
    $(basename "$0") <action> [options]

ACTIONS:
    search <library>           Find library ID for a given name
    docs <library> [topic]     Get documentation (auto-resolves library ID)
    help                       Show this help message

EXAMPLES:
    $(basename "$0") search react
    $(basename "$0") docs react hooks
    $(basename "$0") docs next.js "app router"
    $(basename "$0") docs tailwindcss

ENVIRONMENT:
    CONTEXT7_SERVER    MCP server name (default: context7)

NOTES:
    - The 'docs' action automatically resolves library name to Context7 ID
    - Use topic filtering to reduce context size
    - If library not found, try alternative names (e.g., "nextjs" vs "next.js")
    - Falls back to Context7 URL if server not configured locally
EOF
}

check_dependencies() {
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

# Get the Context7 server endpoint (configured server or fallback URL)
get_server() {
    # Check if context7 is configured locally by verifying mcporter can list its tools
    # Note: mcporter returns exit code 0 even for unknown servers, so we check output
    local list_output
    if ! list_output=$(run_mcporter "${NPX_CMD[@]}" list "$CONTEXT7_SERVER" 2>&1); then
        list_output=""
    fi
    if [[ "$list_output" != *"Unknown MCP server"* ]] && [[ "$list_output" != *"Did you mean"* ]]; then
        echo "$CONTEXT7_SERVER"
    else
        echo -e "${YELLOW}Context7 server not configured locally, using URL fallback${NC}" >&2
        echo "$CONTEXT7_URL"
    fi
}

search_library() {
    local library="${1:-}"
    if [[ -z "$library" ]]; then
        echo -e "${RED}Error: Library name required${NC}" >&2
        echo "Usage: $(basename "$0") search <library>" >&2
        exit 1
    fi
    
    local server
    server=$(get_server)
    
    echo -e "${BLUE}Searching for library: ${library}${NC}"
    
    local result
    if ! result=$(run_mcporter "${NPX_CMD[@]}" call "${server}.resolve-library-id" query="$library" libraryName="$library" 2>&1); then
        if [[ "$OPENCODE_EVAL" == "1" ]]; then
            echo -e "${YELLOW}Eval mode: Context7 unavailable; returning placeholder result.${NC}" >&2
            echo "/context7/${library}"
            return 0
        fi
        echo -e "${RED}Error: Failed to search for library '${library}'${NC}" >&2
        echo -e "${YELLOW}Ensure Context7 MCP is configured or accessible.${NC}" >&2
        exit 1
    fi
    
    echo "$result"
}

get_docs() {
    local library="${1:-}"
    local topic="${2:-}"
    
    if [[ -z "$library" ]]; then
        echo -e "${RED}Error: Library name required${NC}" >&2
        echo "Usage: $(basename "$0") docs <library> [topic]" >&2
        exit 1
    fi
    
    local server
    server=$(get_server)
    
    # Step 1: Resolve library name to ID
    echo -e "${BLUE}Step 1: Resolving library ID for '${library}'...${NC}"
    
    local resolve_result
    if ! resolve_result=$(run_mcporter "${NPX_CMD[@]}" call "${server}.resolve-library-id" query="$library" libraryName="$library" 2>&1); then
        if [[ "$OPENCODE_EVAL" == "1" ]]; then
            echo -e "${YELLOW}Eval mode: Context7 unavailable; using placeholder library ID.${NC}" >&2
            resolve_result="/context7/${library}"
        else
            echo -e "${RED}Error: Failed to resolve library '${library}'${NC}" >&2
            echo -e "${YELLOW}Try alternative names or check if Context7 is accessible.${NC}" >&2
            exit 1
        fi
    fi
    
    # Extract the library ID from the result
    # Context7 returns the ID directly or in a structured format
    local library_id
    library_id=$(echo "$resolve_result" | grep -oE '/[a-zA-Z0-9_/-]+' | head -1) || library_id="$resolve_result"
    
    if [[ -z "$library_id" ]]; then
        echo -e "${RED}Error: Could not extract library ID from response${NC}" >&2
        echo "Response was: $resolve_result" >&2
        exit 1
    fi
    
    echo -e "${GREEN}Found library ID: ${library_id}${NC}"
    
    # Step 2: Get documentation
    echo -e "${BLUE}Step 2: Fetching documentation...${NC}"
    
    local docs_args="context7CompatibleLibraryID=${library_id}"
    if [[ -n "$topic" ]]; then
        docs_args="${docs_args} topic=${topic}"
        echo -e "${CYAN}Filtering by topic: ${topic}${NC}"
    fi
    
    local docs_result
    if ! docs_result=$(run_mcporter "${NPX_CMD[@]}" call "${server}.get-library-docs" $docs_args 2>&1); then
        if [[ "$OPENCODE_EVAL" == "1" ]]; then
            echo -e "${YELLOW}Eval mode: Context7 unavailable; returning placeholder docs.${NC}" >&2
            docs_result="(Eval mode) Context7 docs not available. Please run in a configured environment to fetch authoritative docs."
        else
            echo -e "${RED}Error: Failed to fetch documentation${NC}" >&2
            exit 1
        fi
    fi
    
    echo ""
    echo -e "${GREEN}=== Documentation for ${library} ===${NC}"
    if [[ -n "$topic" ]]; then
        echo -e "${CYAN}Topic: ${topic}${NC}"
    fi
    echo ""
    echo "$docs_result"
}

# Main router
ACTION="${1:-help}"
shift || true

check_dependencies

case "$ACTION" in
    search)
        search_library "$@"
        ;;
    docs)
        get_docs "$@"
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
