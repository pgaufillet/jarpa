#!/bin/bash
#
# JARPA Context Monitor — Statusline
#
# Reads the Claude Code statusline payload on stdin (JSON) and emits a
# single compact status line on stdout for the Claude Code UI.
#
# Claude Code invokes this script on every turn. It must be fast
# (<100ms) and must never fail in a way that breaks the UI line.
#
# Auto-configured in .claude/settings.json by the SessionStart hook.
#
# Dependencies: bash only. No jq, no Python.
#

set -uo pipefail

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
model_display=$(json_get_str "$payload" "display_name")
: "${model_display:=$(json_get_str "$payload" "id")}"

# --- Context usage percentage ---
#
# Primary: read context_window.used_percentage and context_window_size from
# the Claude Code payload (real token counts).
# Fallback: approximate from transcript file size (4 bytes/token, 200K window)
# in case a future payload version drops these fields.
#
# The payload also exposes rate_limits.*.used_percentage. Strip it first so
# our greedy sed extraction picks the context_window value, not the rate
# limit. Same precaution for context_window_size.

context_payload="${payload%%\"rate_limits\"*}"
usage_percent=$(json_get_num "$context_payload" "used_percentage")
context_window_size=$(json_get_num "$context_payload" "context_window_size")

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

# --- Account rate-limit windows (opt-in) ---
#
# When JARPA_SHOW_RATE_LIMITS=1, two consumption gauges are appended and
# right-justified: the 5-hour session window and the 7-day (weekly) window.
# These come from the payload's rate_limits object and are GLOBAL to the
# account, not scoped to this session — hence the distinct 5h/7d labels so
# they are never confused with the ctx percentage.
#
# The payload exposes no per-model weekly window (the "Fable" row in /usage
# is not plumbed to the statusline), so only these two windows are shown.
#
# Fields appear only for Pro/Max accounts and only after the first API
# response of the session; each window may be independently absent. Missing
# values are tolerated silently.

# Extract a rate_limits.<window>.used_percentage value (integer part) without
# jq. The payload nests three used_percentage keys, so we scope to the window
# key first and read the FIRST used_percentage after it. Prints nothing when
# the window is absent.
rate_pct() {
    local window="$1"
    [[ "$payload" == *"\"$window\""* ]] || return 0
    local after="${payload#*\"$window\"}"
    [[ "$after" == *"used_percentage"* ]] || return 0
    after="${after#*used_percentage}"
    printf '%s' "$after" | sed -n 's/^[^0-9]*\([0-9][0-9]*\).*/\1/p'
}

# --- Emit visible status line ---
#
# Base  : "<model> · JARPA <gauge> <pct>% ctx <label>"
# Opt-in: " │ 5h <gauge> NN% · 7d <gauge> NN%" appended right after the base.
# Context gauge uses a 10-cell bar; rate-limit gauges use a compact 4-cell bar.
#
# The rate-limit section is appended, not right-justified: outside fullscreen
# rendering Claude Code shows its own notifications (MCP errors, updates,
# context-low warning) on the right side of the status line row, truncating
# whatever sits there.

gauge() {
    local pct="$1"
    local cells="${2:-10}"
    local filled=$(( pct * cells / 100 ))
    [[ "$filled" -gt "$cells" ]] && filled="$cells"
    [[ "$filled" -lt 0 ]] && filled=0
    local bar=""
    local i
    for (( i = 0; i < filled; i++ )); do bar+="█"; done
    for (( i = filled; i < cells; i++ )); do bar+="░"; done
    printf '%s' "$bar"
}

# Display width in terminal columns. The only non-ASCII glyphs we emit are the
# gauge cells and the "·" / "│" separators, all one column wide but multi-byte
# in UTF-8. Collapse them to a single ASCII byte first so ${#} counts columns
# regardless of the locale (C or UTF-8).
disp_width() {
    local s="$1"
    s="${s//█/#}"
    s="${s//░/#}"
    s="${s//·/.}"
    s="${s//│/|}"
    printf '%s' "${#s}"
}

label=""
if [[ "$jarpa_pct" -ge 90 ]]; then
    label="CRITICAL"
elif [[ "$jarpa_pct" -ge 75 ]]; then
    label="WARN"
else
    label="OK"
fi

left=$(printf '%s · JARPA %s %d%% ctx %s' \
    "$model_display" "$(gauge "$usage_percent")" "$usage_percent" "$label")

# Build the optional rate-limit section.
rates=""
if [[ "${JARPA_SHOW_RATE_LIMITS:-}" == "1" ]]; then
    fh=$(rate_pct "five_hour")
    sd=$(rate_pct "seven_day")
    if [[ -n "$fh" ]]; then
        rates="5h $(gauge "$fh" 4) ${fh}%"
    fi
    if [[ -n "$sd" ]]; then
        [[ -n "$rates" ]] && rates="$rates · "
        rates="${rates}7d $(gauge "$sd" 4) ${sd}%"
    fi
fi

# Append the rate-limit section after a "│" separator. All-or-nothing: if the
# columns are unknown or the full line would not fit, the whole section is
# dropped rather than wrapped or truncated mid-gauge. The interface indents
# the line by 2 columns and keeps 3 free on the right (measured: on a
# 68-column terminal a 65-column line was cut to 63 with an ellipsis).
# Claude Code runs the script again on its next event, not on resize.
UI_MARGIN=5
line="$left"
if [[ -n "$rates" && "${COLUMNS:-}" =~ ^[0-9]+$ ]]; then
    full="$left │ $rates"
    if [[ "$(disp_width "$full")" -le $(( COLUMNS - UI_MARGIN )) ]]; then
        line="$full"
    fi
fi
printf '%s\n' "$line"
