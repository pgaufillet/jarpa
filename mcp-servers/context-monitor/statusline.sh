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
# Auto-configured in .claude/settings.json by the SessionStart hook.
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
cwd=$(json_get_str "$payload" "cwd")
model_display=$(json_get_str "$payload" "display_name")
: "${model_display:=$(json_get_str "$payload" "id")}"

# --- Context usage percentage ---
#
# Primary: read context_window.used_percentage and context_window_size from
# the Claude Code payload (real token counts).
# Fallback: approximate from transcript file size (4 bytes/token, 200K window)
# in case a future payload version drops these fields.

usage_percent=$(json_get_num "$payload" "used_percentage")
context_window_size=$(json_get_num "$payload" "context_window_size")

if [[ -z "$usage_percent" ]]; then
    # Fallback heuristic
    : "${context_window_size:=200000}"
    BYTES_PER_TOKEN=4
    _path="$transcript_path"
    if [[ -n "$_path" && -f "$_path" ]]; then
        _size=$(stat -c %s "$_path" 2>/dev/null || stat -f %z "$_path" 2>/dev/null || echo 0)
        if [[ "$_size" =~ ^[0-9]+$ ]]; then
            usage_percent=$(( _size * 100 / (context_window_size * BYTES_PER_TOKEN) ))
            [[ "$usage_percent" -gt 100 ]] && usage_percent=100
        else
            usage_percent=0
        fi
    else
        usage_percent=0
    fi
fi

# --- JARPA budget vs model context ---
#
# The JARPA working budget (JARPA_CONTEXT_TOKENS) can be smaller than the
# model's context window. For example, 250K on a 1M model for efficiency.
#
# - The displayed percentage reflects the model's real context usage so the
#   user can calibrate their JARPA budget.
# - The WARN/CRITICAL labels fire based on the JARPA budget, which is what
#   actually matters for session management.
#
# Default budget: model's full context window (no artificial limit).

jarpa_budget="${JARPA_CONTEXT_TOKENS:-${context_window_size:-200000}}"

if [[ -n "$context_window_size" && "$context_window_size" -gt 0 ]]; then
    used_tokens=$(( usage_percent * context_window_size / 100 ))
else
    used_tokens=0
fi

if [[ "$jarpa_budget" -gt 0 ]]; then
    jarpa_pct=$(( used_tokens * 100 / jarpa_budget ))
else
    jarpa_pct=0
fi

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

broker_body="{\"usage_percent\":${jarpa_pct},\"model_percent\":${usage_percent},\"session_id\":\"${session_id}\",\"transcript_path\":\"${transcript_path}\",\"updated_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
write_broker "$CONTEXT_FILE" "$broker_body"

# --- Emit visible status line ---
#
# Format: "<model> · JARPA <gauge> <pct>% ctx <label>"
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
if [[ "$jarpa_pct" -ge 90 ]]; then
    label="CRITICAL"
elif [[ "$jarpa_pct" -ge 75 ]]; then
    label="WARN"
else
    label="OK"
fi

printf '%s · JARPA %s %d%% ctx %s\n' "$model_display" "$(gauge "$usage_percent")" "$usage_percent" "$label"
