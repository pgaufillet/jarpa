#!/usr/bin/env python3
"""
MCP Server for Claude Code context monitoring.

Reads context data from /tmp/claude-context.json (produced by statusline.sh).
Minimal CPU usage - only reads file when tool is called.

Setup:
  pip install mcp
  claude mcp add --transport stdio --scope user context-monitor -- python3 ~/.claude/mcp-servers/context-monitor/server.py
"""

import json
import sys
from pathlib import Path

try:
    from mcp.server.fastmcp import FastMCP
except ImportError:
    print("Error: mcp not installed. Run: pip install mcp", file=sys.stderr)
    sys.exit(1)

mcp = FastMCP("context-monitor")

CONTEXT_FILE = Path("/tmp/claude-context.json")


@mcp.tool()
async def get_context_status() -> str:
    """
    Get current Claude Code context window usage.

    Returns JSON with usage_percent, threshold warnings, and recommendations.
    Data is provided by the statusline (updates in real-time).
    """
    if not CONTEXT_FILE.exists():
        return json.dumps({
            "error": "No context data available",
            "suggestion": "Ensure statusline is configured in Claude Code settings"
        }, indent=2)

    try:
        data = json.loads(CONTEXT_FILE.read_text())
    except (json.JSONDecodeError, OSError) as e:
        return json.dumps({"error": f"Failed to read context data: {e}"}, indent=2)

    # Add recommendations based on threshold
    pct = data.get("usage_percent", 0)
    if pct >= 75:
        data["status"] = "CRITICAL"
        data["recommendation"] = "Close session now. Update JOURNAL.md and TODO.md before context is exhausted."
    elif pct >= 70:
        data["status"] = "WARNING"
        data["recommendation"] = "Approaching threshold. Plan to close session soon."
    else:
        data["status"] = "OK"
        data["recommendation"] = f"Continue working. {85 - pct}% headroom until threshold."

    return json.dumps(data, indent=2)


@mcp.tool()
async def should_close_session(threshold: int = 85) -> str:
    """
    Quick check if session should be closed based on context threshold.

    Args:
        threshold: Percentage threshold (default: 85)

    Returns JSON with boolean 'close_now' and current percentage.
    """
    if not CONTEXT_FILE.exists():
        return json.dumps({"error": "No context data", "close_now": False})

    try:
        data = json.loads(CONTEXT_FILE.read_text())
        pct = data.get("usage_percent", 0)
        return json.dumps({
            "close_now": pct >= threshold,
            "usage_percent": pct,
            "threshold": threshold
        })
    except Exception as e:
        return json.dumps({"error": str(e), "close_now": False})


if __name__ == "__main__":
    mcp.run(transport="stdio")
