#!/bin/sh
# Pure Shell TUI Operator - No external dependencies
# Terminal User Interface for field-by-field comparison using only POSIX shell

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${BASE_DIR}/output"
DIF_DIR="${OUTPUT_DIR}/differences"
APL_DIR="${OUTPUT_DIR}/apply"
TMP_DIR="${BASE_DIR}/tmp"
LOG_FILE="${BASE_DIR}/var/log/tui_pure_shell.log"

# Ensure directories exist
mkdir -p "$DIF_DIR" "$APL_DIR" "$TMP_DIR" "$(dirname "$LOG_FILE")"

# Session files
SELECTIONS_FILE="${TMP_DIR}/selections.json"

# Terminal colors (if supported)
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    MAGENTA=$(tput setaf 5)
    CYAN=$(tput setaf 6)
    WHITE=$(tput setaf 7)
    BOLD=$(tput bold)
    RESET=$(tput sgr0)
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    MAGENTA=""
    CYAN=""
    WHITE=""
    BOLD=""
    RESET=""
fi

# Initialize
initialize() {
    echo '[]' > "$SELECTIONS_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Pure Shell TUI started" >> "$LOG_FILE"
}

# Clear screen
clear_screen() {
    printf '\033[2J\033[H'
}

# Print header
print_header() {
    clear_screen
    echo "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${RESET}"
    echo "${BOLD}${CYAN}            Terminal Asset Merger - Pure Shell TUI${RESET}"
    echo "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${RESET}"
    echo
}

# Print separator
print_separator() {
    echo "${BLUE}───────────────────────────────────────────────────────────────${RESET}"
}

# Log message
log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# JSON escape
json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# Add or update selection
save_selection() {
    local asset_id="$1"
    local field="$2"
    local value="$3"
    local temp_file="${TMP_DIR}/temp_selection.json"
    local current

    # Read current selections
    current=$(cat "$SELECTIONS_FILE")

    # Create new entry
    local new_entry
    new_entry=$(printf '{"asset_id":"%s","fields":{"%s":"%s"}}' \
                "$(json_escape "$asset_id")" \
                "$(json_escape "$field")" \
                "$(json_escape "$value")")

    # Update selections
    if [ "$current" = "[]" ]; then
        echo "[$new_entry]" > "$SELECTIONS_FILE"
    else
        # Simple append (doesn't handle updates to existing assets)
        echo "${current%]},${new_entry}]" > "$SELECTIONS_FILE"
    fi

    log_msg "Saved: asset=$asset_id, field=$field, value=$value"
}

# Parse difference file
parse_difference_file() {
    local dif_file="$1"
    local temp_parsed="${TMP_DIR}/parsed_fields.txt"

    # Simple extraction of field data from JSON-like format
    # This assumes a structure like: {"field1": {"zabbix": "val1", "topdesk": "val2"}, ...}

    # Extract fields and values
    sed 's/[{}]/ /g' "$dif_file" | \
    tr ',' '\n' | \
    sed 's/^ *//; s/ *$//' | \
    grep -v '^$' | \
    awk -F':' '
        BEGIN { field=""; zabbix=""; topdesk="" }
        /"[^"]+".*{/ {
            gsub(/[" ]/, "", $1)
            field = $1
        }
        /zabbix/ {
            gsub(/.*"zabbix"[[:space:]]*:[[:space:]]*"/, "")
            gsub(/".*/, "")
            zabbix = $0
        }
        /topdesk/ {
            gsub(/.*"topdesk"[[:space:]]*:[[:space:]]*"/, "")
            gsub(/".*/, "")
            topdesk = $0
            if (field != "") {
                printf "%s|%s|%s\n", field, zabbix, topdesk
            }
            field=""; zabbix=""; topdesk=""
        }
    ' > "$temp_parsed"

    echo "$temp_parsed"
}

# Display field comparison
display_field_comparison() {
    local field="$1"
    local zabbix_val="$2"
    local topdesk_val="$3"

    # Handle empty values
    [ -z "$zabbix_val" ] && zabbix_val="(empty)"
    [ -z "$topdesk_val" ] && topdesk_val="(empty)"

    print_separator
    echo "${BOLD}Field: ${YELLOW}$field${RESET}"
    echo

    # Determine conflict status
    if [ "$zabbix_val" = "$topdesk_val" ]; then
        echo "  ${GREEN}✓ Values match${RESET}"
        echo "  Value: ${WHITE}$zabbix_val${RESET}"
    else
        echo "  ${RED}✗ Values differ${RESET}"
        echo "  ${CYAN}[Z]${RESET} Zabbix:  ${WHITE}$zabbix_val${RESET}"
        echo "  ${MAGENTA}[T]${RESET} Topdesk: ${WHITE}$topdesk_val${RESET}"
    fi
    echo
}

# Get user selection for field
get_field_selection() {
    local field="$1"
    local zabbix_val="$2"
    local topdesk_val="$3"
    local choice
    local custom_val

    # Handle empty values
    [ -z "$zabbix_val" ] && zabbix_val="(empty)"
    [ -z "$topdesk_val" ] && topdesk_val="(empty)"

    # If values match, auto-select
    if [ "$zabbix_val" = "$topdesk_val" ]; then
        [ "$zabbix_val" = "(empty)" ] && echo "" || echo "$zabbix_val"
        return 0
    fi

    # Show options
    echo "${BOLD}Select value for this field:${RESET}"
    echo "  ${CYAN}[z]${RESET} Use Zabbix value"
    echo "  ${MAGENTA}[t]${RESET} Use Topdesk value"
    echo "  ${YELLOW}[c]${RESET} Enter custom value"
    echo "  ${WHITE}[s]${RESET} Skip this field"
    echo
    printf "Your choice [z/t/c/s]: "
    read -r choice

    case "$choice" in
        z|Z)
            [ "$zabbix_val" = "(empty)" ] && echo "" || echo "$zabbix_val"
            return 0
            ;;
        t|T)
            [ "$topdesk_val" = "(empty)" ] && echo "" || echo "$topdesk_val"
            return 0
            ;;
        c|C)
            printf "Enter custom value: "
            read -r custom_val
            echo "$custom_val"
            return 0
            ;;
        s|S)
            return 1
            ;;
        *)
            echo "${RED}Invalid choice. Skipping field.${RESET}"
            return 1
            ;;
    esac
}

# Process single asset
process_asset() {
    local dif_file="$1"
    local asset_id
    local parsed_file
    local field zabbix_val topdesk_val
    local selected_val
    local field_count=0
    local processed_count=0

    asset_id="$(basename "$dif_file" .dif)"

    print_header
    echo "${BOLD}${GREEN}Processing Asset: ${YELLOW}$asset_id${RESET}"
    echo

    # Parse the difference file
    parsed_file="$(parse_difference_file "$dif_file")"

    if [ ! -s "$parsed_file" ]; then
        echo "${RED}No differences found in file${RESET}"
        printf "Press Enter to continue..."
        read -r _
        return 1
    fi

    # Count total fields
    total_fields=$(wc -l < "$parsed_file" | tr -d ' ')

    # Process each field
    while IFS='|' read -r field zabbix_val topdesk_val; do
        [ -z "$field" ] && continue

        field_count=$((field_count + 1))

        print_header
        echo "${BOLD}${GREEN}Asset: ${YELLOW}$asset_id${RESET}"
        echo "${WHITE}Field ${field_count} of ${total_fields}${RESET}"
        echo

        display_field_comparison "$field" "$zabbix_val" "$topdesk_val"

        if get_field_selection "$field" "$zabbix_val" "$topdesk_val"; then
            selected_val=$?
            if [ $? -eq 0 ]; then
                # Get the actual returned value
                selected_val=$(get_field_selection "$field" "$zabbix_val" "$topdesk_val")
                save_selection "$asset_id" "$field" "$selected_val"
                processed_count=$((processed_count + 1))
                echo "${GREEN}✓ Selection saved${RESET}"
            fi
        fi

        echo
        printf "Press Enter to continue..."
        read -r _
    done < "$parsed_file"

    print_separator
    echo "${GREEN}Asset processing complete!${RESET}"
    echo "Processed ${processed_count} of ${total_fields} fields"
    echo
    printf "Press Enter to continue..."
    read -r _

    return 0
}

# List difference files
list_difference_files() {
    local count=0
    local dif_file
    local asset_id

    echo "${BOLD}Available Difference Files:${RESET}"
    echo

    for dif_file in "$DIF_DIR"/*.dif; do
        [ -f "$dif_file" ] || continue
        count=$((count + 1))
        asset_id="$(basename "$dif_file" .dif)"
        printf "  ${CYAN}%2d${RESET}. %s\n" "$count" "$asset_id"
    done

    if [ $count -eq 0 ]; then
        echo "${RED}No difference files found in: $DIF_DIR${RESET}"
        return 1
    fi

    echo
    echo "Total files: $count"
    return 0
}

# Select difference file
select_difference_file() {
    local count=0
    local selection
    local dif_file
    local selected_file=""

    list_difference_files || return 1

    echo
    printf "Enter file number (0 to cancel): "
    read -r selection

    # Validate selection
    if [ "$selection" = "0" ]; then
        return 1
    fi

    if ! echo "$selection" | grep -qE '^[0-9]+$'; then
        echo "${RED}Invalid selection${RESET}"
        return 1
    fi

    # Find the selected file
    for dif_file in "$DIF_DIR"/*.dif; do
        [ -f "$dif_file" ] || continue
        count=$((count + 1))
        if [ "$count" = "$selection" ]; then
            selected_file="$dif_file"
            break
        fi
    done

    if [ -z "$selected_file" ]; then
        echo "${RED}Invalid file number${RESET}"
        return 1
    fi

    echo "$selected_file"
    return 0
}

# Generate APL file
generate_apl_file() {
    local apl_file="${APL_DIR}/merge_$(date +%Y%m%d_%H%M%S).apl"

    if [ ! -s "$SELECTIONS_FILE" ] || [ "$(cat "$SELECTIONS_FILE")" = "[]" ]; then
        echo "${RED}No selections to save!${RESET}"
        return 1
    fi

    cp "$SELECTIONS_FILE" "$apl_file"
    log_msg "Generated APL file: $apl_file"

    echo "${GREEN}✓ APL file generated successfully!${RESET}"
    echo "File: ${YELLOW}$apl_file${RESET}"
    return 0
}

# View selections
view_selections() {
    local current

    print_header
    echo "${BOLD}Current Selections${RESET}"
    print_separator

    if [ ! -s "$SELECTIONS_FILE" ] || [ "$(cat "$SELECTIONS_FILE")" = "[]" ]; then
        echo "${YELLOW}No selections have been made yet${RESET}"
        return
    fi

    # Simple display of selections
    current=$(cat "$SELECTIONS_FILE")
    echo "$current" | sed 's/},{/}\n{/g' | sed 's/[[\]]//g' | \
    while IFS= read -r line; do
        echo "$line" | sed 's/{/\n  /g; s/}/\n/g; s/,/\n  /g; s/"//g'
    done

    return 0
}

# Main menu
main_menu() {
    local choice

    while true; do
        print_header
        echo "${BOLD}Main Menu${RESET}"
        print_separator
        echo
        echo "  ${CYAN}[1]${RESET} Process difference files"
        echo "  ${CYAN}[2]${RESET} View current selections"
        echo "  ${CYAN}[3]${RESET} Generate APL file"
        echo "  ${CYAN}[4]${RESET} Clear all selections"
        echo "  ${CYAN}[5]${RESET} View log"
        echo "  ${CYAN}[h]${RESET} Help"
        echo "  ${CYAN}[q]${RESET} Quit"
        echo
        printf "Enter your choice: "
        read -r choice

        case "$choice" in
            1)
                print_header
                selected_file=$(select_difference_file)
                if [ $? -eq 0 ] && [ -n "$selected_file" ]; then
                    process_asset "$selected_file"
                fi
                ;;
            2)
                view_selections
                echo
                printf "Press Enter to continue..."
                read -r _
                ;;
            3)
                print_header
                generate_apl_file
                echo
                printf "Press Enter to continue..."
                read -r _
                ;;
            4)
                print_header
                printf "Clear all selections? [y/N]: "
                read -r confirm
                if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                    echo '[]' > "$SELECTIONS_FILE"
                    log_msg "Selections cleared"
                    echo "${GREEN}✓ All selections cleared${RESET}"
                else
                    echo "Cancelled"
                fi
                echo
                printf "Press Enter to continue..."
                read -r _
                ;;
            5)
                print_header
                echo "${BOLD}Recent Log Entries${RESET}"
                print_separator
                if [ -f "$LOG_FILE" ]; then
                    tail -20 "$LOG_FILE"
                else
                    echo "${YELLOW}No log file found${RESET}"
                fi
                echo
                printf "Press Enter to continue..."
                read -r _
                ;;
            h|H)
                print_header
                echo "${BOLD}Help${RESET}"
                print_separator
                echo
                echo "This tool allows you to:"
                echo "  • Compare field values from Zabbix and Topdesk"
                echo "  • Select which values to keep"
                echo "  • Enter custom values when needed"
                echo "  • Generate APL files for applying changes"
                echo
                echo "Workflow:"
                echo "  1. Process difference files one by one"
                echo "  2. For each field, select the preferred value"
                echo "  3. Review your selections"
                echo "  4. Generate an APL file with your choices"
                echo
                echo "The APL file contains all your selections in JSON format"
                echo "and can be used to apply the changes to your systems."
                echo
                printf "Press Enter to continue..."
                read -r _
                ;;
            q|Q)
                echo
                echo "${GREEN}Goodbye!${RESET}"
                break
                ;;
            *)
                echo "${RED}Invalid choice. Please try again.${RESET}"
                sleep 1
                ;;
        esac
    done
}

# Cleanup
cleanup() {
    log_msg "Pure Shell TUI ended"
    # Reset terminal
    printf '\033[?25h'  # Show cursor
    clear_screen
}

trap cleanup EXIT INT TERM

# Main execution
main() {
    # Hide cursor for better display
    printf '\033[?25l'

    initialize

    print_header
    echo "${BOLD}Welcome to the Terminal Asset Merger${RESET}"
    echo
    echo "This tool helps you merge asset data from"
    echo "Zabbix and Topdesk systems using a simple"
    echo "terminal interface."
    echo
    echo "No external dependencies required!"
    echo
    printf "Press Enter to start..."
    read -r _

    main_menu
}

# Run main
main "$@"