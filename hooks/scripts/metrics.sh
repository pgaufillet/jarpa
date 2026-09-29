#!/bin/bash
# JARPA hygiene metrics — report only, never blocks (always exits 0).
#
# Usage: metrics.sh [project-dir] [--since <git date>]
#
# Measures the consumer's jarpa/ files in bytes (line counts are skewed by
# wrapping), TODO markers, session references in recent commits of the
# project's code repositories, the managed CLAUDE.md block, the auto-memory
# state and satellite status markers. Files absent from jarpa/ are skipped.
# Flagged lines start with "[!!]"; session-end relays the report as is.

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
SINCE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --since) SINCE="${2:-}"; shift 2 ;;
        *) PROJECT_DIR="$1"; shift ;;
    esac
done

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
JARPA="$PROJECT_DIR/jarpa"
SETTINGS="$PROJECT_DIR/.claude/jarpa.local.md"
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

# Canonical (not configurable): the methodology says prune on completion and
# at most one [ONGOING]; a handful of closed items is a "Recently Done".
CLOSED_ITEMS_MAX=10

FLAGS=0
ok()   { printf '  [ok] %s\n' "$1"; }
warn() { printf '  [!!] %s\n' "$1"; FLAGS=$((FLAGS + 1)); }
info() { printf '  [--] %s\n' "$1"; }
kb()   { awk -v b="$1" 'BEGIN { printf "%.1f KB", b / 1000 }'; }

# Integer setting from .claude/jarpa.local.md, else the default.
setting() {
    local v=""
    [[ -f "$SETTINGS" ]] && v=$(sed -n "s/^[[:space:]]*$1:[[:space:]]*\([0-9][0-9]*\).*/\1/p" "$SETTINGS" | head -1)
    printf '%s' "${v:-$2}"
}

JOURNAL_LINES_MAX=$(setting journal_lines 1500)
ENTRY_BYTES_MAX=$(setting journal_entry_bytes 6000)
TODO_BYTES_MAX=$(setting todo_bytes 30000)
PLAN_BYTES_MAX=$(setting plan_bytes 15000)

echo "JARPA hygiene (report only)"

if [[ ! -d "$JARPA" ]]; then
    info "no jarpa/ in $PROJECT_DIR — run /jarpa:init"
    exit 0
fi

# --- JOURNAL: total lines drive archiving; entry size is measured in bytes.
# Legacy "## Session N" headers are tolerated so drifted journals still count.
if [[ -f "$JARPA/JOURNAL.md" ]]; then
    j_bytes=$(wc -c < "$JARPA/JOURNAL.md")
    j_lines=$(wc -l < "$JARPA/JOURNAL.md")
    read -r n_entries mean_entry last_entry < <(LC_ALL=C awk '
        /^## (\[|Session )/ { if (started) s[n++] = cur; started = 1; cur = 0 }
        started { cur += length($0) + 1 }
        END {
            if (started) s[n++] = cur
            for (i = 0; i < n; i++) t += s[i]
            printf "%d %d %d\n", n, (n ? int(t / n) : 0), (n ? s[n - 1] : 0)
        }' "$JARPA/JOURNAL.md")

    msg="JOURNAL.md $(kb "$j_bytes"), $j_lines lines (archive at $JOURNAL_LINES_MAX)"
    if (( j_lines > JOURNAL_LINES_MAX )); then
        warn "$msg — run /jarpa:archive"
    elif (( j_lines * 10 >= JOURNAL_LINES_MAX * 9 )); then
        warn "$msg — archiving soon"
    else
        ok "$msg"
    fi

    msg="journal entries: $n_entries, mean $(kb "$mean_entry"), last $(kb "$last_entry") (target <= $(kb "$ENTRY_BYTES_MAX"))"
    if (( last_entry > ENTRY_BYTES_MAX || mean_entry > ENTRY_BYTES_MAX )); then
        warn "$msg — keep entries lean"
    else
        ok "$msg"
    fi
fi

# --- TODO: size, closed items lingering, [ONGOING] markers.
if [[ -f "$JARPA/TODO.md" ]]; then
    t_bytes=$(wc -c < "$JARPA/TODO.md")
    msg="TODO.md $(kb "$t_bytes") (threshold $(kb "$TODO_BYTES_MAX"))"
    if (( t_bytes > TODO_BYTES_MAX )); then warn "$msg — prune"; else ok "$msg"; fi

    # A closed box at line start, with or without a list bullet.
    closed=$(LC_ALL=C grep -cE '^[[:space:]]*([-*+][[:space:]]+)?(\[[xX]\]|✅)' "$JARPA/TODO.md" || true)
    msg="TODO closed items: $closed (prune above $CLOSED_ITEMS_MAX — their record lives in JOURNAL)"
    if (( closed > CLOSED_ITEMS_MAX )); then warn "$msg"; else ok "$msg"; fi

    # Marker at line start (optionally after a list dash, checkbox, heading
    # or bold) or anywhere in a heading, so prose mentioning "[ONGOING]" is
    # not counted.
    ongoing=$(grep -cE '^[[:space:]#*-]*(\[[ xX]\][[:space:]]*)?\**\[ONGOING|^#+[[:space:]].*\[ONGOING' "$JARPA/TODO.md" || true)
    msg="TODO [ONGOING] markers: $ongoing (at most 1)"
    if (( ongoing > 1 )); then warn "$msg"; else ok "$msg"; fi
fi

# --- PROJECT_PLAN: size only; content drift is judged at review time.
if [[ -f "$JARPA/PROJECT_PLAN.md" ]]; then
    p_bytes=$(wc -c < "$JARPA/PROJECT_PLAN.md")
    msg="PROJECT_PLAN.md $(kb "$p_bytes") (threshold $(kb "$PLAN_BYTES_MAX"))"
    if (( p_bytes > PLAN_BYTES_MAX )); then
        warn "$msg — rewrite to current state; planned work belongs in TODO"
    else
        ok "$msg"
    fi
fi

# --- ARCHITECTURE / REQUIREMENTS: read on demand, not at session start, so
# their size is reported for information only.
for f in ARCHITECTURE.md REQUIREMENTS.md; do
    [[ -f "$JARPA/$f" ]] && info "$f $(kb "$(wc -c < "$JARPA/$f")") (read on demand, no threshold)"
done

# --- Satellites: any other jarpa/*.md needs a status marker in its head.
# A temporary one carries a due date: "temporary, due: YYYY-MM-DD".
satellites=0
unmarked=()
temporary=0
undated=()
overdue=()
today=$(date +%F)
for f in "$JARPA"/*.md; do
    [[ -f "$f" ]] || continue
    case "$(basename "$f")" in
        PROJECT_PLAN.md|TODO.md|REQUIREMENTS.md|ARCHITECTURE.md|JOURNAL.md|CLAUDE.md) continue ;;
    esac
    satellites=$((satellites + 1))
    marker=$(head -5 "$f" | sed -n 's/.*<!-- jarpa-status: *\([^>]*[^ ]\) *-->.*/\1/p' | head -1)
    status=${marker%%,*}
    case "$status" in
        living|snapshot) ;;
        temporary)
            temporary=$((temporary + 1))
            due=$(sed -n 's/.*due: *\([0-9-]*\).*/\1/p' <<< "$marker")
            if [[ ! "$due" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
                undated+=("$(basename "$f")")
            elif [[ "$due" < "$today" ]]; then
                overdue+=("$(basename "$f") $due")
            fi
            ;;
        *) unmarked+=("$(basename "$f")") ;;
    esac
done
if (( satellites > 0 )); then
    if (( ${#unmarked[@]} > 0 )); then
        list="${unmarked[*]:0:5}"
        (( ${#unmarked[@]} > 5 )) && list="$list …"
        warn "satellites: $satellites, ${#unmarked[@]} without jarpa-status marker ($list)"
    else
        ok "satellites: $satellites, all with a jarpa-status marker"
    fi
    (( temporary > 0 )) && info "temporary satellites: $temporary (delete once consumed)"
    if (( ${#undated[@]} > 0 )); then
        warn "temporary satellites without a due date: ${undated[*]} — add \", due: YYYY-MM-DD\" to the marker"
    fi
    if (( ${#overdue[@]} > 0 )); then
        list=$(printf '%s, ' "${overdue[@]}")
        warn "temporary satellites past due: ${list%, } — consume and delete, or reschedule"
    fi
fi

# --- Session references in commits of the project's code repositories:
# the project dir itself and its direct sub-directories, deduplicated, minus
# a repository that is the jarpa/ folder itself (a private logbook).
jarpa_real=$(cd "$JARPA" && pwd -P)
declare -A seen=()
repos=()
for d in "$PROJECT_DIR" "$PROJECT_DIR"/*/; do
    [[ -d "$d" ]] || continue
    [[ "$d" == "$PROJECT_DIR" || -e "$d/.git" ]] || continue
    top=$(git -C "$d" rev-parse --show-toplevel 2>/dev/null) || continue
    top=$(cd "$top" && pwd -P)
    [[ "$top" == "$jarpa_real" || -n "${seen[$top]:-}" ]] && continue
    seen[$top]=1
    repos+=("$top")
done

# Window: the last 30 days or the last 10 JOURNAL entries, whichever is
# longer, so a pause does not empty it; --since overrides.
SINCE_NOTE=""
if [[ -z "$SINCE" ]]; then
    SINCE="30 days ago"
    tenth=""
    [[ -f "$JARPA/JOURNAL.md" ]] && tenth=$(sed -n 's/^## \[\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\)\].*/\1/p' "$JARPA/JOURNAL.md" | tail -10 | head -1)
    # GNU date, then BSD date.
    month_ago=$(date -d '30 days ago' +%F 2>/dev/null || date -v-30d +%F 2>/dev/null || true)
    if [[ -n "$tenth" && -n "$month_ago" && "$tenth" < "$month_ago" ]]; then
        SINCE="$tenth" SINCE_NOTE=" (last 10 sessions)"
    fi
fi

SESSION_RE_1='(^|[^[:alnum:]_])S[0-9]{2,4}($|[^[:alnum:]_])'
SESSION_RE_2='[Ss]ession[[:space:]]+[0-9]+'
if (( ${#repos[@]} > 0 )); then
    total=0
    details=()
    for r in "${repos[@]}"; do
        email=$(git -C "$r" config user.email 2>/dev/null || true)
        hits=$(git -C "$r" log --since="$SINCE" ${email:+--author="$email"} \
            -E --grep="$SESSION_RE_1" --grep="$SESSION_RE_2" --date=short --format='%ad %h %s' 2>/dev/null || true)
        [[ -z "$hits" ]] && continue
        count=$(printf '%s\n' "$hits" | wc -l)
        total=$((total + count))
        # Newest first: the latest date tells a stopped practice from a live one.
        latest=$(printf '%s\n' "$hits" | head -1)
        details+=("$(basename "$r") $count, latest ${latest%% *} \"$(printf '%s' "${latest#* }" | cut -c1-60)\"")
    done
    if (( total > 0 )); then
        warn "session references in commits since $SINCE$SINCE_NOTE: $total ($(IFS=';'; echo "${details[*]}")) — commits are public-facing"
    else
        ok "session references in commits since $SINCE$SINCE_NOTE: 0 (${#repos[@]} repo(s))"
    fi
fi

# --- Managed CLAUDE.md block vs the installed template.
TEMPLATE="$PLUGIN_ROOT/templates/CLAUDE_MD_INJECT.md"
CLAUDE_MD="$PROJECT_DIR/CLAUDE.md"
if [[ -f "$TEMPLATE" ]]; then
    if [[ ! -f "$CLAUDE_MD" ]] || ! grep -q '^<!-- JARPA:BEGIN' "$CLAUDE_MD"; then
        warn "CLAUDE.md managed block: absent — run /jarpa:init"
    elif ! grep -q '^<!-- JARPA:END -->$' "$CLAUDE_MD"; then
        warn "CLAUDE.md managed block: malformed (END marker missing) — repair markers"
    elif [[ "$(sed -n '/^<!-- JARPA:BEGIN/,/^<!-- JARPA:END -->$/p' "$CLAUDE_MD")" == "$(cat "$TEMPLATE")" ]]; then
        ok "CLAUDE.md managed block: up to date"
    else
        warn "CLAUDE.md managed block: stale — run /jarpa:upgrade"
    fi
fi

# --- Auto-memory: env var, then settings local > project > user; absent = on.
memory_setting() {
    [[ -f "$1" ]] || return 1
    local v
    v=$(grep -oE '"autoMemoryEnabled"[[:space:]]*:[[:space:]]*(true|false)' "$1" | grep -oE 'true|false' | tail -1)
    [[ -n "$v" ]] && printf '%s' "$v"
}
mem_state="" mem_source=""
if [[ "${CLAUDE_CODE_DISABLE_AUTO_MEMORY:-}" == "1" ]]; then
    mem_state=false mem_source="CLAUDE_CODE_DISABLE_AUTO_MEMORY"
else
    for scope in "local:$PROJECT_DIR/.claude/settings.local.json" \
                 "project:$PROJECT_DIR/.claude/settings.json" \
                 "user:$CONFIG_DIR/settings.json"; do
        if v=$(memory_setting "${scope#*:}"); then
            mem_state=$v mem_source="${scope%%:*} settings"
            break
        fi
    done
fi
if [[ "$mem_state" == "false" ]]; then
    ok "auto-memory: disabled ($mem_source)"
else
    slug=$(printf '%s' "$PROJECT_DIR" | sed 's/[^[:alnum:]]/-/g')
    mem_dir="$CONFIG_DIR/projects/$slug/memory"
    mem_files=0 mem_project=0
    if [[ -d "$mem_dir" ]]; then
        mem_files=$(find "$mem_dir" -maxdepth 1 -name '*.md' ! -name MEMORY.md | wc -l)
        # The methodology allows user profile and collaboration preferences
        # (types user, feedback); project and reference memories hold facts
        # that belong in the repository.
        mem_project=$(find "$mem_dir" -maxdepth 1 -name '*.md' ! -name MEMORY.md \
            -exec grep -lE '^[[:space:]]*type:[[:space:]]*(project|reference)[[:space:]]*$' {} + 2>/dev/null | wc -l)
    fi
    msg="auto-memory: enabled (${mem_source:-default}), $mem_files memory file(s)"
    if (( mem_project > 0 )); then
        warn "$msg, $mem_project project/reference — project facts belong in the repository; prefer \"autoMemoryEnabled\": false in .claude/settings.json"
    else
        ok "$msg, preferences only"
    fi
fi

if (( FLAGS > 0 )); then
    echo "  $FLAGS item(s) flagged — recommendations only, nothing was changed"
else
    echo "  all measures within thresholds"
fi
exit 0
