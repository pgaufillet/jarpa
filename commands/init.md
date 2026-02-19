---
name: jarpa:init
description: Initialize JARPA documentation structure in the current project
---

# Initialize JARPA Documentation

Initialize the JARPA documentation structure for a new or existing project.

## Behavior

This command sets up the complete JARPA documentation structure with safe re-run capability.

## Process

1. **Ask for project name** using AskUserQuestion:
   - Question: "What is your project name?"
   - This will be used to populate templates

2. **Check existing structure**:
   - Check if `jarpa/` directory exists
   - Check which template files already exist

3. **Create directory structure**:
   ```bash
   mkdir -p jarpa/archive
   mkdir -p .claude
   ```

4. **Copy template files** (only if they don't exist):
   - Copy from `${CLAUDE_PLUGIN_ROOT}/templates/` to `jarpa/`:
     - PROJECT_PLAN.md
     - TODO.md
     - REQUIREMENTS.md
     - ARCHITECTURE.md
     - JOURNAL.md
   - If file exists: Skip and inform user (safe re-run)
   - If --force flag provided: Overwrite existing files

5. **Substitute project name**:
   - In PROJECT_PLAN.md, replace `<project name>` with actual project name
   - Use Edit tool to perform substitution

6. **Create settings file** `.claude/jarpa.local.md`:
   ```yaml
   ---
   project:
     name: "[Project Name]"
     description: ""

   paths:
     docs: "./jarpa"
     archives: "./jarpa/archive"

   thresholds:
     journal_lines: 1500
     context_percent: 95

   session:
     expected_duration: "2-4 hours"
     strict_mode: true
   ---

   # JARPA Settings for [Project Name]

   Project-specific notes and configuration.
   ```

7. **Write initial journal entry** (only if JOURNAL.md was created or overwritten):
   Append to jarpa/JOURNAL.md:
   ```markdown

   ## [YYYY-MM-DD] — Initialization

   ### Goal
   - Initialize the standard documentation set for "[Project Name]".

   ### Actions Performed
   - Created/updated: jarpa/PROJECT_PLAN.md
   - Created/updated: jarpa/TODO.md
   - Created/updated: jarpa/REQUIREMENTS.md
   - Created/updated: jarpa/ARCHITECTURE.md
   - Created/updated: jarpa/JOURNAL.md (this file)
   - Created/updated: .claude/jarpa.local.md

   ### Technical Decisions & Rationale
   - Decision: Use a repo-wide jarpa/ folder with one cumulative journal and four up-to-date documents.
   - Rationale: Keep current truth clean while preserving history in one place.

   ### Changes Made
   - Files created:
     - jarpa/PROJECT_PLAN.md
     - jarpa/TODO.md
     - jarpa/REQUIREMENTS.md
     - jarpa/ARCHITECTURE.md
     - jarpa/JOURNAL.md
     - .claude/jarpa.local.md

   ### Results
   - Documentation skeleton is ready. Next session should fill Goal/Milestones/Current Step and set the first session-sized task.

   ### Remaining Work / Next Step
   - Update jarpa/PROJECT_PLAN.md: Goal, Milestones, Current Step.
   - Update jarpa/TODO.md: define the first session task with DoD.

   ### Notes / Risks
   - None.
   ```

8. **Report summary**:
   - List files created
   - List files skipped (if any)
   - Next steps guidance

## Tools to Use

- AskUserQuestion: Get project name
- Read: Check existing files
- Bash: Create directories (mkdir -p)
- Write: Create new files from templates
- Edit: Substitute project name, append journal entry

## Example Usage

```
/jarpa:init
```

User will be prompted for project name, then structure will be created.

## Safe Re-run

If jarpa/ already exists, only missing files will be created. Existing files are preserved unless --force is used (not recommended).

## Next Steps for User

After initialization:
1. Edit jarpa/PROJECT_PLAN.md - Define project goal, milestones, and current step
2. Edit jarpa/TODO.md - Add first session-sized task with definition of done
3. Edit jarpa/REQUIREMENTS.md - Document initial requirements
4. Edit jarpa/ARCHITECTURE.md - Sketch initial architecture
