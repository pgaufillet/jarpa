#!/bin/bash
# JARPA SessionStart hook
#
# 1. Ensure the JARPA statusline is configured in the project's
#    .claude/settings.json (auto-install on first session).
# 2. Trigger the session-protocol agent for the full start workflow.

SETTINGS="${CLAUDE_PROJECT_DIR:-.}/.claude/settings.json"
# Resolved path — ${CLAUDE_PLUGIN_ROOT} is NOT expanded in settings.json,
# so we must write the full path and refresh it on every session start.
STATUSLINE_SCRIPT="${CLAUDE_PLUGIN_ROOT}/mcp-servers/context-monitor/statusline.sh"
STATUSLINE_CMD="bash ${STATUSLINE_SCRIPT}"
ESCAPED_CMD=$(printf '%s' "$STATUSLINE_CMD" | sed 's/[&/\]/\\&/g')

ensure_statusline() {
    mkdir -p "$(dirname "$SETTINGS")" 2>/dev/null || true

    if [[ -f "$SETTINGS" ]] && grep -q 'statusline\.sh' "$SETTINGS" 2>/dev/null; then
        # JARPA statusline present — refresh path to current plugin version
        if ! grep -qF "$STATUSLINE_SCRIPT" "$SETTINGS" 2>/dev/null; then
            sed -i "s|bash [^\"]*statusline\.sh|${ESCAPED_CMD}|" "$SETTINGS"
        fi
        return
    fi

    if [[ ! -f "$SETTINGS" ]]; then
        cat > "$SETTINGS" << SEOF
{
  "statusLine": {
    "type": "command",
    "command": "${STATUSLINE_CMD}"
  }
}
SEOF
    elif ! grep -q '"statusLine"' "$SETTINGS" 2>/dev/null; then
        sed -i 's/}$/,\n  "statusLine": {\n    "type": "command",\n    "command": "'"${ESCAPED_CMD}"'"\n  }\n}/' "$SETTINGS"
    fi
}

ensure_statusline

cat << 'EOF'
Invoke the session-protocol agent (subagent_type: jarpa:session-protocol) with the task: "Perform session-start workflow: read jarpa/PROJECT_PLAN.md, jarpa/TODO.md, and jarpa/JOURNAL.md. Present a 'where are we now' status summary. Validate that the current task scope fits one working session. Check if JOURNAL.md needs archiving."
EOF
