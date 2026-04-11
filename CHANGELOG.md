# Changelog

All notable changes to the JARPA plugin are recorded here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Upcoming `0.2.0` — all changes since `0.1.0`.

### Added

- **Context-window monitoring.** A new statusline shows live context usage
  with warning/critical thresholds. `/jarpa:init` offers to install it
  automatically.
- **`/jarpa:init` now seeds your project's `CLAUDE.md`** with the core JARPA
  rules.
- **`/jarpa:upgrade` command.** Upgrades your project's `jarpa/` files when
  the plugin's on-disk format evolves.
- **`coherence-validator` agent** (opt-in, advisory). Checks that your five
  `jarpa/` files stay consistent with each other. Read-only.
- **`session-reviewer` agent** (opt-in, advisory). Reviews recent journal
  entries for scope drift and retrospective insights. Read-only.

### Changed

- **No more Python dependency.** The context-monitoring MCP server is now
  pure bash. Installing JARPA no longer requires `python`, `pip`, or `jq`.
- **More reliable session protocol in multi-project repos.** Session
  workflows stay focused on your top-level `jarpa/` logbook instead of
  wandering into sub-projects.
- **Safer journal archiving.** The archiver no longer treats an unparseable
  `JOURNAL.md` as empty.
- **Settings simplified.** A few unused options were removed from
  `.claude/jarpa.local.md`.

### Removed

- **`/jarpa:migrate` command.** Legacy pre-plugin workflow, now gone.

### Notes

- **Your existing projects keep working.** Files created by `0.1.0` are
  treated as format version 1; `/jarpa:upgrade` can add the explicit format
  marker on demand.

## [0.1.0] — 2026-02-19

First public release. See `git log c0dfd16` for the shipping commit.
