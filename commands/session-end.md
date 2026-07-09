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

Only update if milestones or the Current Step changed:
- Mark completed deliverables (one-line status per milestone — not a progress
  log; detail belongs in JOURNAL).
- Update Current Step emphasis.

Skip this step if nothing changed at the plan level.

### Step 5: Check archiving threshold

```bash
wc -l jarpa/JOURNAL.md
```

Read threshold from `.claude/jarpa.local.md` (`thresholds.journal_lines`,
default: 1500). If the line count is near or exceeds the threshold,
recommend running `/jarpa:archive` separately. Do not archive during
session-end — archiving is a distinct operation that runs
`journal-validator` and requires its own confirmation.

### Step 6: Report summary

Present a concise summary to the user:

```
Session End Complete
━━━━━━━━━━━━━━━━━━━━

✓ Journal entry appended: Session N (YYYY-MM-DD)
✓ TODO.md updated: [what changed]
✓ PROJECT_PLAN.md updated: [what changed, or "no change"]

Next task: [name]

JOURNAL.md: [N] lines (threshold: [M])[ — archiving recommended]
```

## Context-Awareness Thresholds

Canonical, in sync with `statusline/statusline.sh`:

- At 75% (WARNING), suggest planning session closure.
- At 90% (CRITICAL), strongly recommend immediate `/jarpa:session-end`.

## When to Use

Runs automatically via the Stop and PreCompact hooks; also invoke manually
before closing, before committing significant work, or when switching tasks.
