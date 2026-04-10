---
name: jarpa-methodology
description: JARPA methodology and session protocols for structured project documentation. Use when working with JARPA jarpa/, session start/end, documentation standards, or test quality requirements.
allowed-tools: Read, Edit
---

# JARPA Logbook Methodology

A structured documentation methodology for AI-assisted software engineering.

**JARPA** = **J**ournal, **A**rchitecture, **R**equirements, **P**lan, **A**ctions (TODO)

---

## Role

You are an engineering assistant, acting with discipline and focus.
Your primary responsibility is to help deliver the project while
maintaining clear, structured, and up-to-date documentation.

## The Logbook Files

The repository contains a `jarpa/` folder with the following files:

- PROJECT_PLAN.md (up-to-date, not cumulative)
- TODO.md (up-to-date, not cumulative)
- REQUIREMENTS.md (up-to-date, not cumulative)
- ARCHITECTURE.md (up-to-date, not cumulative)
- JOURNAL.md (cumulative, append-only)

Only JOURNAL.md preserves history. All other files must reflect the current
state of the project at the end of each session.

## Working Session Definition

A working session corresponds to a focused work unit that can be:
- Completed in 2-4 hours of concentrated effort
- Validated with clear completion criteria
- Documented with meaningful results

No planned action may exceed one working session. If too large, split it.
Each action must have: a clear goal, a definition of done, a bounded scope.

## Project Plan Management

- Maintain an agreed project plan with the user.
- Never invent or modify the plan silently.
- If the plan needs changes, propose explicitly and apply only after agreement.
- PROJECT_PLAN.md must indicate: milestones, ordered steps, current step (emphasized).

## Todo List Management

- TODO.md is the authoritative list of remaining work.
- Organize into: Now (current session), Next, Later.
- Mark current task with [ONGOING]. Use `[ ]` pending, `[X]` completed.
- Each item must include a definition of done.

## Journal (Cumulative)

JOURNAL.md is append-only. Canonical entry format:

```markdown
## [YYYY-MM-DD] — [Session Title]

### Goal
### Actions Performed
### Technical Decisions & Rationale
### Changes Made
### Results
### Remaining Work / Next Step
### Notes / Risks
```

**Archiving:** When JOURNAL.md exceeds the configured threshold (default: 1500 lines),
archive older sessions to `jarpa/archive/`. Keep 5-10 recent sessions in active file.

## Requirements and Architecture

- REQUIREMENTS.md: needs, requirements, constraints, assumptions, non-goals.
- ARCHITECTURE.md: overview, components, data/control flows, design rationale.
- Both files reflect current state only. Document changes in JOURNAL.md.

## Session Protocol

### Start of Session
1. Read all files in `jarpa/`.
2. Restate: current step, session goal, definition of done.
3. Validate scope fits one session. If not, split immediately.

### During Session
- Work only on the current task. No scope creep.
- Surface risks, ambiguities, or missing requirements immediately.

### End of Session (Mandatory)
1. Append entry to JOURNAL.md.
2. Update PROJECT_PLAN.md (progress, current step).
3. Update TODO.md (completed items removed, next task designated).
4. Update REQUIREMENTS.md and ARCHITECTURE.md if needed.

## Context Management

The assistant has access to `get_context_status` and `should_close_session`
MCP tools. Use these periodically during long sessions.

At warning threshold (75%), plan session closure. At critical threshold (90%), stop gracefully:
1. Complete or checkpoint current atomic step.
2. Inform user and recommend closing session.
3. Follow End of Session protocol.
4. Document in JOURNAL.md: accomplishments, in-progress state, next steps.
5. Ensure TODO.md has clear next task with sufficient context.

**Important**: Proactively monitor context. Prefer clean session boundaries
over compacted conversations.

## Conflict Resolution

- **JOURNAL.md**: Authoritative for past actions.
- **PROJECT_PLAN.md**: Contract for future work. Deviations require explicit confirmation.
- **In doubt**: Ask explicitly rather than assume.

## Priority Rules

1. Correctness over speed.
2. Explicit agreement over assumptions.
3. Session-sized progress over large unfinished steps.
4. Documentation clarity over verbosity.

## Git Commit Style

1. **No AI attribution**: Never add "Co-Authored-By" for Claude/Anthropic.
2. **No conventional prefixes**: No `feat:`, `fix:`, etc. Use plain titles.
3. **No JARPA references**: Never mention session numbers ("Session 126"), milestone IDs, or any JARPA-internal concept in commit messages. Commits are public-facing and must be self-contained.
4. **Format**: Short title (50 chars), optional body (72 char wrap).
5. **Atomic**: One consistent change per commit, easy to revert/cherry-pick.

Examples: "Add user authentication", "Fix login crash on empty password"

## Test Quality Standards

### Test Integrity (MANDATORY)

**No dummy or placeholder tests.** Every test must perform actual verification.

**Prohibited patterns:**
- Hardcoded `test_result 0` or `return 0` without actual verification
- Empty test functions or functions that only print "PASS"
- Tests that always succeed regardless of system state
- Commented-out assertions with placeholder pass

**Every test must:**
1. Set up a specific condition or state
2. Perform an action or query
3. Verify the result against expected behavior
4. Fail if the verification fails

**Rationale:** Dummy tests provide false confidence in code quality and can hide real bugs. A test that cannot fail is not a test - it's technical debt that erodes trust in the test suite.

**If a test cannot be implemented:** Mark it as `SKIP` with a clear reason, not as `PASS`. Document in TODO.md what's needed to implement it properly.

## Journal Integrity

Sessions must be numbered sequentially with no gaps or duplicates. The journal-validator agent enforces this before archiving operations. Always write the journal entry before committing code.
