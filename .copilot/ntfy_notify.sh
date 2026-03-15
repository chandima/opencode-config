#!/usr/bin/env bash

set -euo pipefail

# ntfy notification script for GitHub Copilot CLI agentStop hook.
# Reads hook payload from stdin, extracts the agent's last response from
# the transcript file, and sends a push notification via ntfy.
# Uses a lockfile to deduplicate — only the first agentStop within
# DEBOUNCE_SEC fires a notification; subsequent ones are suppressed.

TOKEN="${NTFY_TOKEN:-tk_qks9lapox2xgj0sy7q5br3txb3bbe}"
TOPIC="${NTFY_TOPIC:-copilot-tasks}"
URL="${NTFY_URL:-https://ntfy.sandbox.iamzone.dev}"
DEBOUNCE_SEC="${NTFY_DEBOUNCE_SEC:-5}"
LOCKFILE="${TMPDIR:-/tmp}/copilot-ntfy.lock"
MAX_BODY_LEN="${NTFY_MAX_BODY_LEN:-512}"
POLL_ATTEMPTS="${NTFY_POLL_ATTEMPTS:-10}"
POLL_INTERVAL="${NTFY_POLL_INTERVAL:-0.05}"
ACCEPTABLE_AGE_MS="${NTFY_ACCEPTABLE_AGE_MS:-3000}"

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
transcript_path="$(jq -r '.transcriptPath // empty' <<<"$payload")"

# Extract timestamp from payload for freshness check
input_ts_ms="$(jq -r '
    .timestamp as $ts
    | if ($ts | type) == "number" then ($ts | floor)
      elif ($ts | type) == "string" then
        (try (($ts | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) * 1000 | floor) catch 0)
      else 0 end
' <<<"$payload")"

# --- Build notification title from session name ---
title="Copilot CLI"
if [[ -n "$transcript_path" ]]; then
    session_dir="$(dirname "$transcript_path")"
    session_meta="$session_dir/session.json"
    if [[ -f "$session_meta" ]]; then
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
if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
    min_ts_ms=0
    if (( input_ts_ms > 0 )); then
        min_ts_ms=$(( input_ts_ms - ACCEPTABLE_AGE_MS ))
        (( min_ts_ms < 0 )) && min_ts_ms=0
    fi

    attempt=0
    while (( attempt < POLL_ATTEMPTS )); do
        body="$(jq -r --argjson min_ts "$min_ts_ms" '
            select(.type == "assistant.message")
            | select((.data.toolRequests // []) | length == 0)
            | {
                ts_ms: (try ((.timestamp | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) * 1000 | floor) catch 0),
                content: (.data.content // "")
              }
            | select((.content | length) > 0)
            | select(.ts_ms >= $min_ts)
            | .content
        ' "$transcript_path" 2>/dev/null |
            awk 'length > 0 { line = $0 } END { print line }'
        )"

        if [[ -n "$body" ]]; then
            break
        fi

        attempt=$(( attempt + 1 ))
        if (( attempt < POLL_ATTEMPTS )); then
            sleep "$POLL_INTERVAL"
        fi
    done
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
