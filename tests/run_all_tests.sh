#!/bin/bash
#
# JARPA Plugin - Run All Tests
#
# Runs plugin validation, threshold checks, and optionally installation tests.
#
# Usage:
#   ./tests/run_all_tests.sh           # Structure + unit tests only
#   ./tests/run_all_tests.sh -v        # Verbose
#   ./tests/run_all_tests.sh --full    # Include Claude Code installation tests
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

VERBOSE=""
FULL_TESTS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose) VERBOSE="-v"; shift ;;
        --full) FULL_TESTS=true; shift ;;
        *) shift ;;
    esac
done

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              JARPA Plugin - Full Test Suite                ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

FAILED=0
TOTAL_SUITES=2
if $FULL_TESTS; then
    TOTAL_SUITES=3
fi

# Test 1: Plugin Structure Tests (shell)
echo -e "${BLUE}[1/$TOTAL_SUITES]${NC} Running plugin structure tests..."
echo ""
if "$SCRIPT_DIR/test_plugin.sh" $VERBOSE; then
    echo ""
    echo -e "${GREEN}✓ Plugin structure tests passed${NC}"
else
    echo ""
    echo -e "${RED}✗ Plugin structure tests failed${NC}"
    FAILED=1
fi

echo ""
echo "────────────────────────────────────────────────────────────────"
echo ""


# Test 2: Threshold consistency (anti-drift)
echo -e "${BLUE}[2/$TOTAL_SUITES]${NC} Running threshold consistency checks..."
echo ""
if "$SCRIPT_DIR/test_thresholds_consistency.sh"; then
    echo ""
    echo -e "${GREEN}✓ Threshold consistency passed${NC}"
else
    echo ""
    echo -e "${RED}✗ Threshold consistency failed${NC}"
    FAILED=1
fi

# Test 3: Installation Tests (requires Claude CLI)
if $FULL_TESTS; then
    echo ""
    echo "────────────────────────────────────────────────────────────────"
    echo ""
    echo -e "${BLUE}[3/$TOTAL_SUITES]${NC} Running Claude Code installation tests..."
    echo ""

    if command -v claude &>/dev/null; then
        if "$SCRIPT_DIR/test_plugin_installation.sh"; then
            echo ""
            echo -e "${GREEN}✓ Installation tests passed${NC}"
        else
            echo ""
            echo -e "${RED}✗ Installation tests failed${NC}"
            FAILED=1
        fi
    else
        echo -e "${YELLOW}[SKIP]${NC} Claude CLI not found - skipping installation tests"
        echo "       Install Claude Code to run these tests"
    fi
fi

# Informational: Plugin Footprint
echo ""
echo "────────────────────────────────────────────────────────────────"
echo ""
echo -e "${BLUE}[info]${NC} Plugin context footprint..."
echo ""
if "$PLUGIN_ROOT/tools/footprint.sh"; then
    echo ""
    echo -e "${GREEN}✓ Footprint measurement complete${NC}"
else
    echo ""
    echo -e "${YELLOW}⚠ Footprint measurement failed (non-blocking)${NC}"
fi

echo ""
echo "────────────────────────────────────────────────────────────────"
echo ""
echo -e "${BLUE}[info]${NC} Plugin overlap analysis..."
echo ""
if python3 "$PLUGIN_ROOT/tools/overlap.py"; then
    echo ""
    echo -e "${GREEN}✓ Overlap analysis complete${NC}"
else
    echo ""
    echo -e "${YELLOW}⚠ Overlap analysis failed (non-blocking)${NC}"
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo ""

if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All test suites passed!${NC}"
    if ! $FULL_TESTS; then
        echo ""
        echo -e "${YELLOW}Note:${NC} Run with --full to include Claude Code installation tests"
    fi
    exit 0
else
    echo -e "${RED}✗ Some test suites failed.${NC}"
    exit 1
fi
