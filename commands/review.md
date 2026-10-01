---
name: jarpa:review
description: Periodic JARPA review - project, document and method drift, closed finding by finding
---

# JARPA Review

A periodic retrospective of the project and of its JARPA practice. It
catches what session-end cannot see from inside one session: goal and
execution drift, misfiled or stale content, local rules that diverge from
the methodology.

Run it inline in the main conversation; only Step 5 uses sub-agents.
`/jarpa:session-start` announces when a review is due and never runs it:
the operator starts it. When session-start already ran in this session (the
SessionStart hook asks for it), do not run it again: its summary is where
the review starts.

**A review is a dedicated session.** No production work alongside it; fixes
made during the review are limited to the findings the operator accepts.
It ends with its own JOURNAL entry, which replaces `/jarpa:session-end` for
this session (Step 7 says which of its duties remain).

## Scope Discipline (MANDATORY)

- Read `jarpa/` at the repository root, the root `CLAUDE.md`, and the git
  log of the project's repositories. Read other files only to verify a
  finding (1-3 targeted reads per finding).
- Change nothing before the operator has decided a finding's closure.
- **Verify before relaying.** Every finding cites its evidence
  (`file:line`, commit, JOURNAL entry) and was checked by you, not inferred.
- Keep the model you started with. If a skill or command that pins another
  model runs during the review, record it in the JOURNAL entry.

## Findings

Each finding carries:

- **Family** — project, document, method, or retro.
- **Class** — *would-decide-wrong* when an agent or the operator reading the
  docs would take a wrong decision because of it; name that decision, or the
  finding is *stock*. *Stock* is housekeeping: true but misleading no one.
- **Evidence** — as above.
- **Closure** — exactly one of: **fixed** during the review, **scheduled**
  as a TODO item, or **refused** with a one-line reason. No finding leaves
  the review open. A scheduled item is re-examined at the next review; give
  it a date only when the project works with dates.

A finding already raised by the previous review (scheduled, refused, or not
closed) is marked **seen twice** and becomes a priority: fix it now or
schedule it first in TODO.

## Process

### Step 1: Locate the window and the previous review

Find the last review: the last header matching
`## [YYYY-MM-DD] — Session N: JARPA review` in `jarpa/JOURNAL.md`, or in
`jarpa/archive/JOURNAL*.md` if it was archived. The window is the entries
after it; without a previous review, the last `review_interval_sessions`
entries (default 15). Older sessions stay unreviewed even when session-start
counted them as due; the JOURNAL entry says so.

Read `jarpa/PROJECT_PLAN.md`, `jarpa/TODO.md` and the window's entries.

### Step 2: Carry over the previous review

List the previous review's scheduled items (its `Remaining Work / Next
Step` section) with their state: done or still pending, and past its date
when it has one. Pending items are the first findings of this review.

### Step 3: Ask the operator — one message

Before presenting the plan, ask the three questions together, so the
operator answers once:

1. **The open question: "What will the next sessions be about?"** Never ask
   "does the plan match your intent?" — a closed question gets a yes and
   hides the drift.
2. **The retro**: what helped and what hindered in the window; what to
   stop, start, continue. On a long window (a first review, or one spanning
   a pause), ask about its last sessions and name a few of its events as
   prompts.
3. **The validators of Step 5**: run them or not. They cost far more than
   the rest of the review (on a 15-session window, about 150k tokens
   against about 50k); give the estimate.

Compare the answer to (1) with PROJECT_PLAN's Current Step and TODO's
Now/Next: a gap between intent and plan is a project finding. Each retro
answer that asks for a change is a retro finding; a retro left unanswered
is noted in the JOURNAL entry, not counted as a finding.

### Step 4: Measured and judged parts

**Measure.** Run the metrics script over the window (the date of its first
entry); journal entry sizes and session references in commits then cover
the window only:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/metrics.sh" --since <date>
```

Each `[!!]` line is a finding to verify and close.

**Judge.** Review the four families; stop at what you can verify.

- **Project** — plan vs sessions of the window.
  - Age of the Current Step: sessions since it last changed.
  - Exit criteria or commitments with no progress in the window; declared
    deadlines, if any, with no action.
  - Sessions off the Current Step, and whether the plan should follow them.
  - Temporary plans still alive: `jarpa-status: temporary` satellites and
    sprint or run-sheet sections kept inside TODO or PROJECT_PLAN — consumed,
    or still needed? Past their date when they have one (the metrics flag
    those satellites).
- **Documents** — content in the wrong file or no longer true.
  - Narrative or backlog in PROJECT_PLAN; new needs appearing only in TODO;
    decisions recorded only in JOURNAL that ARCHITECTURE should carry.
  - Paths, components and figures cited by ARCHITECTURE and REQUIREMENTS
    that no longer exist or no longer hold.
  - Satellites: missing status, `living` but stale, `temporary` but consumed.
- **Method** — local practice vs the canonical methodology (the
  jarpa-methodology skill).
  - Rules in `CLAUDE.md` outside the managed block, and conventions visible
    in `jarpa/`, that contradict or extend the canonical rules; a local rule
    on trial says when it is re-examined (next review by default).
  - Rules written for a specific model.
  - Session references in commits (from the metrics).
- **Retro** — the findings from the answers to Step 3.

### Step 5: Validators — new findings only

Only if the operator accepted them in Step 3; otherwise record that they
were declined in the JOURNAL entry and go to Step 6.

Launch both agents in parallel (a single message with two Agent calls):

- `coherence-validator` — cross-document coherence.
- `session-reviewer` — with the window of Step 1.

Pass each:

- the list of findings already made (one line each: family, file, claim),
  asking it to report only findings not on that list and to say when it
  contradicts one;
- this review's Scope Discipline: `jarpa/` at the repository root, the root
  `CLAUDE.md`, the project's repositories — never user configuration
  (`~/.claude`) or other projects.

Verify each new finding before relaying it: open the cited file at the cited
line (a line number past the end of the file means the finding is not
verified). Drop the ones that do not hold and say how many were dropped. A
contradiction that holds corrects the earlier finding.

### Step 6: Close every finding

Present the findings as one table, would-decide-wrong first:

```
| # | Family | Class (decision misled) | Evidence | Proposed closure |
```

The operator decides each closure. Apply the fixes, add the scheduled
items to TODO (with a date if the operator gives one), record the refusals.

**Cadence.** Propose a change only on evidence: tighten
(`review_interval_sessions` in `.claude/jarpa.local.md`, default 15) after a
would-decide-wrong finding; relax after two reviews in a row with none. A
first review and a window spanning a pause do not tighten: their findings
accumulated without a review.

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
- **Results**: the findings table with their closures; the number of
  validator findings dropped.
- **Remaining Work / Next Step**: the scheduled items (and their dates, if
  any) — the next review starts from this list.

Update TODO and PROJECT_PLAN as the closures require. The operator ratifies
the entry.

Then finish the session-end duties the entry does not cover: prune TODO and
apply memory hygiene (`/jarpa:session-end`, Steps 3 and 5); the metrics of
Step 4 stand for its Step 6. Commit the review's fixes as the project
usually does. A `/jarpa:session-end` run afterwards (by the Stop hook, for
instance) finds today's review entry and adds no second one.

## When to Use

When `/jarpa:session-start` announces a review due, or when the operator
suspects drift: after a pause, a milestone change, or a model change.
