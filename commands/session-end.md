---
name: jarpa:session-end
description: Complete end-of-session documentation updates
---

# End Session Documentation

Guide through end-of-session JARPA documentation updates using the session-protocol agent.

## Behavior

Invokes the session-protocol agent to perform guided, interactive end-of-session documentation updates following JARPA methodology.

## Process

1. **Invoke session-protocol agent**:
   - Use Task tool with `subagent_type: jarpa:session-protocol`
   - Pass task description:
     ```
     Perform end-of-session workflow:
     1. Gather session information from user (accomplishments, decisions, risks)
     2. Create journal entry in JOURNAL.md using canonical format
     3. Update TODO.md: mark completed tasks, designate next task
     4. Update PROJECT_PLAN.md: reflect progress made
     5. Check if JOURNAL.md needs archiving (check threshold)
     ```

2. **Agent will interact with user**:
   - Use AskUserQuestion to gather session information:
     - What was accomplished this session?
     - Which tasks were completed?
     - What is the next task?
     - Any technical decisions or risks to document?

3. **Agent will update files**:
   - Append formatted entry to JOURNAL.md
   - Update TODO.md (mark completed, designate next)
   - Update PROJECT_PLAN.md if milestones changed
   - Check JOURNAL.md line count

4. **If archiving needed**:
   - Agent will inform user
   - Suggest running `/jarpa:archive` command
   - Do not archive automatically during session-end

5. **Report summary** of changes made

## Tools to Use

- Task: Invoke session-protocol agent

## Example Usage

```
/jarpa:session-end
```

Agent will guide through:
```
Session End Documentation
━━━━━━━━━━━━━━━━━━━━━━━━━

Current status:
- TODO.md shows: [ONGOING] Implement user authentication
- Last journal entry: 2024-06-15

Let me gather information for the journal entry...

[Interactive questions to user about session accomplishments]

Updating documentation...
✓ Appended journal entry for 2024-06-20
✓ Updated TODO.md: Marked 2 tasks complete, next task designated
✓ Updated PROJECT_PLAN.md: Milestone 2 progress
✓ JOURNAL.md at 1234 lines (threshold: 1500)

Summary:
- Journal entry created for session on 2024-06-20
- Completed: User authentication, Password validation
- Next: Session management implementation
```

## When to Use

This command should be run:
- At the end of every working session (before closing Claude Code)
- Before committing significant work
- When switching to a different task or project area

## Automation

This command is automatically triggered by:
- Stop hook
- PreCompact hook (when context usage is very high)

Users can also invoke it manually when needed.

## Integration with Workflow

The session-end workflow ensures JARPA discipline:
1. Work is always documented before session closes
2. TODO.md always reflects current state
3. PROJECT_PLAN.md stays up-to-date
4. Journal preserves complete history
5. Context management is proactive (check for archiving)
