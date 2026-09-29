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

An engineering assistant acting with discipline and focus: deliver the
project while keeping documentation clear, structured, and up-to-date.

## The Logbook Files

The repository contains a `jarpa/` folder with the following files:

- PROJECT_PLAN.md (up-to-date, not cumulative)
- TODO.md (up-to-date, not cumulative)
- REQUIREMENTS.md (up-to-date, not cumulative)
- ARCHITECTURE.md (up-to-date, not cumulative)
- JOURNAL.md (cumulative, append-only)

Only JOURNAL.md preserves history. All other files must reflect the current
state of the project at the end of each session.

**Satellite files.** Any other file in `jarpa/` (a sub-plan, an index, an
audit report) declares its status in its first lines, so it can be kept or
removed deliberately:

- `<!-- jarpa-status: living -->` — kept current, like the core files.
- `<!-- jarpa-status: snapshot -->` — dated record, never updated.
- `<!-- jarpa-status: temporary, due: YYYY-MM-DD -->` — a temporary plan
  (sprint, run-sheet), deleted once consumed. The due date is mandatory;
  past it, consume the plan or reschedule it explicitly.

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
- Current-state only: no per-session progress narrative. A milestone carries a
  one-line status, not a running log. Completed-work detail lives in JOURNAL.
- Current Step is a constant-size synthesis (a few sentences). Update it by
  rewriting, never by appending session entries — if it only grows, it is
  drifting into a journal.
- **PLAN holds direction, TODO holds work.** PROJECT_PLAN carries only stable
  content: goal, milestones, ordered steps, current step. Every actionable
  task — including planned work not yet started — lives in TODO. A PLAN entry
  that needs the JOURNAL to justify itself is misfiled.

## Todo List Management

- TODO.md is the authoritative list of remaining work.
- Organize into: Now (current session), Next, Later.
- Mark current task with [ONGOING]. Use `[ ]` pending, `[X]` completed.
- Each item must include a definition of done.
- Prune on completion: drop finished items (their record lives in JOURNAL).
  Keep at most a short "Recently Done" for the current session only.
- Not-yet-started work goes to Next or Later, never to PROJECT_PLAN (see
  Project Plan Management).

## Journal (Cumulative)

JOURNAL.md is append-only. Canonical entry format:

```markdown
## [YYYY-MM-DD] — Session N: Title

### Goal
### Actions Performed
### Technical Decisions & Rationale
### Changes Made
### Results
### Remaining Work / Next Step
### Notes / Risks
```

Session numbers are mandatory, sequential, and enforced by journal-validator
before archiving.

**Keep entries lean — target 50-100 lines (about 6 KB).** Write only what a
future session needs: Changes Made summarizes (don't enumerate every file);
Technical Decisions records only the non-obvious; fold Notes/Risks into
Remaining Work when thin. Measurements repeated every session belong in a
structured file cited by the entry, not in prose.

**Measure in bytes.** Line counts are skewed by wrapping. `/jarpa:session-end`
reports sizes in bytes against configurable thresholds (report only).

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
2. Update PROJECT_PLAN.md only if the current step or a milestone status changed.
3. Update TODO.md (completed items removed, next task designated).
4. Update REQUIREMENTS.md and ARCHITECTURE.md if needed.
5. Review the hygiene report and act on flagged items, or plan them in TODO.

### Periodic Review
`/jarpa:review` runs as a dedicated session when session start announces it
due (every 15 sessions, after a pause of over 30 days, or on a milestone
change). It checks project, document and method drift; every finding is fixed,
scheduled in TODO with a date, or refused, and the next review starts from
the scheduled ones. Its JOURNAL entry is titled `Session N: JARPA review`.

## Context Management

The JARPA statusline surfaces context-window usage every turn; watch its gauge
during long sessions.

At warning threshold (75%), plan session closure. At critical threshold (90%),
stop gracefully: checkpoint the current atomic step, follow the End of Session
protocol, and ensure TODO.md carries a clear next task with enough context.
Prefer clean session boundaries over compacted conversations.

## Conflict Resolution

- **JOURNAL.md**: Authoritative for past actions.
- **PROJECT_PLAN.md**: Contract for direction (goal, milestones, current step). Deviations require explicit confirmation.
- **In doubt**: Ask explicitly rather than assume.

## Persistent Memory Boundary

The consumer repository IS the project's memory. The assistant's persistent
memory (auto-memory directory) is a second, unversioned, probabilistically
recalled store. **Prefer disabling it** in JARPA projects:
`"autoMemoryEnabled": false` in `.claude/settings.json` (or
`CLAUDE_CODE_DISABLE_AUTO_MEMORY=1` for one session). If kept, restrict it
to what the repository cannot hold:

- **Store in memory**: user profile and collaboration preferences only
  (who the user is, how they want the assistant to work).
- **Never store in memory**: project facts, technical findings, tooling
  pitfalls, methodology rules. Their homes are the consumer's `docs/`,
  `CLAUDE.md`, or `jarpa/` files — versioned, reviewable, and loaded
  deterministically.
- **Write-time test**: "would this matter in a different project with the
  same user?" If not, it is a project fact — it goes in the repository.
- **Recall-time rule**: a recalled memory asserting a project fact is a
  pointer, not a truth. Verify it against the repository; the repository
  wins.

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

**No dummy or placeholder tests.** Every test must set up a specific state,
act, verify against expected behavior, and be able to fail. Prohibited: hardcoded
`return 0`, functions that only print "PASS", tests that pass regardless of state,
commented-out assertions. A test that cannot fail is technical debt that hides
bugs and erodes trust.

If a test cannot be implemented, mark it `SKIP` with a reason (never `PASS`) and
note in TODO.md what's needed.

## Journal Integrity

Sessions must be numbered sequentially with no gaps or duplicates. The journal-validator agent enforces this before archiving operations. Always write the journal entry before committing code.
