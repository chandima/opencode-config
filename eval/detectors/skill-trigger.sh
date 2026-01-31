#!/usr/bin/env bash
#
# Skill Invocation Detector
# Analyzes OpenCode output to detect if/when skills were invoked
#

set -euo pipefail

# Check if output file provided
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <output_file>" >&2
    exit 1
fi

OUTPUT_FILE="$1"

# Skill load indicators
SKILL_INDICATORS=(
    "Loading skill"
    "Skill loaded"
    "Using skill"
    "@skill/"
    "skill:"
)

# Detect skill invocation
detect_skill() {
    local file="$1"
    local detected_skill=""
    
    # Check for skill loading patterns
    for indicator in "${SKILL_INDICATORS[@]}"; do
        if grep -q "$indicator" "$file" 2>/dev/null; then
            # Extract skill name if possible
            detected_skill=$(grep -oP "${indicator}\s*\K\S+" "$file" 2>/dev/null | head -1)
            if [[ -n "$detected_skill" ]]; then
                echo "$detected_skill"
                return 0
            fi
        fi
    done
    
    # Check for skill directory references
    if grep -q "skills/" "$file" 2>/dev/null; then
        detected_skill=$(grep -oP "skills/\K[^/]+" "$file" 2>/dev/null | head -1)
        if [[ -n "$detected_skill" ]]; then
            echo "$detected_skill"
            return 0
        fi
    fi
    
    # No skill detected
    return 1
}

# Run detection
if [[ -f "$OUTPUT_FILE" ]]; then
    if detect_skill "$OUTPUT_FILE"; then
        exit 0
    else
        exit 1
    fi
else
    echo "Error: Output file not found: $OUTPUT_FILE" >&2
    exit 1
fi
