#!/bin/bash
# JARPA SessionStart hook - triggers session status display
#
# This hook instructs Claude to invoke the /jarpa:status command
# which reads project docs and presents a formatted status summary.

cat << 'EOF'
Invoke the /jarpa:status command now to display the current project status before proceeding with any user requests.
EOF
