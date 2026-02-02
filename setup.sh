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

    local all_skills=()
    local skill_dir
    for skill_dir in "$SCRIPT_DIR/skills"/*; do
        [[ -d "$skill_dir" ]] || continue
        all_skills+=("$(basename "$skill_dir")")
    done

    if [[ "${#all_skills[@]}" -eq 0 ]]; then
        echo "  No skills found."
        return 0
    fi

    local payload=""
    local skill_name
    for skill_name in "${all_skills[@]}"; do
        local target="$config_dir/skills/$skill_name"
        local installed=0
        local disabled=0

        if [[ -e "$target" ]]; then
            installed=1
        fi

        if [[ -n "$disabled_skills" ]] && echo "$skill_name" | grep -qE "^($disabled_skills)$"; then
            disabled=1
        fi

        payload+="${skill_name}\t${installed}\t${disabled}\n"
    done

    payload="${payload%$'\n'}"

    local selected_skills=""
    if [[ -t 0 && -t 1 && -n "${payload}" && -x "$(command -v python3)" ]]; then
        echo "  Select skills to install (existing unselected symlinks are left unchanged)."
        if ! selected_skills=$(SKILLS_PAYLOAD="$payload" python3 - << 'PY'
import curses
import os
import sys

payload = os.environ.get("SKILLS_PAYLOAD", "")
lines = [line for line in payload.splitlines() if line.strip()]
skills = []
for line in lines:
    parts = line.split("\t")
    if len(parts) != 3:
        continue
    name, installed, disabled = parts
    skills.append({
        "name": name,
        "selected": installed == "1" and disabled != "1",
        "disabled": disabled == "1",
    })

if not skills:
    sys.exit(0)

def run(stdscr):
    curses.curs_set(0)
    stdscr.keypad(True)
    index = 0
    top = 0

    while True:
        stdscr.clear()
        height, width = stdscr.getmaxyx()
        list_height = max(1, height - 3)

        header = "Up/Down: navigate  Space: toggle  Enter: confirm  q: cancel"
        stdscr.addnstr(0, 0, header, width - 1)

        if index < top:
            top = index
        elif index >= top + list_height:
            top = index - list_height + 1

        for i in range(list_height):
            item_index = top + i
            if item_index >= len(skills):
                break
            item = skills[item_index]
            marker = "[x]" if item["selected"] else "[ ]"
            label = item["name"]
            if item["disabled"]:
                label = f"{label} (disabled)"
            line = f"{marker} {label}"
            if item_index == index:
                stdscr.attron(curses.A_REVERSE)
                stdscr.addnstr(i + 1, 0, line, width - 1)
                stdscr.attroff(curses.A_REVERSE)
            else:
                stdscr.addnstr(i + 1, 0, line, width - 1)

        stdscr.refresh()
        key = stdscr.getch()

        if key in (curses.KEY_UP, ord("k")):
            index = max(0, index - 1)
        elif key in (curses.KEY_DOWN, ord("j")):
            index = min(len(skills) - 1, index + 1)
        elif key in (ord(" "),):
            item = skills[index]
            if not item["disabled"]:
                item["selected"] = not item["selected"]
        elif key in (curses.KEY_ENTER, 10, 13):
            break
        elif key in (ord("q"), 27):
            raise KeyboardInterrupt

def main():
    try:
        curses.wrapper(run)
    except KeyboardInterrupt:
        sys.exit(1)

    selected = [item["name"] for item in skills if item["selected"]]
    sys.stdout.write("\n".join(selected))

main()
PY
); then
            echo "  Selection cancelled."
            exit 1
        fi
    else
        echo "  Interactive selection unavailable; installing all enabled skills."
        selected_skills=$(printf '%s\n' "${all_skills[@]}")
    fi

    local selected_lookup
    selected_lookup="$(printf '%s\n' "$selected_skills" | tr '\n' ' ')"

    for skill_dir in "$SCRIPT_DIR/skills"/*; do
        [[ -d "$skill_dir" ]] || continue

        skill_name=$(basename "$skill_dir")
        target="$config_dir/skills/$skill_name"

        if [[ -n "$disabled_skills" ]] && echo "$skill_name" | grep -qE "^($disabled_skills)$"; then
            echo "  Skipping disabled: $skill_name"
            continue
        fi

        if ! printf '%s\n' "$selected_skills" | grep -qx "$skill_name"; then
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

    if [[ -n "$disabled_skills" ]]; then
        local disabled_list=""
        for skill_name in "${all_skills[@]}"; do
            if echo "$skill_name" | grep -qE "^($disabled_skills)$"; then
                disabled_list+="${skill_name} "
            fi
        done
        if [[ -n "$disabled_list" ]]; then
            echo "  Disabled skills skipped: ${disabled_list% }"
        fi
    fi

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
TARGET=""

for arg in "$@"; do
    case "$arg" in
        --help|-h)
            show_help
            exit 0
            ;;
        --remove|-r)
            ACTION="remove"
            ;;
        opencode|codex|both)
            TARGET="$arg"
            ;;
        *)
            echo "Error: Invalid option '$arg'"
            echo ""
            show_help
            exit 1
            ;;
    esac
done

TARGET="${TARGET:-opencode}"

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
