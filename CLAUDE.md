# JARPA Plugin Development

## Project Overview

JARPA is a Claude Code plugin providing structured documentation methodology for AI-assisted software engineering. The acronym stands for **J**ournal, **A**rchitecture, **R**equirements, **P**lan, **A**ctions.

## Plugin Development Methodology

Self-apply skills/jarpa-methodology/SKILL.md.

## JARPA Self-Application Disambiguation (MANDATORY)

This repo develops the JARPA plugin AND uses JARPA methodology on itself.
Two distinct JARPA instances coexist conceptually — same filenames, same
folder layout, entirely different roles:

1. **Plugin's own JARPA** (self-applied, this repo)
   - Location: `/home/pgaufillet/git/jarpa/jarpa/` (gitignored, maintainer-only)
   - Purpose: tracks plugin development sessions and decisions
   - Audience: plugin maintainer only

2. **Consumer project's JARPA** (abstract or actual end-user project)
   - Location: `<user-project>/jarpa/` (wherever the consumer placed it)
   - Purpose: tracks the user's own project, using this plugin
   - Audience: end users of the plugin

**Rule**: when referencing any JARPA file during plugin development,
always qualify with "plugin's" or "consumer's". Never write or say
bare `jarpa/ARCHITECTURE.md` or "the PROJECT_PLAN" — those references
are ambiguous in this repo.

**Reflex check**: before stating a fact about any `jarpa/` file, ask
"which instance?" If the answer is not obvious from context, re-read
to confirm before asserting.

**Why it matters**: confusion between instances has caused real bugs
in this project (stale agent inventories, wrong grep patterns in
validators, wrong schema assumptions). Vocabulary discipline is a
cheap guardrail against a recurring and dangerous failure mode.

## Plugin Structure

```
.claude-plugin/plugin.json    # Plugin manifest
commands/                      # Slash commands (jarpa:init, jarpa:status, etc.)
agents/                        # Sub-agents (journal-validator, coherence-validator, session-reviewer) — reserved for autonomous reviews; synchronous workflows run inline in commands/
skills/                        # Skills (jarpa-methodology, jarpa-housekeeping)
hooks/                         # Hook definitions and scripts
statusline/                    # Statusline script (statusline.sh)
templates/                     # Template files for /jarpa:init
tests/                         # Automated test suite
jarpa/                         # JARPA logbook (gitignored, local working docs)
```

## Key Conventions

- **Git commits**: No AI attribution, no conventional prefixes, no JARPA references (session numbers, milestones). Short title (50 chars), optional body.
- **Tests**: No dummy or placeholder tests. Every test must set up, act, verify, and be capable of failing.
- **Documentation**: Only JOURNAL.md is cumulative. All other docs reflect current state.

## Running Tests

```bash
# Structure + unit tests (safe to run anywhere)
./tests/run_all_tests.sh -v

# Full suite including Claude Code integration (requires separate terminal)
./tests/run_all_tests.sh --full
```

