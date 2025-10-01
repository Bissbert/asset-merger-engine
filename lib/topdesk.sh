#!/bin/sh
# topdesk.sh - Topdesk-specific functions for asset-merger-engine
# POSIX-compliant library for Topdesk operations

# Source common library
. "$(dirname "$0")/../lib/common.sh" 2>/dev/null || true

# Topdesk API functions
# ---------------------

# Initialize Topdesk connection
topdesk_init() {
    local url="${1:-${TOPDESK_URL}}"
    local user="${2:-${TOPDESK_USER}}"
    local password="${3:-${TOPDESK_PASSWORD}}"

    # Validate connection parameters
    if [ -z "${url}" ] || [ -z "${user}" ] || [ -z "${password}" ]; then
        return 1
    fi

    # Test connection
    if ! is_reachable "$(parse_url "${url}" host)" "$(parse_url "${url}" port)"; then
        return 1
    fi

    return 0
}

# Get Topdesk authentication token
topdesk_auth() {
    local url="${1:-${TOPDESK_URL}}"
    local user="${2:-${TOPDESK_USER}}"
    local password="${3:-${TOPDESK_PASSWORD}}"

    # Check for cached token
    local cached_token
    if cached_token=$(cache_get "topdesk_token" 3600); then
        printf '%s' "${cached_token}"
        return 0
    fi

    # Request new token via topdesk-cli
    local token
    token=$(topdesk-cli --url "${url}" --user "${user}" --password "${password}" auth 2>/dev/null)

    if [ -n "${token}" ]; then
        cache_set "topdesk_token" "${token}"
        printf '%s' "${token}"
        return 0
    fi

    return 1
}

# Fetch assets from Topdesk
topdesk_get_assets() {
    local filter="${1}"
    local output_format="${2:-json}"

    local cmd="topdesk-cli asset list"

    # Add filter if provided
    [ -n "${filter}" ] && cmd="${cmd} --filter '${filter}'"
    [ -n "${output_format}" ] && cmd="${cmd} --format '${output_format}'"

    # Execute command and return output
    eval "${cmd}" 2>/dev/null
}

# Get asset details
topdesk_get_asset_details() {
    local asset_id="$1"

    if [ -z "${asset_id}" ]; then
        return 1
    fi

    topdesk-cli asset get --id "${asset_id}" --format json 2>/dev/null
}

# Create new asset
topdesk_create_asset() {
    local asset_json="$1"

    if [ -z "${asset_json}" ]; then
        return 1
    fi

    printf '%s' "${asset_json}" | topdesk-cli asset create --input - --format json 2>/dev/null
}

# Update existing asset
topdesk_update_asset() {
    local asset_id="$1"
    local asset_json="$2"

    if [ -z "${asset_id}" ] || [ -z "${asset_json}" ]; then
        return 1
    fi

    printf '%s' "${asset_json}" | topdesk-cli asset update --id "${asset_id}" --input - --format json 2>/dev/null
}

# Delete asset
topdesk_delete_asset() {
    local asset_id="$1"

    if [ -z "${asset_id}" ]; then
        return 1
    fi

    topdesk-cli asset delete --id "${asset_id}" 2>/dev/null
}

# Get locations
topdesk_get_locations() {
    topdesk-cli location list --format json 2>/dev/null
}

# Get suppliers
topdesk_get_suppliers() {
    topdesk-cli supplier list --format json 2>/dev/null
}

# Topdesk data extraction functions
# ---------------------------------

# Extract asset information
topdesk_extract_asset() {
    local asset_json="$1"

    # Extract relevant fields
    local asset_id=$(json_get "${asset_json}" ".id")
    local name=$(json_get "${asset_json}" ".name")
    local specification=$(json_get "${asset_json}" ".specification")
    local serial_number=$(json_get "${asset_json}" ".serialNumber")
    local ip_address=$(json_get "${asset_json}" ".ipAddress")

    # Build asset JSON
    cat << EOF
{
    "asset_id": "${asset_id}",
    "name": "${name}",
    "specification": "${specification}",
    "serial_number": "${serial_number}",
    "ip_address": "${ip_address}"
}
EOF
}

# Extract location information
topdesk_extract_location() {
    local asset_json="$1"

    local location_id=$(json_get "${asset_json}" ".locationId")
    local location_name=$(json_get "${asset_json}" ".locationName")
    local branch_id=$(json_get "${asset_json}" ".branchId")
    local branch_name=$(json_get "${asset_json}" ".branchName")

    cat << EOF
{
    "location_id": "${location_id}",
    "location_name": "${location_name}",
    "branch_id": "${branch_id}",
    "branch_name": "${branch_name}"
}
EOF
}

# Extract technical details
topdesk_extract_technical() {
    local asset_json="$1"

    local brand=$(json_get "${asset_json}" ".brand")
    local model=$(json_get "${asset_json}" ".model")
    local operating_system=$(json_get "${asset_json}" ".operatingSystem")
    local mac_address=$(json_get "${asset_json}" ".macAddress")

    cat << EOF
{
    "brand": "${brand}",
    "model": "${model}",
    "operating_system": "${operating_system}",
    "mac_address": "${mac_address}"
}
EOF
}

# Topdesk data transformation functions
# -------------------------------------

# Transform Topdesk asset to standard format
topdesk_standardize_asset() {
    local asset_data="$1"

    # Extract all components
    local asset_info=$(topdesk_extract_asset "${asset_data}")
    local location_info=$(topdesk_extract_location "${asset_data}")
    local technical_info=$(topdesk_extract_technical "${asset_data}")

    # Merge all information
    local merged_data=$(json_merge "${asset_info}" "${location_info}")
    merged_data=$(json_merge "${merged_data}" "${technical_info}")

    printf '%s' "${merged_data}"
}

# Prepare asset for update
topdesk_prepare_update() {
    local existing_asset="$1"
    local new_data="$2"
    local merge_strategy="${3:-update}"

    case "${merge_strategy}" in
        update)
            # Update only provided fields
            json_merge "${existing_asset}" "${new_data}"
            ;;
        replace)
            # Replace entire asset
            printf '%s' "${new_data}"
            ;;
        merge)
            # Intelligent merge based on field priority
            topdesk_intelligent_merge "${existing_asset}" "${new_data}"
            ;;
        *)
            return 1
            ;;
    esac
}

# Intelligent merge function
topdesk_intelligent_merge() {
    local existing="$1"
    local new="$2"

    # Fields that should always be updated from new data
    local update_fields=".ipAddress .operatingSystem .lastSync"

    # Fields that should be kept from existing if empty in new
    local preserve_fields=".serialNumber .brand .model"

    # Start with existing data
    local result="${existing}"

    # Update specific fields from new data
    for field in ${update_fields}; do
        local new_value=$(json_get "${new}" "${field}")
        if [ -n "${new_value}" ]; then
            result=$(json_set "${result}" "${field}" "\"${new_value}\"")
        fi
    done

    # Preserve fields if not present in new data
    for field in ${preserve_fields}; do
        local new_value=$(json_get "${new}" "${field}")
        local existing_value=$(json_get "${existing}" "${field}")
        if [ -z "${new_value}" ] && [ -n "${existing_value}" ]; then
            result=$(json_set "${result}" "${field}" "\"${existing_value}\"")
        fi
    done

    printf '%s' "${result}"
}

# Batch processing functions
# -------------------------

# Process assets in batches
topdesk_process_batch() {
    local operation="${1:-update}"
    local batch_size="${2:-50}"
    local input_file="${3:-/dev/stdin}"
    local output_file="${4:-/dev/stdout}"

    local count=0
    local batch_data="["
    local results="["

    while IFS= read -r line; do
        if [ ${count} -gt 0 ]; then
            batch_data="${batch_data},"
        fi
        batch_data="${batch_data}${line}"
        count=$((count + 1))

        if [ ${count} -ge ${batch_size} ]; then
            # Process batch
            local batch_result=$(topdesk_execute_batch "${operation}" "${batch_data}]")
            if [ -n "${batch_result}" ]; then
                results="${results}${batch_result},"
            fi
            count=0
            batch_data="["
        fi
    done < "${input_file}"

    # Process remaining items
    if [ ${count} -gt 0 ]; then
        local batch_result=$(topdesk_execute_batch "${operation}" "${batch_data}]")
        if [ -n "${batch_result}" ]; then
            results="${results}${batch_result}"
        fi
    fi

    # Output results
    printf '%s]' "${results}" > "${output_file}"
}

# Execute batch operation
topdesk_execute_batch() {
    local operation="$1"
    local batch_data="$2"

    case "${operation}" in
        update)
            printf '%s' "${batch_data}" | topdesk-cli asset update-batch --input - --format json
            ;;
        create)
            printf '%s' "${batch_data}" | topdesk-cli asset create-batch --input - --format json
            ;;
        delete)
            printf '%s' "${batch_data}" | topdesk-cli asset delete-batch --input - --format json
            ;;
        *)
            return 1
            ;;
    esac
}

# Validation functions
# -------------------

# Validate Topdesk asset data
topdesk_validate_asset() {
    local asset_json="$1"

    # Check required fields
    local name=$(json_get "${asset_json}" ".name")

    if [ -z "${name}" ]; then
        return 1
    fi

    # Validate IP address if present
    local ip_address=$(json_get "${asset_json}" ".ipAddress")
    if [ -n "${ip_address}" ] && ! is_valid_ipv4 "${ip_address}"; then
        return 1
    fi

    return 0
}

# Validate location
topdesk_validate_location() {
    local location_name="$1"
    local valid_locations

    # Get list of valid locations
    valid_locations=$(topdesk_get_locations | jq -r '.[].name' 2>/dev/null)

    # Check if location exists
    if printf '%s' "${valid_locations}" | grep -q "^${location_name}$"; then
        return 0
    fi

    return 1
}

# Error handling functions
# -----------------------

# Parse Topdesk error response
topdesk_parse_error() {
    local error_json="$1"

    local error_code=$(json_get "${error_json}" ".errorCode")
    local error_message=$(json_get "${error_json}" ".message")
    local error_details=$(json_get "${error_json}" ".details")

    cat << EOF
{
    "error": {
        "code": "${error_code}",
        "message": "${error_message}",
        "details": "${error_details}",
        "timestamp": "$(timestamp)"
    }
}
EOF
}

# Handle API rate limiting
topdesk_handle_rate_limit() {
    local retry_after="${1:-60}"

    # Log rate limit event
    printf 'Rate limit reached, waiting %d seconds...\n' "${retry_after}" >&2

    # Wait before retry
    sleep "${retry_after}"

    return 0
}