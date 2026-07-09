#!/bin/bash
#
# JARPA Plugin Context Footprint
#
# Measures word count of all plugin content files to track context overhead.
# Output: formatted table suitable for pasting into docs.
#
# Usage: ./tools/footprint.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors (disabled if not a terminal)
if [[ -t 1 ]]; then
    BOLD='\033[1m'
    NC='\033[0m'
else
    BOLD=''
    NC=''
fi

echo ""
echo -e "${BOLD}JARPA Plugin Context Footprint${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

total_words=0

# Function: print a component group and add to total_words
print_group() {
    local label="$1"
    shift
    local patterns=("$@")
    local group_total=0

    echo -e "${BOLD}$label${NC}"
    for pattern in "${patterns[@]}"; do
        while IFS= read -r file; do
            if [[ -f "$file" ]]; then
                local rel_path="${file#$PLUGIN_ROOT/}"
                local words
                words=$(wc -w < "$file")
                printf "  %-55s %6d\n" "$rel_path" "$words"
                group_total=$((group_total + words))
            fi
        done < <(find "$PLUGIN_ROOT"/$pattern \( -name "*.md" -o -name "*.sh" -o -name "*.py" \) 2>/dev/null | sort)
    done
    printf "  %-55s %6d\n" "── Subtotal" "$group_total"
    echo ""
    total_words=$((total_words + group_total))
}

print_group "Commands" "commands"
print_group "Agents" "agents"
print_group "Skills" "skills"
print_group "Hooks" "hooks"
print_group "Templates" "templates"
print_group "Statusline" "mcp-servers"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "  %-55s %6d\n" "TOTAL PLUGIN FOOTPRINT" "$total_words"
echo ""

# Session overhead estimate: files loaded during start+end cycle
echo -e "${BOLD}Session Overhead Estimate${NC}"
echo "(Files loaded during a typical start+end cycle)"
echo ""

session_words=0
session_files=(
    "$PLUGIN_ROOT/commands/session-start.md"
    "$PLUGIN_ROOT/commands/session-end.md"
    "$PLUGIN_ROOT/skills/jarpa-methodology/SKILL.md"
)

for file in "${session_files[@]}"; do
    rel_path="${file#$PLUGIN_ROOT/}"
    if [[ -f "$file" ]]; then
        words=$(wc -w < "$file")
        printf "  %-55s %6d\n" "$rel_path" "$words"
        session_words=$((session_words + words))
    fi
done
printf "  %-55s %6d\n" "── Session overhead" "$session_words"
echo ""
echo "Date: $(date +%F)"
