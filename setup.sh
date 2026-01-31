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
const config = require(process.argv[1]);
const perms = config.permission?.skill || {};
const disabled = Object.keys(perms)
  .filter(k => k !== '*' && perms[k] === 'deny')
  .map(k => k.replace(/\*/g, '.*'));
console.log(disabled.join('|'));
" "$SCRIPT_DIR/opencode.json"
}

skill_in_list() {
    local needle="$1"
    shift
    local item
    for item in "$@"; do
        if [[ "$item" == "$needle" ]]; then
            return 0
        fi
    done
    return 1
}

update_codex_permissions() {
    local config_dir="$HOME/.codex"
    local config_file="$config_dir/config.toml"

    if [[ ! -f "$config_file" ]]; then
        echo "  Skipping config.toml update (not found)"
        return
    fi

    node -e "
const fs = require('fs');
const configFile = process.argv[1];
const opencodePath = process.argv[2];

const opencode = JSON.parse(fs.readFileSync(opencodePath, 'utf8'));
const perms = opencode.permission?.skill || {};
const entries = Object.entries(perms);

if (!entries.length) process.exit(0);

const lines = ['[permission.skill]'];
for (const [key, value] of entries) {
  const needsQuote = !/^[A-Za-z0-9_]+$/.test(key);
  const escapedKey = key.replace(/\\\\/g, '\\\\\\\\').replace(/\"/g, '\\\\\"');
  const escapedValue = String(value).replace(/\\\\/g, '\\\\\\\\').replace(/\"/g, '\\\\\"');
  lines.push((needsQuote ? '\"' + escapedKey + '\"' : escapedKey) + ' = \"' + escapedValue + '\"');
}
const block = lines.join('\\n');

let content = fs.readFileSync(configFile, 'utf8');
const sectionRegex = /(^|\\n)\\[permission\\.skill\\][\\s\\S]*?(?=\\n\\[|\\s*$)/;

if (sectionRegex.test(content)) {
  content = content.replace(sectionRegex, (match, lead) => (lead + block));
} else {
  const needsNewline = content.length && !content.endsWith('\\n');
  content = content + (needsNewline ? '\\n' : '') + '\\n' + block + '\\n';
}

fs.writeFileSync(configFile, content);
" "$config_file" "$SCRIPT_DIR/opencode.json"

    echo "  Synced: config.toml permissions"
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

    local desired_skills=()
    
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

        desired_skills+=("$skill_name")
        
        if [[ -L "$target" ]]; then
            rm "$target"
        elif [[ -e "$target" ]]; then
            echo "  Warning: Replacing existing directory: $target"
            rm -rf "$target"
        fi
        
        ln -sfn "$skill_dir" "$target"
        echo "  Linked: $skill_name"
    done

    # Remove stale symlinks pointing to this repo
    for target in "$config_dir/skills"/*; do
        [[ ! -L "$target" ]] && continue

        local skill_name
        skill_name=$(basename "$target")
        local link_target
        link_target=$(readlink "$target")

        if [[ "$link_target" == "$SCRIPT_DIR/skills/"* ]]; then
            if [[ ! -d "$link_target" ]] || ! skill_in_list "$skill_name" "${desired_skills[@]}"; then
                rm "$target"
                echo "  Removed stale: $skill_name"
            fi
        fi
    done

    update_codex_permissions
    
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
