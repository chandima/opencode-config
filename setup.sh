#!/usr/bin/env bash
set -euo pipefail

# OpenCode configuration setup script
# This script only configures OpenCode (~/.config/opencode)
# For Codex CLI setup, see README.md for manual instructions

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/opencode"

echo "Setting up OpenCode config symlinks..."
echo "(For Codex CLI setup, see README.md manual instructions)"
echo ""
echo "Source: $SCRIPT_DIR"
echo "Target: $CONFIG_DIR"
echo ""

# Ensure target directory exists
mkdir -p "$CONFIG_DIR"

# Check for existing symlinks/files and warn
for item in opencode.json skills; do
    target="$CONFIG_DIR/$item"
    if [[ -L "$target" ]]; then
        echo "Warning: Replacing existing symlink: $target"
    elif [[ -e "$target" ]]; then
        echo "Warning: Replacing existing file/directory: $target"
    fi
done

# Create symlinks
ln -sf "$SCRIPT_DIR/opencode.json" "$CONFIG_DIR/opencode.json"
ln -sfn "$SCRIPT_DIR/skills" "$CONFIG_DIR/skills"

echo ""
echo "Done! Symlinks created:"
ls -la "$CONFIG_DIR/" | grep -E "(opencode.json|skills)" || true
