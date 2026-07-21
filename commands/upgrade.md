---
name: jarpa:upgrade
description: Upgrade consumer jarpa/ files to the current format and resync the managed CLAUDE.md block
---

# Upgrade JARPA Format

Bring the consumer project up to date with the installed plugin: migrate `jarpa/*.md` files from an older on-disk format to the current one, and resync the plugin-managed block in `CLAUDE.md` to the installed template. The contract that defines each format version lives in the plugin's own `jarpa/FORMAT_CONTRACT.md`.

## Scope discipline

This command touches **plugin-owned artifacts only**:

- Format markers in `jarpa/*.md` (migration to the current format version).
- The managed `CLAUDE.md` block between `<!-- JARPA:BEGIN` and `<!-- JARPA:END -->` (resync to the installed template). That block is marked "managed by jarpa plugin, do not edit manually" — its content belongs to the plugin, not the consumer.

It does not:
- Rewrite session content, task wording, or architectural prose.
- Touch `.claude/jarpa.local.md` or anything outside `jarpa/` and the managed block.
- Inject a new `CLAUDE.md` block where none exists — that is `/jarpa:init`'s job.
- Run automatically. It is only invoked on demand when the maintainer explicitly asks.

If a future feature needs to rewrite consumer content, it gets its own command.

## Current target format

**Format version:** `1`

**Marker:** `<!-- jarpa-format: 1 -->` on the first line of each `jarpa/*.md` file, above the H1 heading.

## Files in scope

```
jarpa/PROJECT_PLAN.md
jarpa/TODO.md
jarpa/REQUIREMENTS.md
jarpa/ARCHITECTURE.md
jarpa/JOURNAL.md
CLAUDE.md            (managed block only, between the JARPA:BEGIN / JARPA:END markers)
```

Files inside `jarpa/archive/` are out of scope. Archives are historical artifacts and keep whatever format they were archived with.

## Process

### 1. Detect current state per file

For each in-scope file, read the first non-empty line and classify:

- **Marker present and current** — first line is exactly `<!-- jarpa-format: 1 -->`. Status: `up-to-date`.
- **Marker present but unknown version** — first line matches `<!-- jarpa-format: N -->` with `N != 1`. Status: `unknown-version`. Refuse to touch the file.
- **Marker absent** — first line is anything else (typically `# <Title>`). Status: `pre-marker`. This is a pre-Step 8 consumer file that implicitly follows format version 1.

### 2. Apply per-status action

| Status            | Action                                                     |
|-------------------|------------------------------------------------------------|
| `up-to-date`      | None. Report as `skip`.                                    |
| `pre-marker`      | Insert `<!-- jarpa-format: 1 -->` as a new first line, preserving the rest of the file byte-for-byte.                                        |
| `unknown-version` | Abort this file. Report as `refused` with the observed version. Do not modify anything.                                                          |

Use Edit to insert the marker — never rewrite the whole file. The edit is a single insertion at the top; content below is untouched.

### 3. Detect managed CLAUDE.md block state

Read the consumer's root `CLAUDE.md` and the installed template `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE_MD_INJECT.md`. Classify:

- **`up-to-date`** — the lines from `<!-- JARPA:BEGIN` through `<!-- JARPA:END -->` (inclusive) are identical to the template. No action.
- **`stale`** — both markers present but the block differs from the template. Action: replace the whole block, BEGIN marker line through END marker line inclusive, with the full template content. Everything outside the markers is preserved byte-for-byte.
- **`no-block`** — `CLAUDE.md` is missing or contains no `<!-- JARPA:BEGIN` marker. No action; report it and point the maintainer to `/jarpa:init`, which owns first-time injection.
- **`malformed`** — one marker present without its counterpart. Refuse to touch the file; the maintainer must repair the markers before a resync is safe.

The template's first line is the BEGIN marker and its last line is the END marker, so a marker-to-marker replacement with the full template preserves the delimiters by construction.

### 4. Dry-run first

Always present the plan before making changes. Use AskUserQuestion:

- Question: "Apply these upgrades?"
- Options:
  - "Apply all" — execute the listed changes
  - "Cancel" — make no changes

List what will happen per file:

```
jarpa/PROJECT_PLAN.md      pre-marker    → insert <!-- jarpa-format: 1 -->
jarpa/TODO.md              up-to-date    → skip
jarpa/REQUIREMENTS.md      pre-marker    → insert <!-- jarpa-format: 1 -->
jarpa/ARCHITECTURE.md      up-to-date    → skip
jarpa/JOURNAL.md           pre-marker    → insert <!-- jarpa-format: 1 -->
CLAUDE.md (managed block)  stale         → resync from installed template
```

### 5. Apply changes (if user confirmed)

Process files sequentially. For each `pre-marker` file, insert the marker via Edit. For a `stale` managed block, replace the block via Edit (old content between and including the markers → template content). Report success or failure per file.

Do not run any shell commands that rewrite files in bulk. Per-file Edit keeps the blast radius small and makes failures recoverable.

### 6. Report summary

```
JARPA Upgrade Complete
━━━━━━━━━━━━━━━━━━━━━━

Target format: 1

  Upgraded:   <N> file(s)
  Unchanged:  <M> file(s)
  Refused:    <K> file(s)

Details:
  jarpa/PROJECT_PLAN.md      upgraded (pre-marker → 1)
  jarpa/TODO.md              unchanged (already at 1)
  CLAUDE.md (managed block)  resynced (stale → current template)
  ...

No consumer content was modified. Only format markers and the plugin-managed CLAUDE.md block were touched.
```

If any file was `refused` (or the managed block `malformed`), surface it prominently and stop — the maintainer needs to investigate before the plugin can operate on that file safely.

## Idempotency

Running `/jarpa:upgrade` on an already-current project is a safe no-op: every file reports `up-to-date`, the managed block matches the template, and no writes occur.

## Error handling

- **`jarpa/` missing** — report "No jarpa/ directory found. Run /jarpa:init first." and exit.
- **File unreadable** — report the error for that file and continue with the rest.
- **Unknown version in marker** — refuse that file and report it. Do not guess what the version means.
- **`CLAUDE.md` missing or without markers** — report `no-block`, suggest `/jarpa:init`, and continue with the rest. Never create the file or inject a first block from here.

## Future versions

When format version 2 ships, this command gains a second branch: detect marker `1`, apply a real content migration, rewrite the marker to `2`. The scaffolding above stays; a new per-version migration block is added. Each version bump must:

1. Update `jarpa/FORMAT_CONTRACT.md` with the new contract.
2. Add a migration path in this command.
3. Cover the migration with a test in `tests/`.

## Tools to use

- Read — inspect the first line of each jarpa/ file; read CLAUDE.md and the installed template for the block comparison
- Edit — insert the marker (single top-of-file insertion); replace the managed block (single marker-to-marker replacement)
- AskUserQuestion — confirm before applying changes
