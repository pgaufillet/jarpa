#!/bin/bash
# JARPA PreToolUse hook - checks for journal entry before git commits
# Note: This hook fires on all Bash tool invocations (matcher: "Bash").
# The prompt instructs Claude to only act on git commit commands.

cat << 'EOF'
If this Bash command is a git commit (contains "git commit"), check if jarpa/JOURNAL.md has an entry from today (use `date +%F` to get current date, then grep for that date in JOURNAL.md). If journal entry exists or this is not a git commit: allow the command to proceed silently. If no journal entry found and this is a git commit: display reminder message 'JARPA Reminder: Best practice is to document work in JOURNAL.md before committing.' but allow the commit to proceed (educational, not blocking).
EOF
