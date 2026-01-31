#!/usr/bin/env bash
#
# Test Case Validator
# Validates test cases against the schema and framework requirements
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVAL_DIR="$(dirname "$SCRIPT_DIR")"
SCHEMA_FILE="$EVAL_DIR/framework/schema.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
VALID=0
INVALID=0

# Validate a single test case file
validate_test_case() {
    local file="$1"
    local filename
    filename=$(basename "$file")
    
    echo "Validating: $filename"
    
    # Check file exists and is readable
    if [[ ! -f "$file" ]]; then
        echo -e "${RED}  ✗ File not found${NC}"
        ((INVALID++))
        return 1
    fi
    
    # Check YAML syntax
    if ! yq e '.' "$file" > /dev/null 2>&1; then
        echo -e "${RED}  ✗ Invalid YAML syntax${NC}"
        ((INVALID++))
        return 1
    fi
    
    # Check required fields
    local id agent query
    id=$(yq e '.test_case.id' "$file" 2>/dev/null || echo "")
    agent=$(yq e '.test_case.agent' "$file" 2>/dev/null || echo "")
    query=$(yq e '.test_case.query' "$file" 2>/dev/null || echo "")
    
    if [[ -z "$id" || "$id" == "null" ]]; then
        echo -e "${RED}  ✗ Missing required field: id${NC}"
        ((INVALID++))
        return 1
    fi
    
    if [[ -z "$agent" || "$agent" == "null" ]]; then
        echo -e "${RED}  ✗ Missing required field: agent${NC}"
        ((INVALID++))
        return 1
    fi
    
    if [[ -z "$query" || "$query" == "null" ]]; then
        echo -e "${RED}  ✗ Missing required field: query${NC}"
        ((INVALID++))
        return 1
    fi
    
    # Validate agent value
    if [[ "$agent" != "my-plan" && "$agent" != "my-plan-exec" ]]; then
        echo -e "${YELLOW}  ⚠ Invalid agent value: $agent (expected: my-plan or my-plan-exec)${NC}"
    fi
    
    # Validate expected.skill_triggered
    local triggered
    triggered=$(yq e '.test_case.expected.skill_triggered' "$file" 2>/dev/null || echo "")
    if [[ -z "$triggered" || "$triggered" == "null" ]]; then
        echo -e "${YELLOW}  ⚠ Missing expected.skill_triggered (defaults to true)${NC}"
    elif [[ "$triggered" != "true" && "$triggered" != "false" ]]; then
        echo -e "${RED}  ✗ Invalid skill_triggered value: $triggered (must be true/false)${NC}"
        ((INVALID++))
        return 1
    fi
    
    # Check for skill name consistency
    local skill
    skill=$(yq e '.test_case.expected.skill' "$file" 2>/dev/null || echo "")
    if [[ -n "$skill" && "$skill" != "null" ]]; then
        # Validate skill name format
        if [[ ! "$skill" =~ ^[a-z0-9-]+$ ]]; then
            echo -e "${YELLOW}  ⚠ Skill name should use lowercase-kebab-case: $skill${NC}"
        fi
    fi
    
    echo -e "${GREEN}  ✓ Valid${NC}"
    ((VALID++))
    return 0
}

# Validate all test cases in a directory
validate_directory() {
    local dir="$1"
    
    if [[ ! -d "$dir" ]]; then
        echo "Directory not found: $dir"
        return 1
    fi
    
    echo ""
    echo "Scanning: $dir"
    echo "----------------------------------------"
    
    local found=0
    while IFS= read -r -d '' file; do
        validate_test_case "$file"
        found=1
    done < <(find "$dir" -type f \( -name "*.yaml" -o -name "*.yml" \) -print0 2>/dev/null)
    
    if [[ $found -eq 0 ]]; then
        echo "No test case files found"
    fi
}

# Main
main() {
    echo "Test Case Validator"
    echo "==================="
    echo ""
    
    # Check dependencies
    if ! command -v yq &> /dev/null; then
        echo "Error: yq is required but not installed"
        exit 1
    fi
    
    # Validate all test cases
    validate_directory "$EVAL_DIR/test-cases/my-plan"
    validate_directory "$EVAL_DIR/test-cases/my-plan-exec"
    
    # Summary
    echo ""
    echo "======================================"
    echo "Validation Summary"
    echo "======================================"
    echo -e "Valid:   ${GREEN}$VALID${NC}"
    echo -e "Invalid: ${RED}$INVALID${NC}"
    echo ""
    
    if [[ $INVALID -gt 0 ]]; then
        exit 1
    fi
    
    echo "All test cases are valid!"
    exit 0
}

main "$@"
