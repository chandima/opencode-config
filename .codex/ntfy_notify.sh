#!/usr/bin/env bash

set -euo pipefail

TOKEN="tk_qks9lapox2xgj0sy7q5br3txb3bbe"
TOPIC="codex-tasks"
URL="https://ntfy.sandbox.iamzone.dev"

payload="${1:-"{}"}"
type="$(jq -r '.type // empty' <<<"$payload")"

if [[ "$type" != "agent-turn-complete" ]]; then
    exit 0
fi

cwd="$(jq -r '.cwd // empty' <<<"$payload")"
cwd_name="${cwd##*/}"
last_message="$(jq -r '."last-assistant-message" // "Task complete"' <<<"$payload")"
title="Codex CLI"

if [[ -n "$cwd_name" ]]; then
    title="Codex CLI: $cwd_name"
fi

curl --silent --show-error --fail \
    -H "Authorization: Bearer $TOKEN" \
    -H "Title: $title" \
    -H "Priority: high" \
    -H "Tags: robot,mac" \
    -d "$last_message" \
    "$URL/$TOPIC"
