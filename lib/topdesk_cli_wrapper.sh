#!/bin/sh
# topdesk_cli_wrapper.sh - Topdesk CLI wrapper with enhanced functionality

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/common.sh"
. "${SCRIPT_DIR}/auth_manager.sh" 2>/dev/null || true

# Topdesk-specific configuration
TD_TIMEOUT="${TD_TIMEOUT:-30}"
TD_OUTPUT_FORMAT="${TD_OUTPUT_FORMAT:-json}"
TD_PAGE_SIZE="${TD_PAGE_SIZE:-100}"

# Execute topdesk-cli command with proper authentication
td_execute() {
    local command="$1"
    shift
    local args="$*"

    # Ensure authentication
    if ! authenticate_topdesk; then
        log_error "Topdesk authentication failed"
        return 1
    fi

    # Get the detected command name
    local td_cmd="${TOPDESK_CLI_COMMAND:-topdesk-cli}"

    # Build command
    local full_cmd="$td_cmd"

    # Add config file if set
    [ -n "${TOPDESK_CLI_CONFIG}" ] && full_cmd="${full_cmd} --config '${TOPDESK_CLI_CONFIG}'"

    # Add output format (if supported)
    full_cmd="${full_cmd} --output ${TD_OUTPUT_FORMAT}"

    # Add timeout (if supported)
    full_cmd="${full_cmd} --timeout ${TD_TIMEOUT}"

    # Add command and arguments
    full_cmd="${full_cmd} ${command} ${args}"

    log_debug "Executing: ${full_cmd}"

    # Execute command
    eval "${full_cmd}" 2>&1
}

# Get assets with optional filter
td_get_assets() {
    local filter="${1:-}"
    local fields="${2:-}"
    local limit="${3:-${TD_PAGE_SIZE}}"

    log_info "Fetching assets from Topdesk${filter:+ (filter: ${filter})}"

    # Note: Actual topdesk-cli syntax may vary
    # Common patterns: topdesk asset list, topdesk-cli list-assets
    local cmd="asset list"

    # Add filter if specified (syntax may vary)
    [ -n "${filter}" ] && cmd="${cmd} --filter '${filter}'"

    # Add field selection if specified
    [ -n "${fields}" ] && cmd="${cmd} --fields '${fields}'"

    # Add limit
    [ -n "${limit}" ] && cmd="${cmd} --limit ${limit}"

    td_execute "${cmd}"
}

# Get asset by ID
td_get_asset_by_id() {
    local asset_id="$1"

    log_debug "Fetching asset: ${asset_id}"

    # Note: Actual topdesk-cli syntax may be:
    # topdesk asset get <id> or topdesk-cli get-asset --id <id>
    td_execute "asset get '${asset_id}'"
}

# Search assets
td_search_assets() {
    local query="$1"
    local search_field="${2:-name}"

    log_info "Searching Topdesk assets: ${query} (field: ${search_field})"

    # Note: Actual topdesk-cli syntax may be:
    # topdesk asset search <query> or topdesk-cli search-assets --query <query>
    td_execute "asset search --query '${query}' --field '${search_field}'"
}

# Get assets by type
td_get_assets_by_type() {
    local type="$1"
    local limit="${2:-${TD_PAGE_SIZE}}"

    log_info "Fetching assets of type: ${type}"

    # Note: Actual topdesk-cli syntax may vary
    td_execute "asset list --type '${type}' --limit ${limit}"
}

# Get assets with pagination
td_get_assets_paginated() {
    local page="${1:-1}"
    local page_size="${2:-${TD_PAGE_SIZE}}"
    local filter="${3:-}"

    local offset=$(((page - 1) * page_size))

    log_debug "Fetching assets page ${page} (size: ${page_size}, offset: ${offset})"

    local cmd="asset list --limit ${page_size} --offset ${offset}"
    [ -n "${filter}" ] && cmd="${cmd} --filter '${filter}'"

    td_execute "${cmd}"
}

# Get all assets (handling pagination automatically)
td_get_all_assets() {
    local filter="${1:-}"
    local max_pages="${2:-100}"
    local temp_file="$(create_temp_file td_assets)"

    log_info "Fetching all assets from Topdesk"

    echo '[]' > "${temp_file}"
    local page=1
    local has_more=true

    while [ "${has_more}" = "true" ] && [ ${page} -le ${max_pages} ]; do
        log_debug "Fetching page ${page}"

        local page_data="$(td_get_assets_paginated ${page} ${TD_PAGE_SIZE} "${filter}")"

        if [ -z "${page_data}" ] || [ "${page_data}" = "[]" ]; then
            has_more=false
        else
            # Merge with existing data
            local current="$(cat "${temp_file}")"
            echo "${current}" | python3 -c "
import sys, json
current = json.load(sys.stdin)
new_data = ${page_data}
current.extend(new_data)
print(json.dumps(current))
" > "${temp_file}.new"
            mv "${temp_file}.new" "${temp_file}"

            # Check if we got a full page
            local count="$(echo "${page_data}" | python3 -c "import sys, json; print(len(json.load(sys.stdin)))")"
            [ ${count} -lt ${TD_PAGE_SIZE} ] && has_more=false
        fi

        page=$((page + 1))
    done

    cat "${temp_file}"
    rm -f "${temp_file}"
}

# Get asset locations
td_get_locations() {
    log_info "Fetching Topdesk locations"

    # Note: Actual topdesk-cli syntax may be:
    # topdesk location list or topdesk-cli list-locations
    td_execute "location list"
}

# Get asset branches
td_get_branches() {
    log_info "Fetching Topdesk branches"

    # Note: Actual topdesk-cli syntax may be:
    # topdesk branch list or topdesk-cli list-branches
    td_execute "branch list"
}

# Get asset types
td_get_asset_types() {
    log_info "Fetching Topdesk asset types"

    # Note: Actual topdesk-cli syntax may be:
    # topdesk asset-type list or topdesk-cli list-asset-types
    td_execute "asset-type list"
}

# Batch get assets with details
td_batch_get_assets() {
    local filter="${1:-}"
    local include_specifications="${2:-true}"

    log_info "Batch fetching assets from Topdesk"

    # Get all assets
    local assets="$(td_get_all_assets "${filter}")"

    if [ -z "${assets}" ] || [ "${assets}" = "[]" ]; then
        log_warning "No assets found${filter:+ with filter: ${filter}}"
        echo '[]'
        return 0
    fi

    # Process each asset if additional details are needed
    if [ "${include_specifications}" = "true" ]; then
        local enhanced_assets="[]"
        local asset_ids="$(echo "${assets}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data:
    print(item.get('id', item.get('unid', '')))
")"

        for asset_id in ${asset_ids}; do
            [ -z "${asset_id}" ] && continue
            local asset_details="$(td_get_asset_by_id "${asset_id}")"
            enhanced_assets="$(echo "${enhanced_assets}" | python3 -c "
import sys, json
current = json.load(sys.stdin)
new_asset = ${asset_details}
current.append(new_asset)
print(json.dumps(current))
")"
        done

        echo "${enhanced_assets}"
    else
        echo "${assets}"
    fi
}

# Export asset data to file
td_export_assets() {
    local filter="${1:-}"
    local output_file="$2"
    local format="${3:-json}"

    log_info "Exporting Topdesk assets to: ${output_file}"

    local data="$(td_batch_get_assets "${filter}")"

    case "${format}" in
        json)
            echo "${data}" | python3 -m json.tool > "${output_file}"
            ;;
        csv)
            echo "${data}" | python3 -c "
import sys, json, csv

def flatten_dict(d, parent_key='', sep='_'):
    items = []
    for k, v in d.items():
        new_key = f'{parent_key}{sep}{k}' if parent_key else k
        if isinstance(v, dict):
            items.extend(flatten_dict(v, new_key, sep=sep).items())
        else:
            items.append((new_key, v))
    return dict(items)

data = json.load(sys.stdin)
if data:
    # Flatten nested structures
    flat_data = [flatten_dict(item) for item in data]

    # Get all unique keys
    all_keys = set()
    for item in flat_data:
        all_keys.update(item.keys())

    writer = csv.DictWriter(sys.stdout, fieldnames=sorted(all_keys))
    writer.writeheader()
    writer.writerows(flat_data)
" > "${output_file}"
            ;;
        *)
            log_error "Unsupported export format: ${format}"
            return 1
            ;;
    esac

    log_info "Export completed: ${output_file}"
}

# Get asset statistics
td_get_asset_stats() {
    local filter="${1:-}"

    log_info "Getting Topdesk asset statistics"

    local assets="$(td_get_all_assets "${filter}")"

    echo "${assets}" | python3 -c "
import sys, json
from collections import Counter

data = json.load(sys.stdin)
stats = {
    'total_count': len(data),
    'by_type': Counter(item.get('type', 'Unknown') for item in data),
    'by_status': Counter(item.get('status', 'Unknown') for item in data),
    'by_location': Counter(item.get('location', 'Unknown') for item in data)
}

print(json.dumps(stats, indent=2, default=str))
"
}

# Test Topdesk connection
td_test_connection() {
    log_info "Testing Topdesk connection"

    if td_execute "assets list --limit 1" >/dev/null 2>&1; then
        log_info "Topdesk connection successful"
        return 0
    else
        log_error "Topdesk connection failed"
        return 1
    fi
}

# Sync assets to cache
td_sync_to_cache() {
    local cache_dir="${CACHE_DIR:-/tmp/asset-merger-engine/cache}"
    local filter="${1:-}"

    log_info "Syncing Topdesk assets to cache"

    ensure_dir "${cache_dir}"

    local assets="$(td_get_all_assets "${filter}")"
    local cache_file="${cache_dir}/topdesk_assets_$(date +%Y%m%d_%H%M%S).json"

    echo "${assets}" > "${cache_file}"

    # Create symlink to latest
    ln -sf "$(basename "${cache_file}")" "${cache_dir}/topdesk_assets_latest.json"

    log_info "Assets cached to: ${cache_file}"
    echo "${cache_file}"
}

# Main function for standalone execution
main() {
    local action="${1:-test}"
    shift

    case "$action" in
        test)
            td_test_connection
            ;;
        list)
            td_get_assets "$@"
            ;;
        get)
            td_get_asset_by_id "$@"
            ;;
        search)
            td_search_assets "$@"
            ;;
        all)
            td_get_all_assets "$@"
            ;;
        batch)
            td_batch_get_assets "$@"
            ;;
        export)
            td_export_assets "$@"
            ;;
        stats)
            td_get_asset_stats "$@"
            ;;
        sync)
            td_sync_to_cache "$@"
            ;;
        locations)
            td_get_locations
            ;;
        branches)
            td_get_branches
            ;;
        types)
            td_get_asset_types
            ;;
        *)
            echo "Usage: $0 {test|list|get|search|all|batch|export|stats|sync|locations|branches|types} [options]" >&2
            exit 1
            ;;
    esac
}

# Run main if executed directly
if [ "${0##*/}" = "topdesk_cli_wrapper.sh" ]; then
    main "$@"
fi