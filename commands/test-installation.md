---
name: jarpa:test-installation
description: Verify JARPA plugin is correctly installed and functional in Claude Code
---

# JARPA Installation Test

This command verifies that the JARPA plugin is correctly installed and all components are functional.

## Instructions

Run each test and report results. Use this format for each test:

```
[PASS] Test description
[FAIL] Test description - reason
```

### Test 1: Plugin Loaded

Check that the JARPA plugin is recognized by looking at available commands.

The following commands should be available (check /help output or attempt to invoke):
- `/jarpa:init`
- `/jarpa:status`
- `/jarpa:archive`
- `/jarpa:session-end`
- `/jarpa:migrate`
- `/jarpa:test-installation` (this command)

Report: List which commands are available and which are missing.

### Test 2: Agents Registered

Check that JARPA agents are available:
- `session-protocol`
- `journal-validator`

Try to determine if agents are registered (they appear in agent listings or can be invoked via Task tool).

### Test 3: Skills Loaded

Check that JARPA skills are available:
- `jarpa-methodology`
- `jarpa-housekeeping`

Skills should be loadable and their content accessible.

### Test 4: MCP Server Status

Run `/mcp` to check MCP server status. Look for:
- `context-monitor` server should be listed
- Server should show as "connected" or available

If the server is not listed or has errors, report the issue.

### Test 5: Hook Configuration

Hooks cannot be directly tested without triggering events, but verify:
- Read the hooks.json file at the plugin root (use Glob to find `**/hooks/hooks.json` under the JARPA plugin directory)
- Confirm it contains: SessionStart, Stop, PreCompact, PreToolUse hooks
- For each hook, verify the referenced script file exists and is executable

### Test 6: Template Files

Verify template files exist and are readable:
- Use Glob to find `**/templates/*.md` under the JARPA plugin directory
- Verify all 5 expected templates are present

Expected templates:
- PROJECT_PLAN.md
- TODO.md
- REQUIREMENTS.md
- ARCHITECTURE.md
- JOURNAL.md

### Test 7: Functional Test - Init (Dry Run)

Do NOT actually run /jarpa:init, but verify it would work:
1. Check that templates directory exists
2. Check that templates are readable
3. Confirm the command definition is valid

### Summary

After running all tests, present a summary:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
JARPA Installation Test Results
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Plugin loaded:     [PASS/FAIL]
Commands:          [X/6] available
Agents:            [X/2] registered
Skills:            [X/2] loaded
MCP Server:        [PASS/FAIL]
Hooks configured:  [PASS/FAIL]
Templates:         [X/5] found

Overall: [PASS/FAIL]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If any tests fail, provide specific remediation steps.
