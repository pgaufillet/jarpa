#!/bin/bash
#
# JARPA — Thresholds anti-drift test
#
# The warning (75%) and critical (90%) context thresholds are duplicated
# across several files because those files run independently of each other
# and cannot share a runtime import. This test fails if any consumer drifts
# from the canonical values.
#
# Canonical source: jarpa/ARCHITECTURE.md "Canonical Values" table.
#
# Consumers checked by this test:
#   - mcp-servers/context-monitor/server.sh
#   - skills/jarpa-methodology/SKILL.md
#   - agents/session-protocol.md
#   - mcp-servers/context-monitor/statusline.sh
#

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

WARNING_CANONICAL=75
CRITICAL_CANONICAL=90

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

FAILED=0

fail() {
    printf '%b✗%b %s\n' "$RED" "$NC" "$1" >&2
    FAILED=1
}

pass() {
    printf '%b✓%b %s\n' "$GREEN" "$NC" "$1"
}

# --- Check 1: server.sh has the exact canonical values ---

SERVER="$PLUGIN_ROOT/mcp-servers/context-monitor/server.sh"
if [[ ! -f "$SERVER" ]]; then
    fail "server.sh not found at $SERVER"
else
    warning_line=$(grep -E '^THRESHOLD_WARNING=[0-9]+' "$SERVER" || true)
    critical_line=$(grep -E '^THRESHOLD_CRITICAL=[0-9]+' "$SERVER" || true)
    warning_val=${warning_line#THRESHOLD_WARNING=}
    critical_val=${critical_line#THRESHOLD_CRITICAL=}

    if [[ "$warning_val" == "$WARNING_CANONICAL" ]]; then
        pass "server.sh THRESHOLD_WARNING=$WARNING_CANONICAL"
    else
        fail "server.sh THRESHOLD_WARNING is '$warning_val' (expected $WARNING_CANONICAL)"
    fi

    if [[ "$critical_val" == "$CRITICAL_CANONICAL" ]]; then
        pass "server.sh THRESHOLD_CRITICAL=$CRITICAL_CANONICAL"
    else
        fail "server.sh THRESHOLD_CRITICAL is '$critical_val' (expected $CRITICAL_CANONICAL)"
    fi
fi

# --- Check 2: methodology skill mentions both canonical values ---

SKILL="$PLUGIN_ROOT/skills/jarpa-methodology/SKILL.md"
if [[ ! -f "$SKILL" ]]; then
    fail "methodology skill not found at $SKILL"
else
    if grep -qE "warning threshold \(${WARNING_CANONICAL}%\)" "$SKILL"; then
        pass "methodology skill references ${WARNING_CANONICAL}% warning threshold"
    else
        fail "methodology skill is missing '${WARNING_CANONICAL}%' warning threshold reference"
    fi

    if grep -qE "critical threshold \(${CRITICAL_CANONICAL}%\)" "$SKILL"; then
        pass "methodology skill references ${CRITICAL_CANONICAL}% critical threshold"
    else
        fail "methodology skill is missing '${CRITICAL_CANONICAL}%' critical threshold reference"
    fi
fi

# --- Check 3: session-protocol agent mentions both canonical values ---

AGENT="$PLUGIN_ROOT/agents/session-protocol.md"
if [[ ! -f "$AGENT" ]]; then
    fail "session-protocol agent not found at $AGENT"
else
    if grep -qE "At ${WARNING_CANONICAL}% \(WARNING\)" "$AGENT"; then
        pass "session-protocol agent references ${WARNING_CANONICAL}% warning"
    else
        fail "session-protocol agent is missing 'At ${WARNING_CANONICAL}% (WARNING)' reference"
    fi

    if grep -qE "At ${CRITICAL_CANONICAL}% \(CRITICAL\)" "$AGENT"; then
        pass "session-protocol agent references ${CRITICAL_CANONICAL}% critical"
    else
        fail "session-protocol agent is missing 'At ${CRITICAL_CANONICAL}% (CRITICAL)' reference"
    fi
fi

# --- Check 4: statusline.sh emits the same thresholds in its label logic ---

STATUSLINE="$PLUGIN_ROOT/mcp-servers/context-monitor/statusline.sh"
if [[ ! -f "$STATUSLINE" ]]; then
    fail "statusline.sh not found at $STATUSLINE"
else
    if grep -qE "usage_percent\" -ge ${CRITICAL_CANONICAL}" "$STATUSLINE"; then
        pass "statusline.sh uses ${CRITICAL_CANONICAL} as critical label threshold"
    else
        fail "statusline.sh critical label does not match canonical ${CRITICAL_CANONICAL}"
    fi

    if grep -qE "usage_percent\" -ge ${WARNING_CANONICAL}" "$STATUSLINE"; then
        pass "statusline.sh uses ${WARNING_CANONICAL} as warning label threshold"
    else
        fail "statusline.sh warning label does not match canonical ${WARNING_CANONICAL}"
    fi
fi

# --- Check 5: ARCHITECTURE.md Canonical Values table matches ---

ARCH="$PLUGIN_ROOT/jarpa/ARCHITECTURE.md"
if [[ -f "$ARCH" ]]; then
    if grep -qE "Context warning threshold .* ${WARNING_CANONICAL}%" "$ARCH"; then
        pass "ARCHITECTURE.md canonical warning matches ${WARNING_CANONICAL}%"
    else
        fail "ARCHITECTURE.md canonical warning row does not match ${WARNING_CANONICAL}%"
    fi

    if grep -qE "Context critical threshold .* ${CRITICAL_CANONICAL}%" "$ARCH"; then
        pass "ARCHITECTURE.md canonical critical matches ${CRITICAL_CANONICAL}%"
    else
        fail "ARCHITECTURE.md canonical critical row does not match ${CRITICAL_CANONICAL}%"
    fi
fi

echo ""
if [[ $FAILED -eq 0 ]]; then
    printf '%bAll threshold consumers agree on WARNING=%d CRITICAL=%d%b\n' \
        "$GREEN" "$WARNING_CANONICAL" "$CRITICAL_CANONICAL" "$NC"
    exit 0
else
    printf '%bThreshold drift detected. Fix the divergent consumers.%b\n' "$RED" "$NC" >&2
    exit 1
fi
