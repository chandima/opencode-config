#!/usr/bin/env bash
#
# Tool Usage Detector
# Tracks which tools were invoked during agent execution
#

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <output_file>" >&2
    exit 1
fi

OUTPUT_FILE="$1"

# Tool patterns to detect
TOOL_PATTERNS=(
    "Bash("
    "Read("
    "Write("
    "Edit("
    "Glob("
    "Grep("
    "Fetch("
    "WebSearch("
)

# Detect tool usage
detect_tools() {
    local file="$1"
    local tools=()
    
    for pattern in "${TOOL_PATTERNS[@]}"; do
        if grep -q "$pattern" "$file" 2>/dev/null; then
            tool_name=$(echo "$pattern" | tr -d '()')
            tools+=("$tool_name")
        fi
    done
    
    # Output detected tools
    if [[ ${#tools[@]} -gt 0 ]]; then
        printf '%s\n' "${tools[@]}"
    fi
}

if [[ -f "$OUTPUT_FILE" ]]; then
    detect_tools "$OUTPUT_FILE"
else
    echo "Error: Output file not found: $OUTPUT_FILE" >&2
    exit 1
fi
