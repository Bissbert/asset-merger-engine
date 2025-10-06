#!/bin/sh
# Profile Manager - Manage synchronization profiles for Asset Merger Engine
# POSIX-compliant profile management module

set -e

# Get the directory where profiles are stored
get_profiles_dir() {
    if [ -n "${PROFILES_DIR:-}" ]; then
        echo "${PROFILES_DIR}"
    elif [ -n "${ETC_DIR:-}" ]; then
        echo "${ETC_DIR}/profiles"
    elif [ -d "${HOME}/.config/asset-merger-engine" ]; then
        echo "${HOME}/.config/asset-merger-engine/profiles"
    else
        echo "/etc/asset-merger-engine/profiles"
    fi
}

# Ensure profiles directory exists
ensure_profiles_dir() {
    local profiles_dir="$(get_profiles_dir)"
    if [ ! -d "${profiles_dir}" ]; then
        mkdir -p "${profiles_dir}" 2>/dev/null || {
            echo "Error: Cannot create profiles directory: ${profiles_dir}" >&2
            return 1
        }
    fi
    echo "${profiles_dir}"
}

# List all available profiles
list_profiles() {
    local profiles_dir="$(get_profiles_dir)"
    local verbose="${1:-0}"

    if [ ! -d "${profiles_dir}" ]; then
        echo "No profiles directory found" >&2
        return 1
    fi

    if [ "${verbose}" = "1" ]; then
        printf "%-20s %-50s\n" "PROFILE NAME" "DESCRIPTION"
        printf "%-20s %-50s\n" "--------------------" "--------------------------------------------------"
    fi

    for profile in "${profiles_dir}"/*.conf; do
        if [ -f "${profile}" ]; then
            local name="$(basename "${profile}" .conf)"
            if [ "${verbose}" = "1" ]; then
                local desc="$(grep -E '^# Description:' "${profile}" 2>/dev/null | sed 's/^# Description: *//')"
                [ -z "${desc}" ] && desc="No description"
                printf "%-20s %-50s\n" "${name}" "${desc}"
            else
                echo "${name}"
            fi
        fi
    done
}

# Show profile details
show_profile() {
    local profile_name="$1"
    local profiles_dir="$(get_profiles_dir)"
    local profile_file="${profiles_dir}/${profile_name}.conf"

    if [ ! -f "${profile_file}" ]; then
        echo "Error: Profile '${profile_name}' not found" >&2
        return 1
    fi

    echo "Profile: ${profile_name}"
    echo "File: ${profile_file}"
    echo ""
    echo "Settings:"
    echo "---------"
    grep -v '^#' "${profile_file}" | grep -v '^$' || true
}

# Create a new profile
create_profile() {
    local profile_name="$1"
    local profiles_dir="$(ensure_profiles_dir)"
    local profile_file="${profiles_dir}/${profile_name}.conf"

    # Check if profile already exists
    if [ -f "${profile_file}" ]; then
        echo "Error: Profile '${profile_name}' already exists" >&2
        return 1
    fi

    # Shift to get remaining arguments
    shift

    # Start with header
    cat > "${profile_file}" << EOF
# Profile: ${profile_name}
# Created: $(date)
# Description: Custom synchronization profile

EOF

    # Process key=value pairs from arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --description)
                sed -i.bak "s/^# Description:.*$/# Description: $2/" "${profile_file}"
                rm -f "${profile_file}.bak"
                shift 2
                ;;
            --template)
                # Load from template if specified
                local template_file="${profiles_dir}/../profile-templates/${2}.template"
                if [ -f "${template_file}" ]; then
                    cat "${template_file}" >> "${profile_file}"
                else
                    echo "Warning: Template '${2}' not found" >&2
                fi
                shift 2
                ;;
            --set)
                # Add key=value setting
                echo "$2" >> "${profile_file}"
                shift 2
                ;;
            --strategy|--merge-strategy)
                echo "MERGE_STRATEGY=\"$2\"" >> "${profile_file}"
                shift 2
                ;;
            --conflict|--conflict-resolution)
                echo "CONFLICT_RESOLUTION=\"$2\"" >> "${profile_file}"
                shift 2
                ;;
            --batch-size)
                echo "BATCH_SIZE=\"$2\"" >> "${profile_file}"
                shift 2
                ;;
            --workers|--max-workers)
                echo "MAX_WORKERS=\"$2\"" >> "${profile_file}"
                shift 2
                ;;
            --dry-run)
                echo "DRY_RUN=\"$2\"" >> "${profile_file}"
                shift 2
                ;;
            --cache-ttl)
                echo "CACHE_TTL=\"$2\"" >> "${profile_file}"
                shift 2
                ;;
            --notify-success)
                echo "NOTIFY_ON_SUCCESS=\"$2\"" >> "${profile_file}"
                shift 2
                ;;
            --notify-error)
                echo "NOTIFY_ON_ERROR=\"$2\"" >> "${profile_file}"
                shift 2
                ;;
            --parallel)
                echo "PARALLEL_FETCH=\"$2\"" >> "${profile_file}"
                shift 2
                ;;
            --validation|--strict-validation)
                echo "STRICT_VALIDATION=\"$2\"" >> "${profile_file}"
                shift 2
                ;;
            *)
                echo "Unknown option: $1" >&2
                shift
                ;;
        esac
    done

    echo "Profile '${profile_name}' created successfully"
    echo "Location: ${profile_file}"
}

# Edit an existing profile
edit_profile() {
    local profile_name="$1"
    local profiles_dir="$(get_profiles_dir)"
    local profile_file="${profiles_dir}/${profile_name}.conf"

    if [ ! -f "${profile_file}" ]; then
        echo "Error: Profile '${profile_name}' not found" >&2
        return 1
    fi

    shift

    # Create backup
    cp "${profile_file}" "${profile_file}.bak"

    # Process updates
    while [ $# -gt 0 ]; do
        case "$1" in
            --set)
                local key="${2%%=*}"
                local value="${2#*=}"
                # Update or add the setting
                if grep -q "^${key}=" "${profile_file}"; then
                    sed -i.tmp "s/^${key}=.*$/${key}=\"${value}\"/" "${profile_file}"
                    rm -f "${profile_file}.tmp"
                else
                    echo "${key}=\"${value}\"" >> "${profile_file}"
                fi
                shift 2
                ;;
            --unset)
                # Remove a setting
                sed -i.tmp "/^$2=/d" "${profile_file}"
                rm -f "${profile_file}.tmp"
                shift 2
                ;;
            *)
                # Use same options as create
                case "$1" in
                    --strategy|--merge-strategy)
                        update_setting "${profile_file}" "MERGE_STRATEGY" "$2"
                        shift 2
                        ;;
                    --conflict|--conflict-resolution)
                        update_setting "${profile_file}" "CONFLICT_RESOLUTION" "$2"
                        shift 2
                        ;;
                    --batch-size)
                        update_setting "${profile_file}" "BATCH_SIZE" "$2"
                        shift 2
                        ;;
                    --workers|--max-workers)
                        update_setting "${profile_file}" "MAX_WORKERS" "$2"
                        shift 2
                        ;;
                    --dry-run)
                        update_setting "${profile_file}" "DRY_RUN" "$2"
                        shift 2
                        ;;
                    *)
                        echo "Unknown option: $1" >&2
                        shift
                        ;;
                esac
                ;;
        esac
    done

    echo "Profile '${profile_name}' updated successfully"
}

# Helper function to update a setting
update_setting() {
    local file="$1"
    local key="$2"
    local value="$3"

    if grep -q "^${key}=" "${file}"; then
        sed -i.tmp "s/^${key}=.*$/${key}=\"${value}\"/" "${file}"
        rm -f "${file}.tmp"
    else
        echo "${key}=\"${value}\"" >> "${file}"
    fi
}

# Delete a profile
delete_profile() {
    local profile_name="$1"
    local confirm="${2:-0}"
    local profiles_dir="$(get_profiles_dir)"
    local profile_file="${profiles_dir}/${profile_name}.conf"

    if [ ! -f "${profile_file}" ]; then
        echo "Error: Profile '${profile_name}' not found" >&2
        return 1
    fi

    if [ "${confirm}" != "1" ]; then
        printf "Delete profile '${profile_name}'? [y/N] "
        read -r response
        case "${response}" in
            [yY][eE][sS]|[yY])
                ;;
            *)
                echo "Deletion cancelled"
                return 0
                ;;
        esac
    fi

    rm -f "${profile_file}"
    echo "Profile '${profile_name}' deleted"
}

# Copy a profile
copy_profile() {
    local source_name="$1"
    local dest_name="$2"
    local profiles_dir="$(ensure_profiles_dir)"
    local source_file="${profiles_dir}/${source_name}.conf"
    local dest_file="${profiles_dir}/${dest_name}.conf"

    if [ ! -f "${source_file}" ]; then
        echo "Error: Source profile '${source_name}' not found" >&2
        return 1
    fi

    if [ -f "${dest_file}" ]; then
        echo "Error: Destination profile '${dest_name}' already exists" >&2
        return 1
    fi

    cp "${source_file}" "${dest_file}"

    # Update the profile name in the header
    sed -i.tmp "s/^# Profile: ${source_name}$/# Profile: ${dest_name}/" "${dest_file}"
    sed -i.tmp "s/^# Created:.*$/# Created: $(date)/" "${dest_file}"
    sed -i.tmp "s/^# Description:.*$/# Description: Copy of ${source_name}/" "${dest_file}"
    rm -f "${dest_file}.tmp"

    echo "Profile '${source_name}' copied to '${dest_name}'"
}

# Validate a profile
validate_profile() {
    local profile_name="$1"
    local profiles_dir="$(get_profiles_dir)"
    local profile_file="${profiles_dir}/${profile_name}.conf"

    if [ ! -f "${profile_file}" ]; then
        echo "Error: Profile '${profile_name}' not found" >&2
        return 1
    fi

    local errors=0

    # Source the profile in a subshell to check for syntax errors
    (
        set +e
        . "${profile_file}" 2>/dev/null
    ) || {
        echo "Error: Profile has syntax errors" >&2
        errors=$((errors + 1))
    }

    # Check for valid merge strategy
    local strategy="$(grep '^MERGE_STRATEGY=' "${profile_file}" | cut -d'"' -f2)"
    if [ -n "${strategy}" ]; then
        case "${strategy}" in
            update|create|sync)
                ;;
            *)
                echo "Error: Invalid MERGE_STRATEGY: ${strategy}" >&2
                errors=$((errors + 1))
                ;;
        esac
    fi

    # Check for valid conflict resolution
    local conflict="$(grep '^CONFLICT_RESOLUTION=' "${profile_file}" | cut -d'"' -f2)"
    if [ -n "${conflict}" ]; then
        case "${conflict}" in
            zabbix|topdesk|manual|newest)
                ;;
            *)
                echo "Error: Invalid CONFLICT_RESOLUTION: ${conflict}" >&2
                errors=$((errors + 1))
                ;;
        esac
    fi

    # Check numeric values
    local batch_size="$(grep '^BATCH_SIZE=' "${profile_file}" | cut -d'"' -f2)"
    if [ -n "${batch_size}" ]; then
        if ! echo "${batch_size}" | grep -qE '^[0-9]+$'; then
            echo "Error: BATCH_SIZE must be numeric: ${batch_size}" >&2
            errors=$((errors + 1))
        elif [ "${batch_size}" -lt 1 ] || [ "${batch_size}" -gt 10000 ]; then
            echo "Warning: BATCH_SIZE ${batch_size} is outside recommended range (1-10000)" >&2
        fi
    fi

    if [ ${errors} -eq 0 ]; then
        echo "Profile '${profile_name}' is valid"
        return 0
    else
        echo "Profile '${profile_name}' has ${errors} error(s)" >&2
        return 1
    fi
}

# Export a profile
export_profile() {
    local profile_name="$1"
    local output_file="${2:-${profile_name}.profile}"
    local profiles_dir="$(get_profiles_dir)"
    local profile_file="${profiles_dir}/${profile_name}.conf"

    if [ ! -f "${profile_file}" ]; then
        echo "Error: Profile '${profile_name}' not found" >&2
        return 1
    fi

    cp "${profile_file}" "${output_file}"
    echo "Profile '${profile_name}' exported to '${output_file}'"
}

# Import a profile
import_profile() {
    local input_file="$1"
    local profile_name="${2:-$(basename "${input_file}" .conf | sed 's/\.profile$//')}"
    local profiles_dir="$(ensure_profiles_dir)"
    local profile_file="${profiles_dir}/${profile_name}.conf"

    if [ ! -f "${input_file}" ]; then
        echo "Error: Input file '${input_file}' not found" >&2
        return 1
    fi

    if [ -f "${profile_file}" ]; then
        echo "Error: Profile '${profile_name}' already exists" >&2
        return 1
    fi

    cp "${input_file}" "${profile_file}"

    # Update the profile name in the header
    sed -i.tmp "s/^# Profile:.*$/# Profile: ${profile_name}/" "${profile_file}"
    sed -i.tmp "s/^# Created:.*$/# Created: $(date) (imported)/" "${profile_file}"
    rm -f "${profile_file}.tmp"

    echo "Profile imported as '${profile_name}'"
}