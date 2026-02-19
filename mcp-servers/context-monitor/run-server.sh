#!/bin/bash
exec "$HOME/.claude/mcp-venv/bin/python" "$(dirname "$0")/server.py"
