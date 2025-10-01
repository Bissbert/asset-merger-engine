#!/bin/sh
# zbx_cli_wrapper.sh - Zabbix CLI wrapper with enhanced functionality

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/common.sh"
. "${SCRIPT_DIR}/auth_manager.sh" 2>/dev/null || true

# Zabbix-specific configuration
ZBX_TIMEOUT="${ZBX_TIMEOUT:-30}"
ZBX_OUTPUT_FORMAT="${ZBX_OUTPUT_FORMAT:-json}"

# Execute zbx-cli command with proper authentication
zbx_execute() {
    local command="$1"
    shift
    local args="$*"

    # Ensure authentication
    if ! authenticate_zabbix; then
        log_error "Zabbix authentication failed"
        return 1
    fi

    # Get the detected command name
    local zbx_cmd="${ZBX_CLI_COMMAND:-zbx-cli}"

    # Build command
    local full_cmd="$zbx_cmd"

    # Add config file if set
    [ -n "${ZBX_CLI_CONFIG}" ] && full_cmd="${full_cmd} --config '${ZBX_CLI_CONFIG}'"

    # Add output format
    full_cmd="${full_cmd} --output ${ZBX_OUTPUT_FORMAT}"

    # Add timeout (if supported)
    full_cmd="${full_cmd} --timeout ${ZBX_TIMEOUT}"

    # Add command and arguments
    full_cmd="${full_cmd} ${command} ${args}"

    log_debug "Executing: ${full_cmd}"

    # Execute command
    eval "${full_cmd}" 2>&1
}

# Get hosts from a specific group
zbx_get_hosts_by_group() {
    local group="$1"
    local fields="${2:-}"

    log_info "Fetching hosts from Zabbix group: ${group}"

    # Note: Actual zbx-cli syntax may be:
    # zbx-cli show_hosts --hostgroup "groupname"
    # or: zbx-cli host list --filter "groups:[{name:groupname}]"
    local cmd="show_hosts --hostgroup '${group}'"

    # Add field selection if specified (syntax may vary)
    [ -n "${fields}" ] && cmd="${cmd} --select '${fields}'"

    zbx_execute "${cmd}"
}

# Get hosts with specific tag
zbx_get_hosts_by_tag() {
    local tag="$1"
    local value="${2:-}"
    local fields="${3:-}"

    log_info "Fetching hosts from Zabbix with tag: ${tag}${value:+=${value}}"

    # Note: Actual zbx-cli syntax for tags may be:
    # zbx-cli show_hosts --tag "tagname:value"
    local cmd="show_hosts"

    # Add tag filter
    if [ -n "${value}" ]; then
        cmd="${cmd} --tag '${tag}:${value}'"
    else
        cmd="${cmd} --tag '${tag}'"
    fi

    # Add field selection if specified
    [ -n "${fields}" ] && cmd="${cmd} --select '${fields}'"

    zbx_execute "${cmd}"
}

# Get host inventory
zbx_get_host_inventory() {
    local host_id="$1"

    log_debug "Fetching inventory for host: ${host_id}"

    # Note: Actual zbx-cli syntax may be:
    # zbx-cli show_host_inventory <hostname>
    zbx_execute "show_host_inventory '${host_id}'"
}

# Get host interfaces
zbx_get_host_interfaces() {
    local host_id="$1"

    log_debug "Fetching interfaces for host: ${host_id}"

    # Note: Actual zbx-cli syntax may be:
    # zbx-cli show_host_interfaces <hostname>
    zbx_execute "show_host_interfaces '${host_id}'"
}

# Get all host details
zbx_get_host_details() {
    local host_id="$1"
    local temp_file="$(create_temp_file zbx_host)"

    # Get basic host info
    # Note: Actual zbx-cli syntax may be:
    # zbx-cli show_host <hostname>
    local host_info="$(zbx_execute "show_host '${host_id}'")"

    # Get inventory if available
    local inventory="$(zbx_get_host_inventory "${host_id}" 2>/dev/null || echo '{}')"

    # Get interfaces
    local interfaces="$(zbx_get_host_interfaces "${host_id}" 2>/dev/null || echo '[]')"

    # Combine all data
    cat > "${temp_file}" <<EOF
{
  "host": ${host_info},
  "inventory": ${inventory},
  "interfaces": ${interfaces}
}
EOF

    cat "${temp_file}"
    rm -f "${temp_file}"
}

# Batch get hosts with details
zbx_batch_get_hosts() {
    local group="${1:-Topdesk}"
    local include_inventory="${2:-true}"
    local include_interfaces="${3:-true}"

    log_info "Batch fetching hosts from Zabbix"

    # Get initial host list
    local hosts="$(zbx_get_hosts_by_group "${group}")"

    if [ -z "${hosts}" ] || [ "${hosts}" = "[]" ]; then
        log_warning "No hosts found in group: ${group}"
        echo '[]'
        return 0
    fi

    # Process each host if additional details are needed
    if [ "${include_inventory}" = "true" ] || [ "${include_interfaces}" = "true" ]; then
        local enhanced_hosts="[]"
        local host_ids="$(echo "${hosts}" | json_get '.[].hostid')"

        for host_id in ${host_ids}; do
            local host_details="$(zbx_get_host_details "${host_id}")"
            enhanced_hosts="$(json_merge "${enhanced_hosts}" "[${host_details}]")"
        done

        echo "${enhanced_hosts}"
    else
        echo "${hosts}"
    fi
}

# Search hosts by pattern
zbx_search_hosts() {
    local pattern="$1"
    local search_type="${2:-name}"  # name, ip, dns

    log_info "Searching Zabbix hosts: ${pattern} (type: ${search_type})"

    case "${search_type}" in
        name)
            zbx_execute "host list --search '${pattern}'"
            ;;
        ip)
            zbx_execute "host list --filter 'ip:${pattern}'"
            ;;
        dns)
            zbx_execute "host list --filter 'dns:${pattern}'"
            ;;
        *)
            log_error "Unknown search type: ${search_type}"
            return 1
            ;;
    esac
}

# Get hosts with pagination
zbx_get_hosts_paginated() {
    local group="$1"
    local limit="${2:-100}"
    local offset="${3:-0}"

    log_debug "Fetching hosts with pagination: limit=${limit}, offset=${offset}"

    zbx_execute "host list --group '${group}' --limit ${limit} --offset ${offset}"
}

# Export host data to file
zbx_export_hosts() {
    local group="$1"
    local output_file="$2"
    local format="${3:-json}"

    log_info "Exporting Zabbix hosts to: ${output_file}"

    local data="$(zbx_batch_get_hosts "${group}")"

    case "${format}" in
        json)
            echo "${data}" | format_json > "${output_file}"
            ;;
        csv)
            echo "${data}" | python3 -c "
import sys, json, csv
data = json.load(sys.stdin)
if data:
    writer = csv.DictWriter(sys.stdout, fieldnames=data[0].keys())
    writer.writeheader()
    writer.writerows(data)
" > "${output_file}"
            ;;
        *)
            log_error "Unsupported export format: ${format}"
            return 1
            ;;
    esac

    log_info "Export completed: ${output_file}"
}

# Test Zabbix connection
zbx_test_connection() {
    log_info "Testing Zabbix connection"

    if zbx_execute "host list --limit 1" >/dev/null 2>&1; then
        log_info "Zabbix connection successful"
        return 0
    else
        log_error "Zabbix connection failed"
        return 1
    fi
}

# Main function for standalone execution
main() {
    local action="${1:-test}"
    shift

    case "$action" in
        test)
            zbx_test_connection
            ;;
        list-hosts)
            zbx_get_hosts_by_group "$@"
            ;;
        list-by-tag)
            zbx_get_hosts_by_tag "$@"
            ;;
        host-details)
            zbx_get_host_details "$@"
            ;;
        batch-get)
            zbx_batch_get_hosts "$@"
            ;;
        search)
            zbx_search_hosts "$@"
            ;;
        export)
            zbx_export_hosts "$@"
            ;;
        *)
            echo "Usage: $0 {test|list-hosts|list-by-tag|host-details|batch-get|search|export} [options]" >&2
            exit 1
            ;;
    esac
}

# Run main if executed directly
if [ "${0##*/}" = "zbx_cli_wrapper.sh" ]; then
    main "$@"
fi