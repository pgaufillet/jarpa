#!/bin/bash
#
# JARPA Plugin - Claude Code Integration Test
#
# Tests that require a Claude Code environment.
# Run this AFTER installing the plugin in Claude Code.
#
# Usage:
#   ./tests/test_claude_code_integration.sh
#
# Prerequisites:
#   - Claude Code CLI installed and accessible as 'claude'
#   - JARPA plugin installed (via settings.json or --plugin-dir)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

log_pass() {
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_fail() {
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}[FAIL]${NC} $1"
}

log_skip() {
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    echo -e "${YELLOW}[SKIP]${NC} $1"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║        JARPA Plugin - Claude Code Integration Tests        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check prerequisites
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Prerequisites"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check Claude CLI exists
if command -v claude &>/dev/null; then
    log_pass "Claude CLI is installed"
    CLAUDE_VERSION=$(claude --version 2>/dev/null || echo "unknown")
    log_info "  Version: $CLAUDE_VERSION"
else
    log_fail "Claude CLI not found in PATH"
    echo ""
    echo "Install Claude Code first: https://claude.ai/code"
    exit 1
fi

# Check if plugin is configured
SETTINGS_FILE="$HOME/.claude/settings.json"
if [[ -f "$SETTINGS_FILE" ]]; then
    if grep -q "jarpa" "$SETTINGS_FILE" 2>/dev/null; then
        log_pass "JARPA plugin found in settings.json"
    else
        log_skip "JARPA not in settings.json (may use --plugin-dir)"
    fi
else
    log_skip "No settings.json found"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " MCP Server Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test MCP server can start
MCP_SERVER="$PLUGIN_ROOT/mcp-servers/context-monitor/server.py"
if [[ -f "$MCP_SERVER" ]]; then
    # Try to import and check syntax
    if python3 -c "import sys; sys.path.insert(0, '$(dirname "$MCP_SERVER")'); exec(open('$MCP_SERVER').read().split('if __name__')[0])" 2>/dev/null; then
        log_pass "MCP server Python syntax valid"
    else
        # Check if it's just missing mcp module
        if python3 -c "from mcp.server.fastmcp import FastMCP" 2>/dev/null; then
            log_pass "MCP FastMCP module available"
        else
            log_skip "MCP server needs 'mcp' package (pip install mcp)"
        fi
    fi

    # Test server can be invoked (will fail fast if broken)
    log_info "Testing MCP server startup (5s timeout)..."
    if timeout 5 python3 "$MCP_SERVER" --help 2>/dev/null; then
        log_pass "MCP server responds to --help"
    else
        # Server doesn't have --help, try starting it briefly
        if timeout 2 python3 "$MCP_SERVER" 2>&1 | head -1 | grep -q "Error\|Traceback"; then
            log_fail "MCP server has startup errors"
        else
            log_pass "MCP server starts without immediate errors"
        fi
    fi
else
    log_fail "MCP server file not found: $MCP_SERVER"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Hook Script Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test hook scripts execute without error
for script in session-start.sh session-end.sh pre-compact.sh pre-commit.sh; do
    script_path="$PLUGIN_ROOT/hooks/scripts/$script"
    if [[ -x "$script_path" ]]; then
        output=$("$script_path" 2>&1)
        if [[ -n "$output" ]]; then
            log_pass "Hook $script executes and produces output"
        else
            log_fail "Hook $script produces no output"
        fi
    else
        log_fail "Hook $script not executable"
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Plugin Path Resolution"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Simulate CLAUDE_PLUGIN_ROOT resolution
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

# Check hooks.json paths resolve
log_info "Testing \${CLAUDE_PLUGIN_ROOT} path resolution..."
hooks_json="$PLUGIN_ROOT/hooks/hooks.json"
script_refs=$(jq -r '.. | .command? // empty' "$hooks_json" 2>/dev/null | sed "s|\${CLAUDE_PLUGIN_ROOT}|$PLUGIN_ROOT|g")

all_resolve=true
for ref in $script_refs; do
    if [[ -f "$ref" ]]; then
        log_pass "Path resolves: $(basename "$ref")"
    else
        log_fail "Path not found: $ref"
        all_resolve=false
    fi
done

# Check .mcp.json paths resolve
mcp_json="$PLUGIN_ROOT/.mcp.json"
mcp_refs=$(jq -r '.. | strings' "$mcp_json" 2>/dev/null | grep '\${CLAUDE_PLUGIN_ROOT}' | sed "s|\${CLAUDE_PLUGIN_ROOT}|$PLUGIN_ROOT|g")

for ref in $mcp_refs; do
    if [[ -f "$ref" ]]; then
        log_pass "MCP path resolves: $(basename "$ref")"
    else
        log_fail "MCP path not found: $ref"
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Interactive Test Instructions"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "The following tests require manual verification in Claude Code:"
echo ""
echo -e "1. Start Claude Code with the plugin:"
echo -e "   ${BLUE}claude --plugin-dir $PLUGIN_ROOT${NC}"
echo ""
echo -e "2. Verify commands are registered:"
echo -e "   ${BLUE}/help${NC}"
echo "   Look for: jarpa:init, jarpa:status, jarpa:archive, etc."
echo ""
echo -e "3. Run the installation test command:"
echo -e "   ${BLUE}/jarpa:test-installation${NC}"
echo ""
echo "4. Test SessionStart hook (start new session):"
echo "   - Hook should trigger /jarpa:status automatically"
echo ""
echo -e "5. Check MCP server:"
echo -e "   ${BLUE}/mcp${NC}"
echo "   Look for: context-monitor server"
echo ""

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Automated Test Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "  Total:   $TESTS_RUN"
echo -e "  ${GREEN}Passed:${NC}  $TESTS_PASSED"
echo -e "  ${RED}Failed:${NC}  $TESTS_FAILED"
echo -e "  ${YELLOW}Skipped:${NC} $TESTS_SKIPPED"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ Automated tests passed!${NC}"
    echo ""
    echo "Run manual tests above to complete verification."
    exit 0
else
    echo -e "${RED}✗ Some automated tests failed.${NC}"
    exit 1
fi
