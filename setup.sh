#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
    cat << 'EOF'
Usage: ./setup.sh [TARGET] [--remove]

Install OpenCode/Codex configuration by symlinking skills and merging Codex config.

TARGETS:
    (none)      Install for OpenCode only (default)
    opencode    Install for OpenCode only
    codex       Install for Codex only (skills under ~/.codex, config under ~/.config/.codex)
    both        Install for both OpenCode and Codex
    --remove, -r  Remove symlinks instead of installing
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

require_python3() {
    local python_cmd
    python_cmd="$(command -v python3 || true)"
    if [[ -z "$python_cmd" ]]; then
        echo "Error: python3 is required for Codex config merging."
        exit 1
    fi
}

codex_config_root() {
    echo "$HOME/.config/.codex"
}

codex_config_file() {
    echo "$(codex_config_root)/config.toml"
}

codex_state_file() {
    echo "$(codex_config_root)/.opencode-config-state.json"
}

codex_backup_dir() {
    echo "$(codex_config_root)/.opencode-config-backups"
}

merge_codex_config() {
    local repo_config="$SCRIPT_DIR/.codex/config.toml"
    local target_config
    target_config="$(codex_config_file)"
    local state_file
    state_file="$(codex_state_file)"

    if [[ ! -f "$repo_config" ]]; then
        echo "  Skipping Codex config (repo config not found)"
        return 0
    fi

    require_python3

    python3 "$SCRIPT_DIR/scripts/codex-config.py" install \
        --repo "$repo_config" \
        --target "$target_config" \
        --state "$state_file" \
        --opencode "$SCRIPT_DIR/opencode.json"

    echo "  Merged: .config/.codex/config.toml"
}

install_codex_rules() {
    local repo_rules_dir="$SCRIPT_DIR/.codex/rules"
    local target_rules_dir
    target_rules_dir="$(codex_config_root)/rules"
    local backup_dir
    backup_dir="$(codex_backup_dir)/rules"

    if [[ ! -d "$repo_rules_dir" ]]; then
        echo "  Skipping Codex rules (repo rules not found)"
        return 0
    fi

    mkdir -p "$target_rules_dir"
    mkdir -p "$backup_dir"

    local rule_file
    for rule_file in "$repo_rules_dir"/*; do
        [[ -f "$rule_file" ]] || continue
        local rule_name
        rule_name="$(basename "$rule_file")"
        local target="$target_rules_dir/$rule_name"
        local backup="$backup_dir/$rule_name"

        if [[ -L "$target" ]]; then
            local link_target
            link_target="$(readlink "$target")"
            if [[ "$link_target" == "$rule_file" ]]; then
                echo "  Linked: rules/$rule_name (already)"
                continue
            fi
        fi

        if [[ -e "$target" || -L "$target" ]]; then
            rm -rf "$backup"
            mv "$target" "$backup"
            echo "  Backed up: rules/$rule_name"
        fi

        ln -sfn "$rule_file" "$target"
        echo "  Linked: rules/$rule_name"
    done
}

remove_codex_rules() {
    local repo_rules_dir="$SCRIPT_DIR/.codex/rules"
    local target_rules_dir
    target_rules_dir="$(codex_config_root)/rules"
    local backup_dir
    backup_dir="$(codex_backup_dir)/rules"

    if [[ ! -d "$repo_rules_dir" ]]; then
        return 0
    fi

    if [[ ! -d "$target_rules_dir" ]]; then
        return 0
    fi

    local rule_file
    for rule_file in "$repo_rules_dir"/*; do
        [[ -f "$rule_file" ]] || continue
        local rule_name
        rule_name="$(basename "$rule_file")"
        local target="$target_rules_dir/$rule_name"
        local backup="$backup_dir/$rule_name"

        if [[ -L "$target" ]]; then
            local link_target
            link_target="$(readlink "$target")"
            if [[ "$link_target" == "$rule_file" ]]; then
                rm "$target"
                echo "  Removed: rules/$rule_name"
            else
                echo "  Skipped (not our symlink): rules/$rule_name"
                continue
            fi
        elif [[ -e "$target" ]]; then
            echo "  Skipped (not a symlink): rules/$rule_name"
            continue
        fi

        if [[ ! -e "$target" && ! -L "$target" && -e "$backup" ]]; then
            mv "$backup" "$target"
            echo "  Restored: rules/$rule_name"
        fi
    done
}

setup_codex_config() {
    local config_root
    config_root="$(codex_config_root)"
    echo "  Config target: $config_root"

    mkdir -p "$config_root"
    install_codex_rules
    merge_codex_config
}

remove_codex_config() {
    local config_root
    config_root="$(codex_config_root)"
    local state_file
    state_file="$(codex_state_file)"
    local target_config
    target_config="$(codex_config_file)"

    if [[ ! -d "$config_root" ]]; then
        return 0
    fi

    remove_codex_rules

    if [[ -f "$state_file" || -f "$target_config" ]]; then
        require_python3
        python3 "$SCRIPT_DIR/scripts/codex-config.py" remove \
            --target "$target_config" \
            --state "$state_file"
    fi
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
    echo "  Skills target: $config_dir/skills/"
    
    mkdir -p "$config_dir/skills"
    
    # Get disabled skills
    local disabled_skills
    disabled_skills=$(get_disabled_skills)

    local desired_skills=()
    
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

    setup_codex_config
    
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
    else
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
    fi

    remove_codex_config

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
