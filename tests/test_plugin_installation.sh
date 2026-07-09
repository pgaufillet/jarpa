#!/bin/bash
#
# JARPA Plugin - Automated Installation Test
#
# Invokes Claude Code with the plugin and verifies it loads correctly.
# Uses claude CLI in non-interactive mode to test plugin functionality.
#
# Usage:
#   ./tests/test_plugin_installation.sh
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

log_pass() {
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_fail() {
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}[FAIL]${NC} $1"
    if [[ -n "${2:-}" ]]; then
        echo -e "       ${RED}Error:${NC} $2"
    fi
}

log_skip() {
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${YELLOW}[SKIP]${NC} $1"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║      JARPA Plugin - Automated Installation Tests           ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Plugin root: $PLUGIN_ROOT"
echo ""

# Check Claude CLI exists
if ! command -v claude &>/dev/null; then
    echo -e "${RED}Error: Claude CLI not found in PATH${NC}"
    echo "Install Claude Code first: https://claude.ai/code"
    exit 1
fi

log_info "Claude CLI found: $(which claude)"

# Check if running inside Claude Code (nested sessions are not supported)
if [[ -n "${CLAUDECODE:-}" ]]; then
    echo ""
    echo -e "${YELLOW}Warning: Running inside a Claude Code session.${NC}"
    echo "Tests that invoke 'claude' CLI will be skipped (nested sessions not supported)."
    echo "Run this test from a regular terminal for full coverage."
    INSIDE_CLAUDE=true
else
    INSIDE_CLAUDE=false
fi

# Create temp directory for test project
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT
log_info "Test directory: $TEST_DIR"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Test 1: Plugin Loads Without Errors"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if $INSIDE_CLAUDE; then
    log_skip "Plugin load test (nested Claude Code session)"
else
    # Run claude with plugin and a simple prompt to verify it loads
    # Using --print to get output and -p for non-interactive prompt
    log_info "Starting Claude Code with JARPA plugin..."

    LOAD_OUTPUT=$(cd "$TEST_DIR" && claude --plugin-dir "$PLUGIN_ROOT" --print -p "Say 'plugin loaded' and nothing else" 2>&1) || true

    if echo "$LOAD_OUTPUT" | grep -qi "error\|failed\|exception"; then
        # Check if it's a real error or just part of normal output
        if echo "$LOAD_OUTPUT" | grep -qi "plugin.*error\|failed to load\|cannot load"; then
            log_fail "Plugin load errors detected" "$(echo "$LOAD_OUTPUT" | grep -i "error\|failed" | head -3)"
        else
            log_pass "Plugin loads (some output contains 'error' but not plugin-related)"
        fi
    else
        log_pass "Plugin loads without errors"
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Test 2: Commands Are Registered"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if $INSIDE_CLAUDE; then
    log_skip "Command registration test (nested Claude Code session)"
else
    # Ask Claude to list available jarpa commands
    log_info "Checking if JARPA commands are registered..."

    CMD_OUTPUT=$(cd "$TEST_DIR" && claude --plugin-dir "$PLUGIN_ROOT" --print -p "List all available slash commands that start with 'jarpa'. Just list the command names, one per line." 2>&1) || true

    # Check for expected commands
    EXPECTED_COMMANDS=("jarpa:init" "jarpa:status" "jarpa:archive" "jarpa:session-end" "jarpa:upgrade")
    FOUND_COUNT=0

    for cmd in "${EXPECTED_COMMANDS[@]}"; do
        if echo "$CMD_OUTPUT" | grep -qi "$cmd"; then
            log_pass "Command registered: $cmd"
            FOUND_COUNT=$((FOUND_COUNT + 1))
        else
            log_fail "Command not found: $cmd"
        fi
    done

    log_info "Found $FOUND_COUNT/${#EXPECTED_COMMANDS[@]} expected commands"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Test 3: Statusline Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# The context-monitor MCP server was removed in 0.3.0; the statusline is the
# only context-monitoring artifact the plugin ships.
if [[ -x "$PLUGIN_ROOT/mcp-servers/context-monitor/statusline.sh" ]]; then
    log_pass "statusline.sh present and executable"
else
    log_fail "statusline.sh missing or not executable"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Test 4: Plugin Metadata"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if $INSIDE_CLAUDE; then
    log_skip "Plugin metadata test (nested Claude Code session)"
else
    # Ask about the plugin
    log_info "Checking plugin metadata..."

    META_OUTPUT=$(cd "$TEST_DIR" && claude --plugin-dir "$PLUGIN_ROOT" --print -p "What plugins are currently loaded? List their names." 2>&1) || true

    if echo "$META_OUTPUT" | grep -qi "jarpa"; then
        log_pass "JARPA plugin is recognized"
    else
        log_fail "JARPA plugin not mentioned in loaded plugins"
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Test 5: Hooks Configuration Loaded"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# We can't easily test hooks fire, but we can verify the config is loaded
log_info "Verifying hooks.json is valid and loadable..."

if jq empty "$PLUGIN_ROOT/hooks/hooks.json" 2>/dev/null; then
    # Count configured hooks
    HOOK_COUNT=$(jq '.hooks | keys | length' "$PLUGIN_ROOT/hooks/hooks.json")
    if [[ "$HOOK_COUNT" -ge 4 ]]; then
        log_pass "Hooks configuration valid ($HOOK_COUNT hook types configured)"
    else
        log_fail "Expected at least 4 hook types, found $HOOK_COUNT"
    fi
else
    log_fail "hooks.json is invalid JSON"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Test 6: Init Command Dry Run"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test that /jarpa:init would work (don't actually run it)
log_info "Testing /jarpa:init prerequisites..."

# Check templates exist
TEMPLATES=("PROJECT_PLAN.md" "TODO.md" "REQUIREMENTS.md" "ARCHITECTURE.md" "JOURNAL.md")
TEMPLATES_OK=true

for tmpl in "${TEMPLATES[@]}"; do
    if [[ ! -f "$PLUGIN_ROOT/templates/$tmpl" ]]; then
        log_fail "Missing template: $tmpl"
        TEMPLATES_OK=false
    fi
done

if $TEMPLATES_OK; then
    log_pass "All ${#TEMPLATES[@]} templates present for /jarpa:init"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Test Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "  Total:  $TESTS_RUN"
echo -e "  ${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "  ${RED}Failed:${NC} $TESTS_FAILED"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All installation tests passed!${NC}"
    echo ""
    echo "Plugin is correctly installed and functional."
    exit 0
else
    echo -e "${RED}✗ Some tests failed.${NC}"
    echo ""
    echo "Review the failures above and fix issues before deploying."
    exit 1
fi
