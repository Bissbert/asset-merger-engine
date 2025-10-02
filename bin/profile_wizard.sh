#!/bin/sh
# Profile Wizard - Interactive TUI for creating and editing profiles
# Uses dialog/whiptail for terminal user interface

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source profile manager
. "${PROJECT_ROOT}/lib/profile_manager.sh"

# Temp files
TMP_DIR="${TMP_DIR:-/tmp}"
TEMP_FILE="${TMP_DIR}/profile_wizard_$$"
PROFILE_TEMP="${TMP_DIR}/profile_temp_$$"

# Cleanup on exit
cleanup() {
    rm -f "${TEMP_FILE}" "${PROFILE_TEMP}"
}
trap cleanup EXIT

# Detect dialog tool
detect_dialog_tool() {
    if command -v dialog >/dev/null 2>&1; then
        echo "dialog"
    elif command -v whiptail >/dev/null 2>&1; then
        echo "whiptail"
    else
        echo "none"
    fi
}

DIALOG_TOOL="$(detect_dialog_tool)"

if [ "${DIALOG_TOOL}" = "none" ]; then
    echo "Error: No dialog tool found. Please install 'dialog' or 'whiptail'" >&2
    exit 1
fi

# Dialog wrapper for compatibility
show_dialog() {
    "${DIALOG_TOOL}" "$@" 2>"${TEMP_FILE}"
}

# Main menu
show_main_menu() {
    while true; do
        show_dialog \
            --title "Profile Manager" \
            --menu "Select an action:" 15 60 7 \
            1 "Create New Profile" \
            2 "Edit Existing Profile" \
            3 "Copy Profile" \
            4 "Delete Profile" \
            5 "List All Profiles" \
            6 "Validate Profile" \
            0 "Exit"

        local choice="$(cat "${TEMP_FILE}")"

        case "${choice}" in
            1) create_profile_wizard ;;
            2) edit_profile_wizard ;;
            3) copy_profile_wizard ;;
            4) delete_profile_wizard ;;
            5) list_profiles_dialog ;;
            6) validate_profile_wizard ;;
            0|"") break ;;
        esac
    done
}

# Create profile wizard
create_profile_wizard() {
    local profile_name=""
    local description=""
    local template=""

    # Step 1: Profile name
    show_dialog \
        --title "Create Profile - Step 1/6" \
        --inputbox "Enter profile name (e.g., weekend-maintenance):" 10 60

    profile_name="$(cat "${TEMP_FILE}")"
    [ -z "${profile_name}" ] && return

    # Check if profile exists
    local profiles_dir="$(get_profiles_dir)"
    if [ -f "${profiles_dir}/${profile_name}.conf" ]; then
        show_dialog \
            --title "Error" \
            --msgbox "Profile '${profile_name}' already exists!" 8 40
        return
    fi

    # Step 2: Description
    show_dialog \
        --title "Create Profile - Step 2/6" \
        --inputbox "Enter profile description:" 10 60

    description="$(cat "${TEMP_FILE}")"

    # Step 3: Base template
    show_dialog \
        --title "Create Profile - Step 3/6" \
        --radiolist "Select base template:" 15 60 5 \
        "none" "Start from scratch" ON \
        "production" "Conservative settings" OFF \
        "staging" "Balanced settings" OFF \
        "development" "Aggressive settings" OFF \
        "audit" "Read-only/reporting" OFF

    template="$(cat "${TEMP_FILE}")"

    # Initialize profile settings
    > "${PROFILE_TEMP}"
    echo "# Profile: ${profile_name}" >> "${PROFILE_TEMP}"
    echo "# Created: $(date)" >> "${PROFILE_TEMP}"
    echo "# Description: ${description}" >> "${PROFILE_TEMP}"
    echo "" >> "${PROFILE_TEMP}"

    # Step 4: Merge strategy
    show_dialog \
        --title "Create Profile - Step 4/6" \
        --radiolist "Select merge strategy:" 12 60 3 \
        "update" "Only update existing assets" OFF \
        "create" "Only create new assets" OFF \
        "sync" "Full synchronization" ON

    local strategy="$(cat "${TEMP_FILE}")"
    [ -n "${strategy}" ] && echo "MERGE_STRATEGY=\"${strategy}\"" >> "${PROFILE_TEMP}"

    # Step 5: Conflict resolution
    show_dialog \
        --title "Create Profile - Step 5/6" \
        --radiolist "Select conflict resolution:" 12 60 4 \
        "zabbix" "Zabbix data takes precedence" ON \
        "topdesk" "TopDesk data takes precedence" OFF \
        "manual" "Prompt for each conflict" OFF \
        "newest" "Use most recent data" OFF

    local conflict="$(cat "${TEMP_FILE}")"
    [ -n "${conflict}" ] && echo "CONFLICT_RESOLUTION=\"${conflict}\"" >> "${PROFILE_TEMP}"

    # Step 6: Performance settings
    local settings_done=0
    while [ ${settings_done} -eq 0 ]; do
        show_dialog \
            --title "Create Profile - Step 6/6" \
            --form "Performance Settings:" 15 60 5 \
            "Batch Size (1-1000):"     1 1 "100"  1 25 10 0 \
            "Max Workers (1-16):"       2 1 "4"    2 25 10 0 \
            "Cache TTL (seconds):"      3 1 "3600" 3 25 10 0 \
            "Error Threshold (0-100):"  4 1 "10"   4 25 10 0

        if [ $? -eq 0 ]; then
            local batch_size="$(sed -n '1p' "${TEMP_FILE}")"
            local max_workers="$(sed -n '2p' "${TEMP_FILE}")"
            local cache_ttl="$(sed -n '3p' "${TEMP_FILE}")"
            local error_threshold="$(sed -n '4p' "${TEMP_FILE}")"

            [ -n "${batch_size}" ] && echo "BATCH_SIZE=\"${batch_size}\"" >> "${PROFILE_TEMP}"
            [ -n "${max_workers}" ] && echo "MAX_WORKERS=\"${max_workers}\"" >> "${PROFILE_TEMP}"
            [ -n "${cache_ttl}" ] && echo "CACHE_TTL=\"${cache_ttl}\"" >> "${PROFILE_TEMP}"
            [ -n "${error_threshold}" ] && echo "ERROR_THRESHOLD=\"${error_threshold}\"" >> "${PROFILE_TEMP}"

            settings_done=1
        else
            settings_done=1
        fi
    done

    # Additional options
    show_dialog \
        --title "Additional Options" \
        --checklist "Select additional options:" 15 60 6 \
        "DRY_RUN" "Always perform dry run first" OFF \
        "STRICT_VALIDATION" "Enable strict validation" ON \
        "PARALLEL_FETCH" "Enable parallel fetching" ON \
        "NOTIFY_ON_SUCCESS" "Send success notifications" OFF \
        "NOTIFY_ON_ERROR" "Send error notifications" ON \
        "GENERATE_REPORTS" "Generate HTML reports" ON

    local options="$(cat "${TEMP_FILE}")"
    for opt in ${options}; do
        opt="$(echo "${opt}" | tr -d '"')"
        echo "${opt}=\"true\"" >> "${PROFILE_TEMP}"
    done

    # Review and save
    show_dialog \
        --title "Review Profile" \
        --yesno "Profile settings:\n\n$(grep -v '^#' "${PROFILE_TEMP}" | head -10)\n\nSave this profile?" 20 60

    if [ $? -eq 0 ]; then
        ensure_profiles_dir
        local profile_file="${profiles_dir}/${profile_name}.conf"
        cp "${PROFILE_TEMP}" "${profile_file}"
        show_dialog \
            --title "Success" \
            --msgbox "Profile '${profile_name}' created successfully!" 8 50
    fi
}

# Edit profile wizard
edit_profile_wizard() {
    # Get list of profiles
    local profiles="$(list_profiles 2>/dev/null)"
    if [ -z "${profiles}" ]; then
        show_dialog \
            --title "No Profiles" \
            --msgbox "No profiles found to edit." 8 40
        return
    fi

    # Build menu options
    local menu_options=""
    local i=1
    for profile in ${profiles}; do
        menu_options="${menu_options} ${i} ${profile}"
        i=$((i + 1))
    done

    show_dialog \
        --title "Edit Profile" \
        --menu "Select profile to edit:" 15 60 10 \
        ${menu_options}

    local choice="$(cat "${TEMP_FILE}")"
    [ -z "${choice}" ] && return

    local profile_name="$(echo "${profiles}" | sed -n "${choice}p")"
    [ -z "${profile_name}" ] && return

    # Load current settings
    local profiles_dir="$(get_profiles_dir)"
    local profile_file="${profiles_dir}/${profile_name}.conf"

    # Show edit menu
    while true; do
        show_dialog \
            --title "Edit Profile: ${profile_name}" \
            --menu "Select setting to modify:" 20 60 10 \
            1 "Merge Strategy" \
            2 "Conflict Resolution" \
            3 "Batch Size" \
            4 "Max Workers" \
            5 "Cache TTL" \
            6 "Toggle Dry Run" \
            7 "Toggle Notifications" \
            8 "View Current Settings" \
            0 "Save and Exit"

        local choice="$(cat "${TEMP_FILE}")"

        case "${choice}" in
            1) edit_merge_strategy "${profile_file}" ;;
            2) edit_conflict_resolution "${profile_file}" ;;
            3) edit_batch_size "${profile_file}" ;;
            4) edit_max_workers "${profile_file}" ;;
            5) edit_cache_ttl "${profile_file}" ;;
            6) toggle_dry_run "${profile_file}" ;;
            7) toggle_notifications "${profile_file}" ;;
            8) view_profile_settings "${profile_file}" ;;
            0|"") break ;;
        esac
    done
}

# Helper functions for editing
edit_merge_strategy() {
    local profile_file="$1"
    local current="$(grep '^MERGE_STRATEGY=' "${profile_file}" 2>/dev/null | cut -d'"' -f2)"

    show_dialog \
        --title "Edit Merge Strategy" \
        --radiolist "Select merge strategy:" 12 60 3 \
        "update" "Only update existing assets" $([ "${current}" = "update" ] && echo "ON" || echo "OFF") \
        "create" "Only create new assets" $([ "${current}" = "create" ] && echo "ON" || echo "OFF") \
        "sync" "Full synchronization" $([ "${current}" = "sync" ] && echo "ON" || echo "OFF")

    local new_value="$(cat "${TEMP_FILE}")"
    if [ -n "${new_value}" ]; then
        update_setting "${profile_file}" "MERGE_STRATEGY" "${new_value}"
    fi
}

edit_conflict_resolution() {
    local profile_file="$1"
    local current="$(grep '^CONFLICT_RESOLUTION=' "${profile_file}" 2>/dev/null | cut -d'"' -f2)"

    show_dialog \
        --title "Edit Conflict Resolution" \
        --radiolist "Select conflict resolution:" 12 60 4 \
        "zabbix" "Zabbix data takes precedence" $([ "${current}" = "zabbix" ] && echo "ON" || echo "OFF") \
        "topdesk" "TopDesk data takes precedence" $([ "${current}" = "topdesk" ] && echo "ON" || echo "OFF") \
        "manual" "Prompt for each conflict" $([ "${current}" = "manual" ] && echo "ON" || echo "OFF") \
        "newest" "Use most recent data" $([ "${current}" = "newest" ] && echo "ON" || echo "OFF")

    local new_value="$(cat "${TEMP_FILE}")"
    if [ -n "${new_value}" ]; then
        update_setting "${profile_file}" "CONFLICT_RESOLUTION" "${new_value}"
    fi
}

edit_batch_size() {
    local profile_file="$1"
    local current="$(grep '^BATCH_SIZE=' "${profile_file}" 2>/dev/null | cut -d'"' -f2)"
    [ -z "${current}" ] && current="100"

    show_dialog \
        --title "Edit Batch Size" \
        --inputbox "Enter batch size (1-1000):" 10 60 "${current}"

    local new_value="$(cat "${TEMP_FILE}")"
    if [ -n "${new_value}" ]; then
        update_setting "${profile_file}" "BATCH_SIZE" "${new_value}"
    fi
}

edit_max_workers() {
    local profile_file="$1"
    local current="$(grep '^MAX_WORKERS=' "${profile_file}" 2>/dev/null | cut -d'"' -f2)"
    [ -z "${current}" ] && current="4"

    show_dialog \
        --title "Edit Max Workers" \
        --inputbox "Enter max workers (1-16):" 10 60 "${current}"

    local new_value="$(cat "${TEMP_FILE}")"
    if [ -n "${new_value}" ]; then
        update_setting "${profile_file}" "MAX_WORKERS" "${new_value}"
    fi
}

edit_cache_ttl() {
    local profile_file="$1"
    local current="$(grep '^CACHE_TTL=' "${profile_file}" 2>/dev/null | cut -d'"' -f2)"
    [ -z "${current}" ] && current="3600"

    show_dialog \
        --title "Edit Cache TTL" \
        --inputbox "Enter cache TTL in seconds:" 10 60 "${current}"

    local new_value="$(cat "${TEMP_FILE}")"
    if [ -n "${new_value}" ]; then
        update_setting "${profile_file}" "CACHE_TTL" "${new_value}"
    fi
}

toggle_dry_run() {
    local profile_file="$1"
    local current="$(grep '^DRY_RUN=' "${profile_file}" 2>/dev/null | cut -d'"' -f2)"

    if [ "${current}" = "true" ]; then
        update_setting "${profile_file}" "DRY_RUN" "false"
        show_dialog --title "Dry Run" --msgbox "Dry run disabled" 6 30
    else
        update_setting "${profile_file}" "DRY_RUN" "true"
        show_dialog --title "Dry Run" --msgbox "Dry run enabled" 6 30
    fi
}

toggle_notifications() {
    local profile_file="$1"

    show_dialog \
        --title "Toggle Notifications" \
        --checklist "Select notification settings:" 12 60 2 \
        "NOTIFY_ON_SUCCESS" "Send success notifications" \
            $(grep -q '^NOTIFY_ON_SUCCESS="true"' "${profile_file}" && echo "ON" || echo "OFF") \
        "NOTIFY_ON_ERROR" "Send error notifications" \
            $(grep -q '^NOTIFY_ON_ERROR="true"' "${profile_file}" && echo "ON" || echo "OFF")

    local selected="$(cat "${TEMP_FILE}")"

    # Update settings based on selection
    if echo "${selected}" | grep -q "NOTIFY_ON_SUCCESS"; then
        update_setting "${profile_file}" "NOTIFY_ON_SUCCESS" "true"
    else
        update_setting "${profile_file}" "NOTIFY_ON_SUCCESS" "false"
    fi

    if echo "${selected}" | grep -q "NOTIFY_ON_ERROR"; then
        update_setting "${profile_file}" "NOTIFY_ON_ERROR" "true"
    else
        update_setting "${profile_file}" "NOTIFY_ON_ERROR" "false"
    fi
}

view_profile_settings() {
    local profile_file="$1"
    local settings="$(grep -v '^#' "${profile_file}" | grep -v '^$')"

    show_dialog \
        --title "Current Profile Settings" \
        --msgbox "${settings}" 20 70
}

# Copy profile wizard
copy_profile_wizard() {
    local profiles="$(list_profiles 2>/dev/null)"
    if [ -z "${profiles}" ]; then
        show_dialog \
            --title "No Profiles" \
            --msgbox "No profiles found to copy." 8 40
        return
    fi

    # Select source profile
    local menu_options=""
    local i=1
    for profile in ${profiles}; do
        menu_options="${menu_options} ${i} ${profile}"
        i=$((i + 1))
    done

    show_dialog \
        --title "Copy Profile" \
        --menu "Select source profile:" 15 60 10 \
        ${menu_options}

    local choice="$(cat "${TEMP_FILE}")"
    [ -z "${choice}" ] && return

    local source_profile="$(echo "${profiles}" | sed -n "${choice}p")"
    [ -z "${source_profile}" ] && return

    # Get new name
    show_dialog \
        --title "Copy Profile" \
        --inputbox "Enter name for new profile:" 10 60

    local new_name="$(cat "${TEMP_FILE}")"
    [ -z "${new_name}" ] && return

    # Copy the profile
    if copy_profile "${source_profile}" "${new_name}"; then
        show_dialog \
            --title "Success" \
            --msgbox "Profile copied successfully!" 8 40
    else
        show_dialog \
            --title "Error" \
            --msgbox "Failed to copy profile." 8 40
    fi
}

# Delete profile wizard
delete_profile_wizard() {
    local profiles="$(list_profiles 2>/dev/null)"
    if [ -z "${profiles}" ]; then
        show_dialog \
            --title "No Profiles" \
            --msgbox "No profiles found to delete." 8 40
        return
    fi

    # Select profile to delete
    local menu_options=""
    local i=1
    for profile in ${profiles}; do
        menu_options="${menu_options} ${i} ${profile}"
        i=$((i + 1))
    done

    show_dialog \
        --title "Delete Profile" \
        --menu "Select profile to delete:" 15 60 10 \
        ${menu_options}

    local choice="$(cat "${TEMP_FILE}")"
    [ -z "${choice}" ] && return

    local profile_name="$(echo "${profiles}" | sed -n "${choice}p")"
    [ -z "${profile_name}" ] && return

    # Confirm deletion
    show_dialog \
        --title "Confirm Deletion" \
        --yesno "Are you sure you want to delete profile '${profile_name}'?" 8 50

    if [ $? -eq 0 ]; then
        if delete_profile "${profile_name}" 1; then
            show_dialog \
                --title "Success" \
                --msgbox "Profile deleted successfully!" 8 40
        else
            show_dialog \
                --title "Error" \
                --msgbox "Failed to delete profile." 8 40
        fi
    fi
}

# List profiles dialog
list_profiles_dialog() {
    local profiles_info="$(list_profiles 1 2>&1)"

    if [ -z "${profiles_info}" ] || echo "${profiles_info}" | grep -q "No profiles"; then
        show_dialog \
            --title "Profiles" \
            --msgbox "No profiles found." 8 40
    else
        show_dialog \
            --title "Available Profiles" \
            --msgbox "${profiles_info}" 20 80
    fi
}

# Validate profile wizard
validate_profile_wizard() {
    local profiles="$(list_profiles 2>/dev/null)"
    if [ -z "${profiles}" ]; then
        show_dialog \
            --title "No Profiles" \
            --msgbox "No profiles found to validate." 8 40
        return
    fi

    # Select profile to validate
    local menu_options=""
    local i=1
    for profile in ${profiles}; do
        menu_options="${menu_options} ${i} ${profile}"
        i=$((i + 1))
    done

    show_dialog \
        --title "Validate Profile" \
        --menu "Select profile to validate:" 15 60 10 \
        ${menu_options}

    local choice="$(cat "${TEMP_FILE}")"
    [ -z "${choice}" ] && return

    local profile_name="$(echo "${profiles}" | sed -n "${choice}p")"
    [ -z "${profile_name}" ] && return

    # Validate the profile
    local result="$(validate_profile "${profile_name}" 2>&1)"

    show_dialog \
        --title "Validation Result" \
        --msgbox "${result}" 12 60
}

# Main execution
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Profile Wizard - Interactive profile management"
    echo "Usage: $0"
    echo ""
    echo "Launches an interactive TUI for managing synchronization profiles."
    exit 0
fi

# Launch main menu
show_main_menu