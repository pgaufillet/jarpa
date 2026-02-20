# JARPA Plugin Development

## Project Overview

JARPA is a Claude Code plugin providing structured documentation methodology for AI-assisted software engineering. The acronym stands for **J**ournal, **A**rchitecture, **R**equirements, **P**lan, **A**ctions.

## Plugin Development Methodology

Self-apply skills/jarpa-methodology/SKILL.md.

## Plugin Structure

```
.claude-plugin/plugin.json    # Plugin manifest
commands/                      # Slash commands (jarpa:init, jarpa:status, etc.)
agents/                        # Sub-agents (session-protocol, journal-validator)
skills/                        # Skills (jarpa-methodology, jarpa-housekeeping)
hooks/                         # Hook definitions and scripts
mcp-servers/                   # MCP server (context-monitor)
templates/                     # Template files for /jarpa:init
tests/                         # Automated test suite
jarpa/                         # JARPA logbook (gitignored, local working docs)
```

## Key Conventions

- **Git commits**: No AI attribution, no conventional prefixes. Short title (50 chars), optional body.
- **Tests**: No dummy or placeholder tests. Every test must set up, act, verify, and be capable of failing.
- **Documentation**: Only JOURNAL.md is cumulative. All other docs reflect current state.

## Running Tests

```bash
# Structure + unit tests (safe to run anywhere)
./tests/run_all_tests.sh -v

# Full suite including Claude Code integration (requires separate terminal)
./tests/run_all_tests.sh --full
```

