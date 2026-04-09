#!/usr/bin/env bash
set -euo pipefail

# ntfy notification script for Kiro CLI stop hook.
# Reads hook payload from stdin and sends a push notification.

TOKEN="${NTFY_TOKEN:-tk_qks9lapox2xgj0sy7q5br3txb3bbe}"
TOPIC="${NTFY_TOPIC:-kiro-tasks}"
URL="${NTFY_URL:-https://ntfy.sandbox.iamzone.dev}"

if ! command -v jq &>/dev/null || ! command -v curl &>/dev/null; then
    exit 0
fi

payload="$(cat)"
if [[ -z "$payload" ]]; then
    exit 0
fi

hook="$(jq -r '.hook_event_name // empty' <<<"$payload")"
if [[ "$hook" != "stop" ]]; then
    exit 0
fi

cwd="$(jq -r '.cwd // empty' <<<"$payload")"
cwd_name="${cwd##*/}"
title="Kiro CLI"
if [[ -n "$cwd_name" ]]; then
    title="Kiro CLI: $cwd_name"
fi

curl --silent --show-error --fail \
    -H "Authorization: Bearer $TOKEN" \
    -H "Title: $title" \
    -H "Priority: high" \
    -H "Tags: robot,kiro" \
    -d "Task complete" \
    "$URL/$TOPIC"
