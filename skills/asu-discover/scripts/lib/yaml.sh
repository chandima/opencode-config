#!/usr/bin/env bash
# ==============================================================================
# YAML Parsing Library
# ==============================================================================
# Provides yq-based YAML parsing with sed fallback for environments
# where yq is not installed.
#
# Usage: Source this file and use yaml_get_* functions
# ==============================================================================

set -euo pipefail

# Track if we've warned about missing yq
YQ_WARNED="${YQ_WARNED:-}"

# ==============================================================================
# yq Detection
# ==============================================================================

# Check if yq is available
has_yq() {
    command -v yq &>/dev/null
}

# Warn once per session if yq is not installed
yaml_check_yq() {
    if ! has_yq && [[ -z "$YQ_WARNED" ]]; then
        echo "Note: Install yq for better YAML parsing: brew install yq" >&2
        export YQ_WARNED=1
    fi
}

# ==============================================================================
# Domain Field Accessors
# ==============================================================================

# Get a field from a domain definition
# Usage: yaml_get_domain_field <domain> <field>
# Example: yaml_get_domain_field "terraform" "triggers"
yaml_get_domain_field() {
    local domain="$1"
    local field="$2"
    local yaml_file="${DOMAINS_YAML:-}"
    
    [[ -z "$yaml_file" || ! -f "$yaml_file" ]] && return 1
    
    if has_yq; then
        # yq v4 syntax - handle both arrays and scalars
        local result
        result=$(yq ".domains.${domain}.${field}" "$yaml_file" 2>/dev/null)
        if [[ "$result" == "null" || -z "$result" ]]; then
            echo ""
        elif [[ "$result" == -* ]]; then
            # Array format (starts with -)
            yq ".domains.${domain}.${field} | .[]" "$yaml_file" 2>/dev/null | tr '\n' ' ' | xargs
        else
            echo "$result" | xargs
        fi
    else
        # Sed-based fallback (less reliable but works)
        sed -n "/^  ${domain}:/,/^  [a-z_-]*:/p" "$yaml_file" 2>/dev/null | \
            grep -E "^    ${field}:" | head -1 | \
            sed 's/.*: *//' | tr -d '[]"' | tr ',' ' ' | xargs
    fi
}

# Get triggers for a domain
# Usage: yaml_get_domain_triggers <domain>
yaml_get_domain_triggers() {
    yaml_get_domain_field "$1" "triggers"
}

# Get synonyms for a domain
# Usage: yaml_get_domain_synonyms <domain>
yaml_get_domain_synonyms() {
    yaml_get_domain_field "$1" "synonyms"
}

# Get repos for a domain
# Usage: yaml_get_domain_repos <domain>
yaml_get_domain_repos() {
    yaml_get_domain_field "$1" "repos"
}

# ==============================================================================
# Design Pattern Accessors
# ==============================================================================

# Get a field from a design pattern
# Usage: yaml_get_pattern_field <pattern> <field>
yaml_get_pattern_field() {
    local pattern="$1"
    local field="$2"
    local yaml_file="${DOMAINS_YAML:-}"
    
    [[ -z "$yaml_file" || ! -f "$yaml_file" ]] && return 1
    
    if has_yq; then
        yq -r ".design_patterns.\"${pattern}\".${field} // empty" "$yaml_file" 2>/dev/null
    else
        # Sed-based fallback
        sed -n "/^  ${pattern}:/,/^  [a-z_-]*:/p" "$yaml_file" 2>/dev/null | \
            grep -E "^    ${field}:" | head -1 | \
            sed 's/.*: *//'
    fi
}

# Get nested field from design pattern
# Usage: yaml_get_pattern_nested <pattern> <path>
# Example: yaml_get_pattern_nested "vault" "types.read.description"
yaml_get_pattern_nested() {
    local pattern="$1"
    local path="$2"
    local yaml_file="${DOMAINS_YAML:-}"
    
    [[ -z "$yaml_file" || ! -f "$yaml_file" ]] && return 1
    
    if has_yq; then
        yq -r ".design_patterns.\"${pattern}\".${path} // empty" "$yaml_file" 2>/dev/null
    else
        # Nested access not reliably supported in sed fallback
        echo ""
    fi
}

# ==============================================================================
# List Accessors
# ==============================================================================

# Get list of all domain names
# Usage: yaml_get_all_domains
yaml_get_all_domains() {
    local yaml_file="${DOMAINS_YAML:-}"
    
    [[ -z "$yaml_file" || ! -f "$yaml_file" ]] && return 1
    
    if has_yq; then
        yq -r '.domains | keys | .[]' "$yaml_file" 2>/dev/null
    else
        # Sed-based fallback - find domain definitions
        grep -E "^  [a-z_-]+:$" "$yaml_file" 2>/dev/null | \
            sed 's/://g' | tr -d ' ' | \
            grep -v -E "^(triggers|synonyms|repos|prefixes|description)$"
    fi
}

# Get list of all design pattern names
# Usage: yaml_get_all_patterns
yaml_get_all_patterns() {
    local yaml_file="${DOMAINS_YAML:-}"
    
    [[ -z "$yaml_file" || ! -f "$yaml_file" ]] && return 1
    
    if has_yq; then
        yq -r '.design_patterns | keys | .[]' "$yaml_file" 2>/dev/null
    else
        # Sed-based fallback
        sed -n '/^design_patterns:/,/^[a-z]/p' "$yaml_file" 2>/dev/null | \
            grep -E "^  [a-z_-]+:$" | sed 's/://g' | tr -d ' '
    fi
}

# ==============================================================================
# Search Configuration
# ==============================================================================

# Get search config value
# Usage: yaml_get_search_config <key>
yaml_get_search_config() {
    local key="$1"
    local yaml_file="${DOMAINS_YAML:-}"
    
    [[ -z "$yaml_file" || ! -f "$yaml_file" ]] && return 1
    
    if has_yq; then
        yq -r ".search.${key} // empty" "$yaml_file" 2>/dev/null
    else
        sed -n '/^search:/,/^[a-z]/p' "$yaml_file" 2>/dev/null | \
            grep -E "^  ${key}:" | head -1 | \
            sed 's/.*: *//'
    fi
}

# ==============================================================================
# Validation
# ==============================================================================

# Check if YAML file is valid
# Usage: yaml_validate <file>
yaml_validate() {
    local yaml_file="$1"
    
    [[ ! -f "$yaml_file" ]] && return 1
    
    if has_yq; then
        yq '.' "$yaml_file" &>/dev/null
        return $?
    else
        # Basic check - file exists and has content
        [[ -s "$yaml_file" ]]
        return $?
    fi
}
