<!-- JARPA:BEGIN - managed by jarpa plugin, do not edit manually -->
## JARPA Methodology

This project uses JARPA for structured documentation.

### Key Rules

- **Git commits**: No AI attribution (no Co-Authored-By). No conventional prefixes. No JARPA references (session numbers, milestones) — commits are public-facing. Short title (50 chars), optional body.
- **Tests**: No dummy or placeholder tests. Every test must set up, act, verify, and be capable of failing.
- **Documentation**: Only `jarpa/JOURNAL.md` is cumulative (append-only). All other jarpa/ docs reflect current state.
- **Session discipline**: Work only on the current task. No scope creep. Surface risks immediately.
- **Talking to the operator** — the operator works on the project, not on its docs, and does not reread them every session:
  - *Explicit*: the first time in a session you use an identifier (M6.14, D35, S202), an abbreviation, or a project or method term, give its meaning in a few plain words; afterwards use it bare.
  - *Concise*: open with the result or the decision needed; no process narration, nothing the operator already knows.
  - *Contextualised*: every question carries what an informed decision needs: the situation and why it arises now, the options and what each changes, your recommendation and its reason. Investigate before asking. Scale the context to the stakes.
- **Persistent memory**: prefer disabling Claude Code auto-memory (`"autoMemoryEnabled": false` in `.claude/settings.json`). If kept, it is reserved for user profile and collaboration preferences. Project and technical facts live in the repository (docs, CLAUDE.md, jarpa/) — never in assistant memory. A recalled memory asserting a project fact must be verified against the repository; the repository wins.

### Periodic Review

`/jarpa:review` is a dedicated session that keeps the jarpa/ docs and CLAUDE.md true and in their role, and questions the method. Claude checks and fixes what it can verify; the operator answers one question at the start and, at the end, decides only what needs their intent or knowledge. Session start announces when it is due; the operator starts it. The read-only agent **coherence-validator** is invoked from the review only.

For full methodology, see the jarpa-methodology skill.
<!-- JARPA:END -->
