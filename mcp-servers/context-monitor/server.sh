#!/bin/bash
#
# JARPA Context Monitor — MCP Server (pure bash)
#
# Reads context data from a broker file produced by the JARPA statusline
# (mcp-servers/context-monitor/statusline.sh). Implements MCP protocol
# over stdio (JSON-RPC 2.0, newline-delimited).
#
# Context file resolution (first match wins):
#   1. --context-file <path>                       (CLI flag, used by tests)
#   2. $JARPA_CONTEXT_FILE                         (user override)
#   3. ${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/jarpa-context.json
#
# Dependencies: bash only. No jq, no Python, no pip.
#

set -uo pipefail

# --- Context file resolution ---

resolve_context_file() {
    local cli_path="$1"
    if [[ -n "$cli_path" ]]; then
        printf '%s' "$cli_path"
        return
    fi
    if [[ -n "${JARPA_CONTEXT_FILE:-}" ]]; then
        printf '%s' "$JARPA_CONTEXT_FILE"
        return
    fi
    local dir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
    printf '%s/jarpa-context.json' "$dir"
}

CLI_CONTEXT_FILE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --context-file) CLI_CONTEXT_FILE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

CONTEXT_FILE=$(resolve_context_file "$CLI_CONTEXT_FILE")

# Canonical thresholds — master values in jarpa/ARCHITECTURE.md "Canonical Values".
# Kept in sync by tests/test_thresholds_consistency.sh.
THRESHOLD_WARNING=75
THRESHOLD_CRITICAL=90

# Statusline script expected location, used by check_health to diagnose
# incomplete deployments.
STATUSLINE_SCRIPT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}/mcp-servers/context-monitor/statusline.sh"

# Consider the context file stale if it has not been updated for more than
# this many seconds (statusline runs on every turn, so anything older than a
# few minutes indicates a broken pipeline).
STALE_AFTER_SECONDS=600

# --- Minimal JSON helpers (no jq needed) ---

# Extract a string value by key from single-line JSON
# Usage: json_get_str "$json" "method"
json_get_str() {
    printf '%s' "$1" | sed -n 's/.*"'"$2"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
}

# Extract a numeric value by key from single-line JSON
# Usage: json_get_num "$json" "id"
json_get_num() {
    printf '%s' "$1" | sed -n 's/.*"'"$2"'"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p'
}

# Escape a string for embedding in a JSON string value
json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# --- Response helpers ---

respond() {
    printf '%s\n' "$1"
}

respond_result() {
    local id="$1" body="$2"
    respond "{\"jsonrpc\":\"2.0\",\"id\":${id},\"result\":${body}}"
}

respond_tool_text() {
    local id="$1" text="$2"
    local escaped
    escaped=$(json_escape "$text")
    respond_result "$id" "{\"content\":[{\"type\":\"text\",\"text\":\"${escaped}\"}]}"
}

respond_error() {
    local id="$1" code="$2" msg="$3"
    respond "{\"jsonrpc\":\"2.0\",\"id\":${id},\"error\":{\"code\":${code},\"message\":\"${msg}\"}}"
}

# --- MCP handlers ---

handle_initialize() {
    respond_result "$1" '{"protocolVersion":"2024-11-05","capabilities":{"tools":{}},"serverInfo":{"name":"context-monitor","version":"0.2.2"}}'
}

handle_tools_list() {
    local id="$1"
    respond_result "$id" "{\"tools\":[{\"name\":\"get_context_status\",\"description\":\"Get current Claude Code context window usage.\\n\\nReturns JSON with usage_percent, threshold warnings, and recommendations.\\nData is provided by the JARPA statusline (updates on every turn).\",\"inputSchema\":{\"type\":\"object\",\"properties\":{},\"required\":[]}},{\"name\":\"should_close_session\",\"description\":\"Quick check if session should be closed based on context threshold.\\n\\nArgs:\\n    threshold: Percentage threshold (default: ${THRESHOLD_WARNING})\\n\\nReturns JSON with boolean close_now and current percentage.\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"threshold\":{\"type\":\"integer\",\"default\":${THRESHOLD_WARNING},\"description\":\"Percentage threshold (default: ${THRESHOLD_WARNING})\"}},\"required\":[]}},{\"name\":\"check_health\",\"description\":\"Diagnose the context monitoring data pipeline end-to-end.\\n\\nReturns JSON with: context file path and presence, file age, whether\\nthe statusline script is installed, and an overall health status (OK,\\nDEGRADED, BROKEN). Use this when get_context_status reports missing\\ndata to understand which stage of the pipeline is failing.\",\"inputSchema\":{\"type\":\"object\",\"properties\":{},\"required\":[]}}]}"
}

handle_get_context_status() {
    local id="$1"

    if [[ ! -f "$CONTEXT_FILE" ]]; then
        respond_tool_text "$id" "{\"error\":\"No context data available\",\"context_file\":\"$(json_escape "$CONTEXT_FILE")\",\"suggestion\":\"The statusline is auto-configured on session start. Call check_health for diagnostics.\"}"
        return
    fi

    local data
    data=$(cat "$CONTEXT_FILE" 2>/dev/null) || true
    if [[ -z "$data" ]]; then
        respond_tool_text "$id" '{"error":"Failed to read context data"}'
        return
    fi

    local pct
    pct=$(json_get_num "$data" "usage_percent")
    pct=${pct:-0}

    local status rec
    if [[ "$pct" -ge "$THRESHOLD_CRITICAL" ]]; then
        status="CRITICAL"
        rec="Close session now. Update JOURNAL.md and TODO.md before context is exhausted."
    elif [[ "$pct" -ge "$THRESHOLD_WARNING" ]]; then
        status="WARNING"
        rec="Approaching threshold. Plan to close session soon."
    else
        status="OK"
        rec="Continue working. $((THRESHOLD_WARNING - pct))% headroom until warning threshold."
    fi

    respond_tool_text "$id" "{\"usage_percent\":${pct},\"status\":\"${status}\",\"recommendation\":\"${rec}\"}"
}

handle_should_close_session() {
    local id="$1"
    local threshold="$2"

    if [[ ! -f "$CONTEXT_FILE" ]]; then
        respond_tool_text "$id" '{"error":"No context data","close_now":false}'
        return
    fi

    local pct
    pct=$(cat "$CONTEXT_FILE" 2>/dev/null | head -1)
    pct=$(json_get_num "$pct" "usage_percent")
    pct=${pct:-0}

    if ! [[ "$pct" =~ ^[0-9]+$ ]]; then
        respond_tool_text "$id" '{"error":"Failed to parse context data","close_now":false}'
        return
    fi

    local close="false"
    [[ "$pct" -ge "$threshold" ]] && close="true"

    respond_tool_text "$id" "{\"close_now\":${close},\"usage_percent\":${pct},\"threshold\":${threshold}}"
}

# Portable mtime query: tries GNU stat first, then BSD stat, then falls back
# to a find -printf trick. Echoes an epoch timestamp, or nothing on failure.
file_mtime_epoch() {
    local path="$1"
    stat -c %Y "$path" 2>/dev/null && return
    stat -f %m "$path" 2>/dev/null && return
}

handle_check_health() {
    local id="$1"
    local context_present="false"
    local context_age="-1"
    local context_stale="unknown"
    local statusline_present="false"
    local statusline_executable="false"
    local overall="BROKEN"

    if [[ -f "$CONTEXT_FILE" ]]; then
        context_present="true"
        local mtime now
        mtime=$(file_mtime_epoch "$CONTEXT_FILE")
        now=$(date +%s)
        if [[ -n "$mtime" ]]; then
            context_age=$(( now - mtime ))
            if [[ "$context_age" -gt "$STALE_AFTER_SECONDS" ]]; then
                context_stale="true"
            else
                context_stale="false"
            fi
        fi
    fi

    if [[ -f "$STATUSLINE_SCRIPT" ]]; then
        statusline_present="true"
        if [[ -x "$STATUSLINE_SCRIPT" ]]; then
            statusline_executable="true"
        fi
    fi

    if [[ "$context_present" == "true" && "$context_stale" == "false" ]]; then
        overall="OK"
    elif [[ "$context_present" == "true" && "$context_stale" == "true" ]]; then
        overall="DEGRADED"
    fi

    local ctx_esc script_esc
    ctx_esc=$(json_escape "$CONTEXT_FILE")
    script_esc=$(json_escape "$STATUSLINE_SCRIPT")

    respond_tool_text "$id" "{\"overall\":\"${overall}\",\"context_file\":\"${ctx_esc}\",\"context_present\":${context_present},\"context_age_seconds\":${context_age},\"context_stale\":\"${context_stale}\",\"statusline_script\":\"${script_esc}\",\"statusline_present\":${statusline_present},\"statusline_executable\":${statusline_executable},\"stale_after_seconds\":${STALE_AFTER_SECONDS}}"
}

# --- Main loop ---

while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    method=$(json_get_str "$line" "method")
    id=$(json_get_num "$line" "id")

    case "$method" in
        initialize)
            handle_initialize "$id"
            ;;
        notifications/initialized)
            ;;
        tools/list)
            handle_tools_list "$id"
            ;;
        tools/call)
            tool_name=$(json_get_str "$line" "name")
            case "$tool_name" in
                get_context_status)
                    handle_get_context_status "$id"
                    ;;
                should_close_session)
                    threshold=$(json_get_num "$line" "threshold")
                    threshold=${threshold:-$THRESHOLD_WARNING}
                    handle_should_close_session "$id" "$threshold"
                    ;;
                check_health)
                    handle_check_health "$id"
                    ;;
                *)
                    respond_error "$id" -32601 "Unknown tool: $tool_name"
                    ;;
            esac
            ;;
        ping)
            respond_result "$id" '{}'
            ;;
        *)
            if [[ -n "$id" ]]; then
                respond_error "$id" -32601 "Method not found"
            fi
            ;;
    esac
done
