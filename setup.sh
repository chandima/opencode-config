#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
    cat << 'EOF'
Usage: ./setup.sh [TARGET] [--remove] [--with-context-mode]

Install OpenCode/Codex/Copilot/Kiro configuration by symlinking skills and generating prompt files.

TARGETS:
    (none)      Install for OpenCode only (default)
    opencode    Install for OpenCode only
    codex       Install for Codex only (skills and config under ~/.codex)
    copilot     Install for GitHub Copilot only (skills, ntfy hooks under ~/.copilot)
    kiro        Install for Kiro CLI only (skills under ~/.kiro)
    all         Install for OpenCode, Codex, Copilot, and Kiro
    both        Install for OpenCode and Codex (legacy alias for backward compat)
    --remove, -r  Remove symlinks/files instead of installing
    --skills-only  Install/remove skills only (skip configs and rules)
    --with-context-mode  Install/configure context-mode where supported
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

opencode_config_root() {
    echo "$HOME/.config/opencode"
}

opencode_context_mode_state_file() {
    echo "$(opencode_config_root)/.context-mode-state.json"
}

codex_config_root() {
    echo "$HOME/.codex"
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

codex_context_mode_state_file() {
    echo "$(codex_config_root)/.context-mode-state.json"
}


target_uses_global_context_mode() {
    case "$TARGET" in
        opencode|codex|copilot|kiro|both|all)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

ensure_context_mode_runtime() {
    if [[ "$ACTION" != "install" || "$WITH_CONTEXT_MODE" -eq 0 || "$SKILLS_ONLY" -eq 1 ]]; then
        return 0
    fi

    if ! target_uses_global_context_mode; then
        return 0
    fi

    echo "Preparing context-mode..."
    bash "$SCRIPT_DIR/scripts/install-context-mode.sh" install
}

install_opencode_context_mode_config() {
    require_python3
    python3 "$SCRIPT_DIR/scripts/context-mode-config.py" install-opencode \
        --base "$SCRIPT_DIR/opencode.json" \
        --target "$(opencode_config_root)/opencode.json" \
        --state "$(opencode_context_mode_state_file)"
    echo "  Installed: opencode.json (context-mode managed)"
}

remove_opencode_context_mode_config() {
    local target="$(opencode_config_root)/opencode.json"
    local state="$(opencode_context_mode_state_file)"

    if [[ ! -f "$state" ]]; then
        return 0
    fi

    require_python3
    python3 "$SCRIPT_DIR/scripts/context-mode-config.py" remove-opencode \
        --target "$target" \
        --state "$state"
}

merge_codex_context_mode_config() {
    local target_config
    target_config="$(codex_config_file)"
    local state_file
    state_file="$(codex_context_mode_state_file)"
    local temp_config
    temp_config="$(mktemp)"

    cat > "$temp_config" << 'EOF'
[mcp_servers.context-mode]
command = "context-mode"
EOF

    require_python3
    python3 "$SCRIPT_DIR/scripts/codex-config.py" install \
        --repo "$temp_config" \
        --target "$target_config" \
        --state "$state_file"

    rm -f "$temp_config"
    echo "  Merged: ~/.codex/config.toml (context-mode)"
}

remove_codex_context_mode_config() {
    local state_file
    state_file="$(codex_context_mode_state_file)"
    local target_config
    target_config="$(codex_config_file)"

    if [[ ! -f "$state_file" && ! -f "$target_config" ]]; then
        return 0
    fi

    require_python3
    python3 "$SCRIPT_DIR/scripts/codex-config.py" remove \
        --target "$target_config" \
        --state "$state_file"
}

cleanup_empty_codex_config() {
    local target_config
    target_config="$(codex_config_file)"

    if [[ ! -f "$target_config" ]]; then
        return 0
    fi

    local normalized
    normalized="$(python3 - <<'PY' "$target_config"
from pathlib import Path
import sys
text = Path(sys.argv[1]).read_text(encoding='utf-8').strip()
print(text)
PY
)"

    if [[ -z "$normalized" || "$normalized" == "#:schema false" ]]; then
        rm -f "$target_config"
        echo "  Removed: config.toml"
    fi
}


install_copilot_context_mode_plugin() {
    if ! command -v copilot >/dev/null 2>&1; then
        echo "  Skipped: copilot CLI not found (install context-mode plugin manually)"
        return 0
    fi

    if copilot plugin list 2>/dev/null | grep -q "context-mode"; then
        echo "  Found: context-mode plugin already installed"
    else
        echo "  Installing context-mode plugin via copilot CLI..."
        copilot plugin install mksglu/context-mode
    fi

    # Rebuild native modules for the current Node version.
    # The marketplace install may compile better-sqlite3 against a different
    # NODE_MODULE_VERSION, breaking FTS5 search at runtime.
    local plugin_dir="$HOME/.copilot/installed-plugins/_direct/mksglu--context-mode"
    if [[ -d "$plugin_dir/node_modules/better-sqlite3" ]]; then
        echo "  Rebuilding native modules..."
        (cd "$plugin_dir" && npm rebuild better-sqlite3 2>/dev/null) \
            && echo "  Rebuilt: better-sqlite3" \
            || echo "  Warning: native module rebuild failed (FTS5 may not work)"
    fi
}

remove_copilot_context_mode_plugin() {
    if ! command -v copilot >/dev/null 2>&1; then
        return 0
    fi

    if ! copilot plugin list 2>/dev/null | grep -q "context-mode"; then
        return 0
    fi

    echo "  Uninstalling context-mode plugin..."
    copilot plugin uninstall context-mode
}

install_codex_notify_script() {
    local source_script="$SCRIPT_DIR/.codex/ntfy_notify.sh"
    local target_script
    target_script="$(codex_config_root)/ntfy_notify.sh"
    local backup
    backup="$(codex_backup_dir)/ntfy_notify.sh"

    if [[ ! -f "$source_script" ]]; then
        echo "  Skipping Codex notify script (repo script not found)"
        return 0
    fi

    mkdir -p "$(codex_config_root)"
    mkdir -p "$(codex_backup_dir)"

    if [[ -L "$target_script" ]]; then
        local link_target
        link_target="$(readlink "$target_script")"
        if [[ "$link_target" == "$source_script" ]]; then
            echo "  Linked: ntfy_notify.sh (already)"
            return 0
        fi
    fi

    if [[ -e "$target_script" || -L "$target_script" ]]; then
        rm -rf "$backup"
        mv "$target_script" "$backup"
        echo "  Backed up: ntfy_notify.sh"
    fi

    ln -sfn "$source_script" "$target_script"
    echo "  Linked: ntfy_notify.sh"
}

remove_codex_notify_script() {
    local source_script="$SCRIPT_DIR/.codex/ntfy_notify.sh"
    local target_script
    target_script="$(codex_config_root)/ntfy_notify.sh"
    local backup
    backup="$(codex_backup_dir)/ntfy_notify.sh"

    if [[ -L "$target_script" ]]; then
        local link_target
        link_target="$(readlink "$target_script")"
        if [[ "$link_target" == "$source_script" ]]; then
            rm "$target_script"
            echo "  Removed: ntfy_notify.sh"
        else
            echo "  Skipped (not our symlink): ntfy_notify.sh"
            return 0
        fi
    elif [[ -e "$target_script" ]]; then
        echo "  Skipped (not a symlink): ntfy_notify.sh"
        return 0
    fi

    if [[ ! -e "$target_script" && ! -L "$target_script" && -e "$backup" ]]; then
        mv "$backup" "$target_script"
        echo "  Restored: ntfy_notify.sh"
    fi
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

    echo "  Merged: ~/.codex/config.toml"
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
    install_codex_notify_script
    install_codex_rules
    merge_codex_config
    if [[ "$WITH_CONTEXT_MODE" -eq 1 ]]; then
        merge_codex_context_mode_config
    fi
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
    remove_codex_notify_script

    if [[ -f "$state_file" || -f "$target_config" ]]; then
        require_python3
        python3 "$SCRIPT_DIR/scripts/codex-config.py" remove \
            --target "$target_config" \
            --state "$state_file"
    fi

    remove_codex_context_mode_config
    cleanup_empty_codex_config
}

setup_opencode() {
    local config_dir
    config_dir="$(opencode_config_root)"
    echo "Setting up OpenCode..."
    echo "  Target: $config_dir"
    
    mkdir -p "$config_dir"
    
    # Check for existing symlinks/files and warn
    local items=(opencode.json skills)
    if [[ "$SKILLS_ONLY" -eq 1 ]]; then
        items=(skills)
    fi
    for item in "${items[@]}"; do
        target="$config_dir/$item"
        if [[ -L "$target" ]]; then
            echo "  Replacing existing symlink: $target"
        elif [[ -e "$target" ]]; then
            echo "  Replacing existing file/directory: $target"
        fi
    done
    
    # Create symlinks
    ln -sfn "$SCRIPT_DIR/skills" "$config_dir/skills"
    echo "  Linked: skills/"

    if [[ "$SKILLS_ONLY" -eq 0 ]]; then
        if [[ "$WITH_CONTEXT_MODE" -eq 1 ]]; then
            install_opencode_context_mode_config
        else
            ln -sf "$SCRIPT_DIR/opencode.json" "$config_dir/opencode.json"
            echo "  Linked: opencode.json"
        fi
    fi
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

    if [[ "$SKILLS_ONLY" -eq 0 ]]; then
        setup_codex_config
    fi
    
    echo "  Done!"
}

# ── GitHub Copilot ─────────────────────────────────────────────────────────
# Copilot natively supports the SKILL.md format (Agent Skills standard).
# We symlink individual skill directories to ~/.copilot/skills/ — same approach
# as Codex, no conversion needed.

copilot_config_root() {
    echo "$HOME/.copilot"
}

copilot_backup_dir() {
    echo "$(copilot_config_root)/.opencode-config-backups"
}

copilot_skills_dir() {
    echo "$(copilot_config_root)/skills"
}

# ── Kiro CLI ────────────────────────────────────────────────────────────────
# Kiro natively supports the SKILL.md format (Agent Skills standard).
# We symlink individual skill directories to ~/.kiro/skills/ — same approach
# as Copilot. The default agent auto-discovers skills; no config merge needed.

kiro_config_root() {
    echo "$HOME/.kiro"
}

kiro_skills_dir() {
    echo "$(kiro_config_root)/skills"
}

setup_kiro() {
    local skills_dir
    skills_dir="$(kiro_skills_dir)"
    echo "Setting up Kiro CLI..."
    echo "  Skills target: $skills_dir/"

    mkdir -p "$skills_dir"

    # Get disabled skills
    local disabled_skills
    disabled_skills=$(get_disabled_skills)

    local desired_skills=()

    # Symlink each skill individually
    local skill_dir
    for skill_dir in "$SCRIPT_DIR/skills"/*; do
        [[ -d "$skill_dir" ]] || continue

        local skill_name
        skill_name=$(basename "$skill_dir")
        local target="$skills_dir/$skill_name"

        # Skip disabled skills
        if [[ -n "$disabled_skills" ]] && echo "$skill_name" | grep -qE "^($disabled_skills)$"; then
            echo "  Skipping disabled: $skill_name"
            continue
        fi

        # Skip skills without SKILL.md
        if [[ ! -f "$skill_dir/SKILL.md" ]]; then
            echo "  Skipping (no SKILL.md): $skill_name"
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
    for target in "$skills_dir"/*; do
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

    echo "  Done!"

    echo ""
    echo "  ℹ️  Kiro's default agent auto-discovers skills from ~/.kiro/skills/."
    echo "     For custom agents, add to the agent's resources field:"
    echo '       "skill://~/.kiro/skills/*/SKILL.md"'
}

remove_kiro() {
    local skills_dir
    skills_dir="$(kiro_skills_dir)"
    echo "Removing Kiro CLI symlinks..."
    echo "  Target: $skills_dir/"

    if [[ ! -d "$skills_dir" ]]; then
        echo "  No Kiro skills directory found."
        echo "  Done!"
        return 0
    fi

    local skill_dir
    for skill_dir in "$SCRIPT_DIR/skills"/*; do
        [[ -d "$skill_dir" ]] || continue
        local skill_name
        skill_name=$(basename "$skill_dir")
        local target="$skills_dir/$skill_name"

        if [[ -L "$target" ]]; then
            rm "$target"
            echo "  Removed: $skill_name"
        elif [[ -e "$target" ]]; then
            echo "  Skipped (not a symlink): $skill_name"
        fi
    done

    echo "  Done!"
}

install_copilot_notify_script() {
    local source_script="$SCRIPT_DIR/.copilot/ntfy_notify.sh"
    local target_script
    target_script="$(copilot_config_root)/ntfy_notify.sh"
    local backup
    backup="$(copilot_backup_dir)/ntfy_notify.sh"

    if [[ ! -f "$source_script" ]]; then
        echo "  Skipping Copilot notify script (repo script not found)"
        return 0
    fi

    mkdir -p "$(copilot_config_root)"
    mkdir -p "$(copilot_backup_dir)"

    if [[ -L "$target_script" ]]; then
        local link_target
        link_target="$(readlink "$target_script")"
        if [[ "$link_target" == "$source_script" ]]; then
            echo "  Linked: ntfy_notify.sh (already)"
            return 0
        fi
    fi

    if [[ -e "$target_script" || -L "$target_script" ]]; then
        rm -rf "$backup"
        mv "$target_script" "$backup"
        echo "  Backed up: ntfy_notify.sh"
    fi

    ln -sfn "$source_script" "$target_script"
    echo "  Linked: ntfy_notify.sh"
}

remove_copilot_notify_script() {
    local source_script="$SCRIPT_DIR/.copilot/ntfy_notify.sh"
    local target_script
    target_script="$(copilot_config_root)/ntfy_notify.sh"
    local backup
    backup="$(copilot_backup_dir)/ntfy_notify.sh"

    if [[ -L "$target_script" ]]; then
        local link_target
        link_target="$(readlink "$target_script")"
        if [[ "$link_target" == "$source_script" ]]; then
            rm "$target_script"
            echo "  Removed: ntfy_notify.sh"
        else
            echo "  Skipped (not our symlink): ntfy_notify.sh"
            return 0
        fi
    elif [[ -e "$target_script" ]]; then
        echo "  Skipped (not a symlink): ntfy_notify.sh"
        return 0
    fi

    if [[ ! -e "$target_script" && ! -L "$target_script" && -e "$backup" ]]; then
        mv "$backup" "$target_script"
        echo "  Restored: ntfy_notify.sh"
    fi
}

ensure_copilot_js_hooks() {
    # The Copilot CLI npm package bundles a platform-specific SEA (Single
    # Executable Application) binary as an optionalDependency.  The npm-loader
    # prefers this native binary over the JS entry-point (index.js).  However,
    # hook support only exists in the JS code path — the SEA binary ships
    # without it.  Removing the platform binary forces the npm-loader to fall
    # through to index.js, enabling agentStop / preToolUse / etc. hooks.
    #
    # This is safe: index.js is functionally identical; it just needs Node ≥ 24.

    local pkg_root
    pkg_root="$(npm root -g 2>/dev/null)/@github/copilot" || true

    if [[ ! -d "$pkg_root" ]]; then
        echo "  ⚠  @github/copilot not installed globally via npm — hooks may not fire."
        echo "     Install with:  npm install -g @github/copilot@prerelease"
        return 0
    fi

    local arch
    arch="$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)"
    # Map to npm package naming convention
    case "$arch" in
        darwin-arm64)  arch="darwin-arm64" ;;
        darwin-x86_64) arch="darwin-x64"   ;;
        linux-x86_64)  arch="linux-x64"    ;;
        linux-aarch64) arch="linux-arm64"  ;;
        *)             arch=""              ;;
    esac

    if [[ -z "$arch" ]]; then
        echo "  Skipping platform-binary removal (unrecognized arch)"
        return 0
    fi

    local platform_pkg="$pkg_root/node_modules/@github/copilot-$arch"

    if [[ -d "$platform_pkg" ]]; then
        rm -rf "$platform_pkg"
        echo "  Removed SEA binary: @github/copilot-$arch (hooks now use JS engine)"
    else
        echo "  JS hook engine: OK (no SEA binary override present)"
    fi

    # Verify Node version
    local node_major
    node_major="$(node -e 'console.log(process.versions.node.split(".")[0])' 2>/dev/null)" || true
    if [[ -n "$node_major" ]] && (( node_major < 24 )); then
        echo "  ⚠  Node.js v${node_major} detected — Copilot JS engine requires v24+."
        echo "     Upgrade Node or hooks will not load."
    fi
}

install_copilot_hooks() {
    local source_hooks="$SCRIPT_DIR/.copilot/hooks/copilot-ntfy.json"
    local target_dir
    target_dir="$(copilot_config_root)/hooks"
    local target_file="$target_dir/copilot-ntfy.json"
    local backup
    backup="$(copilot_backup_dir)/copilot-ntfy.json"

    if [[ ! -f "$source_hooks" ]]; then
        echo "  Skipping Copilot hooks config (repo file not found)"
        return 0
    fi

    mkdir -p "$target_dir"
    mkdir -p "$(copilot_backup_dir)"

    if [[ -L "$target_file" ]]; then
        local link_target
        link_target="$(readlink "$target_file")"
        if [[ "$link_target" == "$source_hooks" ]]; then
            echo "  Linked: hooks/copilot-ntfy.json (already)"
            return 0
        fi
    fi

    if [[ -e "$target_file" || -L "$target_file" ]]; then
        rm -rf "$backup"
        mv "$target_file" "$backup"
        echo "  Backed up: hooks/copilot-ntfy.json"
    fi

    ln -sfn "$source_hooks" "$target_file"
    echo "  Linked: hooks/copilot-ntfy.json"
}

remove_copilot_hooks() {
    local source_hooks="$SCRIPT_DIR/.copilot/hooks/copilot-ntfy.json"
    local target_file
    target_file="$(copilot_config_root)/hooks/copilot-ntfy.json"
    local backup
    backup="$(copilot_backup_dir)/copilot-ntfy.json"

    if [[ -L "$target_file" ]]; then
        local link_target
        link_target="$(readlink "$target_file")"
        if [[ "$link_target" == "$source_hooks" ]]; then
            rm "$target_file"
            echo "  Removed: hooks/copilot-ntfy.json"
        else
            echo "  Skipped (not our symlink): hooks/copilot-ntfy.json"
            return 0
        fi
    elif [[ -e "$target_file" ]]; then
        echo "  Skipped (not a symlink): hooks/copilot-ntfy.json"
        return 0
    fi

    if [[ ! -e "$target_file" && ! -L "$target_file" && -e "$backup" ]]; then
        mv "$backup" "$target_file"
        echo "  Restored: hooks/copilot-ntfy.json"
    fi
}

setup_copilot() {
    local skills_dir
    skills_dir="$(copilot_skills_dir)"
    echo "Setting up GitHub Copilot..."
    echo "  Skills target: $skills_dir/"

    mkdir -p "$skills_dir"

    # Get disabled skills
    local disabled_skills
    disabled_skills=$(get_disabled_skills)

    local desired_skills=()

    # Symlink each skill individually
    local skill_dir
    for skill_dir in "$SCRIPT_DIR/skills"/*; do
        [[ -d "$skill_dir" ]] || continue

        local skill_name
        skill_name=$(basename "$skill_dir")
        local target="$skills_dir/$skill_name"

        # Skip disabled skills
        if [[ -n "$disabled_skills" ]] && echo "$skill_name" | grep -qE "^($disabled_skills)$"; then
            echo "  Skipping disabled: $skill_name"
            continue
        fi

        # Skip skills without SKILL.md
        if [[ ! -f "$skill_dir/SKILL.md" ]]; then
            echo "  Skipping (no SKILL.md): $skill_name"
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
    for target in "$skills_dir"/*; do
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

    echo "  Done!"

    if [[ "$SKILLS_ONLY" -eq 0 ]]; then
        install_copilot_notify_script
        install_copilot_hooks
        ensure_copilot_js_hooks
        echo ""
        echo "  ℹ️  Copilot CLI loads hooks from .github/hooks/ in your working directory."
        echo "     To enable ntfy notifications in a project, run:"
        echo "       mkdir -p <project>/.github/hooks"
        echo "       ln -s ~/.copilot/hooks/copilot-ntfy.json <project>/.github/hooks/copilot-ntfy.json"
    fi

    if [[ "$WITH_CONTEXT_MODE" -eq 1 && "$SKILLS_ONLY" -eq 0 ]]; then
        install_copilot_context_mode_plugin
    fi
}

remove_copilot() {
    local skills_dir
    skills_dir="$(copilot_skills_dir)"
    echo "Removing GitHub Copilot symlinks..."
    echo "  Target: $skills_dir/"

    if [[ ! -d "$skills_dir" ]]; then
        echo "  No Copilot skills directory found."
        echo "  Done!"
        return 0
    fi

    local skill_dir
    for skill_dir in "$SCRIPT_DIR/skills"/*; do
        [[ -d "$skill_dir" ]] || continue
        local skill_name
        skill_name=$(basename "$skill_dir")
        local target="$skills_dir/$skill_name"

        if [[ -L "$target" ]]; then
            rm "$target"
            echo "  Removed: $skill_name"
        elif [[ -e "$target" ]]; then
            echo "  Skipped (not a symlink): $skill_name"
        fi
    done

    echo "  Done!"

    remove_copilot_notify_script
    remove_copilot_hooks
    remove_copilot_context_mode_plugin
}

# Remove symlinks for OpenCode
remove_opencode() {
    local config_dir
    config_dir="$(opencode_config_root)"
    echo "Removing OpenCode symlinks..."
    echo "  Target: $config_dir"

    local items=(opencode.json skills)
    if [[ "$SKILLS_ONLY" -eq 1 ]]; then
        items=(skills)
    fi
    local removed_context_mode=0
    if [[ "$SKILLS_ONLY" -eq 0 && -f "$(opencode_context_mode_state_file)" ]]; then
        remove_opencode_context_mode_config
        removed_context_mode=1
    fi

    for item in "${items[@]}"; do
        local target="$config_dir/$item"
        if [[ "$item" == "opencode.json" && "$removed_context_mode" -eq 1 ]]; then
            if [[ -e "$target" || -L "$target" ]]; then
                echo "  Preserved: $item"
            else
                echo "  Removed: $item"
            fi
            continue
        fi
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

    if [[ "$SKILLS_ONLY" -eq 0 ]]; then
        remove_codex_config
    fi

    echo "  Done!"
}

# Parse arguments
ACTION="install"
TARGET="opencode"
TARGET_SET=0
REMOVE_SEEN=0
SKILLS_ONLY=0
WITH_CONTEXT_MODE=0

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
        --skills-only)
            SKILLS_ONLY=1
            ;;
        --with-context-mode)
            WITH_CONTEXT_MODE=1
            ;;
        opencode|codex|copilot|kiro|both|all)
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

ensure_context_mode_runtime

if [[ "$ACTION" == "install" ]]; then
    case "$TARGET" in
        opencode)
            setup_opencode
            ;;
        codex)
            setup_codex
            ;;
        copilot)
            setup_copilot
            ;;
        kiro)
            setup_kiro
            ;;
        both)
            setup_opencode
            echo ""
            setup_codex
            ;;
        all)
            setup_opencode
            echo ""
            setup_codex
            echo ""
            setup_copilot
            echo ""
            setup_kiro
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
        copilot)
            remove_copilot
            ;;
        kiro)
            remove_kiro
            ;;
        both)
            remove_opencode
            echo ""
            remove_codex
            ;;
        all)
            remove_opencode
            echo ""
            remove_codex
            echo ""
            remove_copilot
            echo ""
            remove_kiro
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
