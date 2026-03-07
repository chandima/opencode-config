#!/usr/bin/env bash
set -euo pipefail

message="${1:-Codex task completed.}"
title="${NTFY_TITLE:-Codex}"

if command -v osascript >/dev/null 2>&1; then
    /usr/bin/osascript - "$title" "$message" <<'APPLESCRIPT'
on run argv
    set notifTitle to item 1 of argv
    set notifMessage to item 2 of argv
    display notification notifMessage with title notifTitle
end run
APPLESCRIPT
else
    printf '%s\n' "$title: $message" >&2
fi
