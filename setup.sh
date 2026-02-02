#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
    cat << 'EOF'
Usage: ./setup.sh [TARGET] [--remove]

Install OpenCode/Codex configuration by symlinking skills and config files.

TARGETS:
    (none)      Install for OpenCode only (default)
    opencode    Install for OpenCode only
    codex       Install for Codex only
    both        Install for both OpenCode and Codex
    --remove, -r  Remove symlinks instead of installing
    --help, -h  Show this help message
EOF
}

# Read disabled skills from opencode.json
get_disabled_skills() {
    node -e "
const config = require('./opencode.json');
const perms = config.permission?.skill || {};
const disabled = Object.keys(perms)
  .filter(k => k !== '*' && perms[k] === 'deny')
  .map(k => k.replace(/\*/g, '.*'));
console.log(disabled.join('|'));
"
}

setup_opencode() {
    local config_dir="$HOME/.config/opencode"
    echo "Setting up OpenCode..."
    echo "  Target: $config_dir"
    
    mkdir -p "$config_dir"
    
    # Check for existing symlinks/files and warn
    for item in opencode.json skills agents; do
        target="$config_dir/$item"
        if [[ -L "$target" ]]; then
            echo "  Replacing existing symlink: $target"
        elif [[ -e "$target" ]]; then
            echo "  Replacing existing file/directory: $target"
        fi
    done
    
    # Create symlinks
    ln -sf "$SCRIPT_DIR/opencode.json" "$config_dir/opencode.json"
    ln -sfn "$SCRIPT_DIR/skills" "$config_dir/skills"
    ln -sfn "$SCRIPT_DIR/.opencode/agents" "$config_dir/agents"
    
    echo "  Linked: opencode.json"
    echo "  Linked: skills/"
    echo "  Linked: agents/"
    echo "  Done!"
}

setup_codex() {
    local config_dir="$HOME/.codex"
    echo "Setting up Codex..."
    echo "  Target: $config_dir/skills/"
    
    mkdir -p "$config_dir/skills"
    
    # Get disabled skills
    local disabled_skills
    disabled_skills=$(get_disabled_skills)

    # Symlink each skill individually (preserves .system/)
    local skill_dir
    for skill_dir in "$SCRIPT_DIR/skills"/*; do
        [[ -d "$skill_dir" ]] || continue

        local skill_name
        skill_name=$(basename "$skill_dir")
        local target="$config_dir/skills/$skill_name"

        # Skip disabled skills
        if [[ -n "$disabled_skills" ]] && echo "$skill_name" | grep -qE "^($disabled_skills)$"; then
            echo "  Skipping disabled: $skill_name"
            continue
        fi

        if [[ -L "$target" ]]; then
            rm "$target"
        elif [[ -e "$target" ]]; then
            echo "  Warning: Replacing existing directory: $target"
            rm -rf "$target"
        fi

        ln -sfn "$skill_dir" "$target"
        echo "  Linked: $skill_name"
    done

    echo "  Done!"
}

# Remove symlinks for OpenCode
remove_opencode() {
    local config_dir="$HOME/.config/opencode"
    echo "Removing OpenCode symlinks..."
    echo "  Target: $config_dir"

    for item in opencode.json skills agents; do
        local target="$config_dir/$item"
        if [[ -L "$target" ]]; then
            rm "$target"
            echo "  Removed: $item"
        elif [[ -e "$target" ]]; then
            echo "  Skipped (not a symlink): $item"
        else
            echo "  Not found: $item"
        fi
    done

    echo "  Done!"
}

# Remove symlinks for Codex
remove_codex() {
    local config_dir="$HOME/.codex"
    echo "Removing Codex symlinks..."
    echo "  Target: $config_dir/skills/"

    if [[ ! -d "$config_dir/skills" ]]; then
        echo "  No Codex skills directory found."
        return 0
    fi

    local skill_dir
    for skill_dir in "$SCRIPT_DIR/skills"/*; do
        [[ -d "$skill_dir" ]] || continue
        local skill_name
        skill_name=$(basename "$skill_dir")
        local target="$config_dir/skills/$skill_name"

        if [[ -L "$target" ]]; then
            rm "$target"
            echo "  Removed: $skill_name"
        elif [[ -e "$target" ]]; then
            echo "  Skipped (not a symlink): $skill_name"
        fi
    done

    echo "  Done!"
}

# Parse arguments
ACTION="install"
TARGET="opencode"
TARGET_SET=0
REMOVE_SEEN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            show_help
            exit 0
            ;;
        --remove|-r)
            ACTION="remove"
            REMOVE_SEEN=1
            ;;
        opencode|codex|both)
            if [[ "$TARGET_SET" -eq 1 ]]; then
                echo "Error: Multiple targets specified."
                echo ""
                show_help
                exit 1
            fi
            if [[ "$REMOVE_SEEN" -eq 1 ]]; then
                echo "Error: Target must come before --remove."
                echo ""
                show_help
                exit 1
            fi
            TARGET="$1"
            TARGET_SET=1
            ;;
        *)
            echo "Error: Invalid option '$1'"
            echo ""
            show_help
            exit 1
            ;;
    esac
    shift
done

if [[ "$ACTION" == "install" ]]; then
    case "$TARGET" in
        opencode)
            setup_opencode
            ;;
        codex)
            setup_codex
            ;;
        both)
            setup_opencode
            echo ""
            setup_codex
            ;;
        *)
            echo "Error: Invalid target '$TARGET'"
            echo ""
            show_help
            exit 1
            ;;
    esac
else
    case "$TARGET" in
        opencode)
            remove_opencode
            ;;
        codex)
            remove_codex
            ;;
        both)
            remove_opencode
            echo ""
            remove_codex
            ;;
        *)
            echo "Error: Invalid target '$TARGET'"
            echo ""
            show_help
            exit 1
            ;;
    esac
fi

echo ""
echo "Setup complete!"
