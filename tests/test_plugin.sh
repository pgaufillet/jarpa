#!/bin/bash
#
# JARPA Plugin Automated Test Suite
#
# Validates plugin structure, configurations, and basic functionality
# without requiring a running Claude Code instance.
#
# Usage:
#   ./tests/test_plugin.sh           # Run all tests
#   ./tests/test_plugin.sh -v        # Verbose output
#   ./tests/test_plugin.sh manifest  # Run specific test group
#
# Test groups: manifest, hooks, mcp, agents, commands, skills, templates, scripts
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
VERBOSE=false

# Parse arguments
TEST_GROUP=""
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose) VERBOSE=true; shift ;;
        *) TEST_GROUP="$1"; shift ;;
    esac
done

# Test helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_verbose() {
    if $VERBOSE; then
        echo -e "       $1"
    fi
}

assert_file_exists() {
    local file="$1"
    local desc="${2:-File exists: $file}"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ -f "$file" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "$desc"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_fail "$desc"
        log_verbose "  Expected file: $file"
        return 1
    fi
}

assert_dir_exists() {
    local dir="$1"
    local desc="${2:-Directory exists: $dir}"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ -d "$dir" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "$desc"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_fail "$desc"
        return 1
    fi
}

assert_json_valid() {
    local file="$1"
    local desc="${2:-Valid JSON: $file}"
    TESTS_RUN=$((TESTS_RUN + 1))
    if jq empty "$file" 2>/dev/null; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "$desc"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_fail "$desc"
        log_verbose "  $(jq empty "$file" 2>&1)"
        return 1
    fi
}

assert_json_has_field() {
    local file="$1"
    local field="$2"
    local desc="${3:-JSON has field '$field': $file}"
    TESTS_RUN=$((TESTS_RUN + 1))
    if jq -e "$field" "$file" >/dev/null 2>&1; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "$desc"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_fail "$desc"
        return 1
    fi
}

assert_yaml_frontmatter() {
    local file="$1"
    local desc="${2:-Has YAML frontmatter: $file}"
    TESTS_RUN=$((TESTS_RUN + 1))
    # Check file starts with --- and has closing ---
    if head -1 "$file" | grep -q "^---$" && awk '/^---$/{c++}c==2{exit}END{exit(c<2)}' "$file"; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "$desc"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_fail "$desc"
        return 1
    fi
}

assert_yaml_has_field() {
    local file="$1"
    local field="$2"
    local desc="${3:-YAML has field '$field': $(basename "$file")}"
    TESTS_RUN=$((TESTS_RUN + 1))
    # Extract YAML frontmatter and check for field
    local yaml
    yaml=$(awk '/^---$/{if(c++)exit;next}c' "$file")
    if echo "$yaml" | grep -q "^${field}:"; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "$desc"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_fail "$desc"
        return 1
    fi
}

assert_executable() {
    local file="$1"
    local desc="${2:-Executable: $file}"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ -x "$file" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "$desc"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_fail "$desc"
        return 1
    fi
}

assert_python_syntax() {
    local file="$1"
    local desc="${2:-Python syntax valid: $file}"
    TESTS_RUN=$((TESTS_RUN + 1))
    if python3 -m py_compile "$file" 2>/dev/null; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "$desc"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_fail "$desc"
        log_verbose "  $(python3 -m py_compile "$file" 2>&1)"
        return 1
    fi
}

assert_shell_syntax() {
    local file="$1"
    local desc="${2:-Shell syntax valid: $file}"
    TESTS_RUN=$((TESTS_RUN + 1))
    if bash -n "$file" 2>/dev/null; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "$desc"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_fail "$desc"
        log_verbose "  $(bash -n "$file" 2>&1)"
        return 1
    fi
}

assert_contains() {
    local file="$1"
    local pattern="$2"
    local desc="${3:-File contains '$pattern'}"
    TESTS_RUN=$((TESTS_RUN + 1))
    if grep -q "$pattern" "$file"; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "$desc"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_fail "$desc"
        return 1
    fi
}

# ============================================================================
# TEST GROUPS
# ============================================================================

test_manifest() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " Plugin Manifest Tests"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local manifest="$PLUGIN_ROOT/.claude-plugin/plugin.json"

    assert_file_exists "$manifest" "plugin.json exists"
    assert_json_valid "$manifest" "plugin.json is valid JSON"
    assert_json_has_field "$manifest" ".name" "plugin.json has 'name' field"
    assert_json_has_field "$manifest" ".description" "plugin.json has 'description' field"

    # Verify name is "jarpa"
    TESTS_RUN=$((TESTS_RUN + 1))
    local name
    name=$(jq -r '.name' "$manifest")
    if [[ "$name" == "jarpa" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "Plugin name is 'jarpa'"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_fail "Plugin name is 'jarpa' (got: $name)"
    fi
}

test_hooks() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " Hooks Configuration Tests"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local hooks_json="$PLUGIN_ROOT/hooks/hooks.json"

    assert_file_exists "$hooks_json" "hooks.json exists"
    assert_json_valid "$hooks_json" "hooks.json is valid JSON"
    assert_json_has_field "$hooks_json" ".hooks" "hooks.json has 'hooks' wrapper"

    # Check each hook type exists
    assert_json_has_field "$hooks_json" ".hooks.SessionStart" "SessionStart hook defined"
    assert_json_has_field "$hooks_json" ".hooks.Stop" "Stop hook defined"
    assert_json_has_field "$hooks_json" ".hooks.PreCompact" "PreCompact hook defined"
    assert_json_has_field "$hooks_json" ".hooks.PreToolUse" "PreToolUse hook defined"

    # Check PreToolUse has matcher
    TESTS_RUN=$((TESTS_RUN + 1))
    local matcher
    matcher=$(jq -r '.hooks.PreToolUse[0].matcher // empty' "$hooks_json")
    if [[ "$matcher" == "Bash" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "PreToolUse has 'Bash' matcher"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_fail "PreToolUse has 'Bash' matcher (got: $matcher)"
    fi

    # Check hook commands use ${CLAUDE_PLUGIN_ROOT}
    TESTS_RUN=$((TESTS_RUN + 1))
    if jq -e '.hooks | .. | .command? // empty | select(. != null) | select(contains("${CLAUDE_PLUGIN_ROOT}"))' "$hooks_json" >/dev/null 2>&1; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "Hook commands use \${CLAUDE_PLUGIN_ROOT}"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_fail "Hook commands should use \${CLAUDE_PLUGIN_ROOT}"
    fi
}

test_mcp() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " MCP Server Configuration Tests"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local mcp_json="$PLUGIN_ROOT/.mcp.json"
    local server_sh="$PLUGIN_ROOT/mcp-servers/context-monitor/server.sh"

    assert_file_exists "$mcp_json" ".mcp.json exists"
    assert_json_valid "$mcp_json" ".mcp.json is valid JSON"
    assert_json_has_field "$mcp_json" ".mcpServers" ".mcp.json has 'mcpServers' field"
    assert_json_has_field "$mcp_json" '.mcpServers["context-monitor"]' "context-monitor server defined"

    # Check server command
    TESTS_RUN=$((TESTS_RUN + 1))
    local cmd
    cmd=$(jq -r '.mcpServers["context-monitor"].command' "$mcp_json")
    if [[ "$cmd" == "bash" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "MCP server command is bash (wrapper script)"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_fail "MCP server command should be bash (got: $cmd)"
    fi

    # Check server args use ${CLAUDE_PLUGIN_ROOT}
    TESTS_RUN=$((TESTS_RUN + 1))
    if jq -e '.mcpServers["context-monitor"].args[] | select(contains("${CLAUDE_PLUGIN_ROOT}"))' "$mcp_json" >/dev/null 2>&1; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "MCP server args use \${CLAUDE_PLUGIN_ROOT}"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_fail "MCP server args should use \${CLAUDE_PLUGIN_ROOT}"
    fi

    # Check bash server file
    assert_file_exists "$server_sh" "server.sh exists"
    assert_executable "$server_sh" "server.sh is executable"
    assert_shell_syntax "$server_sh" "server.sh has valid syntax"
    assert_contains "$server_sh" "THRESHOLD_WARNING" "server.sh defines warning threshold"
    assert_contains "$server_sh" "THRESHOLD_CRITICAL" "server.sh defines critical threshold"
    assert_contains "$server_sh" "check_health" "server.sh exposes check_health tool"

    # .mcp.json must point directly at server.sh (no run-server.sh wrapper)
    TESTS_RUN=$((TESTS_RUN + 1))
    if jq -e '.mcpServers["context-monitor"].args[] | select(endswith("/server.sh"))' "$mcp_json" >/dev/null 2>&1; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success ".mcp.json args point directly to server.sh"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_fail ".mcp.json args should reference server.sh directly"
    fi

    # Legacy wrapper must be gone
    TESTS_RUN=$((TESTS_RUN + 1))
    local wrapper="$PLUGIN_ROOT/mcp-servers/context-monitor/run-server.sh"
    if [[ ! -e "$wrapper" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "Legacy run-server.sh wrapper removed"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_fail "Legacy run-server.sh wrapper should not exist"
    fi

    # Statusline script shipped with the plugin
    local statusline="$PLUGIN_ROOT/mcp-servers/context-monitor/statusline.sh"
    assert_file_exists "$statusline" "statusline.sh exists"
    assert_executable "$statusline" "statusline.sh is executable"
    assert_shell_syntax "$statusline" "statusline.sh has valid syntax"
}

test_agents() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " Agent Definition Tests"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    assert_dir_exists "$PLUGIN_ROOT/agents" "agents/ directory exists"

    # Valid model names
    local valid_models="haiku sonnet opus"

    # Valid tool names (common ones)
    local valid_tools="Read Write Edit Bash Glob Grep Task AskUserQuestion"

    for agent_file in "$PLUGIN_ROOT/agents"/*.md; do
        [[ -f "$agent_file" ]] || continue
        local agent_name
        agent_name=$(basename "$agent_file" .md)

        log_info "Testing agent: $agent_name"

        assert_yaml_frontmatter "$agent_file"
        assert_yaml_has_field "$agent_file" "name" "  has 'name' field"
        assert_yaml_has_field "$agent_file" "description" "  has 'description' field"
        assert_yaml_has_field "$agent_file" "model" "  has 'model' field"

        # Check model is valid
        TESTS_RUN=$((TESTS_RUN + 1))
        local model
        model=$(awk '/^---$/{if(c++)exit;next}c' "$agent_file" | grep "^model:" | sed 's/model: *//')
        if echo "$valid_models" | grep -qw "$model"; then
            TESTS_PASSED=$((TESTS_PASSED + 1))
            log_success "  model '$model' is valid"
        else
            TESTS_FAILED=$((TESTS_FAILED + 1))
            log_fail "  model '$model' is invalid (expected: haiku, sonnet, or opus)"
        fi

        # Check color if present
        if grep -q "^color:" <(awk '/^---$/{if(c++)exit;next}c' "$agent_file"); then
            local color
            color=$(awk '/^---$/{if(c++)exit;next}c' "$agent_file" | grep "^color:" | sed 's/color: *//')
            TESTS_RUN=$((TESTS_RUN + 1))
            # Basic color validation (common names)
            if [[ "$color" =~ ^(red|green|blue|yellow|cyan|magenta|purple|orange|white|black)$ ]]; then
                TESTS_PASSED=$((TESTS_PASSED + 1))
                log_success "  color '$color' is valid"
            else
                TESTS_FAILED=$((TESTS_FAILED + 1))
                log_fail "  color '$color' may be invalid"
            fi
        fi

        # Check allowed-tools if present
        local yaml_block
        yaml_block=$(awk '/^---$/{if(c++)exit;next}c' "$agent_file")
        if echo "$yaml_block" | grep -q "^allowed-tools:"; then
            # Extract tool names from the YAML list (lines starting with "  - ")
            local tools
            tools=$(echo "$yaml_block" | awk '/^allowed-tools:/{found=1;next} found && /^  - /{print $2} found && !/^  - /{exit}')
            local all_valid=true
            for tool in $tools; do
                TESTS_RUN=$((TESTS_RUN + 1))
                if echo "$valid_tools" | grep -qw "$tool"; then
                    TESTS_PASSED=$((TESTS_PASSED + 1))
                    log_verbose "  tool '$tool' is valid"
                else
                    TESTS_FAILED=$((TESTS_FAILED + 1))
                    log_fail "  tool '$tool' is not a recognized tool name"
                    all_valid=false
                fi
            done
            if $all_valid && [[ -n "$tools" ]]; then
                log_success "  allowed-tools are all valid"
            fi
        fi
    done
}

test_commands() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " Command Definition Tests"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    assert_dir_exists "$PLUGIN_ROOT/commands" "commands/ directory exists"

    local expected_commands=("init" "archive" "session-end" "migrate" "status" "test-installation")

    for cmd in "${expected_commands[@]}"; do
        assert_file_exists "$PLUGIN_ROOT/commands/$cmd.md" "Command $cmd.md exists"
    done

    for cmd_file in "$PLUGIN_ROOT/commands"/*.md; do
        [[ -f "$cmd_file" ]] || continue
        local cmd_name
        cmd_name=$(basename "$cmd_file" .md)

        log_info "Testing command: jarpa:$cmd_name"

        assert_yaml_frontmatter "$cmd_file"
        assert_yaml_has_field "$cmd_file" "name" "  has 'name' field"
        assert_yaml_has_field "$cmd_file" "description" "  has 'description' field"

        # Verify command name matches filename
        TESTS_RUN=$((TESTS_RUN + 1))
        local defined_name
        defined_name=$(awk '/^---$/{if(c++)exit;next}c' "$cmd_file" | grep "^name:" | sed 's/name: *//')
        if [[ "$defined_name" == "jarpa:$cmd_name" ]]; then
            TESTS_PASSED=$((TESTS_PASSED + 1))
            log_success "  name matches filename (jarpa:$cmd_name)"
        else
            TESTS_FAILED=$((TESTS_FAILED + 1))
            log_fail "  name mismatch: expected 'jarpa:$cmd_name', got '$defined_name'"
        fi
    done
}

test_skills() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " Skill Definition Tests"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    assert_dir_exists "$PLUGIN_ROOT/skills" "skills/ directory exists"

    for skill_dir in "$PLUGIN_ROOT/skills"/*/; do
        [[ -d "$skill_dir" ]] || continue
        local skill_name
        skill_name=$(basename "$skill_dir")
        local skill_file="$skill_dir/SKILL.md"

        log_info "Testing skill: $skill_name"

        assert_file_exists "$skill_file" "  SKILL.md exists"

        if [[ -f "$skill_file" ]]; then
            assert_yaml_frontmatter "$skill_file"
            assert_yaml_has_field "$skill_file" "name" "  has 'name' field"
            assert_yaml_has_field "$skill_file" "description" "  has 'description' field"
        fi
    done
}

test_templates() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " Template Tests"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    assert_dir_exists "$PLUGIN_ROOT/templates" "templates/ directory exists"

    local expected_templates=("PROJECT_PLAN.md" "TODO.md" "REQUIREMENTS.md" "ARCHITECTURE.md" "JOURNAL.md")

    for template in "${expected_templates[@]}"; do
        assert_file_exists "$PLUGIN_ROOT/templates/$template" "Template $template exists"
    done

    # Check templates are non-empty and valid markdown
    # Note: JOURNAL.md is intentionally minimal (just header) - entries added during sessions
    for template_file in "$PLUGIN_ROOT/templates"/*.md; do
        [[ -f "$template_file" ]] || continue
        local template_name
        template_name=$(basename "$template_file")

        TESTS_RUN=$((TESTS_RUN + 1))
        local lines
        lines=$(wc -l < "$template_file")
        local min_lines=5
        # JOURNAL.md is intentionally minimal - just a header
        if [[ "$template_name" == "JOURNAL.md" ]]; then
            min_lines=1
        fi
        if [[ "$lines" -ge "$min_lines" ]]; then
            TESTS_PASSED=$((TESTS_PASSED + 1))
            log_success "Template $template_name has content ($lines lines)"
        else
            TESTS_FAILED=$((TESTS_FAILED + 1))
            log_fail "Template $template_name appears empty ($lines lines, expected >=$min_lines)"
        fi
    done
}

test_scripts() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " Hook Script Tests"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    assert_dir_exists "$PLUGIN_ROOT/hooks/scripts" "hooks/scripts/ directory exists"

    local expected_scripts=("session-start.sh" "session-end.sh" "pre-compact.sh" "pre-commit.sh")

    for script in "${expected_scripts[@]}"; do
        local script_path="$PLUGIN_ROOT/hooks/scripts/$script"
        assert_file_exists "$script_path" "Script $script exists"

        if [[ -f "$script_path" ]]; then
            assert_executable "$script_path" "Script $script is executable"
            assert_shell_syntax "$script_path" "Script $script has valid syntax"

            # Check shebang
            TESTS_RUN=$((TESTS_RUN + 1))
            if head -1 "$script_path" | grep -q "^#!/"; then
                TESTS_PASSED=$((TESTS_PASSED + 1))
                log_success "Script $script has shebang"
            else
                TESTS_FAILED=$((TESTS_FAILED + 1))
                log_fail "Script $script missing shebang"
            fi
        fi
    done
}

test_integration() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " Integration Tests"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Check hook script paths match hooks.json references
    log_info "Verifying hook script path references..."

    local hooks_json="$PLUGIN_ROOT/hooks/hooks.json"
    local script_refs
    script_refs=$(jq -r '.. | .command? // empty' "$hooks_json" | grep -o '[^/]*\.sh$' | sort -u)

    for script in $script_refs; do
        assert_file_exists "$PLUGIN_ROOT/hooks/scripts/$script" "Referenced script $script exists"
    done

    # Check MCP server path exists
    log_info "Verifying MCP server path..."
    local mcp_json="$PLUGIN_ROOT/.mcp.json"
    local server_path
    server_path=$(jq -r '.mcpServers["context-monitor"].args[0]' "$mcp_json" | sed 's|\${CLAUDE_PLUGIN_ROOT}|'"$PLUGIN_ROOT"'|')
    assert_file_exists "$server_path" "MCP server file exists at referenced path"

    # Cross-reference check: commands referencing agents
    log_info "Checking command-agent references..."
    if grep -l "journal-validator" "$PLUGIN_ROOT/commands"/*.md >/dev/null 2>&1; then
        assert_file_exists "$PLUGIN_ROOT/agents/journal-validator.md" "Referenced agent journal-validator exists"
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║           JARPA Plugin Automated Test Suite                ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Plugin root: $PLUGIN_ROOT"
    echo ""

    # Check dependencies
    if ! command -v jq &>/dev/null; then
        log_fail "jq is required but not installed. Install with: apt install jq"
        exit 1
    fi

    if ! command -v python3 &>/dev/null; then
        log_warn "python3 not found - some tests will be skipped"
    fi

    # Run tests based on group or all
    case "${TEST_GROUP:-all}" in
        manifest)  test_manifest ;;
        hooks)     test_hooks ;;
        mcp)       test_mcp ;;
        agents)    test_agents ;;
        commands)  test_commands ;;
        skills)    test_skills ;;
        templates) test_templates ;;
        scripts)   test_scripts ;;
        integration) test_integration ;;
        all)
            test_manifest
            test_hooks
            test_mcp
            test_agents
            test_commands
            test_skills
            test_templates
            test_scripts
            test_integration
            ;;
        *)
            echo "Unknown test group: $TEST_GROUP"
            echo "Available groups: manifest, hooks, mcp, agents, commands, skills, templates, scripts, integration, all"
            exit 1
            ;;
    esac

    # Summary
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " Test Summary"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo -e "  Total tests:  $TESTS_RUN"
    echo -e "  ${GREEN}Passed:${NC}       $TESTS_PASSED"
    echo -e "  ${RED}Failed:${NC}       $TESTS_FAILED"
    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}✗ Some tests failed.${NC}"
        exit 1
    fi
}

main "$@"
