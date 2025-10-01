#!/bin/sh
# TUI Operator - Terminal User Interface for field-by-field comparison and editing
# Uses dialog for POSIX-compliant terminal interface

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${BASE_DIR}/output"
DIF_DIR="${OUTPUT_DIR}/differences"
APL_DIR="${OUTPUT_DIR}/apply"
TMP_DIR="${BASE_DIR}/tmp"
LOG_FILE="${BASE_DIR}/var/log/tui_operator.log"

# Ensure directories exist
mkdir -p "$DIF_DIR" "$APL_DIR" "$TMP_DIR" "$(dirname "$LOG_FILE")"

# Session management
SESSION_FILE="${TMP_DIR}/tui_session.json"
CURRENT_ASSET_FILE="${TMP_DIR}/current_asset.txt"
SELECTIONS_FILE="${TMP_DIR}/selections.json"

# Color codes for dialog (if supported)
export DIALOGRC="${BASE_DIR}/etc/dialog.rc"

# Initialize log
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Initialize session
init_session() {
    log_message "Initializing TUI session"
    echo '[]' > "$SELECTIONS_FILE"
    : > "$CURRENT_ASSET_FILE"

    # Create dialog config if not exists
    if [ ! -f "$DIALOGRC" ]; then
        cat > "$DIALOGRC" <<'EOF'
# Dialog configuration
use_shadow = ON
use_colors = ON
screen_color = (WHITE,BLUE,ON)
dialog_color = (BLACK,WHITE,OFF)
title_color = (BLUE,WHITE,ON)
border_color = (WHITE,WHITE,ON)
button_active_color = (WHITE,BLUE,ON)
button_inactive_color = (BLACK,WHITE,OFF)
button_key_active_color = (WHITE,BLUE,ON)
button_key_inactive_color = (RED,WHITE,OFF)
button_label_active_color = (YELLOW,BLUE,ON)
button_label_inactive_color = (BLACK,WHITE,ON)
inputbox_color = (BLACK,WHITE,OFF)
inputbox_border_color = (BLACK,WHITE,OFF)
searchbox_color = (BLACK,WHITE,OFF)
searchbox_title_color = (BLUE,WHITE,ON)
searchbox_border_color = (WHITE,WHITE,ON)
position_indicator_color = (BLUE,WHITE,ON)
menubox_color = (BLACK,WHITE,OFF)
menubox_border_color = (WHITE,WHITE,ON)
item_color = (BLACK,WHITE,OFF)
item_selected_color = (WHITE,BLUE,ON)
tag_color = (BLUE,WHITE,ON)
tag_selected_color = (YELLOW,BLUE,ON)
tag_key_color = (RED,WHITE,OFF)
tag_key_selected_color = (RED,BLUE,ON)
check_color = (BLACK,WHITE,OFF)
check_selected_color = (WHITE,BLUE,ON)
uarrow_color = (GREEN,WHITE,ON)
darrow_color = (GREEN,WHITE,ON)
EOF
    fi
}

# Load difference file
load_dif_file() {
    local dif_file="$1"
    local asset_id

    if [ ! -f "$dif_file" ]; then
        log_message "ERROR: Difference file not found: $dif_file"
        return 1
    fi

    # Extract asset ID from filename
    asset_id="$(basename "$dif_file" .dif)"
    echo "$asset_id" > "$CURRENT_ASSET_FILE"

    log_message "Loading difference file for asset: $asset_id"
    return 0
}

# Parse difference data
parse_differences() {
    local dif_file="$1"
    local temp_parsed="${TMP_DIR}/parsed_dif.txt"

    # Parse JSON difference file into readable format
    if command -v jq >/dev/null 2>&1; then
        jq -r '
            to_entries[] |
            "\(.key)|\(.value.zabbix // "")|\(.value.topdesk // "")"
        ' "$dif_file" > "$temp_parsed"
    else
        # Fallback to awk if jq not available
        awk '
            BEGIN { in_field = 0 }
            /"[^"]+":/ {
                gsub(/[":,{}]/, "")
                field = $1
                in_field = 1
                next
            }
            in_field && /zabbix/ {
                gsub(/.*"zabbix"[[:space:]]*:[[:space:]]*"/, "")
                gsub(/".*/, "")
                zabbix_val = $0
            }
            in_field && /topdesk/ {
                gsub(/.*"topdesk"[[:space:]]*:[[:space:]]*"/, "")
                gsub(/".*/, "")
                topdesk_val = $0
                print field "|" zabbix_val "|" topdesk_val
                in_field = 0
                zabbix_val = ""
                topdesk_val = ""
            }
        ' "$dif_file" > "$temp_parsed"
    fi

    echo "$temp_parsed"
}

# Display field comparison dialog
display_field_comparison() {
    local asset_id="$1"
    local field="$2"
    local zabbix_val="$3"
    local topdesk_val="$4"
    local selected_val=""
    local custom_val=""

    # Prepare display values
    [ -z "$zabbix_val" ] && zabbix_val="(empty)"
    [ -z "$topdesk_val" ] && topdesk_val="(empty)"

    # Create menu options
    local menu_file="${TMP_DIR}/menu_options.txt"
    {
        echo "zabbix" "Zabbix: $zabbix_val"
        echo "topdesk" "Topdesk: $topdesk_val"
        if [ "$zabbix_val" != "$topdesk_val" ]; then
            echo "custom" "Enter custom value"
        fi
        echo "skip" "Skip this field"
    } > "$menu_file"

    # Show selection dialog
    local choice
    choice=$(dialog --title "Asset: $asset_id - Field: $field" \
                   --menu "Select value for '$field':" \
                   15 70 4 \
                   --file "$menu_file" \
                   2>&1 >/dev/tty) || return 1

    case "$choice" in
        zabbix)
            [ "$zabbix_val" = "(empty)" ] && selected_val="" || selected_val="$zabbix_val"
            ;;
        topdesk)
            [ "$topdesk_val" = "(empty)" ] && selected_val="" || selected_val="$topdesk_val"
            ;;
        custom)
            custom_val=$(dialog --title "Custom Value" \
                               --inputbox "Enter custom value for '$field':" \
                               8 50 \
                               2>&1 >/dev/tty) || return 1
            selected_val="$custom_val"
            ;;
        skip)
            return 2
            ;;
    esac

    # Save selection
    save_field_selection "$asset_id" "$field" "$selected_val"
    return 0
}

# Save field selection
save_field_selection() {
    local asset_id="$1"
    local field="$2"
    local value="$3"
    local temp_file="${TMP_DIR}/temp_selection.json"

    log_message "Saving selection: asset=$asset_id, field=$field, value=$value"

    # Update selections file
    if command -v jq >/dev/null 2>&1; then
        jq --arg aid "$asset_id" \
           --arg fld "$field" \
           --arg val "$value" \
           '
           . as $data |
           if any(.[]; .asset_id == $aid) then
               map(if .asset_id == $aid then
                   .fields[$fld] = $val
                   else . end)
           else
               . + [{asset_id: $aid, fields: {($fld): $val}}]
           end
           ' "$SELECTIONS_FILE" > "$temp_file"
    else
        # Fallback to awk-based JSON manipulation
        awk -v aid="$asset_id" -v fld="$field" -v val="$value" '
            BEGIN {
                printf "["
                found = 0
            }
            # Simple JSON parser/builder
            {
                # Process existing entries
                if (NR > 1) printf ","
                printf "{\"asset_id\":\"%s\",\"fields\":{\"%s\":\"%s\"}}", aid, fld, val
            }
            END { printf "]\n" }
        ' < "$SELECTIONS_FILE" > "$temp_file"
    fi

    mv "$temp_file" "$SELECTIONS_FILE"
}

# Process all differences for an asset
process_asset_differences() {
    local dif_file="$1"
    local asset_id
    local parsed_file
    local result

    asset_id="$(basename "$dif_file" .dif)"
    parsed_file="$(parse_differences "$dif_file")"

    if [ ! -f "$parsed_file" ]; then
        log_message "ERROR: Failed to parse difference file"
        return 1
    fi

    # Process each field
    while IFS='|' read -r field zabbix_val topdesk_val; do
        [ -z "$field" ] && continue

        display_field_comparison "$asset_id" "$field" "$zabbix_val" "$topdesk_val"
        result=$?

        if [ $result -eq 1 ]; then
            # User cancelled
            return 1
        elif [ $result -eq 2 ]; then
            # Field skipped
            continue
        fi
    done < "$parsed_file"

    return 0
}

# Generate APL file
generate_apl_file() {
    local apl_file="${APL_DIR}/merge_$(date +%Y%m%d_%H%M%S).apl"

    log_message "Generating APL file: $apl_file"

    # Copy selections to APL file
    cp "$SELECTIONS_FILE" "$apl_file"

    dialog --title "Success" \
           --msgbox "APL file generated:\n$apl_file" \
           8 60

    echo "$apl_file"
}

# Main menu
main_menu() {
    local choice
    local dif_files
    local num_files

    while true; do
        # Count available difference files
        dif_files="$(find "$DIF_DIR" -name "*.dif" -type f 2>/dev/null | sort)"
        num_files="$(echo "$dif_files" | grep -c . || echo 0)"

        choice=$(dialog --title "TUI Merger - Main Menu" \
                       --menu "Select an option ($num_files difference files found):" \
                       15 60 6 \
                       1 "Process difference files" \
                       2 "View current selections" \
                       3 "Generate APL file" \
                       4 "Clear selections" \
                       5 "View logs" \
                       6 "Exit" \
                       2>&1 >/dev/tty) || break

        case "$choice" in
            1)
                process_all_differences
                ;;
            2)
                view_selections
                ;;
            3)
                if [ -s "$SELECTIONS_FILE" ] && [ "$(cat "$SELECTIONS_FILE")" != "[]" ]; then
                    generate_apl_file
                else
                    dialog --title "Warning" \
                           --msgbox "No selections to save. Process some differences first." \
                           7 50
                fi
                ;;
            4)
                if dialog --title "Confirm" \
                         --yesno "Clear all current selections?" \
                         7 40; then
                    echo '[]' > "$SELECTIONS_FILE"
                    log_message "Selections cleared by user"
                    dialog --title "Success" --msgbox "Selections cleared" 6 30
                fi
                ;;
            5)
                view_logs
                ;;
            6)
                break
                ;;
        esac
    done
}

# Process all difference files
process_all_differences() {
    local dif_files
    local file_list="${TMP_DIR}/dif_files.txt"
    local selected_file
    local num_processed=0
    local total_files

    # Get list of difference files
    find "$DIF_DIR" -name "*.dif" -type f 2>/dev/null | sort > "$file_list"
    total_files="$(wc -l < "$file_list" | tr -d ' ')"

    if [ "$total_files" -eq 0 ]; then
        dialog --title "No Files" \
               --msgbox "No difference files found in:\n$DIF_DIR" \
               8 50
        return
    fi

    # Create menu of available files
    local menu_items="${TMP_DIR}/menu_items.txt"
    : > "$menu_items"

    while IFS= read -r dif_file; do
        asset_id="$(basename "$dif_file" .dif)"
        echo "$dif_file" "$asset_id" >> "$menu_items"
    done < "$file_list"

    # Show file selection dialog
    selected_file=$(dialog --title "Select Asset to Process" \
                          --menu "Choose a difference file:" \
                          20 70 12 \
                          --file "$menu_items" \
                          2>&1 >/dev/tty) || return

    # Process selected file
    if [ -n "$selected_file" ]; then
        process_asset_differences "$selected_file"
        if [ $? -eq 0 ]; then
            dialog --title "Complete" \
                   --msgbox "Asset processing complete" \
                   6 40
        fi
    fi
}

# View current selections
view_selections() {
    local temp_view="${TMP_DIR}/selections_view.txt"

    if [ ! -s "$SELECTIONS_FILE" ] || [ "$(cat "$SELECTIONS_FILE")" = "[]" ]; then
        dialog --title "No Selections" \
               --msgbox "No selections have been made yet" \
               7 40
        return
    fi

    # Format selections for viewing
    if command -v jq >/dev/null 2>&1; then
        jq -r '.[] |
            "Asset: \(.asset_id)\n" +
            (.fields | to_entries | map("  \(.key): \(.value)") | join("\n")) +
            "\n"
        ' "$SELECTIONS_FILE" > "$temp_view"
    else
        # Simple text extraction
        sed 's/},{/}\n{/g' "$SELECTIONS_FILE" | \
        sed 's/[][]//g' | \
        sed 's/{/\n/g' | \
        sed 's/}/\n/g' | \
        grep -v '^$' > "$temp_view"
    fi

    dialog --title "Current Selections" \
           --textbox "$temp_view" \
           20 70
}

# View logs
view_logs() {
    if [ -f "$LOG_FILE" ]; then
        dialog --title "TUI Operator Logs" \
               --textbox "$LOG_FILE" \
               20 70
    else
        dialog --title "No Logs" \
               --msgbox "No log file found" \
               7 30
    fi
}

# Cleanup on exit
cleanup() {
    log_message "TUI session ended"
    clear
}

# Signal handlers
trap cleanup EXIT
trap 'log_message "TUI interrupted"; exit 130' INT TERM

# Main execution
main() {
    # Check for dialog command
    if ! command -v dialog >/dev/null 2>&1; then
        echo "ERROR: 'dialog' command not found. Please install it first."
        echo "On macOS: brew install dialog"
        echo "On Linux: apt-get install dialog or yum install dialog"
        exit 1
    fi

    # Initialize
    init_session
    log_message "TUI Operator started"

    # Show welcome screen
    dialog --title "TUI Merger Tool" \
           --msgbox "Welcome to the Terminal User Interface for Asset Merger\n\n\
This tool allows you to:\n\
- Compare Zabbix and Topdesk field values\n\
- Select preferred values or enter custom ones\n\
- Generate APL files for applying changes\n\n\
Press OK to continue..." \
           14 60

    # Run main menu
    main_menu

    # Cleanup handled by trap
}

# Run main function
main "$@"