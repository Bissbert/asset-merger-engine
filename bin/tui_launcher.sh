#!/bin/sh
# TUI Launcher - Choose and run the appropriate TUI implementation

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors for output
if [ -t 1 ]; then
    BOLD="\033[1m"
    RED="\033[31m"
    GREEN="\033[32m"
    YELLOW="\033[33m"
    BLUE="\033[34m"
    CYAN="\033[36m"
    RESET="\033[0m"
else
    BOLD=""
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    CYAN=""
    RESET=""
fi

# Check for available TUI implementations
check_dialog() {
    command -v dialog >/dev/null 2>&1
}

check_whiptail() {
    command -v whiptail >/dev/null 2>&1
}

# Display header
print_header() {
    printf "\n${BOLD}${BLUE}═════════════════════════════════════════════${RESET}\n"
    printf "${BOLD}${CYAN}    Terminal Asset Merger - TUI Launcher${RESET}\n"
    printf "${BOLD}${BLUE}═════════════════════════════════════════════${RESET}\n\n"
}

# Main menu
main() {
    print_header

    printf "${BOLD}Available TUI Implementations:${RESET}\n\n"

    # Check which implementations are available
    dialog_available=false
    whiptail_available=false

    if check_dialog; then
        dialog_available=true
        printf "  ${GREEN}✓${RESET} ${CYAN}[1]${RESET} Dialog TUI (Full featured, best experience)\n"
    else
        printf "  ${RED}✗${RESET} ${CYAN}[1]${RESET} Dialog TUI ${YELLOW}(requires 'dialog' - not installed)${RESET}\n"
    fi

    if check_whiptail; then
        whiptail_available=true
        printf "  ${GREEN}✓${RESET} ${CYAN}[2]${RESET} Whiptail TUI (Lightweight, good compatibility)\n"
    else
        printf "  ${RED}✗${RESET} ${CYAN}[2]${RESET} Whiptail TUI ${YELLOW}(requires 'whiptail' - not installed)${RESET}\n"
    fi

    printf "  ${GREEN}✓${RESET} ${CYAN}[3]${RESET} Pure Shell TUI (No dependencies, works everywhere)\n"
    printf "  ${CYAN}[4]${RESET} Install missing dependencies\n"
    printf "  ${CYAN}[q]${RESET} Quit\n"

    printf "\n${BOLD}Enter your choice:${RESET} "
    read -r choice

    case "$choice" in
        1)
            if [ "$dialog_available" = true ]; then
                printf "\n${GREEN}Launching Dialog TUI...${RESET}\n"
                exec "$SCRIPT_DIR/tui_operator.sh" "$@"
            else
                printf "\n${RED}Error: 'dialog' is not installed${RESET}\n"
                printf "Install it with:\n"
                printf "  macOS:    ${YELLOW}brew install dialog${RESET}\n"
                printf "  Ubuntu:   ${YELLOW}sudo apt-get install dialog${RESET}\n"
                printf "  RHEL:     ${YELLOW}sudo yum install dialog${RESET}\n"
                printf "\nPress Enter to continue..."
                read -r _
                exec "$0" "$@"
            fi
            ;;
        2)
            if [ "$whiptail_available" = true ]; then
                printf "\n${GREEN}Launching Whiptail TUI...${RESET}\n"
                exec "$SCRIPT_DIR/tui_whiptail.sh" "$@"
            else
                printf "\n${RED}Error: 'whiptail' is not installed${RESET}\n"
                printf "Install it with:\n"
                printf "  macOS:    ${YELLOW}brew install newt${RESET}\n"
                printf "  Ubuntu:   ${YELLOW}sudo apt-get install whiptail${RESET}\n"
                printf "  RHEL:     ${YELLOW}sudo yum install newt${RESET}\n"
                printf "\nPress Enter to continue..."
                read -r _
                exec "$0" "$@"
            fi
            ;;
        3)
            printf "\n${GREEN}Launching Pure Shell TUI...${RESET}\n"
            exec "$SCRIPT_DIR/tui_pure_shell.sh" "$@"
            ;;
        4)
            printf "\n${BOLD}Installation Instructions:${RESET}\n\n"

            # Detect OS
            if [ "$(uname)" = "Darwin" ]; then
                printf "${BOLD}macOS (using Homebrew):${RESET}\n"
                printf "  ${YELLOW}brew install dialog newt${RESET}\n\n"
            elif [ -f /etc/debian_version ]; then
                printf "${BOLD}Debian/Ubuntu:${RESET}\n"
                printf "  ${YELLOW}sudo apt-get update${RESET}\n"
                printf "  ${YELLOW}sudo apt-get install dialog whiptail${RESET}\n\n"
            elif [ -f /etc/redhat-release ]; then
                printf "${BOLD}RHEL/CentOS/Fedora:${RESET}\n"
                printf "  ${YELLOW}sudo yum install dialog newt${RESET}\n"
                printf "  or\n"
                printf "  ${YELLOW}sudo dnf install dialog newt${RESET}\n\n"
            elif [ -f /etc/alpine-release ]; then
                printf "${BOLD}Alpine Linux:${RESET}\n"
                printf "  ${YELLOW}apk add dialog newt${RESET}\n\n"
            else
                printf "${BOLD}Generic Unix/Linux:${RESET}\n"
                printf "  Install 'dialog' and/or 'whiptail' using your package manager\n\n"
            fi

            printf "After installation, run this launcher again.\n"
            printf "\nPress Enter to continue..."
            read -r _
            exec "$0" "$@"
            ;;
        q|Q)
            printf "\n${GREEN}Goodbye!${RESET}\n"
            exit 0
            ;;
        *)
            printf "\n${RED}Invalid choice. Please try again.${RESET}\n"
            sleep 1
            exec "$0" "$@"
            ;;
    esac
}

# Auto-select if only one option is available
auto_select() {
    if check_dialog; then
        printf "\n${GREEN}Auto-selecting Dialog TUI...${RESET}\n"
        sleep 1
        exec "$SCRIPT_DIR/tui_operator.sh" "$@"
    elif check_whiptail; then
        printf "\n${GREEN}Auto-selecting Whiptail TUI...${RESET}\n"
        sleep 1
        exec "$SCRIPT_DIR/tui_whiptail.sh" "$@"
    else
        printf "\n${GREEN}Auto-selecting Pure Shell TUI...${RESET}\n"
        sleep 1
        exec "$SCRIPT_DIR/tui_pure_shell.sh" "$@"
    fi
}

# Parse arguments
if [ "$1" = "--auto" ]; then
    shift
    auto_select "$@"
else
    main "$@"
fi