#!/bin/sh
# datafetcher.sh - Data retrieval module for asset-merger-engine
# Fetches asset information from Zabbix and Topdesk systems

# Source dependencies (use LIB_DIR from parent script)
. "${LIB_DIR:-$(dirname "$0")}/common.sh" 2>/dev/null || true

# Configuration
CACHE_DIR="${CACHE_DIR:-/tmp/asset-merger-engine/cache}"
CACHE_TTL="${CACHE_TTL:-300}"  # Cache TTL in seconds (5 minutes)
MAX_RETRIES="${MAX_RETRIES:-3}"
RETRY_DELAY="${RETRY_DELAY:-2}"
LOG_FILE="${LOG_FILE:-/tmp/asset-merger-engine/merger.log}"

# Initialize cache directory
init_cache() {
    mkdir -p "$CACHE_DIR" || {
        log_error "Failed to create cache directory: $CACHE_DIR"
        return 1
    }
}

# Check if cache is valid
is_cache_valid() {
    local cache_file="$1"
    local current_time=$(date +%s)

    [ ! -f "$cache_file" ] && return 1

    local file_time=$(stat -f %m "$cache_file" 2>/dev/null || stat -c %Y "$cache_file" 2>/dev/null)
    [ -z "$file_time" ] && return 1

    local age=$((current_time - file_time))
    [ "$age" -lt "$CACHE_TTL" ]
}

# Generic retry logic
retry_command() {
    local cmd="$1"
    local description="$2"
    local attempts=0
    local output=""
    local delay="$RETRY_DELAY"

    while [ "$attempts" -lt "$MAX_RETRIES" ]; do
        attempts=$((attempts + 1))
        log_debug "Attempting $description (attempt $attempts/$MAX_RETRIES)"

        if output=$(eval "$cmd" 2>&1); then
            echo "$output"
            return 0
        fi

        log_warning "$description failed (attempt $attempts/$MAX_RETRIES): $output"

        if [ "$attempts" -lt "$MAX_RETRIES" ]; then
            log_debug "Retrying in $delay seconds..."
            sleep "$delay"
            delay=$((delay * 2))  # Exponential backoff
        fi
    done

    log_error "$description failed after $MAX_RETRIES attempts"
    return 1
}

# Fetch data from Zabbix
fetch_zabbix_assets() {
    local group="${1:-Topdesk}"
    local cache_file="$CACHE_DIR/zabbix_assets_$(echo "$group" | tr ' /' '__').json"

    # Check cache
    if is_cache_valid "$cache_file"; then
        log_debug "Using cached Zabbix data from $cache_file"
        cat "$cache_file"
        return 0
    fi

    log_info "Fetching assets from Zabbix (group: $group)"

    # Build zbx call command for getting hosts in a group using JSON-RPC API
    local cmd="echo '{\"selectGroups\":\"extend\",\"selectInterfaces\":\"extend\",\"selectInventory\":\"extend\",\"filter\":{\"groups\":[\"'\"$group\"'\"]}}' | zbx call host.get"

    # Execute with retry logic
    local raw_output
    if ! raw_output=$(retry_command "$cmd" "Zabbix asset retrieval"); then
        return 1
    fi

    # Debug: Log raw output details
    log_debug "Raw Zabbix output length: ${#raw_output} bytes"
    if [ -n "${DEBUG}" ]; then
        # Save raw output to temp file for debugging
        local debug_file="${CACHE_DIR}/.zbx_raw_output_$$.txt"
        printf '%s' "$raw_output" > "$debug_file"
        log_debug "Saved raw zbx output to: $debug_file"

        # Show first 500 chars with control characters visible
        log_debug "First 500 chars of raw output:"
        printf '%s' "$raw_output" | head -c 500 | cat -v >&2
    fi

    # Strip ANSI color codes and control characters from zbx output
    raw_output=$(echo "$raw_output" | sed $'s/\x1b\[[0-9;]*m//g')
    log_debug "Stripped ANSI codes, new length: ${#raw_output} bytes"

    # Parse and normalize Zabbix output
    local normalized_output
    normalized_output=$(printf '%s' "$raw_output" | normalize_zabbix_data)

    if [ -z "$normalized_output" ] || [ "$normalized_output" = "[]" ]; then
        log_warning "No assets found in Zabbix group: $group"
        echo '{"source":"zabbix","timestamp":"'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'","assets":[]}'
        return 0
    fi

    # Cache the result
    printf '%s\n' "$normalized_output" > "$cache_file"
    log_debug "Cached Zabbix data to $cache_file"

    echo "$normalized_output"
}

# Normalize Zabbix data
normalize_zabbix_data() {
    python3 -c '
import sys
import json
from datetime import datetime

try:
    raw_data = sys.stdin.read()
    if not raw_data:
        print(json.dumps({"source": "zabbix", "timestamp": datetime.utcnow().isoformat() + "Z", "assets": []}))
        sys.exit(0)

    data = json.loads(raw_data)

    # Handle different zbx-cli output formats
    if isinstance(data, dict):
        if "result" in data:
            hosts = data["result"]
        elif "hosts" in data:
            hosts = data["hosts"]
        else:
            hosts = []
    elif isinstance(data, list):
        hosts = data
    else:
        hosts = []

    normalized_assets = []
    for host in hosts:
        # Extract host information
        asset = {
            "asset_id": host.get("hostid", ""),
            "fields": {
                "name": host.get("host", ""),
                "display_name": host.get("name", ""),
                "status": "enabled" if host.get("status", "0") == "0" else "disabled",
                "description": host.get("description", ""),
                "inventory": {}
            }
        }

        # Add inventory fields if present
        if "inventory" in host and isinstance(host["inventory"], dict):
            for key, value in host["inventory"].items():
                if value:  # Only include non-empty values
                    asset["fields"]["inventory"][key] = value

        # Add interfaces if present
        if "interfaces" in host:
            interfaces = []
            for iface in host["interfaces"]:
                interfaces.append({
                    "type": iface.get("type", ""),
                    "ip": iface.get("ip", ""),
                    "dns": iface.get("dns", ""),
                    "port": iface.get("port", "")
                })
            asset["fields"]["interfaces"] = interfaces

        normalized_assets.append(asset)

    result = {
        "source": "zabbix",
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "assets": normalized_assets
    }

    print(json.dumps(result, indent=2))

except json.JSONDecodeError as e:
    import sys
    # Print raw data sample to stderr for debugging
    print(f"[ERROR] JSON Parse Error at line {e.lineno}, column {e.colno}", file=sys.stderr)
    print(f"[ERROR] First 1000 chars of raw input:", file=sys.stderr)
    print(raw_data[:1000], file=sys.stderr)
    print(json.dumps({
        "source": "zabbix",
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "assets": [],
        "error": f"Failed to parse JSON at line {e.lineno}, col {e.colno}: {str(e)}"
    }))
except Exception as e:
    print(json.dumps({
        "source": "zabbix",
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "assets": [],
        "error": str(e)
    }))
' 2>/dev/null || echo '{"source":"zabbix","timestamp":"'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'","assets":[],"error":"Python parsing failed"}'
}

# Fetch data from Topdesk
fetch_topdesk_assets() {
    local filter="${1:-}"
    local cache_key=$(echo "${filter:-all}" | tr ' /' '__')
    local cache_file="$CACHE_DIR/topdesk_assets_${cache_key}.json"

    # Check cache
    if is_cache_valid "$cache_file"; then
        log_debug "Using cached Topdesk data from $cache_file"
        cat "$cache_file"
        return 0
    fi

    log_info "Fetching assets from Topdesk${filter:+ (filter: $filter)}"

    # Build topdesk command
    # The topdesk-cli now handles its own configuration
    local cmd="topdesk asset list --output json"
    [ -n "$filter" ] && cmd="$cmd --query '$filter'"

    # Execute with retry logic
    local raw_output
    if ! raw_output=$(retry_command "$cmd" "Topdesk asset retrieval"); then
        return 1
    fi

    # Parse and normalize Topdesk output
    local normalized_output
    normalized_output=$(echo "$raw_output" | normalize_topdesk_data)

    if [ -z "$normalized_output" ] || [ "$normalized_output" = "[]" ]; then
        log_warning "No assets found in Topdesk${filter:+ with filter: $filter}"
        echo '{"source":"topdesk","timestamp":"'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'","assets":[]}'
        return 0
    fi

    # Cache the result
    echo "$normalized_output" > "$cache_file"
    log_debug "Cached Topdesk data to $cache_file"

    echo "$normalized_output"
}

# Normalize Topdesk data
normalize_topdesk_data() {
    python3 -c '
import sys
import json
from datetime import datetime

try:
    raw_data = sys.stdin.read()
    if not raw_data:
        print(json.dumps({"source": "topdesk", "timestamp": datetime.utcnow().isoformat() + "Z", "assets": []}))
        sys.exit(0)

    data = json.loads(raw_data)

    # Handle different topdesk-cli output formats
    if isinstance(data, dict):
        if "assets" in data:
            assets = data["assets"]
        elif "items" in data:
            assets = data["items"]
        elif "result" in data:
            assets = data["result"]
        else:
            assets = []
    elif isinstance(data, list):
        assets = data
    else:
        assets = []

    normalized_assets = []
    for asset in assets:
        # Extract asset information
        normalized = {
            "asset_id": asset.get("id", asset.get("unid", "")),
            "fields": {
                "name": asset.get("name", ""),
                "type": asset.get("type", asset.get("assetType", "")),
                "status": asset.get("status", ""),
                "location": asset.get("location", ""),
                "branch": asset.get("branch", {}).get("name", "") if isinstance(asset.get("branch"), dict) else asset.get("branch", ""),
                "specifications": {}
            }
        }

        # Add specifications/custom fields
        if "specifications" in asset:
            for key, value in asset["specifications"].items():
                if value:  # Only include non-empty values
                    normalized["fields"]["specifications"][key] = value

        # Add other relevant fields
        for field in ["serialNumber", "purchaseDate", "warrantyExpiryDate", "ipAddress", "macAddress"]:
            if field in asset and asset[field]:
                normalized["fields"][field] = asset[field]

        normalized_assets.append(normalized)

    result = {
        "source": "topdesk",
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "assets": normalized_assets
    }

    print(json.dumps(result, indent=2))

except json.JSONDecodeError as e:
    print(json.dumps({
        "source": "topdesk",
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "assets": [],
        "error": f"Failed to parse JSON: {str(e)}"
    }))
except Exception as e:
    print(json.dumps({
        "source": "topdesk",
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "assets": [],
        "error": str(e)
    }))
' 2>/dev/null || echo '{"source":"topdesk","timestamp":"'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'","assets":[],"error":"Python parsing failed"}'
}

# Fetch all data (both systems)
fetch_all_assets() {
    local zabbix_group="${1:-Topdesk}"
    local topdesk_filter="${2:-}"

    log_info "Fetching assets from both systems"

    # Fetch from both systems in parallel if possible
    local zabbix_data=""
    local topdesk_data=""
    local zabbix_pid=""
    local topdesk_pid=""

    # Start background fetches
    {
        fetch_zabbix_assets "$zabbix_group" > "$CACHE_DIR/.zabbix_fetch.tmp"
    } &
    zabbix_pid=$!

    {
        fetch_topdesk_assets "$topdesk_filter" > "$CACHE_DIR/.topdesk_fetch.tmp"
    } &
    topdesk_pid=$!

    # Wait for both to complete
    local zabbix_success=0
    local topdesk_success=0

    if wait "$zabbix_pid"; then
        zabbix_data=$(cat "$CACHE_DIR/.zabbix_fetch.tmp")
        zabbix_success=1
        rm -f "$CACHE_DIR/.zabbix_fetch.tmp"
    else
        log_error "Failed to fetch Zabbix data"
    fi

    if wait "$topdesk_pid"; then
        topdesk_data=$(cat "$CACHE_DIR/.topdesk_fetch.tmp")
        topdesk_success=1
        rm -f "$CACHE_DIR/.topdesk_fetch.tmp"
    else
        log_error "Failed to fetch Topdesk data"
    fi

    # Combine results
    if [ "$zabbix_success" -eq 1 ] && [ "$topdesk_success" -eq 1 ]; then
        echo '{"zabbix":'$zabbix_data',"topdesk":'$topdesk_data'}'
        return 0
    elif [ "$zabbix_success" -eq 1 ]; then
        echo '{"zabbix":'$zabbix_data',"topdesk":null}'
        return 1
    elif [ "$topdesk_success" -eq 1 ]; then
        echo '{"zabbix":null,"topdesk":'$topdesk_data'}'
        return 1
    else
        echo '{"zabbix":null,"topdesk":null,"error":"Failed to fetch data from both systems"}'
        return 1
    fi
}

# Clear cache
clear_cache() {
    log_info "Clearing cache directory: $CACHE_DIR"
    rm -rf "$CACHE_DIR"/*.json "$CACHE_DIR"/.*.tmp 2>/dev/null
    log_info "Cache cleared"
}

# Validate CLI tools availability
validate_tools() {
    local missing_tools=""
    local zbx_cmd=""
    local td_cmd=""

    # Check for zbx command
    if command -v zbx >/dev/null 2>&1; then
        zbx_cmd="zbx"
        export ZBX_CLI_COMMAND="zbx"
    fi

    if [ -z "$zbx_cmd" ]; then
        missing_tools="${missing_tools}zbx "
        log_warning "zbx command not found in PATH"
    else
        log_debug "Found zbx command: $zbx_cmd"
    fi

    # Check for topdesk command
    if command -v topdesk >/dev/null 2>&1; then
        td_cmd="topdesk"
        export TOPDESK_CLI_COMMAND="topdesk"

        # Validate topdesk configuration
        if topdesk config validate >/dev/null 2>&1; then
            log_debug "Topdesk configuration validated successfully"
        else
            log_warning "Topdesk configuration not initialized. Run 'topdesk config init' to configure"
            missing_tools="${missing_tools}topdesk-config "
        fi
    else
        missing_tools="${missing_tools}topdesk "
        log_warning "topdesk command not found in PATH"
    fi

    if [ -n "$td_cmd" ]; then
        log_debug "Found topdesk command: $td_cmd"
    fi

    if ! command -v python3 >/dev/null 2>&1; then
        missing_tools="${missing_tools}python3 "
    fi

    # Check if mock mode is enabled
    if [ "$MOCK_MODE" = "true" ]; then
        log_info "Running in MOCK mode - CLI tools not required"
        return 0
    fi

    if [ -n "$missing_tools" ]; then
        log_error "Missing required tools: $missing_tools"
        echo "" >&2
        echo "Make sure zbx and topdesk commands are in your PATH" >&2
        echo "" >&2
        echo "To run in mock mode for testing: export MOCK_MODE=true" >&2
        return 1
    fi

    return 0
}

# Main function for standalone execution
main() {
    local action="${1:-fetch}"
    shift

    # Initialize
    init_cache || exit 1

    case "$action" in
        fetch|fetch-all)
            validate_tools || exit 1
            fetch_all_assets "$@"
            ;;
        zabbix)
            validate_tools || exit 1
            fetch_zabbix_assets "$@"
            ;;
        topdesk)
            validate_tools || exit 1
            fetch_topdesk_assets "$@"
            ;;
        clear-cache)
            clear_cache
            ;;
        validate)
            validate_tools
            ;;
        *)
            echo "Usage: $0 {fetch|zabbix|topdesk|clear-cache|validate} [options]" >&2
            echo "  fetch [zabbix_group] [topdesk_filter] - Fetch from both systems" >&2
            echo "  zabbix [group]                        - Fetch from Zabbix only" >&2
            echo "  topdesk [filter]                      - Fetch from Topdesk only" >&2
            echo "  clear-cache                           - Clear all cached data" >&2
            echo "  validate                              - Validate tool availability" >&2
            exit 1
            ;;
    esac
}

# Run main if executed directly
if [ "${0##*/}" = "datafetcher.sh" ]; then
    main "$@"
fi