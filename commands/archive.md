---
name: jarpa:archive
description: Archive older journal entries when threshold is exceeded
---

# Archive Journal

Archive older JOURNAL.md sessions when the file exceeds the configured threshold.

## Behavior

Automatically detects when archiving is needed based on line count and performs validated archiving with session numbering verification.

## Process

1. **Check settings**:
   - Read `.claude/jarpa.local.md` for `thresholds.journal_lines` (default: 1500)
   - Read `paths.docs` and `paths.archives` (defaults: "./jarpa" and "./jarpa/archive")

2. **Count lines** in JOURNAL.md:
   ```bash
   wc -l jarpa/JOURNAL.md
   ```

3. **Evaluate threshold**:
   - If line count < threshold: Inform user no archiving needed, show current count
   - If line count >= threshold: Proceed with archiving

4. **Invoke journal-validator agent**:
   - Use Task tool with `subagent_type: journal-validator`
   - Pass task: "Validate journal structure before archiving"
   - Agent will:
     - Extract session numbers
     - Verify sequential numbering (no gaps/duplicates)
     - Report any issues found

5. **If validation passes, proceed with archiving**:
   - Identify sessions to archive (keep 5-10 most recent)
   - Extract date range from oldest to newest archived session
   - Extract session number range
   - Create archive filename: `JOURNAL_YYYY-MM-DD_YYYY-MM-DD_S<first>-<last>.md`

6. **Create archive file** in jarpa/archive/:
   ```markdown
   # [Project Name] - Journal Archive

   **Sessions:** [first] to [last]
   **Period:** YYYY-MM-DD to YYYY-MM-DD
   **Archived from:** Active JOURNAL.md on YYYY-MM-DD

   ---

   [Archived session content]
   ```

7. **Update JOURNAL.md**:
   - Keep file header (if exists)
   - Add archive reference to header section
   - Keep only recent sessions (5-10 latest)
   - Remove archived sessions

8. **Verify results**:
   - Count lines in updated JOURNAL.md
   - Confirm line count is now under threshold
   - Verify archive file created successfully

9. **Report summary**:
   - Archive filename created
   - Session range archived
   - Date range archived
   - New line count in JOURNAL.md
   - Any validation issues found

## Tools to Use

- Read: Check settings, read JOURNAL.md
- Bash: Count lines with wc -l, create archive directory
- Task: Invoke journal-validator agent
- Write: Create archive file
- Edit: Update JOURNAL.md (remove archived content, add archive reference)

## Example Usage

```
/jarpa:archive
```

If JOURNAL.md is below threshold:
```
JOURNAL.md has 847 lines (threshold: 1500). No archiving needed.
```

If JOURNAL.md exceeds threshold:
```
Archiving JOURNAL.md (1823 lines, threshold: 1500)...
✓ Validation passed: Sessions 1-45 sequential, no gaps
✓ Created: jarpa/archive/JOURNAL_2024-01-15_2024-06-20_S1-S40.md
✓ Archived sessions 1-40 (Jan 15 - Jun 20, 2024)
✓ Kept sessions 41-45 in active JOURNAL.md
✓ New line count: 421 lines
```

## Edge Cases

- **Validation fails**: Report issues to user, do not proceed with archiving
- **No sessions found**: Inform user, cannot archive
- **All sessions are recent**: Inform user, increase threshold or proceed with partial archive
- **Archive directory missing**: Create it automatically

## Safety

- Always validate before archiving
- Never delete content without creating archive first
- Preserve all session numbering information
- Keep session order intact
