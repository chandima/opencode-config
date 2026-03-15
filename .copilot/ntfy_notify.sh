#!/usr/bin/env bash

set -euo pipefail

# ntfy notification script for GitHub Copilot CLI hooks.
# Receives JSON on stdin from agentStop hooks.
# Uses a lockfile to deduplicate — only the first agentStop within
# DEBOUNCE_SEC fires a notification; subsequent ones are suppressed.

TOKEN="${NTFY_TOKEN:-tk_qks9lapox2xgj0sy7q5br3txb3bbe}"
TOPIC="${NTFY_TOPIC:-copilot-tasks}"
URL="${NTFY_URL:-https://ntfy.sandbox.iamzone.dev}"
DEBOUNCE_SEC="${NTFY_DEBOUNCE_SEC:-5}"
LOCKFILE="${TMPDIR:-/tmp}/copilot-ntfy.lock"

if ! command -v jq &>/dev/null; then
    exit 0
fi
if ! command -v curl &>/dev/null; then
    exit 0
fi

payload="$(cat)"
if [[ -z "$payload" ]]; then
    exit 0
fi

# Debounce: skip if lockfile exists and is younger than DEBOUNCE_SEC
if [[ -f "$LOCKFILE" ]]; then
    lock_age=$(( $(date +%s) - $(stat -f %m "$LOCKFILE" 2>/dev/null || stat -c %Y "$LOCKFILE" 2>/dev/null) ))
    if (( lock_age < DEBOUNCE_SEC )); then
        exit 0
    fi
fi
touch "$LOCKFILE"

cwd="$(jq -r '.cwd // empty' <<<"$payload")"
cwd_name="${cwd##*/}"
reason="$(jq -r '.reason // empty' <<<"$payload")"

title="Copilot CLI"
if [[ -n "$cwd_name" ]]; then
    title="Copilot CLI: $cwd_name"
fi

body="Task complete"
if [[ -n "$reason" && "$reason" != "null" ]]; then
    case "$reason" in
        complete) body="Task completed" ;;
        error)    body="Task ended with error" ;;
        abort)    body="Task aborted" ;;
        timeout)  body="Task timed out" ;;
        user_exit) body="Task ended by user" ;;
        *)        body="Task ended ($reason)" ;;
    esac
fi

curl --silent --show-error --fail \
    -H "Authorization: Bearer $TOKEN" \
    -H "Title: $title" \
    -H "Priority: high" \
    -H "Tags: robot,computer" \
    -d "$body" \
    "$URL/$TOPIC"
