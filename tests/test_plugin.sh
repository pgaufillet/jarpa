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
# Test groups: manifest, hooks, statusline, agents, commands, skills, templates, scripts, metrics, review
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

test_statusline() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " Statusline Configuration Tests"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # The context-monitor MCP server was removed in 0.3.0; the statusline is
    # now the only context-monitoring artifact the plugin ships.
    local statusline="$PLUGIN_ROOT/statusline/statusline.sh"
    assert_file_exists "$statusline" "statusline.sh exists"
    assert_executable "$statusline" "statusline.sh is executable"
    assert_shell_syntax "$statusline" "statusline.sh has valid syntax"

    # The plugin must ship no MCP server declaration
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ ! -e "$PLUGIN_ROOT/.mcp.json" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "No .mcp.json (plugin ships no MCP server)"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_fail ".mcp.json should not exist after MCP server removal"
    fi

    # --- Behavioral tests: run the statusline against sample payloads ---
    #
    # Payload with a 58% context window and account rate limits (5h=34%,
    # 7d=18%). Rate-limit values differ from the context value so a
    # regression that mixes them up is caught.
    local payload='{"display_name":"Opus 4.8","context_window":{"used_percentage":58,"context_window_size":200000},"rate_limits":{"five_hour":{"used_percentage":34.2,"resets_at":1},"seven_day":{"used_percentage":18,"resets_at":1},"spend_limit":{"used_percentage":62,"resets_at":1}}}'

    # Display width in terminal columns, mirroring the script's own counting:
    # the gauge glyphs and separators are one column but multi-byte in UTF-8.
    _disp_width() {
        local s="$1"
        s="${s//█/#}"; s="${s//░/#}"; s="${s//·/.}"; s="${s//│/|}"
        printf '%s' "${#s}"
    }

    local out

    # Opt-in, wide terminal: both gauges present with correct percentages.
    out=$(printf '%s' "$payload" | COLUMNS=120 JARPA_SHOW_RATE_LIMITS=1 bash "$statusline")
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$out" == *"5h "*"34%"* && "$out" == *"7d "*"18%"* ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "Rate-limit gauges show 5h 34% and 7d 18% when opted in"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_fail "Rate-limit gauges missing/incorrect (got: $out)"
    fi

    # Opt-in, wide terminal: the section follows the context state directly
    # after a "│" separator — no padding pushing it into the right-side area
    # Claude Code reserves for its notifications.
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$out" == *"ctx OK │ 5h "* && "$(_disp_width "$out")" -lt 80 ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "Rate-limit section appended after separator, not right-justified"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_fail "Rate-limit section not appended after separator (got: $out)"
    fi

    # Fit boundary: the section is kept only when the full line fits within
    # COLUMNS minus the 2-column margin left for the interface's own spacing.
    local full_width
    full_width=$(_disp_width "$out")
    local fits tight
    fits=$(printf '%s' "$payload" | COLUMNS=$((full_width + 2)) JARPA_SHOW_RATE_LIMITS=1 bash "$statusline")
    tight=$(printf '%s' "$payload" | COLUMNS=$((full_width + 1)) JARPA_SHOW_RATE_LIMITS=1 bash "$statusline")
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$fits" == *"7d "* && "$tight" != *"5h "* && "$tight" == *"ctx "* ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "Rate-limit section kept only with 2-column margin"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_fail "Fit boundary wrong (fits: $fits | tight: $tight)"
    fi

    # Context percentage is read from context_window, not from rate_limits
    # (regression guard for the 0.2.2 greedy-match bug).
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$out" == *"58% ctx"* && "$out" != *"34% ctx"* ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "Context percentage isolated from rate-limit values"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_fail "Context percentage confused with rate-limit value (got: $out)"
    fi

    # Not opted in: no rate-limit gauges are shown.
    out=$(printf '%s' "$payload" | COLUMNS=120 bash "$statusline")
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$out" != *"5h "* && "$out" != *"7d "* ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "Rate-limit gauges hidden without JARPA_SHOW_RATE_LIMITS"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_fail "Rate-limit gauges shown despite opt-out (got: $out)"
    fi

    # Opt-in but terminal too narrow: all-or-nothing hides the gauges.
    out=$(printf '%s' "$payload" | COLUMNS=30 JARPA_SHOW_RATE_LIMITS=1 bash "$statusline")
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$out" != *"5h "* && "$out" != *"7d "* ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "Rate-limit gauges hidden when terminal too narrow"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_fail "Rate-limit gauges shown on narrow terminal (got: $out)"
    fi

    # Opt-in but no rate_limits in payload (e.g. before first API response):
    # the base line is emitted unchanged, no gauges.
    out=$(printf '%s' '{"display_name":"M","context_window":{"used_percentage":10,"context_window_size":200000}}' \
        | COLUMNS=120 JARPA_SHOW_RATE_LIMITS=1 bash "$statusline")
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$out" == *"10% ctx"* && "$out" != *"5h "* ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "Missing rate_limits tolerated (base line intact)"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_fail "Missing rate_limits not handled cleanly (got: $out)"
    fi

    unset -f _disp_width
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

    local expected_commands=("init" "archive" "session-end" "status" "test-installation" "upgrade" "review")

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

    local expected_scripts=("session-start.sh" "session-end.sh" "pre-compact.sh" "pre-commit.sh" "metrics.sh" "review-due.sh")

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

    # Cross-reference check: commands referencing agents
    log_info "Checking command-agent references..."
    if grep -l "journal-validator" "$PLUGIN_ROOT/commands"/*.md >/dev/null 2>&1; then
        assert_file_exists "$PLUGIN_ROOT/agents/journal-validator.md" "Referenced agent journal-validator exists"
    fi

    # Review command: invokes both validators; its JOURNAL title is the
    # contract session-start relies on to find the last review.
    log_info "Checking review contract..."
    local review_cmd="$PLUGIN_ROOT/commands/review.md"
    for agent in coherence-validator session-reviewer; do
        assert_contains "$review_cmd" "\`$agent\`" "review invokes $agent"
        assert_contains "$PLUGIN_ROOT/agents/$agent.md" "From \`/jarpa:review\` only" "$agent is scoped to the review"
    done
    assert_contains "$review_cmd" "Session N: JARPA review" "review defines its JOURNAL title"
    assert_contains "$PLUGIN_ROOT/skills/jarpa-methodology/SKILL.md" "Session N: JARPA review" "methodology states the review title"

    # Upgrade command: managed CLAUDE.md block resync contract
    log_info "Checking upgrade block-resync contract..."

    local upgrade_cmd="$PLUGIN_ROOT/commands/upgrade.md"
    local inject_template="$PLUGIN_ROOT/templates/CLAUDE_MD_INJECT.md"

    assert_contains "$upgrade_cmd" "JARPA:BEGIN" "upgrade.md covers the managed CLAUDE.md block"
    assert_contains "$upgrade_cmd" "CLAUDE_MD_INJECT.md" "upgrade.md references the inject template"

    # The documented resync replaces marker-to-marker with the full template,
    # which is only safe if the template is delimited by the markers itself.
    TESTS_RUN=$((TESTS_RUN + 1))
    if head -1 "$inject_template" | grep -q "^<!-- JARPA:BEGIN" \
        && tail -1 "$inject_template" | grep -q "^<!-- JARPA:END -->$"; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "Inject template is delimited by BEGIN/END markers"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_fail "Inject template must start with JARPA:BEGIN and end with JARPA:END"
    fi

    # Simulate the documented resync on a stale block: the block must equal
    # the template afterwards, consumer prose outside the markers must
    # survive, and a second pass must be a no-op.
    resync_block() {
        awk -v tpl="$inject_template" '
            /^<!-- JARPA:BEGIN/ {while ((getline line < tpl) > 0) print line; close(tpl); skip=1; next}
            /^<!-- JARPA:END -->$/ {if (skip) {skip=0; next}}
            !skip {print}
        ' "$1" > "$1.new" && mv "$1.new" "$1"
    }

    local tmp_dir
    tmp_dir=$(mktemp -d)
    {
        echo "# Consumer project"
        echo ""
        echo "Consumer prose above the block."
        echo ""
        echo "<!-- JARPA:BEGIN - managed by jarpa plugin, do not edit manually -->"
        echo "## JARPA Methodology"
        echo ""
        echo "Stale rules from an older plugin version."
        echo "<!-- JARPA:END -->"
        echo ""
        echo "Consumer prose below the block."
    } > "$tmp_dir/CLAUDE.md"

    resync_block "$tmp_dir/CLAUDE.md"

    TESTS_RUN=$((TESTS_RUN + 1))
    local block_after
    block_after=$(sed -n '/^<!-- JARPA:BEGIN/,/^<!-- JARPA:END -->$/p' "$tmp_dir/CLAUDE.md")
    if [[ "$block_after" == "$(cat "$inject_template")" ]] \
        && grep -q "Consumer prose above the block." "$tmp_dir/CLAUDE.md" \
        && grep -q "Consumer prose below the block." "$tmp_dir/CLAUDE.md"; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "Stale block resync yields template block, consumer prose intact"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_fail "Stale block resync corrupted CLAUDE.md"
    fi

    TESTS_RUN=$((TESTS_RUN + 1))
    cp "$tmp_dir/CLAUDE.md" "$tmp_dir/CLAUDE.md.first"
    resync_block "$tmp_dir/CLAUDE.md"
    if cmp -s "$tmp_dir/CLAUDE.md" "$tmp_dir/CLAUDE.md.first"; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "Second resync pass is a no-op (idempotent)"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_fail "Resync is not idempotent"
    fi
    rm -rf "$tmp_dir"
}

test_metrics() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " Hygiene Metrics Tests"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local metrics="$PLUGIN_ROOT/hooks/scripts/metrics.sh"
    local template="$PLUGIN_ROOT/templates/CLAUDE_MD_INJECT.md"
    local tmp
    tmp=$(mktemp -d)

    # Isolated user config: the real ~/.claude must never leak into results.
    local home="$tmp/home"
    mkdir -p "$home/.claude"

    _run_metrics() {
        env -u CLAUDE_CODE_DISABLE_AUTO_MEMORY -u CLAUDE_PROJECT_DIR -u CLAUDE_CONFIG_DIR \
            HOME="$home" bash "$metrics" "$@"
    }

    _check() {
        local desc="$1"; shift
        TESTS_RUN=$((TESTS_RUN + 1))
        if "$@"; then
            TESTS_PASSED=$((TESTS_PASSED + 1))
            log_success "$desc"
        else
            TESTS_FAILED=$((TESTS_FAILED + 1))
            log_fail "$desc"
            log_verbose "  output: $out"
        fi
    }

    _has()    { [[ "$out" == *"$1"* ]]; }
    _hasnt()  { [[ "$out" != *"$1"* ]]; }
    _repeat() { local i; for ((i = 0; i < $2; i++)); do printf '%s\n' "$1"; done; }

    # Healthy project: core files well under thresholds, managed block
    # current, auto-memory disabled at project scope.
    local p="$tmp/healthy"
    mkdir -p "$p/jarpa" "$p/.claude"
    # Entry bodies of 900 and 2900 bytes (plus a ~33-byte header each):
    # mean ~1.9 KB, last ~2.9 KB.
    {
        echo "# Journal"
        echo "## [2026-01-01] — Session 1: A"
        _repeat "$(printf '%099d' 0)" 9
        echo "## [2026-01-02] — Session 2: B"
        _repeat "$(printf '%099d' 0)" 29
    } > "$p/jarpa/JOURNAL.md"
    printf '# Todo\n## Now\n[ONGOING] Do the thing\n- [ ] sub\n      DoD: done\n## Recently Done\n- [X] one\n' > "$p/jarpa/TODO.md"
    printf '# Plan\n## Current Step\n**Current:** Step 1\n' > "$p/jarpa/PROJECT_PLAN.md"
    cp "$template" "$p/CLAUDE.md"
    echo '{ "autoMemoryEnabled": false }' > "$p/.claude/settings.json"

    local out rc
    out=$(_run_metrics "$p"); rc=$?
    _check "Healthy project: nothing flagged" _has "all measures within thresholds"
    _check "Healthy project: exit code 0" [ "$rc" -eq 0 ]
    _check "Journal entries counted with mean and last size" _has "journal entries: 2, mean 1.9 KB, last 2.9 KB"
    _check "Managed block up to date detected" _has "managed block: up to date"
    _check "Auto-memory disabled at project scope detected" _has "auto-memory: disabled (project settings)"

    # ARCHITECTURE and REQUIREMENTS: size for information, never flagged.
    _repeat "$(printf '%0100d' 0)" 1000 > "$p/jarpa/ARCHITECTURE.md"
    out=$(_run_metrics "$p")
    _check "Large ARCHITECTURE reported for information only" _has "[--] ARCHITECTURE.md 101.0 KB (read on demand, no threshold)"
    _check "Large ARCHITECTURE does not raise a flag" _has "all measures within thresholds"

    # Entry size is measured in bytes: many short lines stay under the
    # target, few long lines exceed it.
    local j="$tmp/journal-bytes"
    mkdir -p "$j/jarpa"
    { echo "## [2026-01-01] — Session 1: Many short lines"; _repeat "0123456789" 200; } > "$j/jarpa/JOURNAL.md"
    out=$(_run_metrics "$j")
    _check "200 short lines (~2 KB) not flagged as oversized entry" _has "[ok] journal entries: 1"
    { echo "## [2026-01-01] — Session 1: Few long lines"; _repeat "$(printf '%0200d' 0)" 40; } > "$j/jarpa/JOURNAL.md"
    out=$(_run_metrics "$j")
    _check "40 long lines (~8 KB) flagged as oversized entry" _has "[!!] journal entries: 1"

    # Legacy "## Session N" headers still delimit entries.
    { echo "## Session 1: legacy"; echo x; echo "## [2026-01-02] — Session 2: canonical"; echo y; } > "$j/jarpa/JOURNAL.md"
    out=$(_run_metrics "$j")
    _check "Legacy session headers counted as entries" _has "journal entries: 2"

    # Journal line threshold drives the archive recommendation.
    { echo "## [2026-01-01] — Session 1: A"; _repeat "x" 1600; } > "$j/jarpa/JOURNAL.md"
    out=$(_run_metrics "$j")
    _check "JOURNAL over 1500 lines recommends /jarpa:archive" _has "run /jarpa:archive"

    # TODO and PLAN over default byte thresholds are flagged; a project
    # setting overrides the default.
    local t="$tmp/big"
    mkdir -p "$t/jarpa" "$t/.claude"
    _repeat "$(printf '%0100d' 0)" 310 > "$t/jarpa/TODO.md"
    _repeat "$(printf '%0100d' 0)" 160 > "$t/jarpa/PROJECT_PLAN.md"
    out=$(_run_metrics "$t")
    _check "TODO over 30 KB default flagged" _has "[!!] TODO.md 31.3 KB"
    _check "PROJECT_PLAN over 15 KB default flagged" _has "[!!] PROJECT_PLAN.md 16.2 KB"
    printf -- '---\nthresholds:\n  todo_bytes: 50000\n  plan_bytes: 1000\n---\n' > "$t/.claude/jarpa.local.md"
    out=$(_run_metrics "$t")
    _check "todo_bytes setting raises the TODO threshold" _has "[ok] TODO.md 31.3 KB (threshold 50.0 KB)"
    _check "plan_bytes setting lowers the PLAN threshold" _has "[!!] PROJECT_PLAN.md 16.2 KB (threshold 1.0 KB)"

    # Closed items above 10 and several [ONGOING] markers are flagged;
    # prose mentioning [ONGOING] is not a marker.
    local m="$tmp/markers"
    mkdir -p "$m/jarpa"
    { echo "## Now"; echo "[ONGOING] Task A"; echo "Note: remove the [ONGOING] marker at the end"; _repeat "- [X] done" 10; } > "$m/jarpa/TODO.md"
    out=$(_run_metrics "$m")
    _check "10 closed items not flagged" _has "[ok] TODO closed items: 10"
    _check "Prose [ONGOING] mention not counted" _has "[ok] TODO [ONGOING] markers: 1"
    { echo "## Now"; echo "[ONGOING] Task A"; echo "- [ ] [ONGOING] Task B"; _repeat "- [x] done" 8; _repeat "- ✅ done" 3; } > "$m/jarpa/TODO.md"
    out=$(_run_metrics "$m")
    _check "11 closed items ([x] and ✅) flagged" _has "[!!] TODO closed items: 11"
    _check "Two [ONGOING] markers flagged" _has "[!!] TODO [ONGOING] markers: 2"
    # Closed boxes without a dash or with another bullet count too; a box
    # in the middle of prose does not.
    { _repeat "- [x] done" 9; echo "[x] **2.2 Closed step**"; echo "  * [X] nested"; echo "See the [x] notation above"; } > "$m/jarpa/TODO.md"
    out=$(_run_metrics "$m")
    _check "Closed boxes without a dash counted, prose box ignored" _has "[!!] TODO closed items: 11"
    # A marker inside a heading counts.
    { echo "## Now"; echo "### Tâche [ONGOING] Probe"; echo "- [ ] [ONGOING] Other"; } > "$m/jarpa/TODO.md"
    out=$(_run_metrics "$m")
    _check "Heading with [ONGOING] after text counted as a marker" _has "[!!] TODO [ONGOING] markers: 2"

    # Minimal file set (JOURNAL + TODO only): absent files are skipped.
    local mini="$tmp/minimal"
    mkdir -p "$mini/jarpa"
    printf '## [2026-01-01] — Session 1: A\nx\n' > "$mini/jarpa/JOURNAL.md"
    printf '## Now\n' > "$mini/jarpa/TODO.md"
    out=$(_run_metrics "$mini"); rc=$?
    _check "Minimal file set: no PROJECT_PLAN line, exit 0" bash -c '[[ "$1" != *PROJECT_PLAN* && "$2" -eq 0 ]]' _ "$out" "$rc"

    # Satellites: unmarked flagged, marked accepted, temporary counted.
    printf '<!-- jarpa-status: living -->\n# Index\n' > "$mini/jarpa/INDEX.md"
    printf '# Old audit\n' > "$mini/jarpa/AUDIT.md"
    printf '<!-- jarpa-status: temporary -->\n# Sprint plan\n' > "$mini/jarpa/sprint-plan.md"
    out=$(_run_metrics "$mini")
    _check "Satellite without status marker flagged by name" _has "satellites: 3, 1 without jarpa-status marker (AUDIT.md)"
    _check "Temporary satellite reported" _has "temporary satellites: 1"
    printf '<!-- jarpa-status: snapshot -->\n# Old audit\n' > "$mini/jarpa/AUDIT.md"
    out=$(_run_metrics "$mini")
    _check "All satellites marked: accepted" _has "[ok] satellites: 3, all with a jarpa-status marker"

    # Temporary satellites carry a due date: missing or past is flagged.
    _check "Temporary satellite without a due date flagged" _has "[!!] temporary satellites without a due date: sprint-plan.md"
    printf '<!-- jarpa-status: temporary, due: 2020-01-31 -->\n# Sprint plan\n' > "$mini/jarpa/sprint-plan.md"
    out=$(_run_metrics "$mini")
    _check "Dated temporary marker still counts as a marker" _has "[ok] satellites: 3, all with a jarpa-status marker"
    _check "Temporary satellite past due flagged with its date" _has "[!!] temporary satellites past due: sprint-plan.md 2020-01-31"
    printf '<!-- jarpa-status: temporary, due: 2099-12-31 -->\n# Sprint plan\n' > "$mini/jarpa/sprint-plan.md"
    out=$(_run_metrics "$mini")
    _check "Temporary satellite due in the future not flagged" bash -c '[[ "$1" != *"past due"* && "$1" != *"without a due date"* ]]' _ "$out"

    # Managed block states.
    _run_block() { out=$(_run_metrics "$mini"); }
    rm -f "$mini/CLAUDE.md"; _run_block
    _check "Missing CLAUDE.md block flagged absent" _has "managed block: absent"
    { cat "$template"; } | sed '$d' > "$mini/CLAUDE.md"; _run_block
    _check "Block without END marker flagged malformed" _has "managed block: malformed"
    { echo "# Project"; sed 's/Key Rules/Old Rules/' "$template"; echo "Consumer prose"; } > "$mini/CLAUDE.md"; _run_block
    _check "Drifted block flagged stale" _has "managed block: stale"
    { echo "# Project"; cat "$template"; echo "Consumer prose"; } > "$mini/CLAUDE.md"; _run_block
    _check "Current block with consumer prose around it is up to date" _has "managed block: up to date"

    # Auto-memory resolution: env var, then local > project > user; absent = on.
    local a="$tmp/memory"
    mkdir -p "$a/jarpa" "$a/.claude"
    printf '## Now\n' > "$a/jarpa/TODO.md"
    out=$(_run_metrics "$a")
    _check "Absent setting: auto-memory enabled by default" _has "auto-memory: enabled (default)"
    local slug
    slug=$(printf '%s' "$a" | sed 's/[^[:alnum:]]/-/g')
    mkdir -p "$home/.claude/projects/$slug/memory"
    local memdir="$home/.claude/projects/$slug/memory"
    touch "$memdir/MEMORY.md"
    printf -- '---\nname: pref\ntype: feedback\n---\nAnswer first.\n' > "$memdir/pref.md"
    printf -- '---\nname: me\nmetadata:\n  type: user\n---\nMaintainer.\n' > "$memdir/me.md"
    out=$(_run_metrics "$a")
    _check "Enabled auto-memory reports memory file count (index excluded)" _has "2 memory file(s)"
    _check "Preference-only auto-memory not flagged" _has "[ok] auto-memory: enabled (default), 2 memory file(s), preferences only"
    printf -- '---\nname: fact\nmetadata:\n  type: project\n---\nThe CAN bus runs at 500k.\n' > "$memdir/fact.md"
    printf -- '---\nname: dash\ntype: reference\n---\nGrafana board.\n' > "$memdir/dash.md"
    out=$(_run_metrics "$a")
    _check "Project and reference memories flagged with their count" _has "[!!] auto-memory: enabled (default), 4 memory file(s), 2 project/reference"
    echo '{ "autoMemoryEnabled": false }' > "$home/.claude/settings.json"
    out=$(_run_metrics "$a")
    _check "User settings false disables" _has "auto-memory: disabled (user settings)"
    echo '{ "autoMemoryEnabled": true }' > "$a/.claude/settings.json"
    out=$(_run_metrics "$a")
    _check "Project settings true overrides user false" _has "auto-memory: enabled (project settings)"
    echo '{ "autoMemoryEnabled": false }' > "$a/.claude/settings.local.json"
    out=$(_run_metrics "$a")
    _check "Local settings false overrides project true" _has "auto-memory: disabled (local settings)"
    rm -f "$a/.claude/settings.local.json" "$home/.claude/settings.json"
    out=$(env -u CLAUDE_PROJECT_DIR -u CLAUDE_CONFIG_DIR CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 HOME="$home" bash "$metrics" "$a")
    _check "CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 overrides project true" _has "disabled (CLAUDE_CODE_DISABLE_AUTO_MEMORY)"

    # Session references in commits: multi-repo layout (non-git project
    # root, code repos one level down, jarpa/ as its own repository).
    local w="$tmp/workspace"
    mkdir -p "$w/app" "$w/lib" "$w/jarpa"
    _git() { git -C "$1" -c init.defaultBranch=main "${@:2}" >/dev/null 2>&1; }
    _commit() { # repo author-email message
        git -C "$1" -c user.email="$2" -c user.name=T commit -q --allow-empty -m "$3" >/dev/null 2>&1
    }
    for r in app lib jarpa; do
        _git "$w/$r" init -q
        git -C "$w/$r" config user.email me@example.org
    done
    printf '## Now\n' > "$w/jarpa/TODO.md"
    _commit "$w/app" me@example.org "Add parser"
    _commit "$w/app" me@example.org "Fix overlay S214"
    _commit "$w/app" other@example.org "Upstream change S555"
    _commit "$w/lib" me@example.org "Wire session 42 cleanup"
    _commit "$w/lib" me@example.org "Use S3 bucket for artifacts"
    _commit "$w/jarpa" me@example.org "Journal S215"
    out=$(_run_metrics "$w")
    _check "Session refs found across sub-directory repos (2 own commits)" _has "session references in commits since 30 days ago: 2"
    _check "Own commit in app repo reported" _has "app 1"
    _check "jarpa/ repository excluded from the scan" _hasnt "jarpa 1"
    _check "Other authors' commits not counted" _hasnt "S555"

    # Single-repo layout: jarpa/ inside the code repository is scanned.
    local sr="$tmp/single"
    mkdir -p "$sr/jarpa"
    _git "$sr" init -q
    git -C "$sr" config user.email me@example.org
    printf '## Now\n' > "$sr/jarpa/TODO.md"
    # A 60-day-old offending commit (created first: git's --since walk stops
    # at the first commit older than the window) sits outside the default
    # 30-day window and inside an explicit 90-day one.
    local old_date
    old_date=$(date -d '60 days ago' '+%Y-%m-%dT%H:%M:%S')
    GIT_AUTHOR_DATE="$old_date" GIT_COMMITTER_DATE="$old_date" \
        _commit "$sr" me@example.org "Journal S100"
    _commit "$sr" me@example.org "Cloture S196"
    out=$(_run_metrics "$sr")
    _check "Project repo itself scanned when jarpa/ lives inside it" _has "Cloture S196"
    _check "Date of the latest session reference reported" _has "latest $(date +%F) "
    _check "Commit older than the default window not counted" _has "since 30 days ago: 1"
    out=$(_run_metrics "$sr" --since "90 days ago")
    _check "--since widens the scan window" _has "since 90 days ago: 2"

    # After a pause the window reaches back to the 10th-last JOURNAL entry,
    # so references made before the pause are still reported.
    local pz="$tmp/pause"
    mkdir -p "$pz/jarpa"
    _git "$pz" init -q
    git -C "$pz" config user.email me@example.org
    local d100 d90 d60 i
    d100=$(date -d '100 days ago' '+%Y-%m-%dT%H:%M:%S')
    d90=$(date -d '90 days ago' '+%F')
    d60=$(date -d '60 days ago' '+%Y-%m-%dT%H:%M:%S')
    GIT_AUTHOR_DATE="$d100" GIT_COMMITTER_DATE="$d100" _commit "$pz" me@example.org "Probe S10"
    GIT_AUTHOR_DATE="$d60" GIT_COMMITTER_DATE="$d60" _commit "$pz" me@example.org "Probe S20"
    { for i in $(seq 1 9); do echo "## [$d90] — Session $i: before"; done
      echo "## [$(date +%F)] — Session 10: resume"; } > "$pz/jarpa/JOURNAL.md"
    out=$(_run_metrics "$pz")
    _check "Window reaches the 10th-last entry after a pause" _has "since $d90 (last 10 sessions): 1"
    { for i in $(seq 1 10); do echo "## [$(date +%F)] — Session $i: busy"; done; } > "$pz/jarpa/JOURNAL.md"
    out=$(_run_metrics "$pz")
    _check "Window stays at 30 days when the last 10 entries are recent" _has "since 30 days ago: 0"

    # No jarpa/ at all: explicit hint, still exit 0.
    out=$(_run_metrics "$tmp/nowhere"); rc=$?
    _check "Missing jarpa/ suggests /jarpa:init and exits 0" bash -c '[[ "$1" == *"/jarpa:init"* && "$2" -eq 0 ]]' _ "$out" "$rc"

    unset -f _run_metrics _check _has _hasnt _repeat _run_block _git _commit
    rm -rf "$tmp"
}

test_review() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " Review Announcement Tests"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local script="$PLUGIN_ROOT/hooks/scripts/review-due.sh"
    local tmp
    tmp=$(mktemp -d)
    local out rc

    _run_review() { env -u CLAUDE_PROJECT_DIR bash "$script" "$@"; }

    _check() {
        local desc="$1"; shift
        TESTS_RUN=$((TESTS_RUN + 1))
        if "$@"; then
            TESTS_PASSED=$((TESTS_PASSED + 1))
            log_success "$desc"
        else
            TESTS_FAILED=$((TESTS_FAILED + 1))
            log_fail "$desc"
            log_verbose "  output: $out"
        fi
    }

    _has()   { [[ "$out" == *"$1"* ]]; }
    _hasnt() { [[ "$out" != *"$1"* ]]; }

    # Sessions first..last, one per day from 2026-01-01; the session named
    # by the third argument (if any) is a review.
    _sessions() {
        local i
        for ((i = $1; i <= $2; i++)); do
            if [[ "$i" == "${3:-}" ]]; then
                printf '## [2026-01-%02d] — Session %d: JARPA review\n' "$i" "$i"
            else
                printf '## [2026-01-%02d] — Session %d: Work\n' "$i" "$i"
            fi
            echo "### Goal"
        done
    }

    local p="$tmp/cadence"
    mkdir -p "$p/jarpa" "$p/.claude"

    # Cadence: 15 sessions after the review is due, 14 is not.
    _sessions 1 20 5 > "$p/jarpa/JOURNAL.md"
    out=$(_run_review "$p" --today 2026-01-21); rc=$?
    _check "Cadence: 15 sessions since the review is due" _has "[!!] review due — 15 sessions since the last review (Session 5, 2026-01-05); every 15"
    _check "Exit code 0 when a review is due" [ "$rc" -eq 0 ]
    _sessions 1 20 6 > "$p/jarpa/JOURNAL.md"
    out=$(_run_review "$p" --today 2026-01-21)
    _check "Cadence: 14 sessions since the review is not due" _has "[ok] no review due — 14 sessions since the last review (Session 6, 2026-01-06); every 15"
    printf -- '---\nthresholds:\n  review_interval_sessions: 10\n---\n' > "$p/.claude/jarpa.local.md"
    out=$(_run_review "$p" --today 2026-01-21)
    _check "Cadence setting review_interval_sessions is read" _has "[!!] review due — 14 sessions since the last review (Session 6, 2026-01-06); every 10"
    rm "$p/.claude/jarpa.local.md"

    # The last review wins; other titles mentioning "review" do not count.
    { _sessions 1 20 3; printf '## [2026-01-21] — Session 21: Code review of the parser\n## [2026-01-22] — Session 22: JARPA upgrade\n'; } > "$p/jarpa/JOURNAL.md"
    sed -i 's/Session 12: Work/Session 12: JARPA review/' "$p/jarpa/JOURNAL.md"
    out=$(_run_review "$p" --today 2026-01-22)
    _check "Last review found among several" _has "10 sessions since the last review (Session 12,"
    _check "Titles other than 'JARPA review' are not reviews" bash -c '[[ "$1" != *"Session 21,"* && "$1" != *"Session 22,"* ]]' _ "$out"

    # No review yet: counted from the start.
    _sessions 1 3 > "$p/jarpa/JOURNAL.md"
    out=$(_run_review "$p" --today 2026-01-04)
    _check "No review yet, few sessions: not due" _has "[ok] no review due — 3 sessions since the start (no review yet)"

    # A review moved to the archive is still found.
    mkdir -p "$p/jarpa/archive"
    _sessions 1 8 4 > "$p/jarpa/archive/JOURNAL_2026-01.md"
    _sessions 9 12 > "$p/jarpa/JOURNAL.md"
    out=$(_run_review "$p" --today 2026-01-13)
    _check "Review in an archived journal is found" _has "8 sessions since the last review (Session 4, 2026-01-04)"
    # Other archive files (reports, snapshots) are not journals.
    _sessions 1 30 25 > "$p/jarpa/archive/REX_2026-01.md"
    out=$(_run_review "$p" --today 2026-01-13)
    _check "Non-journal archive files are ignored" _has "(Session 4, 2026-01-04)"
    rm -rf "$p/jarpa/archive"

    # Legacy "## Session N" headers count as sessions.
    { printf '## Session 1: Old\n## Session 2: JARPA review\n'; for i in $(seq 3 17); do printf '## Session %d: Old\n' "$i"; done; } > "$p/jarpa/JOURNAL.md"
    out=$(_run_review "$p" --today 2026-01-04)
    _check "Legacy undated headers count for the cadence" _has "[!!] review due — 15 sessions since the last review (Session 2, -)"
    _check "Legacy undated headers raise no pause" _hasnt "pause"

    # Pause: a gap over review_pause_days between sessions after the review.
    local q="$tmp/pause"
    mkdir -p "$q/jarpa" "$q/.claude"
    printf '## [2026-01-01] — Session 1: JARPA review\n## [2026-01-02] — Session 2: A\n## [2026-02-02] — Session 3: B\n' > "$q/jarpa/JOURNAL.md"
    out=$(_run_review "$q" --today 2026-02-03)
    _check "Pause: 31-day gap between sessions is due" _has "[!!] review due — resumed after a 31-day pause (2026-01-02 to 2026-02-02); pause over 30 days"
    printf '## [2026-01-01] — Session 1: JARPA review\n## [2026-01-02] — Session 2: A\n## [2026-02-01] — Session 3: B\n' > "$q/jarpa/JOURNAL.md"
    out=$(_run_review "$q" --today 2026-02-02)
    _check "Pause: 30-day gap is not due" _has "[ok] no review due"
    out=$(_run_review "$q" --today 2026-03-15)
    _check "Pause: gap between the last session and today counts" _has "resumed after a 42-day pause (2026-02-01 to today)"
    printf -- '---\nthresholds:\n  review_pause_days: 20\n---\n' > "$q/.claude/jarpa.local.md"
    out=$(_run_review "$q" --today 2026-02-02)
    _check "Pause setting review_pause_days is read" _has "pause over 20 days"
    rm "$q/.claude/jarpa.local.md"
    printf '## [2025-06-01] — Session 1: A\n## [2026-01-01] — Session 2: JARPA review\n## [2026-01-05] — Session 3: B\n' > "$q/jarpa/JOURNAL.md"
    out=$(_run_review "$q" --today 2026-01-06)
    _check "Pause before the last review is ignored" _has "[ok] no review due"
    # Across a year boundary and February: 2025-12-31 to 2026-03-01 is 60 days.
    printf '## [2025-12-31] — Session 1: JARPA review\n## [2026-03-01] — Session 2: A\n' > "$q/jarpa/JOURNAL.md"
    out=$(_run_review "$q" --today 2026-03-01)
    _check "Day count is exact across years and February" _has "60-day pause (2025-12-31 to 2026-03-01)"

    # Milestones: compared with the lines the last review recorded.
    local m="$tmp/milestones"
    mkdir -p "$m/jarpa"
    printf '# Plan\n## Milestones\n1. **Core** (Complete)\n   - Success criteria: x\n2. **Next** (In Progress)\n   - Progress: a\n\n## Current Step\n1. not a milestone\n' > "$m/jarpa/PROJECT_PLAN.md"
    out=$(_run_review "$m" --milestones)
    _check "--milestones prints the top-level milestone lines" [ "$out" == $'- Milestone: 1. **Core** (Complete)\n- Milestone: 2. **Next** (In Progress)' ]
    { printf '## [2026-01-01] — Session 1: JARPA review\n### Goal\n'; _run_review "$m" --milestones; printf '## [2026-01-02] — Session 2: A\n'; } > "$m/jarpa/JOURNAL.md"
    out=$(_run_review "$m" --today 2026-01-03)
    _check "Milestones unchanged: not due" _has "[ok] no review due"
    sed -i 's/   - Progress: a/   - Progress: b/' "$m/jarpa/PROJECT_PLAN.md"
    out=$(_run_review "$m" --today 2026-01-03)
    _check "Sub-bullet edit is not a milestone change" _has "[ok] no review due"
    sed -i 's/\*\*Next\*\* (In Progress)/**Next** (Complete)/' "$m/jarpa/PROJECT_PLAN.md"
    out=$(_run_review "$m" --today 2026-01-03)
    _check "Milestone status change is due" _has "[!!] review due — milestones changed since the last review (Session 1)"
    printf '## [2026-01-01] — Session 1: JARPA review\n### Goal\n## [2026-01-02] — Session 2: A\n' > "$m/jarpa/JOURNAL.md"
    out=$(_run_review "$m" --today 2026-01-03)
    _check "Review without recorded milestones is not compared" _has "[ok] no review due"

    # No journal: explicit note, still exit 0.
    mkdir -p "$tmp/empty/jarpa"
    out=$(_run_review "$tmp/empty"); rc=$?
    _check "Missing JOURNAL.md is reported and exits 0" bash -c '[[ "$1" == *"no jarpa/JOURNAL.md"* && "$2" -eq 0 ]]' _ "$out" "$rc"

    unset -f _run_review _check _has _hasnt _sessions
    rm -rf "$tmp"
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
        statusline) test_statusline ;;
        agents)    test_agents ;;
        commands)  test_commands ;;
        skills)    test_skills ;;
        templates) test_templates ;;
        scripts)   test_scripts ;;
        integration) test_integration ;;
        metrics)   test_metrics ;;
        review)    test_review ;;
        all)
            test_manifest
            test_hooks
            test_statusline
            test_agents
            test_commands
            test_skills
            test_templates
            test_scripts
            test_integration
            test_metrics
            test_review
            ;;
        *)
            echo "Unknown test group: $TEST_GROUP"
            echo "Available groups: manifest, hooks, statusline, agents, commands, skills, templates, scripts, integration, metrics, review, all"
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
