#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-install}"
PACKAGE="${CONTEXT_MODE_PACKAGE:-context-mode}"

have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

require_npm() {
    if ! have_cmd npm; then
        echo "Error: npm is required to install $PACKAGE."
        exit 1
    fi
}

verify_context_mode() {
    if ! have_cmd context-mode; then
        echo "Error: context-mode is not available on PATH."
        exit 1
    fi
}

install_context_mode() {
    if [[ "${CONTEXT_MODE_SKIP_INSTALL:-0}" == "1" ]]; then
        echo "  Skipping context-mode installation (CONTEXT_MODE_SKIP_INSTALL=1)"
        verify_context_mode
        return 0
    fi

    if have_cmd context-mode; then
        echo "  Found: $(command -v context-mode)"
        verify_context_mode
        return 0
    fi

    require_npm
    echo "  Installing $PACKAGE via npm..."
    npm install -g "$PACKAGE"
    verify_context_mode
}

upgrade_context_mode() {
    require_npm
    echo "  Upgrading $PACKAGE via npm..."
    npm install -g "$PACKAGE@latest"
    verify_context_mode
}

case "$ACTION" in
    install)
        install_context_mode
        ;;
    verify)
        verify_context_mode
        ;;
    upgrade)
        upgrade_context_mode
        ;;
    *)
        echo "Usage: $0 [install|verify|upgrade]"
        exit 1
        ;;
esac
