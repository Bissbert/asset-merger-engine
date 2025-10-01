#!/bin/sh
# Test script for TUI functionality

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${BASE_DIR}/output"
DIF_DIR="${OUTPUT_DIR}/differences"
APL_DIR="${OUTPUT_DIR}/apply"

# Colors
if [ -t 1 ]; then
    GREEN="\033[32m"
    YELLOW="\033[33m"
    BLUE="\033[34m"
    RESET="\033[0m"
else
    GREEN=""
    YELLOW=""
    BLUE=""
    RESET=""
fi

echo "${BLUE}TUI System Test${RESET}"
echo "==============="
echo

# Check for difference files
echo "Checking difference files..."
dif_count=$(find "$DIF_DIR" -name "*.dif" -type f 2>/dev/null | wc -l | tr -d ' ')
echo "  Found ${GREEN}${dif_count}${RESET} difference files"

# List difference files
if [ "$dif_count" -gt 0 ]; then
    echo "  Files:"
    find "$DIF_DIR" -name "*.dif" -type f 2>/dev/null | while read -r dif; do
        echo "    - $(basename "$dif")"
    done
fi
echo

# Check for APL files
echo "Checking APL files..."
apl_count=$(find "$APL_DIR" -name "*.apl" -type f 2>/dev/null | wc -l | tr -d ' ')
echo "  Found ${GREEN}${apl_count}${RESET} APL files"

if [ "$apl_count" -gt 0 ]; then
    echo "  Files:"
    find "$APL_DIR" -name "*.apl" -type f 2>/dev/null | while read -r apl; do
        echo "    - $(basename "$apl")"
    done
fi
echo

# Check TUI scripts
echo "Checking TUI scripts..."
for script in "$SCRIPT_DIR"/tui*.sh; do
    if [ -x "$script" ]; then
        echo "  ${GREEN}✓${RESET} $(basename "$script") - executable"
    else
        echo "  ${YELLOW}✗${RESET} $(basename "$script") - not executable"
    fi
done
echo

# Check dependencies
echo "Checking optional dependencies..."
if command -v dialog >/dev/null 2>&1; then
    echo "  ${GREEN}✓${RESET} dialog - installed"
else
    echo "  ${YELLOW}○${RESET} dialog - not installed (optional)"
fi

if command -v whiptail >/dev/null 2>&1; then
    echo "  ${GREEN}✓${RESET} whiptail - installed"
else
    echo "  ${YELLOW}○${RESET} whiptail - not installed (optional)"
fi
echo

# Suggest next steps
echo "${BLUE}Next Steps:${RESET}"
echo "1. Run the TUI launcher:"
echo "   ${GREEN}./bin/tui_launcher.sh${RESET}"
echo
echo "2. Or run the pure shell version directly:"
echo "   ${GREEN}./bin/tui_pure_shell.sh${RESET}"
echo
echo "3. Process the sample difference files to create an APL file"
echo

# Display sample difference file content
if [ "$dif_count" -gt 0 ]; then
    first_dif=$(find "$DIF_DIR" -name "*.dif" -type f 2>/dev/null | head -1)
    echo "${BLUE}Sample difference file content:${RESET}"
    echo "File: $(basename "$first_dif")"
    echo "---"
    head -10 "$first_dif"
    echo "---"
fi