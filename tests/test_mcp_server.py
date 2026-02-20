#!/usr/bin/env python3
"""
Test suite for JARPA MCP context-monitor server (bash implementation).

Tests the server as a black box: sends JSON-RPC messages on stdin,
verifies responses on stdout. No external dependencies beyond Python stdlib.

Usage:
    python3 tests/test_mcp_server.py
    python3 tests/test_mcp_server.py -v  # Verbose
"""

import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


SERVER_SH = Path(__file__).parent.parent / "mcp-servers" / "context-monitor" / "server.sh"


def call_server(messages, context_file):
    """Send JSON-RPC messages to the bash server, return parsed responses.

    Always patches the hardcoded context file path to isolate tests from
    the real /tmp/claude-context.json (which may be active if Claude Code
    is running).
    """
    stdin_data = "\n".join(json.dumps(m) for m in messages) + "\n"

    script = SERVER_SH.read_text().replace(
        'CONTEXT_FILE="/tmp/claude-context.json"',
        f'CONTEXT_FILE="{context_file}"',
    )

    result = subprocess.run(
        ["bash", "-c", script],
        input=stdin_data,
        capture_output=True,
        text=True,
        timeout=10,
    )

    responses = []
    for line in result.stdout.strip().splitlines():
        if line:
            responses.append(json.loads(line))
    return responses


class TestInitialize(unittest.TestCase):
    """Tests for the MCP initialize handshake."""

    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.context_file = os.path.join(self.temp_dir, "ctx.json")

    def tearDown(self):
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_initialize_response(self):
        """Server responds to initialize with protocol version and capabilities."""
        responses = call_server([
            {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}}
        ], context_file=self.context_file)
        self.assertEqual(len(responses), 1)
        r = responses[0]
        self.assertEqual(r["id"], 1)
        self.assertEqual(r["result"]["protocolVersion"], "2024-11-05")
        self.assertIn("tools", r["result"]["capabilities"])
        self.assertEqual(r["result"]["serverInfo"]["name"], "context-monitor")


class TestToolsList(unittest.TestCase):
    """Tests for the tools/list method."""

    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.context_file = os.path.join(self.temp_dir, "ctx.json")

    def tearDown(self):
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_lists_two_tools(self):
        """Server lists exactly two tools."""
        responses = call_server([
            {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}},
            {"jsonrpc": "2.0", "id": 2, "method": "tools/list"},
        ], context_file=self.context_file)
        tools_resp = responses[1]
        tools = tools_resp["result"]["tools"]
        self.assertEqual(len(tools), 2)
        names = {t["name"] for t in tools}
        self.assertEqual(names, {"get_context_status", "should_close_session"})

    def test_tool_schemas_present(self):
        """Each tool has an inputSchema."""
        responses = call_server([
            {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}},
            {"jsonrpc": "2.0", "id": 2, "method": "tools/list"},
        ], context_file=self.context_file)
        for tool in responses[1]["result"]["tools"]:
            self.assertIn("inputSchema", tool)


class TestGetContextStatus(unittest.TestCase):
    """Tests for the get_context_status tool."""

    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.context_file = os.path.join(self.temp_dir, "claude-context.json")

    def tearDown(self):
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def write_context(self, data):
        with open(self.context_file, "w") as f:
            json.dump(data, f)

    def call_tool(self):
        responses = call_server([
            {"jsonrpc": "2.0", "id": 1, "method": "tools/call",
             "params": {"name": "get_context_status", "arguments": {}}}
        ], context_file=self.context_file)
        text = responses[0]["result"]["content"][0]["text"]
        return json.loads(text)

    def test_ok_status_below_75(self):
        """Status is OK when usage is below 75%."""
        self.write_context({"usage_percent": 50})
        result = self.call_tool()
        self.assertEqual(result["status"], "OK")
        self.assertEqual(result["usage_percent"], 50)
        self.assertIn("Continue working", result["recommendation"])

    def test_ok_headroom_calculation(self):
        """Headroom is correctly calculated as 75 - usage_percent."""
        self.write_context({"usage_percent": 60})
        result = self.call_tool()
        self.assertIn("15%", result["recommendation"])

    def test_warning_at_75(self):
        """Status is WARNING at exactly 75%."""
        self.write_context({"usage_percent": 75})
        result = self.call_tool()
        self.assertEqual(result["status"], "WARNING")
        self.assertIn("Approaching threshold", result["recommendation"])

    def test_warning_at_89(self):
        """Status is WARNING at 89% (just below critical)."""
        self.write_context({"usage_percent": 89})
        result = self.call_tool()
        self.assertEqual(result["status"], "WARNING")

    def test_critical_at_90(self):
        """Status is CRITICAL at exactly 90%."""
        self.write_context({"usage_percent": 90})
        result = self.call_tool()
        self.assertEqual(result["status"], "CRITICAL")
        self.assertIn("Close session now", result["recommendation"])

    def test_critical_at_100(self):
        """Status is CRITICAL at 100%."""
        self.write_context({"usage_percent": 100})
        result = self.call_tool()
        self.assertEqual(result["status"], "CRITICAL")

    def test_missing_file(self):
        """Returns error when context file does not exist."""
        os.remove(self.context_file) if os.path.exists(self.context_file) else None
        result = self.call_tool()
        self.assertIn("error", result)
        self.assertIn("No context data", result["error"])

    def test_missing_usage_percent_defaults_to_zero(self):
        """Treats missing usage_percent as 0 (OK status)."""
        self.write_context({"some_other_field": 42})
        result = self.call_tool()
        self.assertEqual(result["status"], "OK")


class TestShouldCloseSession(unittest.TestCase):
    """Tests for the should_close_session tool."""

    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.context_file = os.path.join(self.temp_dir, "claude-context.json")

    def tearDown(self):
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def write_context(self, data):
        with open(self.context_file, "w") as f:
            json.dump(data, f)

    def call_tool(self, threshold=None):
        args = {"threshold": threshold} if threshold is not None else {}
        responses = call_server([
            {"jsonrpc": "2.0", "id": 1, "method": "tools/call",
             "params": {"name": "should_close_session", "arguments": args}}
        ], context_file=self.context_file)
        text = responses[0]["result"]["content"][0]["text"]
        return json.loads(text)

    def test_below_default_threshold(self):
        """close_now is False when usage is below default threshold (75)."""
        self.write_context({"usage_percent": 74})
        result = self.call_tool()
        self.assertFalse(result["close_now"])
        self.assertEqual(result["usage_percent"], 74)
        self.assertEqual(result["threshold"], 75)

    def test_at_default_threshold(self):
        """close_now is True when usage equals default threshold (75)."""
        self.write_context({"usage_percent": 75})
        result = self.call_tool()
        self.assertTrue(result["close_now"])

    def test_above_default_threshold(self):
        """close_now is True when usage exceeds default threshold."""
        self.write_context({"usage_percent": 80})
        result = self.call_tool()
        self.assertTrue(result["close_now"])

    def test_custom_threshold(self):
        """Respects custom threshold parameter."""
        self.write_context({"usage_percent": 60})
        result = self.call_tool(threshold=50)
        self.assertTrue(result["close_now"])
        self.assertEqual(result["threshold"], 50)

    def test_custom_threshold_below(self):
        """close_now is False when below custom threshold."""
        self.write_context({"usage_percent": 40})
        result = self.call_tool(threshold=50)
        self.assertFalse(result["close_now"])

    def test_missing_file(self):
        """Returns close_now=False when context file is missing."""
        result = self.call_tool()
        self.assertFalse(result["close_now"])
        self.assertIn("error", result)

    def test_output_includes_threshold(self):
        """Output includes the threshold value used."""
        self.write_context({"usage_percent": 50})
        result = self.call_tool(threshold=60)
        self.assertEqual(result["threshold"], 60)


class TestServerBehavior(unittest.TestCase):
    """Tests for server-level behavior."""

    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.context_file = os.path.join(self.temp_dir, "ctx.json")

    def tearDown(self):
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_server_script_exists(self):
        """server.sh exists and is executable."""
        self.assertTrue(SERVER_SH.exists())
        self.assertTrue(os.access(SERVER_SH, os.X_OK))

    def test_server_has_shebang(self):
        """server.sh starts with bash shebang."""
        first_line = SERVER_SH.read_text().splitlines()[0]
        self.assertEqual(first_line, "#!/bin/bash")

    def test_unknown_method_returns_error(self):
        """Server returns error for unknown methods."""
        responses = call_server([
            {"jsonrpc": "2.0", "id": 99, "method": "nonexistent"}
        ], context_file=self.context_file)
        self.assertEqual(len(responses), 1)
        self.assertIn("error", responses[0])
        self.assertEqual(responses[0]["error"]["code"], -32601)

    def test_notification_no_response(self):
        """Server does not respond to notifications (no id)."""
        responses = call_server([
            {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}},
            {"jsonrpc": "2.0", "method": "notifications/initialized"},
            {"jsonrpc": "2.0", "id": 2, "method": "ping"},
        ], context_file=self.context_file)
        # Should get 2 responses (initialize + ping), not 3
        self.assertEqual(len(responses), 2)
        self.assertEqual(responses[0]["id"], 1)
        self.assertEqual(responses[1]["id"], 2)

    def test_ping(self):
        """Server responds to ping with empty result."""
        responses = call_server([
            {"jsonrpc": "2.0", "id": 42, "method": "ping"}
        ], context_file=self.context_file)
        self.assertEqual(responses[0]["id"], 42)
        self.assertEqual(responses[0]["result"], {})


if __name__ == "__main__":
    unittest.main(verbosity=2)
