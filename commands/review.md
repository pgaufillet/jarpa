---
name: jarpa:review
description: Periodic JARPA review - keeps the jarpa/ docs and CLAUDE.md true and in their role, and questions the method
---

# JARPA Review

A periodic check that the project's documents (PROJECT_PLAN, REQUIREMENTS,
ARCHITECTURE, TODO, JOURNAL, satellites, CLAUDE.md) still hold their role
in the methodology, are current and true; and a moment to question the
method in the light of experience. It catches what session-end cannot see
from inside one session: plan drifting from intent, stale or misfiled
content, local rules that no longer serve.

**The operator's attention is the scarce resource.** The operator works on
their project, not on its documents. They are asked twice: one question at
the start, one message at the end. Claude does the checking and the fixing
in between; the operator decides only what needs their intent or their
knowledge.

Run it inline in the main conversation; only Step 4 uses a sub-agent.
`/jarpa:session-start` announces when a review is due and never runs it:
the operator starts it. When session-start already ran in this session (the
SessionStart hook asks for it), do not run it again: its summary is where
the review starts.

**A review is a dedicated session.** No production work alongside it; fixes
are limited to the review's findings. It ends with its own JOURNAL entry,
which replaces `/jarpa:session-end` for this session (Step 7 says which of
its duties remain).

## Scope Discipline (MANDATORY)

- Read `jarpa/` at the repository root, the root `CLAUDE.md`, and the git
  log of the project's repositories. Read other files only to verify a
  finding (1-3 targeted reads per finding).
- **Verify before acting.** Every finding cites its evidence (`file:line`,
  commit, JOURNAL entry) and was checked by you, not inferred. A fix rests
  on a verified finding only.
- Keep the model you started with. If a skill or command that pins another
  model runs during the review, record it in the JOURNAL entry.

## Findings: who decides

Each finding has an **area** (project, document or method), its
**evidence**, an **owner** and a **closure**: fixed, scheduled as a TODO
item, or dropped with a one-line reason. No finding leaves the review open.

**The operator owns** a finding whose closure depends on:

- their intent: direction, priorities, scope, requirements, accepted risk,
  deadlines;
- something they put on the agenda or already decided (in JOURNAL, TODO or
  PROJECT_PLAN): never settle or reverse it alone;
- a fact only they know: the state of hardware, an outside exchange, a
  decision taken outside the repository;
- a change to a rule of `CLAUDE.md` (outside the managed block): it goes to
  the retro (Step 6).

When in doubt, the finding is theirs.

**Claude owns** the rest: whether the documents are true and in their role.
Stale facts, content in the wrong file, oversize, missing satellite status,
consumed TODO items, obsolete paths or figures. Fix what you can verify,
schedule what needs real work, drop the rest with a reason.

**No repeats.** A finding dropped or refused by an earlier review is not
raised again unless new evidence appears; then say what changed. A finding
the previous review scheduled and that is still pending is raised again:
if you own it, do it now or schedule it first in TODO; if the operator owns
it, it is one of the questions.

## Process

### Step 1: Ask the operator — one question

Before showing anything, ask: **"What will the next sessions be about?"**,
with its purpose in a few words: checking that the plan follows what the
operator wants to do. The documents can be checked against the code, git
and each other; the operator's intent can only be asked. Never ask "does the
plan match your intent?" — a closed question gets a yes and hides the
drift; stating the purpose does not steer the answer, showing the plan
does. Wait for the answer, then work alone until Step 6.

"I don't know" is an answer: recall in two lines where the plan stands
(Current Step, head of TODO), ask whether it should change, and record the
answer as given.

### Step 2: Locate the window and the previous review

Find the last review: the last header matching
`## [YYYY-MM-DD] — Session N: JARPA review` in `jarpa/JOURNAL.md`, or in
`jarpa/archive/JOURNAL*.md` if it was archived. The window is the entries
after it; without a previous review, the last `review_interval_sessions`
entries (default 15). Older sessions stay unreviewed even when session-start
counted them as due; the JOURNAL entry says so.

Read `jarpa/PROJECT_PLAN.md`, `jarpa/TODO.md` and the window's entries.

Compare the operator's answer with PROJECT_PLAN's Current Step and TODO's
Now/Next: a gap between intent and plan is an operator finding.

### Step 3: Carry over the previous review

List the previous review's scheduled items (its `Remaining Work / Next
Step` section) with their state: done or still pending, and past its date
when it has one. Pending items are the first findings of this review.

### Step 4: Check — measure, judge, validate

**Measure.** Run the metrics script over the window (the date of its first
entry); journal entry sizes and session references in commits then cover
the window only:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/metrics.sh" --since <date>
```

Each `[!!]` line is a finding to verify and close.

**Judge.** Stop at what you can verify.

- **Project** — plan vs the window's sessions.
  - Age of the Current Step: sessions since it last changed.
  - Exit criteria or commitments with no progress in the window; declared
    deadlines, if any, with no action.
  - Sessions off the Current Step, and whether the plan should follow them.
  - Sessions whose Results fall materially short of their Goal without
    saying so; a risk or blocker recurring across entries; an `[ONGOING]`
    task already in the Goal of the window's first entry.
  - Temporary plans still alive: `jarpa-status: temporary` satellites and
    sprint or run-sheet sections kept inside TODO or PROJECT_PLAN — consumed,
    or still needed? Past their date when they have one (the metrics flag
    those satellites).
- **Documents** — content in the wrong file or no longer true.
  - Narrative or backlog in PROJECT_PLAN; new needs appearing only in TODO;
    decisions recorded only in JOURNAL that ARCHITECTURE should carry.
  - Paths, components and figures cited by ARCHITECTURE, REQUIREMENTS and
    `CLAUDE.md` that no longer exist or no longer hold.
  - Satellites: missing status, `living` but stale, `temporary` but consumed.
- **Method** — local practice vs the canonical methodology (the
  jarpa-methodology skill).
  - Rules in `CLAUDE.md` outside the managed block, and conventions visible
    in `jarpa/`, that contradict, extend or duplicate the canonical rules;
    a local rule on trial reaching its re-examination (next review by
    default).
  - Rules written for a specific model.
  - Session references in commits (from the metrics).

**Validate.** Launch the `coherence-validator` agent; do not ask first. Pass
it:

- the findings already made (one line each: area, file, claim), asking it
  to report only findings not on that list and to say when it contradicts
  one;
- this review's Scope Discipline: `jarpa/` at the repository root, the root
  `CLAUDE.md`, the project's repositories — never user configuration
  (`~/.claude`) or other projects.

Verify each new finding before using it: open the cited file at the cited
line (a line number past the end of the file means the finding is not
verified). Drop the ones that do not hold and count them. A contradiction
that holds corrects the earlier finding. Note the agent's token count, when
the tool reports one, for the JOURNAL entry.

### Step 5: Close what you own

Apply your fixes, add the scheduled items to TODO, record what you dropped
and why. Commit the fixes as the project usually does, apart from other
work, so the operator can read or revert them in one place.

### Step 6: One message to the operator

Follow the "Talking to the operator" rule of the managed `CLAUDE.md` block:
explain each identifier or term at its first mention, in plain words;
speak of the project, not of the documents; no area, owner or finding
numbers.

1. **What you did, in one line**: fixed / scheduled / dropped counts and the
   commit. The details are in the JOURNAL entry.
2. **The questions**: the operator's findings, related ones grouped, the
   most consequential first. Each carries what an informed decision needs:
   the situation and why it arises now, the options and what each changes,
   your recommendation and its reason, and what happens if nothing is done.
   If you cannot give that context, investigate before asking.
3. **The retro**: zero to three observations drawn from the window about
   the method itself — a rule bypassed or never useful, a friction that
   recurs, a document nobody uses, the weight of the review itself — each
   with a proposal: keep, change or drop. Then one open line: is anything
   in the method weighing on the operator? With nothing to observe, say
   nothing. A point that belongs to the plugin (a check that does not fit
   the project, a script defect) is recorded once in the JOURNAL entry as
   plugin feedback, not raised again.

Apply the operator's decisions. A question left unanswered is scheduled
first in TODO with its context; it is never decided by default.

**Cadence.** Propose a change only on evidence: tighten
(`review_interval_sessions` in `.claude/jarpa.local.md`, default 15) when a
session of the window acted on a document that was wrong or stale — name
the session and what it did; relax after two reviews in a row without such
a case. A first review and a window spanning a pause do not tighten: their
findings accumulated without a review.

### Step 7: JOURNAL entry

Append one entry in the canonical format (see `/jarpa:session-end`), with
this exact title so the next review and session-start can find it:

```markdown
## [YYYY-MM-DD] — Session N: JARPA review
```

- **Goal**: the window (sessions and dates), `Model: <model id>`, and the
  milestone lines printed by
  `bash "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/review-due.sh" --milestones`,
  copied as they are (one `- Milestone:` line each), after the closures
  have updated PROJECT_PLAN. Session-start compares them with PROJECT_PLAN
  to announce the next review on a milestone change.
- **Results**: the findings, one line each (area, owner, evidence,
  closure); the number of validator findings dropped and the validator's
  token count when known; the retro's outcome; plugin feedback, if any.
- **Remaining Work / Next Step**: the scheduled items (and their dates, if
  any), unanswered questions first — the next review starts from this list.

Update TODO and PROJECT_PLAN as the closures require.

Then finish the session-end duties the entry does not cover: prune TODO and
apply memory hygiene (`/jarpa:session-end`, Steps 3 and 5); the metrics of
Step 4 stand for its Step 6. Commit the entry as the project usually does.
A `/jarpa:session-end` run afterwards (by the Stop hook, for instance)
finds today's review entry and adds no second one.

## When to Use

When `/jarpa:session-start` announces a review due, or when the operator
suspects drift: after a pause, a milestone change, or a model change.
