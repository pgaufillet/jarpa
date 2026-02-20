#!/bin/bash
#
# JARPA Context Monitor — MCP Server (pure bash)
#
# Reads context data from /tmp/claude-context.json (produced by statusline).
# Implements MCP protocol over stdio (JSON-RPC 2.0, newline-delimited).
#
# Dependencies: bash only. No jq, no Python, no pip.
#

set -uo pipefail

CONTEXT_FILE="/tmp/claude-context.json"

# Canonical thresholds — master values in jarpa/ARCHITECTURE.md "Canonical Values"
THRESHOLD_WARNING=75
THRESHOLD_CRITICAL=90

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
    respond_result "$1" '{"protocolVersion":"2024-11-05","capabilities":{"tools":{}},"serverInfo":{"name":"context-monitor","version":"0.1.0"}}'
}

handle_tools_list() {
    local id="$1"
    respond_result "$id" "{\"tools\":[{\"name\":\"get_context_status\",\"description\":\"Get current Claude Code context window usage.\\n\\nReturns JSON with usage_percent, threshold warnings, and recommendations.\\nData is provided by the statusline (updates in real-time).\",\"inputSchema\":{\"type\":\"object\",\"properties\":{},\"required\":[]}},{\"name\":\"should_close_session\",\"description\":\"Quick check if session should be closed based on context threshold.\\n\\nArgs:\\n    threshold: Percentage threshold (default: ${THRESHOLD_WARNING})\\n\\nReturns JSON with boolean close_now and current percentage.\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"threshold\":{\"type\":\"integer\",\"default\":${THRESHOLD_WARNING},\"description\":\"Percentage threshold (default: ${THRESHOLD_WARNING})\"}},\"required\":[]}}]}"
}

handle_get_context_status() {
    local id="$1"

    if [[ ! -f "$CONTEXT_FILE" ]]; then
        respond_tool_text "$id" '{"error":"No context data available","suggestion":"Ensure statusline is configured in Claude Code settings"}'
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
