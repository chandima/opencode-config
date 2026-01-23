#!/usr/bin/env bash
#
# discover.sh - ASU Domain Discovery with Smart Keyword Expansion
# Finds relevant code, repos, and patterns across ASU's GitHub org
#
# Features:
#   - Local SQLite index with FTS5 for fast repo discovery (Tier 1)
#   - Rate-limited code search with 24h caching (Tier 2)
#   - Domain taxonomy for intelligent query expansion
#   - Team prefix detection and filtering
#
# Usage: discover.sh <action> [options]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../config"
DATA_DIR="$SCRIPT_DIR/../data"
LIB_DIR="$SCRIPT_DIR/lib"
DOMAINS_FILE="$CONFIG_DIR/domains.yaml"

# Source database helpers
source "$LIB_DIR/db.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Defaults
ORG="ASU"
LIMIT=30
JSON_OUTPUT=false
EXPAND=true
VERBOSE=false
CACHED_ONLY=false
LOCAL_ONLY=false

usage() {
    cat << 'EOF'
Usage: discover.sh <action> [options]

ASU Domain Discovery - Smart search across 760+ ASU repositories

ACTIONS:
  search            Search repos and code with domain-aware expansion
  repos             Find repositories by domain or prefix
  code              Search code with rate limiting and caching
  context           Build context for an integration task
  patterns          Find integration patterns between systems
  expand            Show how a query would be expanded (debug)
  index             Manage the local repository index

INDEX SUBCOMMANDS:
  index build       Build full index from scratch (~30s)
  index refresh     Incremental update (repos changed since last run)
  index stats       Show index statistics
  index classify    Re-run domain classification

COMMON OPTIONS:
  --query QUERY     Search query (natural language or keywords)
  --domain DOMAIN   Filter to specific domain
  --prefix PREFIX   Filter by team prefix (crm, eadv, aiml, etc.)
  --language LANG   Filter by programming language
  --limit N         Maximum results (default: 30)
  --no-expand       Disable keyword expansion
  --local-only      Only search local index (no API calls)
  --cached-only     Only use cached code search results
  --json            Output in JSON format
  --verbose         Show debug information
  --help            Show this help message

EXAMPLES:
  # Search with automatic domain detection
  discover.sh search --query "PeopleSoft IB integration"
  
  # Search within a specific domain
  discover.sh search --query "get principal" --domain dpl
  
  # Find repos by team prefix
  discover.sh repos --prefix crm --limit 20
  
  # Rate-limited code search (checks cache first)
  discover.sh code --query "checkAccess" --language typescript
  
  # Build context for a task
  discover.sh context --query "sync employee data from PS to DPL"
  
  # Find integration patterns
  discover.sh patterns --source peoplesoft --target dpl
  
  # Build/refresh the local index
  discover.sh index build
  discover.sh index stats

DOMAINS:
  peoplesoft, edna, dpl, serviceauth, auth, identity, salesforce,
  ml, terraform, cicd, cloudflare, infoblox, aws, api

TEAM PREFIXES:
  crm (66), eadv (38), authn (15), aiml (12), edna (11), iden (10),
  infra, tf, dpl, ps, sf, cf, unity
EOF
    exit 0
}

error() { echo -e "${RED}Error: $1${NC}" >&2; exit 1; }
info() { echo -e "${BLUE}$1${NC}" >&2; }
success() { echo -e "${GREEN}$1${NC}" >&2; }
warn() { echo -e "${YELLOW}$1${NC}" >&2; }
debug() { [[ "$VERBOSE" == "true" ]] && echo -e "${CYAN}[debug] $1${NC}" >&2 || true; }

# Parse YAML - simple extraction
# Note: domains are under 'domains:' key with 2-space indent
yaml_get_domain_field() {
    local file="$1" domain="$2" field="$3"
    # Match from "  domain:" until next "  something:" at same level
    sed -n "/^  $domain:/,/^  [a-zA-Z]/p" "$file" 2>/dev/null | \
        sed -n "/^    $field:/,/^    [a-zA-Z]/p" 2>/dev/null | \
        grep "^      - " | \
        sed 's/^      - //' | \
        tr -d '"' | \
        head -20 || true
}

yaml_get_prefixes() {
    local file="$1" domain="$2"
    # Get prefixes line which is formatted as: prefixes: [a, b, c]
    sed -n "/^  $domain:/,/^  [a-zA-Z]/p" "$file" 2>/dev/null | \
        grep "prefixes:" | \
        sed 's/.*prefixes: *//' | \
        tr -d '[]' | \
        tr ',' '\n' | \
        tr -d ' ' || true
}

yaml_get_team_prefix_domain() {
    local file="$1" prefix="$2"
    grep "^  $prefix:" "$file" 2>/dev/null | awk '{print $2}' || true
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --query) QUERY="$2"; shift 2 ;;
            --domain) DOMAIN="$2"; shift 2 ;;
            --prefix) PREFIX="$2"; shift 2 ;;
            --source) SOURCE_DOMAIN="$2"; shift 2 ;;
            --target) TARGET_DOMAIN="$2"; shift 2 ;;
            --language) LANGUAGE="$2"; shift 2 ;;
            --limit) LIMIT="$2"; shift 2 ;;
            --no-expand) EXPAND=false; shift ;;
            --local-only) LOCAL_ONLY=true; shift ;;
            --cached-only) CACHED_ONLY=true; shift ;;
            --json) JSON_OUTPUT=true; shift ;;
            --verbose) VERBOSE=true; shift ;;
            --help) usage ;;
            *) shift ;;
        esac
    done
}

#
# Ensure index exists, auto-build if needed
#
ensure_index() {
    if ! db_exists; then
        warn "Index not found. Building automatically (this takes ~30 seconds)..."
        action_index_build
    fi
}

#
# Detect domains from query text
#
detect_domains() {
    local query="$1"
    local query_lower
    query_lower=$(echo "$query" | tr '[:upper:]' '[:lower:]')
    local detected=""
    
    # All known domains
    local all_domains="peoplesoft edna dpl serviceauth auth identity salesforce ml terraform cicd cloudflare infoblox aws api"
    
    for domain in $all_domains; do
        local triggers
        triggers=$(yaml_get_domain_field "$DOMAINS_FILE" "$domain" "triggers" 2>/dev/null)
        while IFS= read -r trigger; do
            [[ -z "$trigger" ]] && continue
            local trigger_lower
            trigger_lower=$(echo "$trigger" | tr '[:upper:]' '[:lower:]')
            if [[ "$query_lower" == *"$trigger_lower"* ]]; then
                detected="$detected $domain"
                break
            fi
        done <<< "$triggers"
    done
    
    # Deduplicate and trim
    echo "$detected" | tr ' ' '\n' | grep -v '^$' | sort -u | tr '\n' ' ' | sed 's/ $//'
}

#
# Expand query with domain synonyms
#
expand_query() {
    local query="$1"
    local domains="$2"
    local expanded_terms=()
    
    # Start with original query
    expanded_terms+=("$query")
    
    # Add synonyms from detected domains
    for domain in $domains; do
        local synonyms
        synonyms=$(yaml_get_domain_field "$DOMAINS_FILE" "$domain" "synonyms" 2>/dev/null)
        while IFS= read -r syn; do
            [[ -z "$syn" ]] && continue
            if [[ "$query" != *"$syn"* ]]; then
                expanded_terms+=("$syn")
            fi
        done <<< "$synonyms"
    done
    
    # Build OR query (max 8 terms)
    local result=""
    local count=0
    for term in "${expanded_terms[@]}"; do
        [[ -z "$term" ]] && continue
        if [[ $count -lt 8 ]]; then
            if [[ -n "$result" ]]; then
                result="$result OR $term"
            else
                result="$term"
            fi
            ((count++))
        fi
    done
    
    echo "$result"
}

#
# Get language hints for domains
#
get_language_hints() {
    local domains="$1"
    local extensions=()
    
    for domain in $domains; do
        local exts
        exts=$(awk "/^  $domain:/,/^  [a-z]/" "$DOMAINS_FILE" 2>/dev/null | \
               grep -A 10 "file_hints:" 2>/dev/null | \
               grep "extensions:" | \
               sed 's/.*\[//' | sed 's/\].*//' | \
               tr ',' '\n' | tr -d ' "' || true)
        while IFS= read -r ext; do
            [[ -n "$ext" ]] && extensions+=("$ext")
        done <<< "$exts"
    done
    
    # Map extension to GitHub language
    if [[ ${#extensions[@]} -gt 0 ]]; then
        case "${extensions[0]}" in
            py) echo "Python" ;;
            ts) echo "TypeScript" ;;
            js) echo "JavaScript" ;;
            go) echo "Go" ;;
            java) echo "Java" ;;
            tf|hcl) echo "HCL" ;;
            *) echo "" ;;
        esac
    fi
}

#
# Get known repos for domains
#
get_domain_repos() {
    local domains="$1"
    local repos=()
    
    for domain in $domains; do
        local domain_repos
        domain_repos=$(yaml_get_domain_field "$DOMAINS_FILE" "$domain" "repos" 2>/dev/null)
        while IFS= read -r repo; do
            [[ -n "$repo" ]] && repos+=("$repo")
        done <<< "$domain_repos"
    done
    
    printf '%s\n' "${repos[@]}" 2>/dev/null | sort -u
}

#
# ACTION: Build Index
#
action_index_build() {
    info "Building ASU repository index..."
    
    # Initialize database
    db_init
    
    # Fetch all repos from ASU org
    info "Fetching repositories from $ORG org..."
    
    local repos_json
    repos_json=$(gh api "orgs/$ORG/repos" --paginate \
        --jq '.[] | {name, full_name, description, language, pushed_at, stargazers_count, visibility, archived, topics}' \
        2>/dev/null) || error "Failed to fetch repos. Check 'gh auth status'"
    
    local count=0
    while IFS= read -r repo; do
        [[ -z "$repo" ]] && continue
        
        local name full_name description language pushed_at stars visibility archived topics
        name=$(echo "$repo" | jq -r '.name')
        full_name=$(echo "$repo" | jq -r '.full_name')
        description=$(echo "$repo" | jq -r '.description // ""')
        language=$(echo "$repo" | jq -r '.language // ""')
        pushed_at=$(echo "$repo" | jq -r '.pushed_at // ""')
        stars=$(echo "$repo" | jq -r '.stargazers_count // 0')
        visibility=$(echo "$repo" | jq -r '.visibility // "private"')
        archived=$(echo "$repo" | jq -r 'if .archived then 1 else 0 end')
        topics=$(echo "$repo" | jq -r '.topics | join(",") // ""')
        
        db_upsert_repo "$name" "$full_name" "$description" "$language" "$pushed_at" "$stars" "$visibility" "$archived" "$topics"
        
        ((count++))
        if [[ $((count % 100)) -eq 0 ]]; then
            debug "Processed $count repos..."
        fi
    done <<< "$repos_json"
    
    # Run domain classification
    info "Classifying repos by domain..."
    action_index_classify_internal
    
    # Update metadata
    db_set_meta "last_index_update" "$(date -Iseconds)"
    db_set_meta "repo_count" "$count"
    
    success "Index built: $count repositories indexed"
}

#
# ACTION: Refresh Index (incremental)
#
action_index_refresh() {
    ensure_index
    
    local last_update
    last_update=$(db_get_meta "last_index_update")
    
    if [[ -z "$last_update" ]]; then
        info "No previous update found. Running full build..."
        action_index_build
        return
    fi
    
    info "Refreshing index (repos updated since $last_update)..."
    
    # Fetch repos updated since last run
    local repos_json
    repos_json=$(gh api "orgs/$ORG/repos" --paginate \
        --jq ".[] | select(.pushed_at > \"$last_update\") | {name, full_name, description, language, pushed_at, stargazers_count, visibility, archived, topics}" \
        2>/dev/null) || error "Failed to fetch repos"
    
    local count=0
    while IFS= read -r repo; do
        [[ -z "$repo" ]] && continue
        
        local name full_name description language pushed_at stars visibility archived topics
        name=$(echo "$repo" | jq -r '.name')
        full_name=$(echo "$repo" | jq -r '.full_name')
        description=$(echo "$repo" | jq -r '.description // ""')
        language=$(echo "$repo" | jq -r '.language // ""')
        pushed_at=$(echo "$repo" | jq -r '.pushed_at // ""')
        stars=$(echo "$repo" | jq -r '.stargazers_count // 0')
        visibility=$(echo "$repo" | jq -r '.visibility // "private"')
        archived=$(echo "$repo" | jq -r 'if .archived then 1 else 0 end')
        topics=$(echo "$repo" | jq -r '.topics | join(",") // ""')
        
        db_upsert_repo "$name" "$full_name" "$description" "$language" "$pushed_at" "$stars" "$visibility" "$archived" "$topics"
        ((count++))
    done <<< "$repos_json"
    
    db_set_meta "last_index_update" "$(date -Iseconds)"
    
    success "Refreshed: $count repositories updated"
}

#
# ACTION: Index Stats
#
action_index_stats() {
    ensure_index
    db_stats
    echo ""
    cache_stats
}

#
# Internal: Classify repos by domain
#
action_index_classify_internal() {
    # Get all domains and their prefixes
    local all_domains="peoplesoft edna dpl serviceauth auth identity salesforce ml terraform cicd cloudflare infoblox aws api"
    
    for domain in $all_domains; do
        # Get prefixes for this domain
        local prefixes
        prefixes=$(yaml_get_prefixes "$DOMAINS_FILE" "$domain")
        
        for prefix in $prefixes; do
            [[ -z "$prefix" ]] && continue
            
            # Link all repos with this prefix to the domain
            local repo_ids
            repo_ids=$(db_query "SELECT id FROM repos WHERE prefix = '$prefix'")
            
            while IFS= read -r repo_id; do
                [[ -z "$repo_id" ]] && continue
                db_link_repo_domain "$repo_id" "$domain" "0.9"
            done <<< "$repo_ids"
        done
        
        # Also match by triggers in name/description
        local triggers
        triggers=$(yaml_get_domain_field "$DOMAINS_FILE" "$domain" "triggers" 2>/dev/null | head -5)
        
        for trigger in $triggers; do
            [[ -z "$trigger" ]] && continue
            trigger="${trigger//\'/\'\'}"
            
            local repo_ids
            repo_ids=$(db_query "SELECT id FROM repos WHERE name LIKE '%$trigger%' OR description LIKE '%$trigger%'")
            
            while IFS= read -r repo_id; do
                [[ -z "$repo_id" ]] && continue
                db_link_repo_domain "$repo_id" "$domain" "0.7"
            done <<< "$repo_ids"
        done
    done
}

#
# ACTION: Search (Tier 1 local + Tier 2 API)
#
action_search() {
    [[ -z "${QUERY:-}" ]] && error "Missing --query"
    
    ensure_index
    
    # Detect domains
    local detected_domains
    if [[ -n "${DOMAIN:-}" ]]; then
        detected_domains="$DOMAIN"
    else
        detected_domains=$(detect_domains "$QUERY")
    fi
    
    debug "Detected domains: $detected_domains"
    
    # Expand query if enabled
    local search_query="$QUERY"
    if [[ "$EXPAND" == "true" ]] && [[ -n "$detected_domains" ]]; then
        search_query=$(expand_query "$QUERY" "$detected_domains")
        debug "Expanded query: $search_query"
    fi
    
    echo -e "${BOLD}=== Tier 1: Local Repository Search ===${NC}"
    info "Searching local index: $QUERY"
    [[ "$EXPAND" == "true" ]] && [[ "$search_query" != "$QUERY" ]] && info "Expanded: ${search_query:0:60}..."
    echo ""
    
    # Tier 1: Local SQLite search
    local local_results
    local_results=$(db_search_repos_like "$QUERY" "$LIMIT")
    
    if [[ -n "$local_results" ]]; then
        echo "Found in local index:"
        echo "$local_results" | while IFS=$'\t' read -r id name full_name desc lang prefix; do
            printf "  ${GREEN}%-40s${NC} %-10s %-8s %s\n" "$full_name" "${lang:-}" "[${prefix:-}]" "${desc:0:40}"
        done
    else
        echo "  No local matches found."
    fi
    
    # Stop here if local-only
    if [[ "$LOCAL_ONLY" == "true" ]]; then
        return
    fi
    
    echo ""
    echo -e "${BOLD}=== Tier 2: GitHub Code Search ===${NC}"
    
    # Tier 2: Code search (rate limited)
    local lang_hint=""
    if [[ -n "${LANGUAGE:-}" ]]; then
        lang_hint="$LANGUAGE"
    elif [[ -n "$detected_domains" ]]; then
        lang_hint=$(get_language_hints "$detected_domains")
    fi
    
    # Check cache first
    local cache_key="$QUERY|$lang_hint|$LIMIT"
    local cached
    cached=$(cache_get "$cache_key")
    
    if [[ -n "$cached" ]]; then
        info "Using cached results (< 24h old)"
        if [[ "$JSON_OUTPUT" == "true" ]]; then
            echo "$cached"
        else
            echo "$cached" | jq -r '.[] | "  \(.repository.nameWithOwner):\(.path)"' 2>/dev/null || echo "$cached"
        fi
        return
    fi
    
    if [[ "$CACHED_ONLY" == "true" ]]; then
        warn "No cached results. Use without --cached-only to query API."
        return
    fi
    
    # Rate limit check
    rate_limit_wait
    
    info "Querying GitHub API..."
    
    # Build search command
    local -a cmd=(gh search code "$QUERY" --owner "$ORG" --limit "$LIMIT")
    [[ -n "$lang_hint" ]] && cmd+=(--language "$lang_hint")
    
    local api_results
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        cmd+=(--json repository,path,textMatches)
        api_results=$("${cmd[@]}" 2>/dev/null) || api_results="[]"
        echo "$api_results"
    else
        cmd+=(--json repository,path)
        api_results=$("${cmd[@]}" 2>/dev/null) || api_results="[]"
        echo "$api_results" | jq -r '.[] | "  \(.repository.nameWithOwner):\(.path)"' 2>/dev/null || echo "  No code matches found."
    fi
    
    # Cache results
    cache_set "$cache_key" "$api_results"
}

#
# ACTION: Code Search (rate-limited with cache)
#
action_code() {
    [[ -z "${QUERY:-}" ]] && error "Missing --query"
    
    ensure_index
    
    local cache_key="code|$QUERY|${LANGUAGE:-}|$LIMIT"
    local cached
    cached=$(cache_get "$cache_key")
    
    if [[ -n "$cached" ]]; then
        info "Using cached code search results"
        if [[ "$JSON_OUTPUT" == "true" ]]; then
            echo "$cached"
        else
            echo "$cached" | jq -r '.[] | "\(.repository.nameWithOwner):\(.path)"' 2>/dev/null || echo "$cached"
        fi
        return
    fi
    
    if [[ "$CACHED_ONLY" == "true" ]]; then
        warn "No cached results for this query."
        return
    fi
    
    # Rate limit
    rate_limit_wait
    
    info "Searching code: $QUERY"
    
    local -a cmd=(gh search code "$QUERY" --owner "$ORG" --limit "$LIMIT")
    [[ -n "${LANGUAGE:-}" ]] && cmd+=(--language "$LANGUAGE")
    
    local results
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        cmd+=(--json repository,path,textMatches)
        results=$("${cmd[@]}" 2>/dev/null) || results="[]"
        echo "$results"
    else
        cmd+=(--json repository,path)
        results=$("${cmd[@]}" 2>/dev/null) || results="[]"
        
        local count
        count=$(echo "$results" | jq 'length' 2>/dev/null || echo "0")
        
        if [[ "$count" -gt 0 ]]; then
            echo "$results" | jq -r '.[] | "\(.repository.nameWithOwner):\(.path)"' 2>/dev/null
        else
            echo "No code matches found."
        fi
    fi
    
    # Cache
    cache_set "$cache_key" "$results"
}

#
# ACTION: Repos (by domain or prefix)
#
action_repos() {
    ensure_index
    
    if [[ -n "${PREFIX:-}" ]]; then
        info "Finding repositories with prefix: $PREFIX"
        
        local results
        results=$(db_get_repos_by_prefix "$PREFIX" "$LIMIT")
        
        if [[ -n "$results" ]]; then
            echo "$results" | while IFS=$'\t' read -r id name full_name desc lang; do
                printf "%-40s %-12s %s\n" "$full_name" "${lang:-}" "${desc:0:50}"
            done
        else
            echo "No repositories found with prefix '$PREFIX'"
        fi
        return
    fi
    
    if [[ -n "${DOMAIN:-}" ]]; then
        info "Finding repositories for domain: $DOMAIN"
        
        # First try local DB
        local results
        results=$(db_get_repos_by_domain "$DOMAIN" "$LIMIT")
        
        if [[ -n "$results" ]]; then
            echo "From local index:"
            echo "$results" | while IFS=$'\t' read -r id name full_name desc lang; do
                printf "  %-40s %-12s %s\n" "$full_name" "${lang:-}" "${desc:0:50}"
            done
        fi
        
        # Also show known repos from config
        echo ""
        echo "Known $DOMAIN repositories (from config):"
        get_domain_repos "$DOMAIN" | while read -r repo; do
            [[ -n "$repo" ]] && echo "  ASU/$repo"
        done
        return
    fi
    
    error "Must specify --domain or --prefix"
}

#
# ACTION: Context Builder
#
action_context() {
    [[ -z "${QUERY:-}" ]] && error "Missing --query (describe the integration task)"
    
    ensure_index
    
    echo -e "${BOLD}=== Context for: $QUERY ===${NC}"
    echo ""
    
    # Detect domains
    local detected_domains
    detected_domains=$(detect_domains "$QUERY")
    
    if [[ -z "$detected_domains" ]]; then
        warn "No specific domains detected. Performing general search."
    fi
    
    echo -e "${BOLD}Detected Domains:${NC} ${detected_domains:-general}"
    echo ""
    
    # Show matching repos from local index
    echo -e "${BOLD}Relevant Repositories (local index):${NC}"
    local local_results
    local_results=$(db_search_repos_like "$QUERY" 10)
    
    if [[ -n "$local_results" ]]; then
        echo "$local_results" | while IFS=$'\t' read -r id name full_name desc lang prefix; do
            printf "  %-40s %-10s %s\n" "$full_name" "${lang:-}" "[${prefix:-}]"
        done
    else
        echo "  (none found)"
    fi
    echo ""
    
    # Show known repos from config
    echo -e "${BOLD}Key Repositories (from config):${NC}"
    if [[ -n "$detected_domains" ]]; then
        for domain in $detected_domains; do
            echo "  [$domain]"
            get_domain_repos "$domain" | head -5 | while read -r repo; do
                [[ -n "$repo" ]] && echo "    - ASU/$repo"
            done
        done
    else
        echo "  (specify domain for known repos)"
    fi
    echo ""
    
    # Show relevant prefixes
    echo -e "${BOLD}Relevant Team Prefixes:${NC}"
    if [[ -n "$detected_domains" ]]; then
        for domain in $detected_domains; do
            local prefixes
            prefixes=$(yaml_get_prefixes "$DOMAINS_FILE" "$domain" | tr '\n' ', ' | sed 's/,$//')
            [[ -n "$prefixes" ]] && echo "  $domain: $prefixes"
        done
    fi
    echo ""
    
    # Suggest search queries
    echo -e "${BOLD}Suggested Searches:${NC}"
    for domain in $detected_domains; do
        local syn
        syn=$(yaml_get_domain_field "$DOMAINS_FILE" "$domain" "synonyms" 2>/dev/null | head -3 | tr '\n' ' ')
        [[ -n "$syn" ]] && echo "  discover.sh code --query \"$syn\" --domain $domain"
    done
}

#
# ACTION: Patterns
#
action_patterns() {
    [[ -z "${SOURCE_DOMAIN:-}" ]] && error "Missing --source domain"
    [[ -z "${TARGET_DOMAIN:-}" ]] && error "Missing --target domain"
    
    ensure_index
    
    echo -e "${BOLD}=== Integration Patterns: $SOURCE_DOMAIN -> $TARGET_DOMAIN ===${NC}"
    echo ""
    
    # Show repos mentioning both
    echo -e "${BOLD}Repositories linking both systems:${NC}"
    local source_triggers target_triggers
    source_triggers=$(yaml_get_domain_field "$DOMAINS_FILE" "$SOURCE_DOMAIN" "triggers" 2>/dev/null | head -3)
    target_triggers=$(yaml_get_domain_field "$DOMAINS_FILE" "$TARGET_DOMAIN" "triggers" 2>/dev/null | head -3)
    
    for st in $source_triggers; do
        [[ -z "$st" ]] && continue
        for tt in $target_triggers; do
            [[ -z "$tt" ]] && continue
            
            local matches
            matches=$(db_query "SELECT full_name, description FROM repos 
                               WHERE (name LIKE '%$st%' OR description LIKE '%$st%')
                                 AND (name LIKE '%$tt%' OR description LIKE '%$tt%')
                               LIMIT 5")
            
            [[ -n "$matches" ]] && echo "$matches" | while IFS=$'\t' read -r name desc; do
                echo "  $name: $desc"
            done
        done
    done | sort -u | head -10
    
    if [[ "$LOCAL_ONLY" != "true" ]] && [[ "$CACHED_ONLY" != "true" ]]; then
        echo ""
        echo -e "${BOLD}Code referencing both (from API):${NC}"
        
        rate_limit_wait
        
        gh search code "$SOURCE_DOMAIN $TARGET_DOMAIN" --owner "$ORG" --limit 10 \
            --json repository,path 2>/dev/null | \
            jq -r '.[] | "  \(.repository.nameWithOwner):\(.path)"' 2>/dev/null || echo "  (no direct references found)"
    fi
}

#
# ACTION: Expand (debug)
#
action_expand() {
    [[ -z "${QUERY:-}" ]] && error "Missing --query"
    
    echo "=== Query Expansion Debug ==="
    echo ""
    echo "Original query: $QUERY"
    echo ""
    
    local detected_domains
    detected_domains=$(detect_domains "$QUERY")
    echo "Detected domains: ${detected_domains:-none}"
    echo ""
    
    if [[ -n "$detected_domains" ]]; then
        echo "Synonyms by domain:"
        for domain in $detected_domains; do
            echo "  [$domain]"
            yaml_get_domain_field "$DOMAINS_FILE" "$domain" "synonyms" 2>/dev/null | head -8 | while read -r syn; do
                echo "    - $syn"
            done
        done
        echo ""
        
        local expanded
        expanded=$(expand_query "$QUERY" "$detected_domains")
        echo "Expanded query:"
        echo "  $expanded"
        echo ""
        
        local lang_hint
        lang_hint=$(get_language_hints "$detected_domains")
        echo "Language hint: ${lang_hint:-none}"
        echo ""
        
        echo "Team prefixes:"
        for domain in $detected_domains; do
            local prefixes
            prefixes=$(yaml_get_prefixes "$DOMAINS_FILE" "$domain" | tr '\n' ', ' | sed 's/,$//')
            [[ -n "$prefixes" ]] && echo "  $domain: $prefixes"
        done
        echo ""
        
        echo "Known repos:"
        get_domain_repos "$detected_domains" | while read -r repo; do
            echo "  - ASU/$repo"
        done
    fi
}

#
# Main
#
main() {
    [[ $# -eq 0 ]] && usage
    
    # Check domains.yaml exists
    [[ ! -f "$DOMAINS_FILE" ]] && error "domains.yaml not found at $DOMAINS_FILE"
    
    local action="$1"; shift
    
    # Handle index subcommands
    if [[ "$action" == "index" ]]; then
        local subaction="${1:-stats}"
        [[ $# -gt 0 ]] && shift
        parse_args "$@"
        
        case "$subaction" in
            build) action_index_build ;;
            refresh) action_index_refresh ;;
            stats) action_index_stats ;;
            classify) 
                ensure_index
                action_index_classify_internal
                success "Domain classification complete"
                ;;
            *) error "Unknown index subcommand: $subaction" ;;
        esac
        return
    fi
    
    parse_args "$@"
    
    case "$action" in
        search) action_search ;;
        code) action_code ;;
        repos) action_repos ;;
        context) action_context ;;
        patterns) action_patterns ;;
        expand) action_expand ;;
        --help|-h) usage ;;
        *) error "Unknown action: $action. Use --help for usage." ;;
    esac
}

main "$@"
