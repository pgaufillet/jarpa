#!/bin/bash
# JARPA review announcement — report only, never runs the review (exit 0).
#
# Usage: review-due.sh [project-dir] [--today YYYY-MM-DD]
#        review-due.sh [project-dir] --milestones
#
# A review is due when, since the last review (the last JOURNAL entry titled
# "Session N: JARPA review", archives included):
#   - review_interval_sessions sessions or more have passed (default 15);
#   - a gap of more than review_pause_days days separates two sessions, or
#     the last session and today (default 30): a resume after a pause;
#   - the milestone lines of PROJECT_PLAN differ from the "- Milestone:"
#     lines the review recorded in its entry.
# --milestones prints the current milestone lines in that recorded form, for
# the review to copy into its entry.

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
TODAY=""
MODE="due"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --today) TODAY="${2:-}"; shift 2 ;;
        --milestones) MODE="milestones"; shift ;;
        *) PROJECT_DIR="$1"; shift ;;
    esac
done
[[ -n "$TODAY" ]] || TODAY=$(date +%F)

JARPA="$PROJECT_DIR/jarpa"
SETTINGS="$PROJECT_DIR/.claude/jarpa.local.md"

# Integer setting from .claude/jarpa.local.md, else the default.
setting() {
    local v=""
    [[ -f "$SETTINGS" ]] && v=$(sed -n "s/^[[:space:]]*$1:[[:space:]]*\([0-9][0-9]*\).*/\1/p" "$SETTINGS" | head -1)
    printf '%s' "${v:-$2}"
}

INTERVAL=$(setting review_interval_sessions 15)
PAUSE_DAYS=$(setting review_pause_days 30)

# Top-level lines of the "## Milestones" section: numbered or bulleted items,
# or sub-headings. Sub-bullets (criteria, progress notes) are left out so
# routine edits do not count as a milestone change.
milestones() {
    [[ -f "$JARPA/PROJECT_PLAN.md" ]] || return 0
    awk '
        /^## / { in_m = ($0 ~ /^## Milestones[[:space:]]*$/); next }
        in_m && /^([0-9]+\.|[-*]) |^### / { sub(/\r$/, ""); sub(/[[:space:]]+$/, ""); print }
    ' "$JARPA/PROJECT_PLAN.md"
}

if [[ "$MODE" == "milestones" ]]; then
    milestones | sed 's/^/- Milestone: /'
    exit 0
fi

if [[ ! -f "$JARPA/JOURNAL.md" ]]; then
    printf '  [--] no jarpa/JOURNAL.md — no review check\n'
    exit 0
fi

journals=()
for f in "$JARPA"/archive/JOURNAL*.md; do
    [[ -f "$f" ]] && journals+=("$f")
done
journals+=("$JARPA/JOURNAL.md")

# Passed through the environment: awk -v would interpret backslashes.
PLAN_MILESTONES=$(milestones) \
LC_ALL=C awk -v interval="$INTERVAL" -v pause="$PAUSE_DAYS" -v today="$TODAY" '
    # Day number of a YYYY-MM-DD date; only differences are used.
    function days(d,   y, m, dd) {
        y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0; dd = substr(d, 9, 2) + 0
        if (m <= 2) { y--; m += 12 }
        return 365 * y + int(y / 4) - int(y / 100) + int(y / 400) + int((153 * (m - 3) + 2) / 5) + dd
    }
    # Canonical headers, and legacy "## Session N" ones (no date).
    # No interval expressions ({4}): mawk does not always support them.
    /^## (\[[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\] .* )?Session [0-9]+/ {
        line = $0
        date = "-"
        if (line ~ /^## \[/) date = substr(line, 5, 10)
        match(line, /Session [0-9]+/)
        num = substr(line, RSTART + 8, RLENGTH - 8) + 0
        n++; nums[n] = num; dates[n] = date
        cur_review = (line ~ /Session [0-9]+: JARPA review/)
        if (num > last) last = num
        if (cur_review && num >= review) { review = num; review_date = date; rm = ""; rcount = 0 }
        in_review = cur_review && num == review
        next
    }
    in_review && /^- Milestone: / {
        l = substr($0, 14); sub(/\r$/, "", l); sub(/[[:space:]]+$/, "", l)
        rm = rm (rcount++ ? "\n" : "") l
        next
    }
    END {
        plan = ENVIRON["PLAN_MILESTONES"]
        if (!n) { print "  [--] no session in JOURNAL.md — no review check"; exit }
        due = 0

        # Cadence: sessions since the last review, or since the start.
        since = last - review
        where = review ? sprintf("the last review (Session %d, %s)", review, review_date) : "the start (no review yet)"
        if (since >= interval) {
            printf "  [!!] review due — %d sessions since %s; every %d\n", since, where, interval
            due++
        }

        # Pause: largest gap between dated sessions from the last review on,
        # and between the last of them and today.
        k = 0
        for (i = 1; i <= n; i++) if (nums[i] >= review && dates[i] != "-") ds[++k] = dates[i]
        ds[++k] = today
        # Sessions are appended in order; sort anyway in case of archive order.
        for (i = 2; i <= k; i++) { v = ds[i]; j = i - 1; while (j > 0 && ds[j] > v) { ds[j + 1] = ds[j]; j-- } ds[j + 1] = v }
        gap = 0
        for (i = 2; i <= k; i++) {
            g = days(ds[i]) - days(ds[i - 1])
            if (g > gap) { gap = g; from = ds[i - 1]; to = (ds[i] == today && i == k) ? "today" : ds[i] }
        }
        if (gap > pause) {
            printf "  [!!] review due — resumed after a %d-day pause (%s to %s); pause over %d days\n", gap, from, to, pause
            due++
        }

        # Milestones: only comparable when the last review recorded them.
        if (review && rcount && rm != plan) {
            printf "  [!!] review due — milestones changed since the last review (Session %d)\n", review
            due++
        }

        if (!due) {
            printf "  [ok] no review due — %d sessions since %s; every %d\n", since, where, interval
        }
    }
' "${journals[@]}"

exit 0
