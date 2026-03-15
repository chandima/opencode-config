#!/usr/bin/env bash

set -euo pipefail

# ntfy notification script for GitHub Copilot CLI hooks.
# Receives JSON on stdin from agentStop / sessionEnd hooks.
# Sends a push notification to an ntfy server.

TOKEN="${NTFY_TOKEN:-tk_qks9lapox2xgj0sy7q5br3txb3bbe}"
TOPIC="${NTFY_TOPIC:-copilot-tasks}"
URL="${NTFY_URL:-https://ntfy.sandbox.iamzone.dev}"

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
        complete) body="Session completed" ;;
        error)    body="Session ended with error" ;;
        abort)    body="Session aborted" ;;
        timeout)  body="Session timed out" ;;
        user_exit) body="Session ended by user" ;;
        *)        body="Session ended ($reason)" ;;
    esac
fi

curl --silent --show-error --fail \
    -H "Authorization: Bearer $TOKEN" \
    -H "Title: $title" \
    -H "Priority: high" \
    -H "Tags: robot,computer" \
    -d "$body" \
    "$URL/$TOPIC"
