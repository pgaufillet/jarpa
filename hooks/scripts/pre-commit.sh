#!/bin/bash
# JARPA PreToolUse hook — reminds to update JOURNAL.md before git commits.
#
# Registered on matcher "Bash", so Claude Code calls this script on every
# Bash tool invocation. To keep the hook cheap, parse the tool input and
# exit silently unless the command is a `git commit`.

set -uo pipefail

input=$(cat)

# Extract tool_input.command from the JSON payload without jq.
# Expected input shape:
#   {"tool_name":"Bash","tool_input":{"command":"git commit -m ..."}, ...}
command=$(printf '%s' "$input" \
    | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(\([^"\\]\|\\.\)*\)".*/\1/p')

# Quick exit for anything that isn't a git commit.
case "$command" in
    *"git commit"*) ;;
    *) exit 0 ;;
esac

cat <<'EOF'
JARPA Reminder: best practice is to document this work in jarpa/JOURNAL.md
before committing. Check whether today's journal entry exists (compare
`date +%F` against headers in jarpa/JOURNAL.md). The commit is not blocked —
this reminder is educational.
EOF
