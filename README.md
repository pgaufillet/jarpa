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

## Commands

| Command | Description |
|---|---|
| `/jarpa:init` | Initialize JARPA documentation structure in your project |
| `/jarpa:session-end` | End-of-session documentation (also triggered automatically) |
| `/jarpa:archive` | Archive older journal entries when JOURNAL.md grows large |
| `/jarpa:status` | Show current project status |
| `/jarpa:migrate` | Migrate a legacy JARPA project to the plugin format |
| `/jarpa:test-installation` | Verify the plugin is installed correctly |

## Project Structure

After initialization, your project will contain:

```
your-project/
├── jarpa/
│   ├── PROJECT_PLAN.md       # Current milestones and progress
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
