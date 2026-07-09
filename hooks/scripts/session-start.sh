#!/bin/bash
# JARPA SessionStart hook
#
# 1. Ensure the JARPA statusline is configured in the project's
#    .claude/settings.json (auto-install on first session).
# 2. Trigger the /jarpa:session-start command for the full start workflow.

SETTINGS="${CLAUDE_PROJECT_DIR:-.}/.claude/settings.json"
# Resolved path — ${CLAUDE_PLUGIN_ROOT} is NOT expanded in settings.json,
# so we must write the full path and refresh it on every session start.
STATUSLINE_SCRIPT="${CLAUDE_PLUGIN_ROOT}/statusline/statusline.sh"
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
Automatically invoke the /jarpa:session-start command to present the current JARPA status, validate task scope, and check journal archiving needs.
EOF
