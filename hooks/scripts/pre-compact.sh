#!/bin/bash
# JARPA PreCompact hook - outputs prompt for context management

cat << 'EOF'
Context usage at 95%+. Before allowing compaction, trigger /jarpa:session-end to complete session documentation. If user declines, create minimal journal checkpoint entry documenting current state. Message user: 'Context at 95%+ - completing session documentation before compaction to maintain JARPA discipline.'
EOF
