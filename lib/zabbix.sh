#!/bin/sh
# zabbix.sh - Zabbix-specific functions for topdesk-zbx-merger
# POSIX-compliant library for Zabbix operations

# Source common library
. "$(dirname "$0")/../lib/common.sh" 2>/dev/null || true

# Zabbix API functions
# --------------------

# Initialize Zabbix connection
zabbix_init() {
    local url="${1:-${ZABBIX_URL}}"
    local user="${2:-${ZABBIX_USER}}"
    local password="${3:-${ZABBIX_PASSWORD}}"

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

# Get Zabbix authentication token
zabbix_auth() {
    local url="${1:-${ZABBIX_URL}}"
    local user="${2:-${ZABBIX_USER}}"
    local password="${3:-${ZABBIX_PASSWORD}}"

    # Check for cached token
    local cached_token
    if cached_token=$(cache_get "zabbix_token" 3600); then
        printf '%s' "${cached_token}"
        return 0
    fi

    # Request new token via zbx
    local token
    token=$(zbx --url "${url}" --user "${user}" --password "${password}" auth 2>/dev/null)

    if [ -n "${token}" ]; then
        cache_set "zabbix_token" "${token}"
        printf '%s' "${token}"
        return 0
    fi

    return 1
}

# Fetch hosts from Zabbix
zabbix_get_hosts() {
    local group_filter="${1}"
    local tag_filter="${2}"
    local output_format="${3:-json}"

    local cmd="zbx host list"

    # Add filters if provided
    [ -n "${group_filter}" ] && cmd="${cmd} --group '${group_filter}'"
    [ -n "${tag_filter}" ] && cmd="${cmd} --tag '${tag_filter}'"
    [ -n "${output_format}" ] && cmd="${cmd} --format '${output_format}'"

    # Execute command and return output
    eval "${cmd}" 2>/dev/null
}

# Get host details
zabbix_get_host_details() {
    local host_id="$1"

    if [ -z "${host_id}" ]; then
        return 1
    fi

    zbx host get --id "${host_id}" --format json 2>/dev/null
}

# Get host inventory
zabbix_get_inventory() {
    local host_id="$1"

    if [ -z "${host_id}" ]; then
        return 1
    fi

    zbx inventory get --host "${host_id}" --format json 2>/dev/null
}

# Get host interfaces
zabbix_get_interfaces() {
    local host_id="$1"

    if [ -z "${host_id}" ]; then
        return 1
    fi

    zbx interface list --host "${host_id}" --format json 2>/dev/null
}

# Get host groups
zabbix_get_groups() {
    zbx group list --format json 2>/dev/null
}

# Get host templates
zabbix_get_templates() {
    local host_id="$1"

    if [ -z "${host_id}" ]; then
        zbx template list --format json 2>/dev/null
    else
        zbx template list --host "${host_id}" --format json 2>/dev/null
    fi
}

# Zabbix data extraction functions
# --------------------------------

# Extract asset information from host data
zabbix_extract_asset() {
    local host_json="$1"

    # Extract relevant fields
    local host_id=$(json_get "${host_json}" ".hostid")
    local hostname=$(json_get "${host_json}" ".host")
    local name=$(json_get "${host_json}" ".name")
    local status=$(json_get "${host_json}" ".status")

    # Build asset JSON
    cat << EOF
{
    "asset_id": "${host_id}",
    "hostname": "${hostname}",
    "display_name": "${name}",
    "monitoring_status": "${status}"
}
EOF
}

# Extract network information
zabbix_extract_network() {
    local interface_json="$1"

    local ip=$(json_get "${interface_json}" ".ip")
    local dns=$(json_get "${interface_json}" ".dns")
    local port=$(json_get "${interface_json}" ".port")
    local type=$(json_get "${interface_json}" ".type")

    cat << EOF
{
    "ip_address": "${ip}",
    "dns_name": "${dns}",
    "port": "${port}",
    "interface_type": "${type}"
}
EOF
}

# Extract inventory information
zabbix_extract_inventory() {
    local inventory_json="$1"

    # Common inventory fields
    local asset_tag=$(json_get "${inventory_json}" ".asset_tag")
    local serial_no=$(json_get "${inventory_json}" ".serialno_a")
    local location=$(json_get "${inventory_json}" ".location")
    local contact=$(json_get "${inventory_json}" ".poc_1_email")
    local vendor=$(json_get "${inventory_json}" ".vendor")
    local model=$(json_get "${inventory_json}" ".model")
    local os=$(json_get "${inventory_json}" ".os")

    cat << EOF
{
    "asset_tag": "${asset_tag}",
    "serial_number": "${serial_no}",
    "location": "${location}",
    "contact_email": "${contact}",
    "vendor": "${vendor}",
    "model": "${model}",
    "operating_system": "${os}"
}
EOF
}

# Zabbix data transformation functions
# ------------------------------------

# Transform Zabbix host to Topdesk asset format
zabbix_to_topdesk_asset() {
    local host_data="$1"
    local inventory_data="$2"
    local interface_data="$3"

    # Extract data from each source
    local host_info=$(zabbix_extract_asset "${host_data}")
    local inventory_info=$(zabbix_extract_inventory "${inventory_data}")
    local network_info=$(zabbix_extract_network "${interface_data}")

    # Merge all information
    local merged_data=$(json_merge "${host_info}" "${inventory_info}")
    merged_data=$(json_merge "${merged_data}" "${network_info}")

    # Map to Topdesk fields
    cat << EOF
{
    "id": $(json_get "${merged_data}" ".asset_id"),
    "name": $(json_get "${merged_data}" ".hostname"),
    "specification": $(json_get "${merged_data}" ".display_name"),
    "serialNumber": $(json_get "${merged_data}" ".serial_number"),
    "ipAddress": $(json_get "${merged_data}" ".ip_address"),
    "locationName": $(json_get "${merged_data}" ".location"),
    "brand": $(json_get "${merged_data}" ".vendor"),
    "model": $(json_get "${merged_data}" ".model"),
    "operatingSystem": $(json_get "${merged_data}" ".operating_system"),
    "email": $(json_get "${merged_data}" ".contact_email"),
    "customFields": {
        "zabbixHostId": $(json_get "${merged_data}" ".asset_id"),
        "zabbixMonitoring": $(json_get "${merged_data}" ".monitoring_status"),
        "lastSync": "$(timestamp)"
    }
}
EOF
}

# Batch processing functions
# -------------------------

# Process hosts in batches
zabbix_process_batch() {
    local batch_size="${1:-100}"
    local process_function="${2:-zabbix_to_topdesk_asset}"
    local input_file="${3:-/dev/stdin}"
    local output_file="${4:-/dev/stdout}"

    local count=0
    local batch_data="["

    while IFS= read -r line; do
        if [ ${count} -gt 0 ]; then
            batch_data="${batch_data},"
        fi
        batch_data="${batch_data}${line}"
        count=$((count + 1))

        if [ ${count} -ge ${batch_size} ]; then
            printf '%s]' "${batch_data}" | ${process_function} >> "${output_file}"
            count=0
            batch_data="["
        fi
    done < "${input_file}"

    # Process remaining items
    if [ ${count} -gt 0 ]; then
        printf '%s]' "${batch_data}" | ${process_function} >> "${output_file}"
    fi
}

# Validation functions
# -------------------

# Validate Zabbix host data
zabbix_validate_host() {
    local host_json="$1"

    # Check required fields
    local host_id=$(json_get "${host_json}" ".hostid")
    local hostname=$(json_get "${host_json}" ".host")

    if [ -z "${host_id}" ] || [ -z "${hostname}" ]; then
        return 1
    fi

    # Validate hostname format
    if ! is_valid_hostname "${hostname}"; then
        return 1
    fi

    return 0
}

# Validate Zabbix interface data
zabbix_validate_interface() {
    local interface_json="$1"

    local ip=$(json_get "${interface_json}" ".ip")

    if [ -n "${ip}" ] && ! is_valid_ipv4 "${ip}"; then
        return 1
    fi

    return 0
}