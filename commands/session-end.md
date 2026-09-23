---
name: jarpa:session-end
description: Complete end-of-session documentation updates
---

# JARPA Session End

Run the full end-of-session workflow inline. **Do not spawn a sub-agent** —
this command must execute in the main conversation so the main agent's
document cache is reused and no extra roundtrip is incurred.

## Scope Discipline (MANDATORY)

Only read and write files under `jarpa/` at the repository root. Do not
descend into nested `jarpa/` directories inside sub-projects.

## Process

### Step 1: Gather session information

Collect the session summary with a single batched `AskUserQuestion` call
(goal, what was accomplished, tasks completed, technical decisions +
rationale, remaining work/risks, next task). If an answer is obvious from
the conversation, propose it as the default instead of asking.

### Step 2: Append journal entry to JOURNAL.md

Determine the next session number by reading the last `## [YYYY-MM-DD] —
Session N:` header in `jarpa/JOURNAL.md` and incrementing. Determine the
date with `date +%F`.

Append using this canonical format:

```markdown

## [YYYY-MM-DD] — Session N: Title

### Goal
- [Session goal]

### Actions Performed
- [Actions taken]

### Technical Decisions & Rationale
- Decision: [Decision]
- Rationale: [Why]

### Changes Made
- Files updated:
  - [File list]

### Results
- [Outcomes and achievements]

### Remaining Work / Next Step
- [Next task or continuation]

### Notes / Risks
- [Any concerns or observations]
```

Keep the entry lean — target 50-100 lines. Summarize Changes Made (don't list
every file); record only non-obvious decisions; fold thin Notes/Risks into
Remaining Work.

Use `Edit` to append (find the last line of the file and add the new entry
after it). Do not use `Write` — it would overwrite the file.

### Step 3: Update TODO.md

- Mark completed tasks with `[X]` and the completion date.
- Prune completed items — their record lives in JOURNAL. Keep at most a short
  "Recently Done" for this session.
- Remove or update the `[ONGOING]` marker.
- Designate the next task if known.
- Use `Edit` for surgical updates.

### Step 4: Update PROJECT_PLAN.md (if needed)

Touch this file only when the coarse-grain state changed: a front opened or
closed, the current step moved, or a milestone status changed. Skip
otherwise — most sessions do not qualify.

When it did change:
- **Rewrite, never append.** Current Step is a constant-size synthesis (a
  few sentences: what is acquired, the active front, the next step).
  Per-session narrative ("Session N: …") never enters this file — that is
  JOURNAL's job.
- Milestones carry a one-line status, not a progress log.
- Open questions go to Risks / Open Questions, not Current Step.
- Planned but not-yet-started work goes to TODO (Next/Later), not here. A
  PLAN entry that needs the JOURNAL to justify itself is misfiled.

### Step 5: Memory hygiene

Review memories written during this session. Any that records a project or
technical fact must be moved to its repository home (docs/, CLAUDE.md,
jarpa/) and the memory file deleted — persistent memory keeps only
user-profile and collaboration preferences (see the jarpa-methodology
skill, "Persistent Memory Boundary").

### Step 6: Measure hygiene

Run the metrics script after the journal and TODO updates, so it measures
this session's final state:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/metrics.sh"
```

It reports — in bytes, since line counts are skewed by wrapping — JOURNAL
size and entry sizes, TODO and PROJECT_PLAN sizes, closed TODO items,
`[ONGOING]` markers, satellites without a status marker, session
references in recent commits of the project's repositories, the managed
CLAUDE.md block state, and the auto-memory state. Thresholds come from
`.claude/jarpa.local.md` (`thresholds.*`) with documented defaults.

The report is advisory: never block, never fix during session-end. Relay
it verbatim, and for each `[!!]` line recommend the matching action in one
line (e.g. `/jarpa:archive`, prune TODO, rewrite PROJECT_PLAN to current
state, `/jarpa:upgrade`). Do not archive during session-end — archiving is
a distinct operation that runs `journal-validator` and requires its own
confirmation.

### Step 7: Report summary

Present a concise summary to the user:

```
Session End Complete
━━━━━━━━━━━━━━━━━━━━

✓ Journal entry appended: Session N (YYYY-MM-DD)
✓ TODO.md updated: [what changed]
✓ PROJECT_PLAN.md updated: [what changed, or "no change"]

Next task: [name]

[metrics report, verbatim]
[one recommended action per [!!] line]
```

## Context-Awareness Thresholds

Canonical, in sync with `statusline/statusline.sh`:

- At 75% (WARNING), suggest planning session closure.
- At 90% (CRITICAL), strongly recommend immediate `/jarpa:session-end`.

## When to Use

Runs automatically via the Stop and PreCompact hooks; also invoke manually
before closing, before committing significant work, or when switching tasks.
