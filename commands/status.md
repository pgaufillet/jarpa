---
name: jarpa:status
description: Display current JARPA session status - milestone, active task, and recent progress
---

# JARPA Status Command

Display the current project status to orient the session.

## Instructions

Execute these steps and present the results:

### Step 1: Check for JARPA project

First, verify that the JARPA documentation structure exists:

```bash
ls -la jarpa/PROJECT_PLAN.md jarpa/TODO.md jarpa/JOURNAL.md 2>/dev/null
```

If files don't exist, inform the user:
> JARPA documentation not found. Run `/jarpa:init` to initialize the project structure.

### Step 2: Read project state

Read these files to extract current state:

1. **jarpa/PROJECT_PLAN.md** - Find:
   - Current milestone (look for emphasis markers like `**current**` or the active milestone)
   - Current step being worked on

2. **jarpa/TODO.md** - Find:
   - Task marked with `[ONGOING]`
   - Or if none, the top task in the "Now" section
   - Include its Definition of Done (DoD)

3. **jarpa/JOURNAL.md** - Find:
   - The most recent entry (last `## [YYYY-MM-DD]` section)
   - Summarize key accomplishments and next steps mentioned

### Step 3: Check journal size

```bash
wc -l jarpa/JOURNAL.md
```

If over 1500 lines, note that archiving is recommended.

### Step 4: Present formatted status

Display to the user:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
JARPA Session Status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

**Milestone**: [current milestone]
**Current Step**: [step description]

**Active Task**: [task name]
  Status: [ONGOING] or [ ] (pending)
  DoD: [definition of done]

**Last Session** ([date]):
- [key accomplishment 1]
- [key accomplishment 2]
- Next: [what was planned next]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If journal needs archiving, add:
```
⚠️  Journal has [N] lines (threshold: 1500). Consider running /jarpa:archive
```

### Step 5: Offer to continue

End with:
> **Ready to continue.** What would you like to work on?
