# JARPA Plugin for Claude Code

A Claude Code plugin that provides the **JARPA methodology** (Journal, Architecture, Requirements, Plan, Actions) for structured documentation in AI-assisted software engineering projects.

## What is JARPA?

JARPA maintains clear, up-to-date documentation while preserving complete project history in a cumulative journal. It automates session workflows so you never lose context between Claude Code sessions.

- **J**ournal - Cumulative session history (append-only)
- **A**rchitecture - System design and components (current state)
- **R**equirements - Project requirements and constraints (current state)
- **P**lan - Milestones and current progress (current state)
- **A**ctions - Task list with Now/Next/Later sections (current state)

Only the Journal is cumulative. All other documents reflect the current state of your project.

## Installation

### From Hephaistos Marketplace (Recommended)

Add the marketplace to `~/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "hephaistos": {
      "source": {
        "source": "git",
        "url": "https://github.com/pgaufillet/hephaistos-marketplace.git"
      }
    }
  }
}
```

Then install and enable:

```bash
claude plugin install jarpa@hephaistos
claude plugin enable --scope local jarpa@hephaistos
```

### From Source

```bash
git clone https://github.com/pgaufillet/jarpa.git ~/jarpa
```

Add to `~/.claude/settings.json`:

```json
{
  "pluginDirs": ["~/jarpa"]
}
```

### Prerequisites

- Claude Code CLI
- Git

## Quick Start

1. **Initialize** in your project directory:
   ```bash
   /jarpa:init
   ```
   This creates a `jarpa/` directory with 5 documentation files and a `.claude/jarpa.local.md` settings file.

2. **Fill in** initial documentation:
   - `jarpa/PROJECT_PLAN.md` - Define goal, milestones, current step
   - `jarpa/TODO.md` - Add your first task (aim for 2-4 hours of work)
   - `jarpa/REQUIREMENTS.md` - Document initial requirements
   - `jarpa/ARCHITECTURE.md` - Sketch initial architecture

3. **Start working.** Session hooks handle the rest:
   - On session start: shows current milestone, task, and recent progress
   - Before commits: reminds you to update the journal
   - On session end: guides you through journal entry and doc updates

## Context Monitoring

JARPA ships a Claude Code statusline that surfaces context-window usage
proactively. On every turn it reads Claude Code's own context telemetry and
renders a gauge in your status line:

```
<model> · JARPA ███░░░░░░░ 28% ctx OK
```

- **Auto-configuration**: The statusline is installed automatically in your
  project's `.claude/settings.json` on the first session start. Existing
  statuslines are never overwritten, and the path self-heals on each session
  start via the SessionStart hook.
- **Thresholds**: 75% = WARNING (plan to close session), 90% = CRITICAL
  (close now). Thresholds are evaluated against the JARPA context budget,
  not the model's full context window.
- **JARPA context budget**: By default the budget equals the model's context
  window. Set `JARPA_CONTEXT_TOKENS` to a lower value (e.g., `250000`) to
  trigger warnings earlier — useful with large-context models where
  efficiency degrades well before the window is full.
- **Account rate-limit gauges (opt-in)**: Set `JARPA_SHOW_RATE_LIMITS=1` to
  append two gauges for your account's 5-hour session window and 7-day
  (weekly) window, separated from the context state by `│`:

  ```
  <model> · JARPA ███░░░░░░░ 28% ctx OK │ 5h █░░░ 34% · 7d ░░░░ 18%
  ```

  These come from Claude Code's `rate_limits` payload (Pro/Max accounts,
  after the first API response) and are global to your account, not this
  session. They stay next to the context state rather than at the right
  edge, which Claude Code uses for its own notifications. If the terminal is
  too narrow to fit them, they are hidden rather than wrapped. The per-model
  weekly window shown in `/usage` ("Fable") is
  not exposed to statuslines and cannot be displayed.

Watch the gauge to decide when to wrap up: at WARNING plan closure, at
CRITICAL run `/jarpa:session-end`.

## Documentation Hygiene

At the end of each session, `/jarpa:session-end` runs
`hooks/scripts/metrics.sh` and relays a short report. It is advisory: it
never blocks and never changes a file. Sizes are measured in bytes, because
line counts are skewed by wrapping.

| Measure | Flagged when | Setting (`.claude/jarpa.local.md`) |
|---|---|---|
| JOURNAL.md length | over (or within 10% of) the archive threshold | `thresholds.journal_lines` (1500) |
| Journal entry size (mean and last) | over the target | `thresholds.journal_entry_bytes` (6000) |
| TODO.md size | over the threshold | `thresholds.todo_bytes` (30000) |
| PROJECT_PLAN.md size | over the threshold | `thresholds.plan_bytes` (15000) |
| Closed TODO items (`[x]` or ✅ at line start, with or without a bullet) | more than 10 | — |
| `[ONGOING]` markers (at line start or in a heading) | more than 1 | — |
| ARCHITECTURE.md, REQUIREMENTS.md size | never — reported for information (read on demand, not at session start) | — |
| Satellite files in `jarpa/` | no `<!-- jarpa-status: living\|snapshot\|temporary -->` in their first lines | — |
| Temporary satellites with a due date (`<!-- jarpa-status: temporary, due: YYYY-MM-DD -->`, optional) | past it | — |
| Session references in commits | any, in the last 30 days or the last 10 JOURNAL entries (whichever is longer, so a pause does not hide them), by you, in the project repository and its direct sub-directory repositories (a `jarpa/` repository is excluded); the date of the latest one is shown | — |
| Managed CLAUDE.md block | absent, malformed or stale | `claude_md.managed_block: false` declares a project without it |
| Claude Code auto-memory | enabled (env var, then local > project > user settings; absent = enabled) and holding `project` or `reference` memories — preferences only (`user`, `feedback`) are accepted | — |

Run it by hand at any time: `bash <plugin-root>/hooks/scripts/metrics.sh [project-dir]`.
`--since <date>` limits the journal entry sizes and the commit scan to a
window; `/jarpa:review` passes the date of its first entry.

## Periodic Review

`/jarpa:review` is a dedicated session that checks project, document and
method drift since the previous review and closes every finding: fixed,
scheduled in TODO (re-examined at the next review, with a date if your
project uses dates), or refused. Session start announces it when
due and never runs it:

| Trigger | Setting (`.claude/jarpa.local.md`) |
|---|---|
| Sessions since the last review (or since the start) | `thresholds.review_interval_sessions` (15) |
| Gap between two sessions, or since the last one, after the last review | `thresholds.review_pause_days` (30) |
| PROJECT_PLAN milestone lines differ from those the last review recorded | — |

The last review is the last JOURNAL entry titled `Session N: JARPA review`,
archived journals included. Check by hand:
`bash <plugin-root>/hooks/scripts/review-due.sh [project-dir]`.

## Commands

| Command | Description |
|---|---|
| `/jarpa:init` | Initialize JARPA documentation structure in your project |
| `/jarpa:session-end` | End-of-session documentation (also triggered automatically) |
| `/jarpa:archive` | Archive older journal entries when JOURNAL.md grows large |
| `/jarpa:status` | Show current project status |
| `/jarpa:review` | Periodic review of project, document and method drift; every finding closed |
| `/jarpa:upgrade` | Upgrade consumer jarpa/ files to the current on-disk format and resync the managed CLAUDE.md block |
| `/jarpa:test-installation` | Verify the plugin is installed correctly |

## Project Structure

After initialization, your project will contain:

```
your-project/
├── jarpa/
│   ├── PROJECT_PLAN.md       # Goal, milestones, current step
│   ├── TODO.md               # Task list (Now/Next/Later)
│   ├── REQUIREMENTS.md       # Current requirements
│   ├── ARCHITECTURE.md       # Current design
│   ├── JOURNAL.md            # Cumulative session history
│   └── archive/
│       └── JOURNAL_*.md      # Archived journal entries
└── .claude/
    └── jarpa.local.md        # Project settings (not committed)
```

## Support

- **Issues**: [Report bugs or request features](https://github.com/pgaufillet/jarpa/issues)
- **Contributing**: Pull requests welcome

## License

MIT License - See [LICENSE](LICENSE) file for details.

## Credits

Created by [Pierre Gaufillet](https://github.com/pgaufillet).

JARPA was designed and built using [Claude](https://claude.ai) by Anthropic. The methodology, plugin architecture, and documentation were developed through AI-assisted pair programming - which is exactly what JARPA is designed to support.
