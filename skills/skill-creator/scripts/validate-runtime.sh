#!/usr/bin/env bash
set -euo pipefail

show_help() {
    cat <<'EOF'
Usage: validate-runtime.sh <skill-path|SKILL.md> [--runtime <opencode|codex|claude-api|portable>]

Runtime-aware validator for skill frontmatter and portability expectations.

Checks:
  - SKILL.md frontmatter exists and has required keys (name, description)
  - name format: lowercase-kebab-case, 3-64 chars
  - description non-empty and <= 1024 chars
  - runtime-specific expectations for allowed-tools/context

Examples:
  ./scripts/validate-runtime.sh skills/github-ops --runtime opencode
  ./scripts/validate-runtime.sh skills/example/SKILL.md --runtime portable
EOF
}

error() {
    echo "ERROR: $*" >&2
    ERRORS=$((ERRORS + 1))
}

warn() {
    echo "WARN: $*" >&2
    WARNINGS=$((WARNINGS + 1))
}

info() {
    echo "INFO: $*"
}

is_valid_runtime() {
    case "$1" in
        opencode|codex|claude-api|portable) return 0 ;;
        *) return 1 ;;
    esac
}

extract_frontmatter() {
    local input_file="$1"
    local first_line
    first_line="$(head -n 1 "$input_file" 2>/dev/null || true)"
    if [[ "$first_line" != "---" ]]; then
        return 1
    fi

    awk '
        NR==1 && $0=="---" { in_fm=1; next }
        in_fm && $0=="---" { exit }
        in_fm { print }
    ' "$input_file"
}

get_key_value() {
    local key="$1"
    local data="$2"
    echo "$data" | sed -nE "s/^${key}:[[:space:]]*(.*)$/\1/p" | head -n 1 | sed -E 's/^"(.*)"$/\1/'
}

TARGET=""
RUNTIME="portable"
ERRORS=0
WARNINGS=0

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
    show_help
    exit 1
fi

shift || true

while [[ $# -gt 0 ]]; do
    case "$1" in
        --runtime)
            shift || true
            if [[ $# -eq 0 ]]; then
                error "--runtime requires a value"
                break
            fi
            RUNTIME="$1"
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            error "Unknown argument: $1"
            ;;
    esac
    shift || true
done

if ! is_valid_runtime "$RUNTIME"; then
    error "Invalid runtime '$RUNTIME'. Expected one of: opencode, codex, claude-api, portable"
fi

if [[ "$TARGET" == */SKILL.md ]]; then
    SKILL_FILE="$TARGET"
else
    SKILL_FILE="$TARGET/SKILL.md"
fi

if [[ ! -f "$SKILL_FILE" ]]; then
    error "SKILL.md not found at $SKILL_FILE"
fi

if [[ $ERRORS -gt 0 ]]; then
    echo
    echo "Validation failed with $ERRORS error(s)."
    exit 1
fi

FRONTMATTER="$(extract_frontmatter "$SKILL_FILE" || true)"
if [[ -z "$FRONTMATTER" ]]; then
    error "Missing YAML frontmatter block in $SKILL_FILE"
fi

NAME="$(get_key_value "name" "$FRONTMATTER")"
DESCRIPTION="$(get_key_value "description" "$FRONTMATTER")"
ALLOWED_TOOLS="$(get_key_value "allowed-tools" "$FRONTMATTER")"
CONTEXT_VALUE="$(get_key_value "context" "$FRONTMATTER")"
HAS_COMPATIBILITY="$(echo "$FRONTMATTER" | grep -E '^compatibility:' || true)"
HAS_METADATA="$(echo "$FRONTMATTER" | grep -E '^metadata:' || true)"

if [[ -z "$NAME" ]]; then
    error "Frontmatter field 'name' is required"
else
    if [[ ${#NAME} -lt 3 || ${#NAME} -gt 64 ]]; then
        error "name must be between 3 and 64 characters"
    fi
    if [[ ! "$NAME" =~ ^[a-z][a-z0-9-]*[a-z0-9]$ ]]; then
        error "name must be lowercase-kebab-case and must not end with '-'."
    fi
fi

if [[ -z "$DESCRIPTION" ]]; then
    error "Frontmatter field 'description' is required"
else
    if [[ ${#DESCRIPTION} -gt 1024 ]]; then
        error "description exceeds 1024 characters"
    fi
fi

case "$RUNTIME" in
    opencode|codex)
        if [[ -z "$ALLOWED_TOOLS" ]]; then
            error "Runtime '$RUNTIME' expects 'allowed-tools' to be present"
        fi
        if [[ -z "$CONTEXT_VALUE" ]]; then
            warn "Runtime '$RUNTIME' usually benefits from explicit 'context: fork'"
        elif [[ "$CONTEXT_VALUE" != "fork" ]]; then
            warn "Expected 'context: fork' for repository conventions, found '$CONTEXT_VALUE'"
        fi
        ;;
    claude-api|portable)
        if [[ -n "$ALLOWED_TOOLS" ]]; then
            warn "Runtime '$RUNTIME' may not enforce 'allowed-tools'; verify portability needs"
        fi
        if [[ -n "$CONTEXT_VALUE" ]]; then
            warn "Runtime '$RUNTIME' may ignore 'context'; keep only if needed for cross-runtime docs"
        fi
        ;;
esac

if [[ -n "$HAS_COMPATIBILITY" ]]; then
    info "Found optional field: compatibility"
fi

if [[ -n "$HAS_METADATA" ]]; then
    info "Found optional field: metadata"
fi

echo
if [[ $ERRORS -gt 0 ]]; then
    echo "Validation failed with $ERRORS error(s) and $WARNINGS warning(s)."
    exit 1
fi

echo "Validation passed with $WARNINGS warning(s)."
