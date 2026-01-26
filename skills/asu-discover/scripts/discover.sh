#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# Ensure dependencies are installed
if [[ ! -d "$SKILL_DIR/node_modules" ]]; then
    echo "Installing dependencies..." >&2
    (cd "$SKILL_DIR" && pnpm install --silent)
fi

# Run CLI
exec pnpm --dir="$SKILL_DIR" exec tsx "$SKILL_DIR/src/cli.ts" "$@"
