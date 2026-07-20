---
name: jarpa:session-start
description: Present current JARPA project status, validate scope, and check journal archiving needs
---

# JARPA Session Start

Run the full session-start workflow inline. **Do not spawn a sub-agent** —
this command must execute in the main conversation so the main agent's
document cache is reused and no extra roundtrip is incurred.

## Scope Discipline (MANDATORY)

JARPA tracks exactly **one** logbook per repository, located at `jarpa/`
under the repository root. Apply these rules strictly:

1. **Only read files under `jarpa/` at the repository root.** Do not descend
   into sub-directories (e.g., `packages/*/jarpa/`).
2. **Treat sub-project names as labels, not navigation signals.** If
   `TODO.md` says `[ONGOING] Fix auth in sub-project A`, do not go exploring
   `sub-project-A/`.
3. **Never invent a JARPA structure** for a sub-project that isn't
   JARPA-tracked. If the user asks about one, say so and stop.
4. **If the user explicitly asks you to read outside `jarpa/`**, do so but
   state clearly that you are stepping outside the JARPA scope.
5. **Recalled persistent memories are pointers, not truths.** One asserting
   a project fact (a file, flag, or procedure) must be verified against the
   repository before use — the repository wins.

## Process

### Step 1: Read project state

Read these three files:

- `jarpa/PROJECT_PLAN.md` → identify current milestone and step
- `jarpa/TODO.md` → find the task marked `[ONGOING]` or the top priority task
- `jarpa/JOURNAL.md` → understand recent work from the last 1-2 entries

### Step 2: Present "where are we now" summary

```
JARPA Session Start
━━━━━━━━━━━━━━━━━━

Current Milestone: [milestone name]
Current Step: [step description]

Current Task: [ONGOING task from TODO.md]
Definition of Done: [DoD from task]

Recent Progress:
- [Summary from last 1-2 journal entries]

Ready to begin working on: [task name]
```

### Step 3: Validate scope

Check whether the current task fits one working session (target: 2-4 hours
of focused work).

- ✅ Good: "Add login form validation with 3 rules"
- ✅ Good: "Fix crash on empty password input"
- ❌ Too large: "Implement complete authentication system"
- ❌ Too vague: "Improve user experience"

If the task is too large:
1. Identify logical breakpoints.
2. Suggest 2-4 smaller, concrete tasks.
3. Help the user choose which to tackle first.
4. Update `TODO.md` with the split (only after the user agrees).

If the task is unclear, ask the user for clarification.

### Step 4: Check for journal archiving need

```bash
wc -l jarpa/JOURNAL.md
```

Read threshold from `.claude/jarpa.local.md` (`thresholds.journal_lines`,
default: 1500). If the line count exceeds the threshold, suggest running
`/jarpa:archive`. Do not archive automatically.

### Step 5: Context awareness during the session

During long sessions, watch the JARPA statusline gauge:
- At 75% (WARNING), recommend planning session closure.
- At 90% (CRITICAL), strongly recommend immediate `/jarpa:session-end`.

## Error Handling

- If `jarpa/` doesn't exist: suggest running `/jarpa:init`.
- If files are malformed: report the specific issue and suggest a fix.
- If no `[ONGOING]` task exists: help identify the next priority task.

## When to Use

This command runs automatically via the SessionStart hook. Users can also
invoke it manually with `/jarpa:session-start` to re-orient mid-session.
