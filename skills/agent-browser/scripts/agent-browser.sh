#!/usr/bin/env bash
set -euo pipefail

if command -v agent-browser >/dev/null 2>&1; then
    exec agent-browser "$@"
fi

if command -v npx >/dev/null 2>&1; then
    exec npx agent-browser "$@"
fi

echo "ERROR: Neither 'agent-browser' nor 'npx' is available." >&2
echo "Install Node.js/npm (for npx) or install agent-browser globally." >&2
exit 1
