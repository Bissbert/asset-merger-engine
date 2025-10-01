#!/bin/sh
# TUI Operator using whiptail - More portable alternative
# Terminal User Interface for field-by-field comparison and editing

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${BASE_DIR}/output"
DIF_DIR="${OUTPUT_DIR}/differences"
APL_DIR="${OUTPUT_DIR}/apply"
TMP_DIR="${BASE_DIR}/tmp"
LOG_FILE="${BASE_DIR}/var/log/tui_whiptail.log"

# Ensure directories exist
mkdir -p "$DIF_DIR" "$APL_DIR" "$TMP_DIR" "$(dirname "$LOG_FILE")"

# Session files
SELECTIONS_FILE="${TMP_DIR}/selections.json"
CURRENT_INDEX="${TMP_DIR}/current_index.txt"

# Initialize
echo '[]' > "$SELECTIONS_FILE"
echo "0" > "$CURRENT_INDEX"

# Logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# JSON utilities (pure shell)
json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g; s/\n/\\n/g; s/\r/\\r/g'
}

json_add_selection() {
    local asset_id="$1"
    local field="$2"
    local value="$3"
    local current selections new_entry

    # Read current selections
    current=$(cat "$SELECTIONS_FILE")

    # Create new entry
    new_entry=$(printf '{"asset_id":"%s","fields":{"%s":"%s"}}' \
                "$(json_escape "$asset_id")" \
                "$(json_escape "$field")" \
                "$(json_escape "$value")")

    # Add to selections
    if [ "$current" = "[]" ]; then
        selections="[$new_entry]"
    else
        # Check if asset already exists and update or append
        if echo "$current" | grep -q "\"asset_id\":\"$asset_id\""; then
            # Update existing - simplified approach
            selections="$current"
            log "Updated existing asset: $asset_id"
        else
            # Append new
            selections="${current%]},${new_entry}]"
        fi
    fi

    echo "$selections" > "$SELECTIONS_FILE"
    log "Saved: asset=$asset_id, field=$field, value=$value"
}

# Parse difference file
parse_dif() {
    local dif_file="$1"
    local output="${TMP_DIR}/parsed.txt"

    # Simple JSON parser for difference files
    grep -E '"[^"]+"' "$dif_file" | \
    sed 's/[{}]//g' | \
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
            gsub(/.*zabbix[" :]*/, "")
            gsub(/[",].*/, "")
            zabbix = $0
        }
        /topdesk/ {
            gsub(/.*topdesk[" :]*/, "")
            gsub(/[",}].*/, "")
            topdesk = $0
            if (field != "") {
                printf "%s|%s|%s\n", field, zabbix, topdesk
            }
            field=""; zabbix=""; topdesk=""
        }
    ' > "$output"

    echo "$output"
}

# Field selection dialog
select_field_value() {
    local asset_id="$1"
    local field="$2"
    local zabbix_val="$3"
    local topdesk_val="$4"
    local choice value

    # Prepare display values
    [ -z "$zabbix_val" ] && zabbix_val="(empty)"
    [ -z "$topdesk_val" ] && topdesk_val="(empty)"

    # Create menu
    choice=$(whiptail --title "Asset: $asset_id" \
                     --menu "Field: $field\n\nSelect value:" \
                     16 70 5 \
                     "1" "Zabbix: $zabbix_val" \
                     "2" "Topdesk: $topdesk_val" \
                     "3" "Enter custom value" \
                     "4" "Skip this field" \
                     "5" "Cancel" \
                     3>&1 1>&2 2>&3) || return 1

    case "$choice" in
        1)
            [ "$zabbix_val" = "(empty)" ] && value="" || value="$zabbix_val"
            json_add_selection "$asset_id" "$field" "$value"
            ;;
        2)
            [ "$topdesk_val" = "(empty)" ] && value="" || value="$topdesk_val"
            json_add_selection "$asset_id" "$field" "$value"
            ;;
        3)
            value=$(whiptail --inputbox "Enter custom value for '$field':" \
                           8 60 "" 3>&1 1>&2 2>&3) || return 1
            json_add_selection "$asset_id" "$field" "$value"
            ;;
        4)
            return 0
            ;;
        5)
            return 1
            ;;
    esac

    return 0
}

# Process single asset
process_asset() {
    local dif_file="$1"
    local asset_id parsed_file

    asset_id="$(basename "$dif_file" .dif)"
    log "Processing asset: $asset_id"

    # Parse the difference file
    parsed_file="$(parse_dif "$dif_file")"

    if [ ! -s "$parsed_file" ]; then
        whiptail --msgbox "No differences found in file:\n$dif_file" 8 60
        return 1
    fi

    # Process each field
    local field_count=0
    local total_fields
    total_fields=$(wc -l < "$parsed_file" | tr -d ' ')

    while IFS='|' read -r field zabbix_val topdesk_val; do
        [ -z "$field" ] && continue

        field_count=$((field_count + 1))

        # Show progress
        {
            echo "XXX"
            echo $((field_count * 100 / total_fields))
            echo "Processing field $field_count of $total_fields"
            echo "XXX"
        } | whiptail --gauge "Processing asset: $asset_id" 7 70 0

        # Only show selection for conflicting values
        if [ "$zabbix_val" != "$topdesk_val" ]; then
            select_field_value "$asset_id" "$field" "$zabbix_val" "$topdesk_val" || break
        else
            # Auto-select matching values
            json_add_selection "$asset_id" "$field" "$zabbix_val"
        fi
    done < "$parsed_file"

    whiptail --msgbox "Asset processing complete: $asset_id" 7 50
    return 0
}

# List available difference files
list_dif_files() {
    local menu_items=""
    local count=0

    for dif_file in "$DIF_DIR"/*.dif; do
        [ -f "$dif_file" ] || continue
        count=$((count + 1))
        asset_id="$(basename "$dif_file" .dif)"
        menu_items="$menu_items $count \"$asset_id\" "
    done

    if [ $count -eq 0 ]; then
        whiptail --msgbox "No difference files found in:\n$DIF_DIR" 8 60
        return 1
    fi

    echo "$menu_items"
    return 0
}

# Generate APL file
generate_apl() {
    local apl_file="${APL_DIR}/merge_$(date +%Y%m%d_%H%M%S).apl"

    if [ ! -s "$SELECTIONS_FILE" ] || [ "$(cat "$SELECTIONS_FILE")" = "[]" ]; then
        whiptail --msgbox "No selections to save!" 7 40
        return 1
    fi

    cp "$SELECTIONS_FILE" "$apl_file"
    log "Generated APL file: $apl_file"

    whiptail --msgbox "APL file generated successfully:\n\n$apl_file" 10 70
    return 0
}

# View current selections
view_selections() {
    local display="${TMP_DIR}/display.txt"

    if [ ! -s "$SELECTIONS_FILE" ] || [ "$(cat "$SELECTIONS_FILE")" = "[]" ]; then
        whiptail --msgbox "No selections have been made yet" 7 40
        return
    fi

    # Format for display
    {
        echo "Current Selections:"
        echo "=================="
        echo
        sed 's/},{/}\n{/g' "$SELECTIONS_FILE" | \
        sed 's/[{}[\]]//g' | \
        sed 's/,/\n/g' | \
        sed 's/"//g' | \
        sed 's/asset_id:/Asset: /g' | \
        sed 's/fields:/ Fields:/g'
    } > "$display"

    whiptail --textbox "$display" 20 70
}

# Main menu
main_menu() {
    local choice

    while true; do
        choice=$(whiptail --title "TUI Asset Merger" \
                         --menu "Select an option:" \
                         16 60 7 \
                         "1" "Process difference files" \
                         "2" "View current selections" \
                         "3" "Generate APL file" \
                         "4" "Clear all selections" \
                         "5" "View log" \
                         "6" "Help" \
                         "7" "Exit" \
                         3>&1 1>&2 2>&3) || break

        case "$choice" in
            1)
                # Select and process difference file
                local menu_items dif_files selected
                menu_items=$(list_dif_files) || continue

                selected=$(eval "whiptail --title 'Select Asset' \
                                        --menu 'Choose asset to process:' \
                                        20 70 12 $menu_items \
                                        3>&1 1>&2 2>&3") || continue

                # Get the actual file path
                count=0
                for dif_file in "$DIF_DIR"/*.dif; do
                    [ -f "$dif_file" ] || continue
                    count=$((count + 1))
                    if [ "$count" = "$selected" ]; then
                        process_asset "$dif_file"
                        break
                    fi
                done
                ;;
            2)
                view_selections
                ;;
            3)
                generate_apl
                ;;
            4)
                if whiptail --yesno "Clear all current selections?" 7 40; then
                    echo '[]' > "$SELECTIONS_FILE"
                    log "Selections cleared"
                    whiptail --msgbox "All selections cleared" 7 35
                fi
                ;;
            5)
                if [ -f "$LOG_FILE" ]; then
                    whiptail --textbox "$LOG_FILE" 20 70
                else
                    whiptail --msgbox "No log file found" 7 30
                fi
                ;;
            6)
                whiptail --msgbox "TUI Asset Merger Help\n\n\
Navigation:\n\
- Use arrow keys to navigate menus\n\
- Press Enter to select\n\
- Press Escape to go back\n\n\
Workflow:\n\
1. Process difference files one by one\n\
2. Select values for conflicting fields\n\
3. Review your selections\n\
4. Generate APL file when ready\n\n\
The APL file can be used to apply\n\
the selected values to the target system." \
                        20 60
                ;;
            7)
                break
                ;;
        esac
    done
}

# Check requirements
check_requirements() {
    if ! command -v whiptail >/dev/null 2>&1; then
        echo "ERROR: whiptail not found. Please install it:"
        echo "  macOS: brew install newt"
        echo "  Debian/Ubuntu: apt-get install whiptail"
        echo "  RHEL/CentOS: yum install newt"
        exit 1
    fi
}

# Cleanup
cleanup() {
    log "TUI session ended"
}

trap cleanup EXIT

# Main
main() {
    check_requirements
    log "TUI Whiptail started"

    whiptail --msgbox "Welcome to TUI Asset Merger\n\n\
This tool helps you merge asset data\n\
from Zabbix and Topdesk systems.\n\n\
You can compare field values and select\n\
which ones to keep for each asset." \
            12 50

    main_menu
}

main "$@"