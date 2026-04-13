# Changelog

All notable changes to the JARPA plugin are recorded here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.2] — 2026-04-13

### Fixed

- **Statusline percentage was reading the rate-limit value, not context
  usage.** The payload exposes `used_percentage` under both
  `context_window` and `rate_limits.*`, and the greedy JSON extraction
  picked the last match. Two side effects: the displayed percentage was
  wrong (e.g., 16% instead of 3%), and all sessions on the same account
  showed the same value because rate limits are global. The payload is
  now trimmed before `rate_limits` to scope the extraction to
  `context_window`.

## [0.2.1] — 2026-04-12

### Fixed

- **Statusline now shows accurate context usage.** The percentage is read
  from Claude Code's real `context_window.used_percentage` instead of a
  rough transcript-size heuristic. Fallback heuristic retained for
  forward-compatibility.
- **Model name displayed in statusline.** Format is now
  `<model> · JARPA <gauge> <pct>% ctx <label>`.
- **JARPA context budget decoupled from model window.** Set
  `JARPA_CONTEXT_TOKENS` (e.g., `250000`) to trigger warnings before the
  full model context is exhausted. The displayed percentage still reflects
  the model's real usage so the user can calibrate the budget.
- **Statusline auto-configured on first session start.** No longer requires
  `/jarpa:init` or manual setup — the SessionStart hook installs it in
  `.claude/settings.json` automatically.

## [0.2.0] — 2026-04-11

### Added

- **Context-window monitoring.** A statusline shows live context usage
  with warning/critical thresholds.
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
