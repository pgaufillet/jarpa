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

    Runs the real server.sh with --context-file to isolate tests from
    the live /tmp/claude-context.json.
    """
    stdin_data = "\n".join(json.dumps(m) for m in messages) + "\n"

    result = subprocess.run(
        [str(SERVER_SH), "--context-file", context_file],
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

    def test_lists_three_tools(self):
        """Server lists exactly three tools."""
        responses = call_server([
            {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}},
            {"jsonrpc": "2.0", "id": 2, "method": "tools/list"},
        ], context_file=self.context_file)
        tools_resp = responses[1]
        tools = tools_resp["result"]["tools"]
        self.assertEqual(len(tools), 3)
        names = {t["name"] for t in tools}
        self.assertEqual(names, {"get_context_status", "should_close_session", "check_health"})

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


class TestCheckHealth(unittest.TestCase):
    """Tests for the check_health tool."""

    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.context_file = os.path.join(self.temp_dir, "jarpa-context.json")

    def tearDown(self):
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def write_context(self, data):
        with open(self.context_file, "w") as f:
            json.dump(data, f)

    def call_tool(self):
        responses = call_server([
            {"jsonrpc": "2.0", "id": 1, "method": "tools/call",
             "params": {"name": "check_health", "arguments": {}}}
        ], context_file=self.context_file)
        text = responses[0]["result"]["content"][0]["text"]
        return json.loads(text)

    def test_broken_when_no_context_file(self):
        """Overall is BROKEN when context file is missing."""
        result = self.call_tool()
        self.assertEqual(result["overall"], "BROKEN")
        self.assertFalse(result["context_present"])
        self.assertEqual(result["context_age_seconds"], -1)
        self.assertEqual(result["context_stale"], "unknown")

    def test_reports_context_file_path(self):
        """check_health reports the resolved context file path."""
        result = self.call_tool()
        self.assertEqual(result["context_file"], self.context_file)

    def test_ok_when_context_fresh(self):
        """Overall is OK when context file exists and is fresh."""
        self.write_context({"usage_percent": 50})
        result = self.call_tool()
        self.assertEqual(result["overall"], "OK")
        self.assertTrue(result["context_present"])
        self.assertEqual(result["context_stale"], "false")
        self.assertGreaterEqual(result["context_age_seconds"], 0)

    def test_degraded_when_context_stale(self):
        """Overall is DEGRADED when context file is older than stale threshold."""
        self.write_context({"usage_percent": 42})
        # Backdate the file by 1 hour (well past 600s stale threshold)
        one_hour_ago = __import__("time").time() - 3600
        os.utime(self.context_file, (one_hour_ago, one_hour_ago))
        result = self.call_tool()
        self.assertEqual(result["overall"], "DEGRADED")
        self.assertEqual(result["context_stale"], "true")
        self.assertGreater(result["context_age_seconds"], 600)

    def test_reports_statusline_script(self):
        """check_health reports whether the statusline script is installed."""
        result = self.call_tool()
        self.assertIn("statusline_script", result)
        self.assertIn("statusline_present", result)
        self.assertIn("statusline_executable", result)
        # In the dev checkout, the statusline script should exist and be executable.
        self.assertTrue(result["statusline_present"])
        self.assertTrue(result["statusline_executable"])

    def test_stale_threshold_reported(self):
        """check_health reports the stale_after_seconds threshold it used."""
        result = self.call_tool()
        self.assertEqual(result["stale_after_seconds"], 600)


class TestContextFileResolution(unittest.TestCase):
    """Tests for context file path resolution rules."""

    def test_env_var_override(self):
        """JARPA_CONTEXT_FILE env var is used when --context-file is not provided."""
        temp_dir = tempfile.mkdtemp()
        try:
            ctx_path = os.path.join(temp_dir, "env-override.json")
            with open(ctx_path, "w") as f:
                json.dump({"usage_percent": 33}, f)
            env = os.environ.copy()
            env["JARPA_CONTEXT_FILE"] = ctx_path
            msg = json.dumps({
                "jsonrpc": "2.0", "id": 1, "method": "tools/call",
                "params": {"name": "get_context_status", "arguments": {}}
            }) + "\n"
            result = subprocess.run(
                [str(SERVER_SH)],
                input=msg,
                capture_output=True,
                text=True,
                timeout=10,
                env=env,
            )
            response = json.loads(result.stdout.strip().splitlines()[0])
            payload = json.loads(response["result"]["content"][0]["text"])
            self.assertEqual(payload["usage_percent"], 33)
        finally:
            shutil.rmtree(temp_dir, ignore_errors=True)

    def test_cli_flag_beats_env_var(self):
        """--context-file takes precedence over JARPA_CONTEXT_FILE."""
        temp_dir = tempfile.mkdtemp()
        try:
            env_path = os.path.join(temp_dir, "env.json")
            cli_path = os.path.join(temp_dir, "cli.json")
            with open(env_path, "w") as f:
                json.dump({"usage_percent": 11}, f)
            with open(cli_path, "w") as f:
                json.dump({"usage_percent": 77}, f)
            env = os.environ.copy()
            env["JARPA_CONTEXT_FILE"] = env_path
            msg = json.dumps({
                "jsonrpc": "2.0", "id": 1, "method": "tools/call",
                "params": {"name": "get_context_status", "arguments": {}}
            }) + "\n"
            result = subprocess.run(
                [str(SERVER_SH), "--context-file", cli_path],
                input=msg,
                capture_output=True,
                text=True,
                timeout=10,
                env=env,
            )
            response = json.loads(result.stdout.strip().splitlines()[0])
            payload = json.loads(response["result"]["content"][0]["text"])
            self.assertEqual(payload["usage_percent"], 77)
        finally:
            shutil.rmtree(temp_dir, ignore_errors=True)


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
