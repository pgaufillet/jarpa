# Changelog

All notable changes to the JARPA plugin are recorded here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Account rate-limit gauges in the statusline (opt-in).** Set
  `JARPA_SHOW_RATE_LIMITS=1` to append two right-justified gauges for the
  account's 5-hour session window (`rate_limits.five_hour`) and 7-day window
  (`rate_limits.seven_day`), labelled `5h`/`7d` to keep them distinct from
  the context percentage (those values are global to the account, not the
  session). The gauges are right-justified against `$COLUMNS` and hidden
  all-or-nothing when the terminal is too narrow or the width is unknown.
  The per-model weekly window that `/usage` shows ("Fable") is not plumbed to
  the statusline payload, so only these two windows are available. Off by
  default; the base line is unchanged when the variable is unset.

## [0.3.2] — 2026-07-21

### Changed

- **`/jarpa:upgrade` now resyncs the managed CLAUDE.md block.** Besides format
  markers in `jarpa/*.md`, the command replaces the content between
  `<!-- JARPA:BEGIN` and `<!-- JARPA:END -->` with the installed
  `templates/CLAUDE_MD_INJECT.md` when it has drifted. The block is
  plugin-owned ("managed by jarpa plugin, do not edit manually") but was
  previously only written at init, so consumers that updated the plugin kept
  outdated rules — the v0.3.1 rollout required manual block edits in every
  consumer. First-time injection remains `/jarpa:init`'s job; consumer
  content outside the markers is never touched.

## [0.3.1] — 2026-07-20

### Added

- **Persistent memory boundary.** The methodology now bounds the assistant's
  persistent memory to user profile and collaboration preferences. Project
  and technical facts belong in the consumer repository (docs, CLAUDE.md,
  jarpa/) — versioned and loaded deterministically, where memory recall is
  probabilistic and drifts. Enforced at session start (recalled memories are
  verified against the repository, which wins), at session end (new "Memory
  hygiene" step migrating stray project facts to their repository homes), in
  the jarpa-methodology skill (normative "Persistent Memory Boundary"
  section), and in the CLAUDE.md inject template (Key Rules bullet).

### Changed

- **Hardened PROJECT_PLAN discipline.** Session-end Step 4 now requires
  rewriting Current Step as a constant-size synthesis — never appending
  per-session narrative — and routes open questions to Risks / Open
  Questions. The PROJECT_PLAN template and the methodology skill state the
  same rule. Motivated by observed drift in a consumer project: Current Step
  had grown into a session-by-session log duplicating JOURNAL.

## [0.3.0] — 2026-07-09

### Removed

- **Context-monitor MCP server.** The `context-monitor` MCP server (tools
  `get_context_status`, `should_close_session`, `check_health`) and its
  `.mcp.json` declaration are removed. Its tool definitions and every tool
  result stayed resident in the session context, and the methodology nudged
  periodic polling — a large, recurring token cost that duplicated
  information already shown by the JARPA statusline and surfaced by Claude
  Code's own context warnings. Context awareness now relies on the
  statusline gauge alone. Session-start no longer runs a health check or
  polls context usage. Tests covering the MCP server were removed
  accordingly.
- **Statusline broker file.** With the MCP server gone, nothing reads the
  `jarpa-context.json` broker file, so `statusline.sh` no longer writes it
  (and the `JARPA_CONTEXT_FILE` override is gone). The visible gauge is
  computed directly from the Claude Code payload; nothing you see changes.

### Changed

- **Leaner documentation discipline.** The methodology now targets 50-100-line
  JOURNAL entries, keeps PROJECT_PLAN free of per-session progress narrative,
  and prunes completed items from TODO (history lives in JOURNAL). Enforced at
  `/jarpa:session-end` and reflected in the `/jarpa:init` templates.

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
