#!/bin/bash
# JARPA PreCompact hook - outputs prompt for context management

cat << 'EOF'
Context near exhaustion. Before allowing compaction, trigger /jarpa:session-end to complete session documentation. If user declines, create minimal journal checkpoint entry documenting current state. Message user: 'Context near exhaustion - completing session documentation before compaction to maintain JARPA discipline.'
EOF
