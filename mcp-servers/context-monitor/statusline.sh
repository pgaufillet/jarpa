#!/bin/bash
#
# JARPA Context Monitor — Statusline
#
# Reads the Claude Code statusline payload on stdin (JSON) and:
#   1. Writes a broker file consumed by server.sh with the current
#      context window usage percentage.
#   2. Emits a single compact status line on stdout for the Claude Code UI.
#
# Claude Code invokes this script on every turn. It must be fast
# (<100ms) and must never fail in a way that breaks the UI line.
#
# Configure in ~/.claude/settings.json:
#   {
#     "statusLine": {
#       "type": "command",
#       "command": "bash ${CLAUDE_PLUGIN_ROOT}/mcp-servers/context-monitor/statusline.sh"
#     }
#   }
#
# /jarpa:init offers to install this automatically.
#
# Dependencies: bash only. No jq, no Python.
#

set -uo pipefail

# --- Context file resolution — must match server.sh exactly ---

resolve_context_file() {
    if [[ -n "${JARPA_CONTEXT_FILE:-}" ]]; then
        printf '%s' "$JARPA_CONTEXT_FILE"
        return
    fi
    local dir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
    printf '%s/jarpa-context.json' "$dir"
}

CONTEXT_FILE=$(resolve_context_file)

# --- Minimal JSON helpers (no jq needed) ---

json_get_str() {
    printf '%s' "$1" | sed -n 's/.*"'"$2"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
}

json_get_num() {
    printf '%s' "$1" | sed -n 's/.*"'"$2"'"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p'
}

# --- Read statusline payload on stdin ---

payload=$(cat 2>/dev/null || true)

transcript_path=$(json_get_str "$payload" "transcript_path")
session_id=$(json_get_str "$payload" "session_id")
model_id=$(json_get_str "$payload" "id")
cwd=$(json_get_str "$payload" "cwd")

# --- Compute context usage percentage ---
#
# Claude Code does not (yet) expose a precise token count on the statusline
# payload, so we approximate from the transcript file size.
#
# Heuristic: 1 token ~= 4 bytes of transcript JSON on average. Model context
# windows are normalized to 200K tokens (Sonnet / Opus default). This is
# deliberately a rough estimate — the goal is to cross the 75/90 thresholds
# at the right order of magnitude, not to be exact.
#
# If you need a tighter measure, override by writing JARPA_CONTEXT_FILE
# yourself from another tool.

ASSUMED_CONTEXT_TOKENS=200000
BYTES_PER_TOKEN=4

compute_percent() {
    local path="$1"
    if [[ -z "$path" || ! -f "$path" ]]; then
        printf '0'
        return
    fi
    local size
    size=$(stat -c %s "$path" 2>/dev/null || stat -f %z "$path" 2>/dev/null || echo 0)
    if ! [[ "$size" =~ ^[0-9]+$ ]]; then
        printf '0'
        return
    fi
    local budget=$((ASSUMED_CONTEXT_TOKENS * BYTES_PER_TOKEN))
    local pct=$(( size * 100 / budget ))
    if [[ "$pct" -gt 100 ]]; then
        pct=100
    fi
    printf '%d' "$pct"
}

usage_percent=$(compute_percent "$transcript_path")

# --- Write broker file atomically ---

write_broker() {
    local path="$1" content="$2"
    local dir
    dir=$(dirname "$path")
    mkdir -p "$dir" 2>/dev/null || true
    local tmp="${path}.tmp.$$"
    if printf '%s\n' "$content" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$path" 2>/dev/null || rm -f "$tmp"
    fi
}

broker_body="{\"usage_percent\":${usage_percent},\"session_id\":\"${session_id}\",\"transcript_path\":\"${transcript_path}\",\"updated_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
write_broker "$CONTEXT_FILE" "$broker_body"

# --- Emit visible status line ---
#
# Format: "JARPA <gauge> <pct>% | <cwd_basename>"
# Gauge uses a 10-cell visual bar.

gauge() {
    local pct="$1"
    local filled=$(( pct / 10 ))
    [[ "$filled" -gt 10 ]] && filled=10
    local bar=""
    local i
    for (( i = 0; i < filled; i++ )); do bar+="█"; done
    for (( i = filled; i < 10; i++ )); do bar+="░"; done
    printf '%s' "$bar"
}

label=""
if [[ "$usage_percent" -ge 90 ]]; then
    label="CRITICAL"
elif [[ "$usage_percent" -ge 75 ]]; then
    label="WARN"
else
    label="OK"
fi

cwd_base=""
if [[ -n "$cwd" ]]; then
    cwd_base=$(basename "$cwd")
fi

printf 'JARPA %s %d%% %s | %s\n' "$(gauge "$usage_percent")" "$usage_percent" "$label" "$cwd_base"
