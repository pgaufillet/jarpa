<!-- JARPA:BEGIN - managed by jarpa plugin, do not edit manually -->
## JARPA Methodology

This project uses JARPA for structured documentation.

### Key Rules

- **Git commits**: No AI attribution (no Co-Authored-By). No conventional prefixes. No JARPA references (session numbers, milestones) — commits are public-facing. Short title (50 chars), optional body.
- **Tests**: No dummy or placeholder tests. Every test must set up, act, verify, and be capable of failing.
- **Documentation**: Only `jarpa/JOURNAL.md` is cumulative (append-only). All other jarpa/ docs reflect current state.
- **Session discipline**: Work only on the current task. No scope creep. Surface risks immediately.
- **Persistent memory**: reserved for user profile and collaboration preferences. Project and technical facts live in the repository (docs, CLAUDE.md, jarpa/) — never in assistant memory. A recalled memory asserting a project fact must be verified against the repository; the repository wins.

### Opt-in Advisory Agents

Two read-only agents are available on demand (not triggered by hooks):

- **coherence-validator** — cross-document coherence check across the 5 `jarpa/` files.
- **session-reviewer** — retrospective pattern review across a window of recent sessions.

Invoke either when useful; both are advisory and never modify files.

For full methodology, see the jarpa-methodology skill.
<!-- JARPA:END -->
