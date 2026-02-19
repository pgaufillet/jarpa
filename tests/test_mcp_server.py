#!/usr/bin/env python3
"""
Test suite for JARPA MCP context-monitor server.

Tests the actual get_context_status() and should_close_session() functions
with prepared fixtures. Requires mocking FastMCP since it may not be installed.

Usage:
    python3 tests/test_mcp_server.py
    python3 tests/test_mcp_server.py -v  # Verbose
"""

import asyncio
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch


# Mock FastMCP before importing server module
mock_fastmcp_module = MagicMock()
mock_mcp_instance = MagicMock()
mock_fastmcp_module.FastMCP.return_value = mock_mcp_instance
# Make @mcp.tool() a passthrough decorator
mock_mcp_instance.tool.return_value = lambda fn: fn

sys.modules["mcp"] = MagicMock()
sys.modules["mcp.server"] = MagicMock()
sys.modules["mcp.server.fastmcp"] = mock_fastmcp_module

# Now import the server module
sys.path.insert(0, str(Path(__file__).parent.parent / "mcp-servers" / "context-monitor"))
import server  # noqa: E402


class TestGetContextStatus(unittest.TestCase):
    """Tests for the get_context_status MCP tool function."""

    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.context_file = Path(self.temp_dir) / "claude-context.json"
        self._orig_context_file = server.CONTEXT_FILE
        server.CONTEXT_FILE = self.context_file

    def tearDown(self):
        server.CONTEXT_FILE = self._orig_context_file
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def write_context(self, data):
        self.context_file.write_text(json.dumps(data))

    def run_async(self, coro):
        return asyncio.run(coro)

    def test_ok_status_below_70(self):
        """Status is OK when usage is below 70%."""
        self.write_context({"usage_percent": 50})
        result = json.loads(self.run_async(server.get_context_status()))
        self.assertEqual(result["status"], "OK")
        self.assertEqual(result["usage_percent"], 50)
        self.assertIn("Continue working", result["recommendation"])

    def test_ok_status_headroom_calculation(self):
        """Headroom is correctly calculated as 85 - usage_percent."""
        self.write_context({"usage_percent": 60})
        result = json.loads(self.run_async(server.get_context_status()))
        self.assertIn("25%", result["recommendation"])

    def test_warning_status_at_70(self):
        """Status is WARNING at exactly 70%."""
        self.write_context({"usage_percent": 70})
        result = json.loads(self.run_async(server.get_context_status()))
        self.assertEqual(result["status"], "WARNING")
        self.assertIn("Approaching threshold", result["recommendation"])

    def test_warning_status_at_74(self):
        """Status is WARNING at 74% (just below critical)."""
        self.write_context({"usage_percent": 74})
        result = json.loads(self.run_async(server.get_context_status()))
        self.assertEqual(result["status"], "WARNING")

    def test_critical_status_at_75(self):
        """Status is CRITICAL at exactly 75%."""
        self.write_context({"usage_percent": 75})
        result = json.loads(self.run_async(server.get_context_status()))
        self.assertEqual(result["status"], "CRITICAL")
        self.assertIn("Close session now", result["recommendation"])

    def test_critical_status_at_100(self):
        """Status is CRITICAL at 100%."""
        self.write_context({"usage_percent": 100})
        result = json.loads(self.run_async(server.get_context_status()))
        self.assertEqual(result["status"], "CRITICAL")

    def test_missing_context_file_returns_error(self):
        """Returns error JSON when context file does not exist."""
        # context_file does not exist (not written in this test)
        self.assertFalse(self.context_file.exists())
        result = json.loads(self.run_async(server.get_context_status()))
        self.assertIn("error", result)
        self.assertIn("No context data available", result["error"])
        self.assertIn("suggestion", result)

    def test_malformed_json_returns_error(self):
        """Returns error JSON when context file has invalid JSON."""
        self.context_file.write_text("not valid json {{{")
        result = json.loads(self.run_async(server.get_context_status()))
        self.assertIn("error", result)
        self.assertIn("Failed to read context data", result["error"])

    def test_missing_usage_percent_defaults_to_zero(self):
        """Treats missing usage_percent as 0 (OK status)."""
        self.write_context({"some_other_field": 42})
        result = json.loads(self.run_async(server.get_context_status()))
        self.assertEqual(result["status"], "OK")

    def test_preserves_extra_fields(self):
        """Extra fields from context file are preserved in output."""
        self.write_context({"usage_percent": 50, "tokens_used": 50000, "tokens_max": 100000})
        result = json.loads(self.run_async(server.get_context_status()))
        self.assertEqual(result["tokens_used"], 50000)
        self.assertEqual(result["tokens_max"], 100000)

    def test_output_is_valid_json_string(self):
        """Return value is a JSON-formatted string, not a dict."""
        self.write_context({"usage_percent": 50})
        raw = self.run_async(server.get_context_status())
        self.assertIsInstance(raw, str)
        # Must be parseable
        parsed = json.loads(raw)
        self.assertIsInstance(parsed, dict)


class TestShouldCloseSession(unittest.TestCase):
    """Tests for the should_close_session MCP tool function."""

    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.context_file = Path(self.temp_dir) / "claude-context.json"
        self._orig_context_file = server.CONTEXT_FILE
        server.CONTEXT_FILE = self.context_file

    def tearDown(self):
        server.CONTEXT_FILE = self._orig_context_file
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def write_context(self, data):
        self.context_file.write_text(json.dumps(data))

    def run_async(self, coro):
        return asyncio.run(coro)

    def test_below_default_threshold(self):
        """close_now is False when usage is below default threshold (85)."""
        self.write_context({"usage_percent": 84})
        result = json.loads(self.run_async(server.should_close_session()))
        self.assertFalse(result["close_now"])
        self.assertEqual(result["usage_percent"], 84)
        self.assertEqual(result["threshold"], 85)

    def test_at_default_threshold(self):
        """close_now is True when usage equals default threshold (85)."""
        self.write_context({"usage_percent": 85})
        result = json.loads(self.run_async(server.should_close_session()))
        self.assertTrue(result["close_now"])

    def test_above_default_threshold(self):
        """close_now is True when usage exceeds default threshold."""
        self.write_context({"usage_percent": 90})
        result = json.loads(self.run_async(server.should_close_session()))
        self.assertTrue(result["close_now"])

    def test_custom_threshold(self):
        """Respects custom threshold parameter."""
        self.write_context({"usage_percent": 74})
        result = json.loads(self.run_async(server.should_close_session(threshold=75)))
        self.assertFalse(result["close_now"])

        result = json.loads(self.run_async(server.should_close_session(threshold=74)))
        self.assertTrue(result["close_now"])

    def test_missing_file_returns_no_close(self):
        """Returns close_now=False when context file is missing."""
        self.assertFalse(self.context_file.exists())
        result = json.loads(self.run_async(server.should_close_session()))
        self.assertFalse(result["close_now"])
        self.assertIn("error", result)

    def test_malformed_json_returns_no_close(self):
        """Returns close_now=False when context file has invalid JSON."""
        self.context_file.write_text("broken")
        result = json.loads(self.run_async(server.should_close_session()))
        self.assertFalse(result["close_now"])
        self.assertIn("error", result)

    def test_output_includes_threshold(self):
        """Output includes the threshold value used."""
        self.write_context({"usage_percent": 50})
        result = json.loads(self.run_async(server.should_close_session(threshold=60)))
        self.assertEqual(result["threshold"], 60)


class TestServerConfiguration(unittest.TestCase):
    """Tests for server module-level configuration."""

    def test_context_file_path(self):
        """Server reads from /tmp/claude-context.json by default."""
        # Test against the module's original constant, not our test override
        # We check the source file to avoid interference from setUp patching
        source = (Path(__file__).parent.parent / "mcp-servers" / "context-monitor" / "server.py").read_text()
        self.assertIn('CONTEXT_FILE = Path("/tmp/claude-context.json")', source)

    def test_transport_mode(self):
        """Server uses stdio transport."""
        source = (Path(__file__).parent.parent / "mcp-servers" / "context-monitor" / "server.py").read_text()
        self.assertIn('transport="stdio"', source)

    def test_server_defines_two_tools(self):
        """Server defines exactly two tool functions."""
        self.assertTrue(callable(server.get_context_status))
        self.assertTrue(callable(server.should_close_session))


if __name__ == "__main__":
    unittest.main(verbosity=2)
