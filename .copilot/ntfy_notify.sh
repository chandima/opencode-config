#!/usr/bin/env bash

set -euo pipefail

# ntfy notification script for GitHub Copilot CLI agentStop hook.
# Reads hook payload from stdin, resolves the session's events.jsonl
# transcript and workspace.yaml metadata, and sends a push notification
# with the session title and the agent's last response as the body.
# Uses a lockfile to deduplicate — only the first agentStop within
# DEBOUNCE_SEC fires a notification; subsequent ones are suppressed.

TOKEN="${NTFY_TOKEN:-tk_qks9lapox2xgj0sy7q5br3txb3bbe}"
TOPIC="${NTFY_TOPIC:-copilot-tasks}"
URL="${NTFY_URL:-https://ntfy.sandbox.iamzone.dev}"
DEBOUNCE_SEC="${NTFY_DEBOUNCE_SEC:-5}"
LOCKFILE="${TMPDIR:-/tmp}/copilot-ntfy.lock"
MAX_BODY_LEN="${NTFY_MAX_BODY_LEN:-512}"
SESSION_STATE_DIR="${COPILOT_SESSION_STATE_DIR:-$HOME/.copilot/session-state}"

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
stop_reason="$(jq -r '.stopReason // empty' <<<"$payload")"
session_id="$(jq -r '.sessionId // empty' <<<"$payload")"
transcript_path="$(jq -r '.transcriptPath // empty' <<<"$payload")"

# --- Resolve session directory ---
session_dir=""
if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
    session_dir="$(dirname "$transcript_path")"
elif [[ -n "$session_id" && -d "$SESSION_STATE_DIR/$session_id" ]]; then
    session_dir="$SESSION_STATE_DIR/$session_id"
fi

# --- Build notification title from session metadata ---
title="Copilot CLI"
if [[ -n "$session_dir" ]]; then
    workspace_meta="$session_dir/workspace.yaml"
    session_meta="$session_dir/session.json"
    if [[ -f "$workspace_meta" ]]; then
        session_name="$(grep -m1 '^summary:' "$workspace_meta" 2>/dev/null | sed 's/^summary: *//' | sed 's/^ *//;s/ *$//')"
        if [[ -n "$session_name" ]]; then
            title="$session_name"
        fi
    elif [[ -f "$session_meta" ]]; then
        session_name="$(jq -r '.name // empty' "$session_meta" 2>/dev/null)"
        if [[ -n "$session_name" ]]; then
            title="$session_name"
        fi
    fi
fi
if [[ "$title" == "Copilot CLI" && -n "$cwd_name" ]]; then
    title="Copilot CLI: $cwd_name"
fi

# --- Extract agent response from transcript ---
body=""

# Resolve transcript file: explicit path, or events.jsonl in session dir
events_file=""
if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
    events_file="$transcript_path"
elif [[ -n "$session_dir" && -f "$session_dir/events.jsonl" ]]; then
    events_file="$session_dir/events.jsonl"
fi

if [[ -n "$events_file" ]]; then
    # Read the last assistant.message with no pending tool requests
    body="$(tail -200 "$events_file" | jq -r '
        select(.type == "assistant.message")
        | select((.data.toolRequests // []) | length == 0)
        | .data.content // ""
    ' 2>/dev/null | awk 'length > 0 { line = $0 } END { print line }')"
fi

# Fallback if transcript reading failed
if [[ -z "$body" ]]; then
    body="Task complete"
    if [[ -n "$stop_reason" && "$stop_reason" != "null" ]]; then
        case "$stop_reason" in
            end_turn)  body="Task completed" ;;
            error)     body="Task ended with error" ;;
            abort)     body="Task aborted" ;;
            timeout)   body="Task timed out" ;;
            *)         body="Task ended ($stop_reason)" ;;
        esac
    fi
fi

# Truncate body if too long
if (( ${#body} > MAX_BODY_LEN )); then
    body="${body:0:$MAX_BODY_LEN}…"
fi

curl --silent --show-error --fail \
    -H "Authorization: Bearer $TOKEN" \
    -H "Title: $title" \
    -H "Priority: high" \
    -H "Tags: robot,computer" \
    -d "$body" \
    "$URL/$TOPIC"
