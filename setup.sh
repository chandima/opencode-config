#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
    cat << 'EOF'
Usage: ./setup.sh [TARGET]

Install OpenCode/Codex configuration by symlinking skills and config files.

TARGETS:
    (none)      Install for both OpenCode and Codex (default)
    opencode    Install for OpenCode only
    codex       Install for Codex only
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
    for item in opencode.json skills; do
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
    for skill_dir in "$SCRIPT_DIR/skills"/*; do
        [[ ! -d "$skill_dir" ]] && continue
        
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

# Parse arguments
TARGET="${1:-both}"

case "$TARGET" in
    --help|-h)
        show_help
        exit 0
        ;;
    opencode)
        setup_opencode
        ;;
    codex)
        setup_codex
        ;;
    both|"")
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

echo ""
echo "Setup complete!"
