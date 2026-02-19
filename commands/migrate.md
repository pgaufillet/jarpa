---
name: jarpa:migrate
description: Migrate legacy JARPA project to plugin-based system
---

# Migrate Legacy JARPA Project

Automate migration of projects using the old JARPA template approach to the new plugin-based system.

## Behavior

This command safely migrates a legacy JARPA project by:
1. Detecting existing jarpa/ structure
2. Creating plugin settings
3. Cleaning up template artifacts
4. Preserving all documentation

## Prerequisites

- Existing `jarpa/` directory with JARPA files
- Git repository (recommended for safety)
- No uncommitted changes (recommended)

## Process

### 1. Safety Check

**Verify git status**:
```bash
git status
```

If uncommitted changes exist, ask user:
- **Option A**: Commit changes first (recommended)
- **Option B**: Proceed anyway (user accepts risk)
- **Option C**: Abort migration

Create checkpoint commit if user agrees:
```bash
git commit -am "Pre-JARPA plugin migration checkpoint"
```

### 2. Detect Legacy Project

Check for legacy indicators:
- `jarpa/` directory exists
- One or more of: `.codex/`, `MASTER_INSTRUCTIONS.md`, `CLAUDE.md`, `init_docs.sh`

If no legacy indicators found:
- Inform user this appears to be a new project
- Suggest using `/jarpa:init` instead
- Abort migration

### 3. Extract Project Information

**Get project name** from:
1. Existing `jarpa/PROJECT_PLAN.md` (parse from first heading or content)
2. Git repository name: `basename $(git rev-parse --show-toplevel 2>/dev/null)`
3. Current directory name: `basename $(pwd)`
4. Ask user with AskUserQuestion if unclear

**Get existing settings** (if any):
- Check for custom threshold in comments or documentation
- Note custom paths if jarpa/ is in different location

### 4. Create Settings File

Create `.claude/jarpa.local.md`:

```yaml
---
project:
  name: "[Detected Project Name]"
  description: "Migrated from legacy JARPA template"

paths:
  docs: "./jarpa"
  archives: "./jarpa/archive"

thresholds:
  journal_lines: 1500
  context_percent: 95

session:
  expected_duration: "2-4 hours"
  strict_mode: true

migration:
  date: "[YYYY-MM-DD]"
  from: "template"
  to: "plugin-0.1.0"
---

# JARPA Settings for [Project Name]

Migrated from legacy template on [date].

## Migration Notes

Original template artifacts removed:
- [List files that were removed]

## Custom Configuration

Add project-specific notes here.
```

### 5. Clean Up Template Artifacts

**Remove legacy files** (with confirmation):

Use AskUserQuestion to confirm removal:
- Question: "Remove legacy template files?"
- Options:
  - "Yes, remove all" (recommended)
  - "No, keep for reference"
  - "Archive to .jarpa-legacy/ folder"

**Files to remove/archive**:
- `.codex/` directory
- `MASTER_INSTRUCTIONS.md`
- `CLAUDE.md`
- `.claude/CLAUDE.md`
- `init_docs.sh`
- Any template-specific files

**If "Archive" selected**:
```bash
mkdir -p .jarpa-legacy
mv .codex .jarpa-legacy/ 2>/dev/null
mv MASTER_INSTRUCTIONS.md .jarpa-legacy/ 2>/dev/null
mv CLAUDE.md .jarpa-legacy/ 2>/dev/null
mv init_docs.sh .jarpa-legacy/ 2>/dev/null
echo "Legacy files archived to .jarpa-legacy/" >> .claude/jarpa.local.md
```

**If "Remove" selected**:
```bash
rm -rf .codex MASTER_INSTRUCTIONS.md CLAUDE.md .claude/CLAUDE.md init_docs.sh
```

### 6. Update .gitignore

Check if `.gitignore` exists. If yes, append; if no, create:

```gitignore
# JARPA plugin settings (per-machine)
.claude/*.local.md

# Planning files
.claude/plans/

# Legacy archive (if kept)
.jarpa-legacy/
```

Verify no duplicate entries before appending.

### 7. Validate jarpa/ Structure

**Check required files exist**:
- jarpa/PROJECT_PLAN.md
- jarpa/TODO.md
- jarpa/REQUIREMENTS.md
- jarpa/ARCHITECTURE.md
- jarpa/JOURNAL.md

**Report any missing files** and suggest recovery:
- If missing: "Warning: jarpa/[file] not found. Create manually or run /jarpa:init"
- If all present: "✓ All documentation files present"

### 8. Check Journal Integrity

Quick validation:
```bash
wc -l jarpa/JOURNAL.md
```

If > 1500 lines, inform user:
"Consider running /jarpa:archive after migration to manage journal size."

### 9. Commit Migration

If git repository exists and user agrees:

```bash
git add .claude/jarpa.local.md .gitignore
git commit -m "Migrate to JARPA plugin

- Add plugin settings file (.claude/jarpa.local.md)
- Remove template artifacts
- Update .gitignore for plugin compatibility

Migrated from template-based JARPA to plugin-based system.
Plugin version: 0.1.0
"
```

### 10. Report Summary

Present migration summary:

```
JARPA Migration Complete
━━━━━━━━━━━━━━━━━━━━━━━━

Project: [Name]
Migration Date: [YYYY-MM-DD]

✓ Created settings: .claude/jarpa.local.md
✓ Updated .gitignore
✓ Removed legacy files:
  - .codex/
  - MASTER_INSTRUCTIONS.md
  - init_docs.sh
✓ Verified jarpa/ structure
✓ Committed changes to git

Documentation preserved:
✓ jarpa/PROJECT_PLAN.md
✓ jarpa/TODO.md
✓ jarpa/REQUIREMENTS.md
✓ jarpa/ARCHITECTURE.md
✓ jarpa/JOURNAL.md ([N] lines)
✓ jarpa/archive/ ([N] archives)

Next Steps:
1. Restart Claude Code to activate hooks
2. Test session start hook: /quit then cc
3. Review settings: .claude/jarpa.local.md
4. Continue working with new automation!

Run /help to see available JARPA commands.
```

## Tools to Use

- Read: Check existing files, parse content
- Bash: Git operations, file operations, line counting
- Write: Create settings file
- Edit: Update .gitignore
- AskUserQuestion: User confirmations and choices

## Example Usage

### Scenario 1: Clean Migration

```
/jarpa:migrate
```

User answers:
- "Commit checkpoint?" → Yes
- "Project name?" → My Project
- "Remove template files?" → Yes, remove all

Result:
```
✓ Migration complete
✓ All legacy files removed
✓ Settings created
✓ Changes committed
```

### Scenario 2: Archive Legacy Files

```
/jarpa:migrate
```

User answers:
- "Remove template files?" → Archive to .jarpa-legacy/

Result:
```
✓ Migration complete
✓ Legacy files archived to .jarpa-legacy/
✓ Settings created
✓ Can reference old files if needed
```

### Scenario 3: Dry Run (Not in Git)

```
/jarpa:migrate
```

No git repository detected:
```
⚠️ No git repository detected
⚠️ Cannot create safety checkpoint
⚠️ Proceed without backup?
```

User can abort or proceed with manual backup.

## Edge Cases

### No jarpa/ Directory

**Error**: "No jarpa/ directory found. This doesn't appear to be a JARPA project."

**Suggest**: Use `/jarpa:init` for new projects instead.

### Already Migrated

Check if `.claude/jarpa.local.md` exists with migration metadata:

**Message**: "Project appears to be already migrated (plugin settings exist)."

**Options**:
- Abort (safe)
- Overwrite settings (regenerate .local.md)
- Update settings only (merge)

### Dirty Git Working Tree

**Warning**: "Uncommitted changes detected."

**Options**:
- Abort and commit first
- Create checkpoint commit automatically
- Proceed without commit (risky)

### Custom jarpa/ Location

If jarpa/ not in expected location:

**Detect** by searching for JOURNAL.md, PROJECT_PLAN.md:
```bash
find . -maxdepth 3 -name "JOURNAL.md" -o -name "PROJECT_PLAN.md"
```

**Ask user**: "Docs found at [path]. Use this location?"

**Update settings** with custom path if confirmed.

## Safety Features

1. **Git checkpoint**: Create commit before changes
2. **Archive option**: Keep legacy files if user prefers
3. **Validation**: Check jarpa/ structure before proceeding
4. **Rollback**: User can `git reset --hard HEAD~1` if needed
5. **Non-destructive**: Never modifies jarpa/ content

## Integration with Other Commands

After successful migration:
- `/jarpa:init` can still be used to create missing files
- `/jarpa:archive` works with existing journals
- `/jarpa:session-end` uses new settings

## Success Criteria

Migration is successful when:
1. `.claude/jarpa.local.md` created with valid YAML
2. Legacy artifacts removed or archived
3. `.gitignore` updated
4. jarpa/ structure intact and validated
5. Changes committed (if git available)
6. User informed of next steps

## Post-Migration Verification

Recommend user test:

```
# Restart Claude Code
/quit
cc

# Should see automatic session start message
# SessionStart hook should display "where are we now"

# Test commands available
/help

# Should see all JARPA commands
```
