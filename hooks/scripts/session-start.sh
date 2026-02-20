#!/bin/bash
# JARPA SessionStart hook - triggers session-protocol agent for session start
#
# This hook instructs Claude to spawn the session-protocol agent which owns
# the full session lifecycle (start + end). The agent reads project state,
# presents a status summary, validates task scope, and checks archiving needs.

cat << 'EOF'
Invoke the session-protocol agent (subagent_type: jarpa:session-protocol) with the task: "Perform session-start workflow: read jarpa/PROJECT_PLAN.md, jarpa/TODO.md, and jarpa/JOURNAL.md. Present a 'where are we now' status summary. Validate that the current task scope fits one working session. Check if JOURNAL.md needs archiving."
EOF
