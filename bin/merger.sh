#!/bin/sh
# asset-merger-engine - Main orchestration script
# Integrates all components for Zabbix-Topdesk asset synchronization
# Version: 3.0.0
# POSIX-compliant production-ready implementation
#
# Copyright (c) 2025 Bissbert
# Licensed under the MIT License - see LICENSE file for details

set -e  # Exit on error
set -u  # Exit on undefined variable

# Script metadata
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Detect if we're running from an installed location or development
# This will be replaced during installation by sed
if [ -f "${SCRIPT_DIR}/../VERSION" ]; then
    # Development mode - running from source tree
    readonly SCRIPT_VERSION="$(cat "${SCRIPT_DIR}/../VERSION" 2>/dev/null || echo "3.0.0")"
    readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
elif [ -f "${SCRIPT_DIR}/../lib/asset-merger-engine/VERSION" ]; then
    # Installed in user or system location
    readonly SCRIPT_VERSION="$(cat "${SCRIPT_DIR}/../lib/asset-merger-engine/VERSION" 2>/dev/null || echo "3.0.0")"
    readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
else
    # Fallback for edge cases
    readonly SCRIPT_VERSION="3.0.0"
    readonly PROJECT_ROOT="${SCRIPT_DIR}/.."
fi

# Component paths
readonly LIB_DIR="${PROJECT_ROOT}/lib"
readonly BIN_DIR="${PROJECT_ROOT}/bin"
readonly ETC_DIR="${PROJECT_ROOT}/etc"

# Determine runtime directories based on installation type
# Check if this is a system-wide installation
if [ "${LIB_DIR}" = "/usr/local/lib/asset-merger-engine" ] || \
   [ "${LIB_DIR}" = "/usr/lib/asset-merger-engine" ] || \
   [ "${LIB_DIR}" = "/opt/asset-merger-engine/lib" ] || \
   [ -n "${SYSTEM_INSTALL:-}" ]; then
    # System-wide installation - use user-specific directories following XDG spec
    readonly VAR_DIR="${HOME}/.local/share/asset-merger-engine"
    readonly OUTPUT_DIR="${HOME}/.local/share/asset-merger-engine/output"
    readonly TMP_DIR="${HOME}/.cache/asset-merger-engine/tmp"
    readonly DEFAULT_CONFIG_FILE="${HOME}/.config/asset-merger-engine/merger.conf"
    readonly DEFAULT_LOG_DIR="${HOME}/.local/state/asset-merger-engine/logs"
    readonly DEFAULT_CACHE_DIR="${HOME}/.cache/asset-merger-engine"
    readonly DEFAULT_RUN_DIR="${HOME}/.local/state/asset-merger-engine/run"
    readonly SYSTEM_CONFIG_TEMPLATE="${ETC_DIR}/merger.conf"
else
    # User installation or development mode - use configured paths
    readonly VAR_DIR="${PROJECT_ROOT}/var"
    readonly OUTPUT_DIR="${PROJECT_ROOT}/output"
    readonly TMP_DIR="${PROJECT_ROOT}/tmp"
    readonly DEFAULT_CONFIG_FILE="${ETC_DIR}/merger.conf"
    readonly DEFAULT_LOG_DIR="${VAR_DIR}/log"
    readonly DEFAULT_CACHE_DIR="${VAR_DIR}/cache"
    readonly DEFAULT_RUN_DIR="${VAR_DIR}/run"
    readonly SYSTEM_CONFIG_TEMPLATE=""
fi

# Component modules
readonly DATAFETCHER_MODULE="${LIB_DIR}/datafetcher.sh"
readonly VALIDATOR_MODULE="${LIB_DIR}/validator.py"
readonly SORTER_MODULE="${LIB_DIR}/sorter.py"
readonly APPLY_MODULE="${LIB_DIR}/apply.py"
readonly LOGGER_MODULE="${LIB_DIR}/logger.py"
# TUI module can be in BIN_DIR (dev) or LIB_DIR (installed)
if [ -f "${BIN_DIR}/tui_operator.sh" ]; then
    readonly TUI_MODULE="${BIN_DIR}/tui_operator.sh"
else
    readonly TUI_MODULE="${LIB_DIR}/tui_operator.sh"
fi
readonly COMMON_LIB="${LIB_DIR}/common.sh"

# Runtime configuration
CONFIG_FILE="${CONFIG_FILE:-${DEFAULT_CONFIG_FILE}}"
LOG_FILE="${LOG_FILE:-${DEFAULT_LOG_DIR}/merger.log}"
PID_FILE="${PID_FILE:-${DEFAULT_RUN_DIR}/merger.pid}"
VERBOSE="${VERBOSE:-0}"
DRY_RUN="${DRY_RUN:-0}"
DEBUG="${DEBUG:-0}"
FORCE="${FORCE:-0}"
INTERACTIVE="${INTERACTIVE:-1}"

# Working files
readonly ZABBIX_DATA_FILE="${OUTPUT_DIR}/zabbix_assets.json"
readonly TOPDESK_DATA_FILE="${OUTPUT_DIR}/topdesk_assets.json"
readonly DIFF_REPORT_FILE="${OUTPUT_DIR}/differences/diff_report.json"
readonly APPLY_QUEUE_FILE="${OUTPUT_DIR}/apply/queue.json"
readonly VALIDATION_REPORT="${OUTPUT_DIR}/validation_report.json"

# Load common library
if [ -f "${COMMON_LIB}" ]; then
    . "${COMMON_LIB}"
else
    # Fallback logging if common.sh not available
    log_message() {
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$1] ${2}" | tee -a "${LOG_FILE}"
    }
    log_error() { log_message "ERROR" "$1"; }
    log_info() { log_message "INFO" "$1"; }
    log_debug() { [ "${DEBUG}" = "1" ] && log_message "DEBUG" "$1" || true; }
fi

# Color codes for output
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    BOLD=''
    NC=''
fi

# Print usage information
usage() {
    printf "%bUsage:%b %s [OPTIONS] COMMAND [ARGUMENTS]\n" "${BOLD}" "${NC}" "${SCRIPT_NAME}"
    printf "\n"
    printf "%bDESCRIPTION:%b\n" "${BOLD}" "${NC}"
    printf "    Orchestrates asset synchronization between Zabbix monitoring and Topdesk ITSM.\n"
    printf "    Integrates multiple components for data retrieval, comparison, and application.\n"
    printf "\n"
    printf "%bCOMMANDS:%b\n" "${BOLD}" "${NC}"
    printf "    %bfetch%b       Retrieve data from Zabbix and Topdesk\n" "${CYAN}" "${NC}"
    printf "    %bdiff%b        Compare and identify differences\n" "${CYAN}" "${NC}"
    printf "    %btui%b         Interactive TUI for field selection\n" "${CYAN}" "${NC}"
    printf "    %bapply%b       Apply selected changes to Topdesk\n" "${CYAN}" "${NC}"
    printf "    %bsync%b        Full workflow (fetch -> diff -> tui -> apply)\n" "${CYAN}" "${NC}"
    printf "    %bvalidate%b    Validate configuration and connectivity\n" "${CYAN}" "${NC}"
    printf "    %bhealth%b      Comprehensive health check of all components\n" "${CYAN}" "${NC}"
    printf "    %bstatus%b      Show current process status\n" "${CYAN}" "${NC}"
    printf "    %bclean%b       Clean temporary and cache files\n" "${CYAN}" "${NC}"
    printf "    %bprofile%b     Manage synchronization profiles\n" "${CYAN}" "${NC}"
    printf "\n"
    printf "%bOPTIONS:%b\n" "${BOLD}" "${NC}"
    printf "    -c, --config FILE    Configuration file (default: %s)\n" "${DEFAULT_CONFIG_FILE}"
    printf "    -o, --output DIR     Output directory (default: %s)\n" "${OUTPUT_DIR}"
    printf "    -l, --log FILE       Log file (default: %s)\n" "${LOG_FILE}"
    printf "    -v, --verbose        Enable verbose output\n"
    printf "    -d, --debug          Enable debug mode\n"
    printf "    -n, --dry-run        Perform dry run without changes\n"
    printf "    -f, --force          Force operation without confirmation\n"
    printf "    -i, --interactive    Interactive mode (default: on)\n"
    printf "    -b, --batch          Batch mode (non-interactive)\n"
    printf "    -h, --help           Show this help message\n"
    printf "    -V, --version        Show version information\n"
    printf "\n"
    printf "%bWORKFLOW COMMANDS:%b\n" "${BOLD}" "${NC}"
    printf "    %bfetch%b [OPTIONS]\n" "${CYAN}" "${NC}"
    printf "        --group GROUP       Filter by Zabbix group\n"
    printf "        --tag TAG          Filter by tag\n"
    printf "        --limit N          Limit number of assets\n"
    printf "        --cache            Use cached data if available\n"
    printf "\n"
    printf "    %bdiff%b [OPTIONS]\n" "${CYAN}" "${NC}"
    printf "        --fields FIELDS    Comma-separated fields to compare\n"
    printf "        --format FORMAT    Output format (json|csv|html)\n"
    printf "        --threshold N      Similarity threshold (0-100)\n"
    printf "\n"
    printf "    %btui%b [OPTIONS]\n" "${CYAN}" "${NC}"
    printf "        --mode MODE        TUI mode (dialog|whiptail|pure)\n"
    printf "        --auto-select      Auto-select all Zabbix values\n"
    printf "\n"
    printf "    %bapply%b [OPTIONS]\n" "${CYAN}" "${NC}"
    printf "        --queue FILE       Apply from queue file\n"
    printf "        --batch-size N     Batch size for updates\n"
    printf "        --confirm          Require confirmation\n"
    printf "\n"
    printf "    %bsync%b [OPTIONS]\n" "${CYAN}" "${NC}"
    printf "        --auto             Full automatic mode\n"
    printf "        --profile PROFILE  Use predefined profile\n"
    printf "\n"
    printf "    %bprofile%b [SUBCOMMAND] [OPTIONS]\n" "${CYAN}" "${NC}"
    printf "        create NAME        Create new profile\n"
    printf "        edit NAME          Edit existing profile\n"
    printf "        list               List all profiles\n"
    printf "        show NAME          Show profile details\n"
    printf "        delete NAME        Delete a profile\n"
    printf "        copy SRC DEST      Copy a profile\n"
    printf "        wizard             Launch interactive wizard\n"
    printf "\n"
    printf "    %bvalidate%b [OPTIONS]\n" "${CYAN}" "${NC}"
    printf "        --verbose, -v      Show configuration details\n"
    printf "        --debug, -d        Show debug connection info\n"
    printf "\n"
    printf "%bEXAMPLES:%b\n" "${BOLD}" "${NC}"
    printf "    # Validate system configuration\n"
    printf "    %s validate\n" "${SCRIPT_NAME}"
    printf "\n"
    printf "    # Validate with debug information\n"
    printf "    %s validate --verbose\n" "${SCRIPT_NAME}"
    printf "\n"
    printf "    # Full interactive synchronization\n"
    printf "    %s sync\n" "${SCRIPT_NAME}"
    printf "\n"
    printf "    # Fetch with filters\n"
    printf "    %s fetch --group \"Linux servers\" --tag \"production\"\n" "${SCRIPT_NAME}"
    printf "\n"
    printf "    # Non-interactive batch sync\n"
    printf "    %s -b sync --auto\n" "${SCRIPT_NAME}"
    printf "\n"
    printf "    # Dry-run to preview changes\n"
    printf "    %s -n sync\n" "${SCRIPT_NAME}"
    printf "\n"
    printf "%bFILES:%b\n" "${BOLD}" "${NC}"
    printf "    Configuration: %s/merger.conf\n" "${ETC_DIR}"
    printf "    Logs:         %s/\n" "${DEFAULT_LOG_DIR}"
    printf "    Cache:        %s/\n" "${DEFAULT_CACHE_DIR}"
    printf "    Output:       %s/\n" "${OUTPUT_DIR}"
    printf "\n"
    printf "%bCOMPONENTS:%b\n" "${BOLD}" "${NC}"
    printf "    - datafetcher: Retrieves data from Zabbix/Topdesk\n"
    printf "    - validator:   Validates data and configuration\n"
    printf "    - sorter:      Compares and sorts differences\n"
    printf "    - tui:         Interactive field selection\n"
    printf "    - applier:     Applies changes to Topdesk\n"
    printf "    - logger:      Centralized logging system\n"
    printf "\n"
    printf "%bEXIT STATUS:%b\n" "${BOLD}" "${NC}"
    printf "    0  Success\n"
    printf "    1  General error\n"
    printf "    2  Configuration error\n"
    printf "    3  Connection error\n"
    printf "    4  Data error\n"
    printf "    5  Component error\n"
    printf "\n"
    printf "%bVERSION:%b\n" "${BOLD}" "${NC}"
    printf "    %s version %s\n" "${SCRIPT_NAME}" "${SCRIPT_VERSION}"
    printf "\n"
    printf "%bDOCUMENTATION:%b\n" "${BOLD}" "${NC}"
    printf "    See %s/README.md for detailed documentation\n" "${PROJECT_ROOT}"
    printf "\n"
}

# Print version
version() {
    echo "${SCRIPT_NAME} version ${SCRIPT_VERSION}"
    echo "Asset Merger Engine"
    echo "Copyright (c) 2025 Bissbert"
    echo "Licensed under the MIT License"
}

# Initialize environment
init_environment() {
    # For system-wide installations, create user config from template if needed
    if [ -n "${SYSTEM_CONFIG_TEMPLATE}" ] && [ -f "${SYSTEM_CONFIG_TEMPLATE}" ]; then
        if [ ! -f "${DEFAULT_CONFIG_FILE}" ]; then
            # Create config directory if it doesn't exist
            local config_dir="$(dirname "${DEFAULT_CONFIG_FILE}")"
            if [ ! -d "${config_dir}" ]; then
                mkdir -p "${config_dir}" 2>/dev/null || {
                    echo "Error: Failed to create config directory: ${config_dir}" >&2
                    return 1
                }
            fi

            # Copy template to user config
            cp "${SYSTEM_CONFIG_TEMPLATE}" "${DEFAULT_CONFIG_FILE}" 2>/dev/null || {
                echo "Error: Failed to create user config from template" >&2
                echo "Please manually copy ${SYSTEM_CONFIG_TEMPLATE} to ${DEFAULT_CONFIG_FILE}" >&2
                return 1
            }
            chmod 600 "${DEFAULT_CONFIG_FILE}" 2>/dev/null || true
            echo "Created user configuration file: ${DEFAULT_CONFIG_FILE}"
            echo "Please edit it with your settings before running sync operations"
        fi
    fi

    # Create log directory first if needed
    if [ ! -d "${DEFAULT_LOG_DIR}" ]; then
        mkdir -p "${DEFAULT_LOG_DIR}" 2>/dev/null || {
            echo "Error: Failed to create log directory: ${DEFAULT_LOG_DIR}" >&2
            return 1
        }
    fi

    log_info "Initializing environment..."

    # Create required directories (including XDG directories for system installs)
    for dir in "${DEFAULT_LOG_DIR}" "${DEFAULT_CACHE_DIR}" "${DEFAULT_RUN_DIR}" \
               "${OUTPUT_DIR}" "${TMP_DIR}" "${OUTPUT_DIR}/differences" \
               "${OUTPUT_DIR}/apply" "${OUTPUT_DIR}/reports" "${OUTPUT_DIR}/processed" \
               "${OUTPUT_DIR}/failed"; do
        if [ ! -d "${dir}" ]; then
            mkdir -p "${dir}" 2>/dev/null || {
                log_error "Failed to create directory: ${dir}"
                echo "Error: Failed to create directory: ${dir}" >&2
                return 1
            }
        fi
    done

    # Initialize log file
    touch "${LOG_FILE}" 2>/dev/null || {
        log_error "Failed to create log file: ${LOG_FILE}"
        echo "Error: Failed to create log file: ${LOG_FILE}" >&2
        return 1
    }

    # Check PID file
    if [ -f "${PID_FILE}" ]; then
        old_pid=$(cat "${PID_FILE}" 2>/dev/null)
        if kill -0 "${old_pid}" 2>/dev/null; then
            log_error "Another instance is running (PID: ${old_pid})"
            return 1
        else
            log_info "Removing stale PID file"
            rm -f "${PID_FILE}"
        fi
    fi

    # Write PID file
    echo $$ > "${PID_FILE}" 2>/dev/null || {
        log_error "Failed to write PID file: ${PID_FILE}"
        echo "Error: Failed to write PID file: ${PID_FILE}" >&2
        return 1
    }

    log_info "Environment initialized successfully"
    return 0
}

# Cleanup on exit
cleanup() {
    local exit_code=$?

    # Only log in debug mode to stderr, not stdout
    [ "${DEBUG}" = "1" ] && echo "[DEBUG] Cleaning up (exit code: ${exit_code})..." >&2

    # Remove PID file
    [ -f "${PID_FILE}" ] && rm -f "${PID_FILE}"

    # Clean temporary files if not debug mode
    if [ "${DEBUG}" != "1" ] && [ -d "${TMP_DIR}" ]; then
        find "${TMP_DIR}" -type f -name "tmp.*" -mtime +1 -delete 2>/dev/null
    fi

    # Only log completion in verbose or debug mode
    [ "${VERBOSE}" = "1" ] && log_info "Cleanup completed"

    exit ${exit_code}
}

# Validate configuration
validate_config() {
    log_info "Validating configuration..."

    if [ ! -f "${CONFIG_FILE}" ]; then
        log_error "Configuration file not found: ${CONFIG_FILE}"
        echo "Creating default configuration..."
        create_default_config
        return 1
    fi

    # Source configuration
    . "${CONFIG_FILE}" || {
        log_error "Failed to load configuration"
        return 1
    }

    # Validate required settings
    local errors=0

    # Check Zabbix configuration - need URL and either user/pass or API token
    if [ -z "${ZABBIX_URL:-}" ]; then
        log_error "Missing Zabbix URL"
        errors=$((errors + 1))
    elif [ -z "${ZABBIX_USER:-}" ] && [ -z "${ZABBIX_API_TOKEN:-}" ]; then
        log_error "Missing Zabbix authentication (need either user/password or API token)"
        errors=$((errors + 1))
    fi

    # Check Topdesk configuration - need URL and either user/pass or API token
    if [ -z "${TOPDESK_URL:-}" ]; then
        log_error "Missing Topdesk URL"
        errors=$((errors + 1))
    elif [ -z "${TOPDESK_USER:-}" ] && [ -z "${TOPDESK_API_TOKEN:-}" ]; then
        log_error "Missing Topdesk authentication (need either user/password or API token)"
        errors=$((errors + 1))
    fi

    if [ ${errors} -gt 0 ]; then
        log_error "Configuration validation failed with ${errors} errors"
        return 1
    fi

    log_info "Configuration validated successfully"
    return 0
}

# Create default configuration
create_default_config() {
    cat > "${CONFIG_FILE}" << 'EOF'
# Asset Merger Engine Configuration
# Generated on: $(date)

# Zabbix Configuration
ZABBIX_URL="https://zabbix.example.com"
ZABBIX_USER="admin"
ZABBIX_PASSWORD=""
ZABBIX_API_TOKEN=""
ZABBIX_GROUP_FILTER="Topdesk"
ZABBIX_TAG_FILTER=""

# Topdesk Configuration
TOPDESK_URL="https://topdesk.example.com"
TOPDESK_USER="api_user"
TOPDESK_PASSWORD=""
TOPDESK_API_TOKEN=""
TOPDESK_BRANCH=""

# Merge Settings
MERGE_STRATEGY="update"          # update|create|sync
CONFLICT_RESOLUTION="zabbix"     # zabbix|topdesk|manual|newest
BATCH_SIZE="100"
FIELD_MAPPING="auto"             # auto|manual|config

# Fields to sync
SYNC_FIELDS="name,ip_address,location,owner,status,description"
IGNORE_FIELDS="last_seen,created_date"
CUSTOM_FIELD_PREFIX="zbx_"

# Processing Options
ENABLE_CACHING="true"
CACHE_TTL="300"                  # seconds
MAX_RETRIES="3"
RETRY_DELAY="5"                  # seconds
CONNECTION_TIMEOUT="30"          # seconds

# Validation Rules
VALIDATE_IP="true"
VALIDATE_HOSTNAME="true"
VALIDATE_EMAIL="true"
REQUIRE_OWNER="false"

# Output Options
OUTPUT_FORMAT="json"             # json|csv|xml|yaml
GENERATE_REPORTS="true"
REPORT_FORMAT="html"             # html|pdf|text|markdown
COMPRESS_OUTPUT="false"

# Logging
LOG_LEVEL="INFO"                # DEBUG|INFO|WARNING|ERROR
LOG_ROTATE="true"
LOG_MAX_SIZE="10M"
LOG_MAX_FILES="10"

# TUI Settings
TUI_MODE="auto"                  # auto|dialog|whiptail|pure
TUI_COLORS="true"
TUI_AUTO_REFRESH="true"
TUI_REFRESH_INTERVAL="5"

# Performance
PARALLEL_FETCH="true"
MAX_WORKERS="4"
CHUNK_SIZE="50"

# Security
VERIFY_SSL="true"
SSL_CERT_PATH=""
USE_KEYRING="false"

# Notifications (optional)
NOTIFY_EMAIL=""
NOTIFY_SLACK_WEBHOOK=""
NOTIFY_ON_SUCCESS="false"
NOTIFY_ON_ERROR="true"

EOF
    log_info "Default configuration created: ${CONFIG_FILE}"
    echo "Please edit ${CONFIG_FILE} with your settings"
}

# Command: fetch
cmd_fetch() {
    log_info "=== Starting Data Fetch ==="

    local group_filter=""
    local tag_filter=""
    local limit=""
    local use_cache=0

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --group)
                group_filter="$2"
                shift 2
                ;;
            --tag)
                tag_filter="$2"
                shift 2
                ;;
            --limit)
                limit="$2"
                shift 2
                ;;
            --cache)
                use_cache=1
                shift
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -d|--debug)
                DEBUG=1
                VERBOSE=1
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    # Check for cached data
    if [ ${use_cache} -eq 1 ] && [ -f "${ZABBIX_DATA_FILE}" ] && [ -f "${TOPDESK_DATA_FILE}" ]; then
        local cache_age=$(( $(date +%s) - $(stat -f %m "${ZABBIX_DATA_FILE}" 2>/dev/null || stat -c %Y "${ZABBIX_DATA_FILE}" 2>/dev/null) ))
        if [ ${cache_age} -lt ${CACHE_TTL:-300} ]; then
            log_info "Using cached data (age: ${cache_age}s)"
            return 0
        fi
    fi

    # Load configuration
    . "${CONFIG_FILE}"

    # Export environment for modules
    export ZABBIX_URL ZABBIX_USER ZABBIX_PASSWORD ZABBIX_API_TOKEN
    export TOPDESK_URL TOPDESK_USER TOPDESK_PASSWORD TOPDESK_API_TOKEN
    export LOG_FILE OUTPUT_DIR DEBUG VERBOSE

    # Ensure output directories exist
    mkdir -p "$(dirname "${ZABBIX_DATA_FILE}")"
    mkdir -p "$(dirname "${TOPDESK_DATA_FILE}")"

    # Fetch from Zabbix using the datafetcher module
    log_info "Fetching data from Zabbix..."
    if [ -f "${DATAFETCHER_MODULE}" ]; then
        # Source the datafetcher module
        . "${DATAFETCHER_MODULE}"

        # Call the fetch_zabbix function with proper arguments
        fetch_zabbix_assets \
            "${group_filter:-${ZABBIX_GROUP_FILTER:-Topdesk}}" \
            "${tag_filter:-${ZABBIX_TAG_FILTER:-}}" \
            "${limit:-}" \
            > "${ZABBIX_DATA_FILE}" || {
            log_error "Failed to fetch Zabbix data"
            return 4
        }

        log_info "Zabbix data saved to ${ZABBIX_DATA_FILE}"
    else
        log_error "Datafetcher module not found: ${DATAFETCHER_MODULE}"
        return 5
    fi

    # Fetch from Topdesk using the datafetcher module
    log_info "Fetching data from Topdesk..."
    if [ -f "${DATAFETCHER_MODULE}" ]; then
        # Call the fetch_topdesk function
        fetch_topdesk_assets \
            "${limit:-}" \
            > "${TOPDESK_DATA_FILE}" || {
            log_error "Failed to fetch Topdesk data"
            return 4
        }

        log_info "Topdesk data saved to ${TOPDESK_DATA_FILE}"
    else
        log_error "Datafetcher module not found: ${DATAFETCHER_MODULE}"
        return 5
    fi

    # Validate fetched data
    if [ -f "${ZABBIX_DATA_FILE}" ]; then
        if ! jq empty "${ZABBIX_DATA_FILE}" 2>/dev/null; then
            log_error "Invalid JSON in Zabbix data file"
            return 4
        fi
    else
        log_error "Zabbix data file not created"
        return 4
    fi

    if [ -f "${TOPDESK_DATA_FILE}" ]; then
        if ! jq empty "${TOPDESK_DATA_FILE}" 2>/dev/null; then
            log_error "Invalid JSON in Topdesk data file"
            return 4
        fi
    else
        log_error "Topdesk data file not created"
        return 4
    fi

    # Show summary
    if [ -f "${ZABBIX_DATA_FILE}" ] && [ -f "${TOPDESK_DATA_FILE}" ]; then
        local zbx_count=$(jq 'length' "${ZABBIX_DATA_FILE}" 2>/dev/null || echo "0")
        local td_count=$(jq 'length' "${TOPDESK_DATA_FILE}" 2>/dev/null || echo "0")

        echo ""
        echo "${GREEN}Data fetch completed successfully${NC}"
        echo "  Zabbix assets:  ${zbx_count}"
        echo "  Topdesk assets: ${td_count}"
        echo ""

        # Log to centralized logger if available
        if [ -f "${LOGGER_MODULE}" ]; then
            python3 "${LOGGER_MODULE}" log \
                --level INFO \
                --component datafetcher \
                --message "Fetch completed: Zabbix=${zbx_count}, Topdesk=${td_count}" \
                2>/dev/null || true
        fi
    fi

    log_info "Data fetch completed"
    return 0
}

# Command: diff
cmd_diff() {
    log_info "=== Starting Difference Analysis ==="

    local fields=""
    local format="json"
    local threshold="80"

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --fields)
                fields="$2"
                shift 2
                ;;
            --format)
                format="$2"
                shift 2
                ;;
            --threshold)
                threshold="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    # Check input files
    if [ ! -f "${ZABBIX_DATA_FILE}" ] || [ ! -f "${TOPDESK_DATA_FILE}" ]; then
        log_error "Input data files not found. Run 'fetch' first."
        return 4
    fi

    # Load configuration
    . "${CONFIG_FILE}"

    # Use Python sorter module for comparison
    log_info "Comparing assets and identifying differences..."

    if [ -f "${SORTER_MODULE}" ]; then
        python3 "${SORTER_MODULE}" \
            --zabbix "${ZABBIX_DATA_FILE}" \
            --topdesk "${TOPDESK_DATA_FILE}" \
            --output "${DIFF_REPORT_FILE}" \
            --format "${format}" \
            --threshold "${threshold}" \
            ${fields:+--fields "${fields}"} || {
            log_error "Difference analysis failed"
            return 5
        }
    else
        log_error "Sorter module not found: ${SORTER_MODULE}"
        return 5
    fi

    # Show summary
    if [ -f "${DIFF_REPORT_FILE}" ]; then
        local total_diff=$(jq '.summary.total_differences' "${DIFF_REPORT_FILE}" 2>/dev/null || echo "0")
        local matched=$(jq '.summary.matched_assets' "${DIFF_REPORT_FILE}" 2>/dev/null || echo "0")
        local unmatched=$(jq '.summary.unmatched_assets' "${DIFF_REPORT_FILE}" 2>/dev/null || echo "0")

        echo ""
        echo "${GREEN}Difference analysis completed${NC}"
        echo "  Matched assets:     ${matched}"
        echo "  Unmatched assets:   ${unmatched}"
        echo "  Total differences:  ${total_diff}"
        echo ""
        echo "Report saved to: ${DIFF_REPORT_FILE}"
        echo ""
    fi

    log_info "Difference analysis completed"
    return 0
}

# Command: tui
cmd_tui() {
    log_info "=== Starting Terminal User Interface ==="

    local mode="auto"
    local auto_select=0

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --mode)
                mode="$2"
                shift 2
                ;;
            --auto-select)
                auto_select=1
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    # Check for difference report
    if [ ! -f "${DIFF_REPORT_FILE}" ]; then
        log_error "Difference report not found. Run 'diff' first."
        return 4
    fi

    # Launch TUI
    if [ -x "${TUI_MODULE}" ]; then
        log_info "Launching TUI for field selection..."

        "${TUI_MODULE}" \
            --input "${DIFF_REPORT_FILE}" \
            --output "${APPLY_QUEUE_FILE}" \
            --mode "${mode}" \
            ${auto_select:+--auto-select} || {
            log_error "TUI operation failed"
            return 5
        }

        # Show summary
        if [ -f "${APPLY_QUEUE_FILE}" ]; then
            local queue_count=$(jq 'length' "${APPLY_QUEUE_FILE}" 2>/dev/null || echo "0")
            echo ""
            echo "${GREEN}Field selection completed${NC}"
            echo "  Changes queued: ${queue_count}"
            echo ""
        fi
    else
        log_error "TUI module not found or not executable: ${TUI_MODULE}"
        return 5
    fi

    log_info "TUI operation completed"
    return 0
}

# Command: apply
cmd_apply() {
    log_info "=== Starting Apply Changes ==="

    local queue_file="${APPLY_QUEUE_FILE}"
    local batch_size="50"
    local require_confirm=1

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --queue)
                queue_file="$2"
                shift 2
                ;;
            --batch-size)
                batch_size="$2"
                shift 2
                ;;
            --no-confirm)
                require_confirm=0
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    # Check queue file
    if [ ! -f "${queue_file}" ]; then
        log_error "Apply queue not found: ${queue_file}"
        return 4
    fi

    # Load configuration
    . "${CONFIG_FILE}"

    # Count changes
    local change_count=$(jq 'length' "${queue_file}" 2>/dev/null || echo "0")

    if [ ${change_count} -eq 0 ]; then
        log_info "No changes to apply"
        return 0
    fi

    # Confirm if required
    if [ ${require_confirm} -eq 1 ] && [ ${FORCE} -eq 0 ]; then
        echo ""
        echo "${YELLOW}About to apply ${change_count} changes to Topdesk${NC}"
        printf "Continue? [y/N] "
        read -r response
        case "${response}" in
            [yY][eE][sS]|[yY])
                ;;
            *)
                log_info "Apply cancelled by user"
                return 0
                ;;
        esac
    fi

    # Apply changes using Python module
    if [ -f "${APPLY_MODULE}" ]; then
        log_info "Applying changes to Topdesk..."

        python3 "${APPLY_MODULE}" \
            --queue "${queue_file}" \
            --batch-size "${batch_size}" \
            ${DRY_RUN:+--dry-run} \
            --output "${OUTPUT_DIR}/apply/results.json" || {
            log_error "Failed to apply changes"
            return 5
        }

        # Show results
        if [ -f "${OUTPUT_DIR}/apply/results.json" ]; then
            local success=$(jq '.summary.successful' "${OUTPUT_DIR}/apply/results.json" 2>/dev/null || echo "0")
            local failed=$(jq '.summary.failed' "${OUTPUT_DIR}/apply/results.json" 2>/dev/null || echo "0")

            echo ""
            echo "${GREEN}Apply completed${NC}"
            echo "  Successful: ${success}"
            echo "  Failed:     ${failed}"
            echo ""
        fi
    else
        log_error "Apply module not found: ${APPLY_MODULE}"
        return 5
    fi

    log_info "Apply operation completed"
    return 0
}

# Command: sync (full workflow)
cmd_sync() {
    log_info "=== Starting Full Synchronization Workflow ==="

    local auto_mode=0
    local profile=""

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --auto)
                auto_mode=1
                INTERACTIVE=0
                shift
                ;;
            --profile)
                profile="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -d|--debug)
                DEBUG=1
                VERBOSE=1
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    # Load profile if specified
    if [ -n "${profile}" ] && [ -f "${ETC_DIR}/profiles/${profile}.conf" ]; then
        log_info "Loading profile: ${profile}"
        . "${ETC_DIR}/profiles/${profile}.conf"
    fi

    echo ""
    echo "${BOLD}Starting full synchronization workflow...${NC}"
    echo ""

    # Step 1: Fetch data
    echo "${CYAN}Step 1/4: Fetching data...${NC}"
    cmd_fetch || return $?

    # Step 2: Analyze differences
    echo ""
    echo "${CYAN}Step 2/4: Analyzing differences...${NC}"
    cmd_diff || return $?

    # Step 3: Select fields (interactive or auto)
    echo ""
    if [ ${INTERACTIVE} -eq 1 ] && [ ${auto_mode} -eq 0 ]; then
        echo "${CYAN}Step 3/4: Interactive field selection...${NC}"
        cmd_tui || return $?
    else
        echo "${CYAN}Step 3/4: Auto-selecting all Zabbix values...${NC}"
        cmd_tui --auto-select || return $?
    fi

    # Step 4: Apply changes
    echo ""
    echo "${CYAN}Step 4/4: Applying changes...${NC}"
    if [ ${auto_mode} -eq 1 ]; then
        cmd_apply --no-confirm || return $?
    else
        cmd_apply || return $?
    fi

    echo ""
    echo "${GREEN}${BOLD}Full synchronization completed successfully!${NC}"
    echo ""

    # Generate report
    if [ "${GENERATE_REPORTS:-true}" = "true" ]; then
        cmd_report
    fi

    log_info "Full synchronization workflow completed"
    return 0
}

# Command: validate
cmd_validate() {
    # Parse command-specific options
    while [ $# -gt 0 ]; do
        case "$1" in
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -d|--debug)
                DEBUG=1
                VERBOSE=1
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    log_info "=== Starting Validation ==="
    log_debug "Starting cmd_validate function" || true

    printf "%bSystem Validation%b\n" "${BOLD}" "${NC}" || true
    printf "\n" || true

    # Check configuration
    log_debug "About to check configuration" || true
    printf "Checking configuration... " || true
    if validate_config; then
        printf "%bOK%b\n" "${GREEN}" "${NC}" || true
    else
        printf "%bFAILED%b\n" "${RED}" "${NC}" || true
        return 2
    fi
    log_debug "Configuration check completed" || true

    # Check components
    printf "Checking components... "
    local components_ok=1

    # Check shell scripts (must be executable)
    for component in "${DATAFETCHER_MODULE}" "${TUI_MODULE}"; do
        if [ ! -f "${component}" ]; then
            components_ok=0
            log_error "Component not found: ${component}"
        elif [ ! -r "${component}" ]; then
            components_ok=0
            log_error "Component not readable: ${component}"
        fi
    done

    # Check Python modules (must exist)
    for component in "${VALIDATOR_MODULE}" "${SORTER_MODULE}" "${APPLY_MODULE}" "${LOGGER_MODULE}"; do
        if [ ! -f "${component}" ]; then
            components_ok=0
            log_error "Component not found: ${component}"
        fi
    done

    if [ ${components_ok} -eq 1 ]; then
        printf "%bOK%b\n" "${GREEN}" "${NC}"
    else
        printf "%bFAILED%b\n" "${RED}" "${NC}"
        return 5
    fi

    # Check Python
    printf "Checking Python... "
    if command -v python3 >/dev/null 2>&1; then
        local py_version=$(python3 --version 2>&1 | cut -d' ' -f2)
        printf "%bOK%b (%s)\n" "${GREEN}" "${NC}" "${py_version}"
    else
        printf "%bFAILED%b\n" "${RED}" "${NC}"
        return 5
    fi

    # Check required commands
    printf "Checking required commands... "
    local cmds_ok=1
    for cmd in jq curl; do
        if ! command -v "${cmd}" >/dev/null 2>&1; then
            cmds_ok=0
            log_error "Required command not found: ${cmd}"
        fi
    done

    if [ ${cmds_ok} -eq 1 ]; then
        printf "%bOK%b\n" "${GREEN}" "${NC}"
    else
        printf "%bFAILED%b\n" "${RED}" "${NC}"
        return 5
    fi

    # Check CLI tools
    printf "Checking CLI tools... "
    local cli_tools_ok=1

    # Check zbx command
    if command -v zbx >/dev/null 2>&1; then
        printf "%bzbx OK%b " "${GREEN}" "${NC}"
    else
        printf "%bzbx NOT FOUND%b " "${YELLOW}" "${NC}"
        cli_tools_ok=0
    fi

    # Check topdesk command
    if command -v topdesk >/dev/null 2>&1; then
        printf "%btopdesk OK%b\n" "${GREEN}" "${NC}"
    else
        printf "%btopdesk NOT FOUND%b\n" "${YELLOW}" "${NC}"
        cli_tools_ok=0
    fi

    if [ ${cli_tools_ok} -eq 0 ]; then
        log_info "CLI tools not found - will use API fallback methods"
    fi

    # Test connections if not dry-run
    if [ ${DRY_RUN} -eq 0 ]; then
        # Load config
        . "${CONFIG_FILE}"

        # Show configuration being used (with debug mode)
        if [ "${DEBUG}" = "1" ] || [ "${VERBOSE}" = "1" ]; then
            printf "\n%bConfiguration Details:%b\n" "${BOLD}" "${NC}"
            printf "  Config file: %s\n" "${CONFIG_FILE}"

            # Zabbix config
            printf "  Zabbix:\n"
            printf "    URL: %s\n" "${ZABBIX_URL:-<not set>}"
            if [ -n "${ZABBIX_API_TOKEN:-}" ]; then
                printf "    Auth: API Token (${GREEN}configured${NC})\n"
            elif [ -n "${ZABBIX_USER:-}" ]; then
                printf "    Auth: User/Password (user: %s)\n" "${ZABBIX_USER}"
            else
                printf "    Auth: ${RED}Not configured${NC}\n"
            fi

            # Topdesk config
            printf "  Topdesk:\n"
            printf "    URL: %s\n" "${TOPDESK_URL:-<not set>}"
            if [ -n "${TOPDESK_API_TOKEN:-}" ]; then
                printf "    Auth: API Token (${GREEN}configured${NC})\n"
            elif [ -n "${TOPDESK_USER:-}" ]; then
                printf "    Auth: User/Password (user: %s)\n" "${TOPDESK_USER}"
            else
                printf "    Auth: ${RED}Not configured${NC}\n"
            fi
            printf "\n"
        fi

        # Test Zabbix using zbx CLI
        printf "Testing Zabbix API connection... "
        if [ -n "${ZABBIX_URL}" ] && command -v zbx >/dev/null 2>&1; then
            # Create temporary config file for zbx to ensure our config takes precedence
            local temp_zbx_config="${TMP_DIR:-/tmp}/zbx_test_$$.sh"

            # Create the temp config based on our settings (zbx uses shell format)
            {
                echo "# Temporary zbx config for testing"
                echo "export ZABBIX_URL='${ZABBIX_URL}'"
                if [ -n "${ZABBIX_API_TOKEN:-}" ]; then
                    echo "export ZABBIX_API_TOKEN='${ZABBIX_API_TOKEN}'"
                else
                    echo "export ZABBIX_USER='${ZABBIX_USER:-}'"
                    echo "export ZABBIX_PASS='${ZABBIX_PASSWORD:-}'"
                fi
                # Map VERIFY_SSL to ZABBIX_VERIFY_TLS (zbx expects 0 or 1)
                if [ "${VERIFY_SSL:-true}" = "false" ]; then
                    echo "export ZABBIX_VERIFY_TLS=0"
                else
                    echo "export ZABBIX_VERIFY_TLS=1"
                fi
                echo "export ZABBIX_CURL_TIMEOUT=30"
            } > "${temp_zbx_config}"

            # Set ZBX_CONFIG to use our temp file
            export ZBX_CONFIG="${temp_zbx_config}"

            if [ "${DEBUG}" = "1" ]; then
                printf "\n  Testing with: zbx ping (using our config)\n"
                printf "  Config file: %s\n" "${temp_zbx_config}"
                printf "  URL: %s\n" "${ZABBIX_URL}"
                if [ -n "${ZABBIX_API_TOKEN:-}" ]; then
                    printf "  Auth: API Token\n"
                elif [ -n "${ZABBIX_USER:-}" ]; then
                    printf "  Auth: User/Password (user: %s)\n" "${ZABBIX_USER}"
                fi
                printf "  "
            fi

            # Try zbx ping first (quickest test)
            local test_result
            if [ "${DEBUG}" = "1" ]; then
                # Show full output in debug mode
                printf "Running: zbx ping (with ZBX_CONFIG=%s)\n" "${temp_zbx_config}"
                if zbx ping 2>&1; then
                    test_result=0
                    printf "  "
                else
                    test_result=$?
                    printf "  zbx ping failed with exit code: %s\n" "${test_result}"
                    # Try version as alternate test
                    printf "  Trying: zbx version\n"
                    if zbx version 2>&1; then
                        test_result=0
                        printf "  "
                    else
                        test_result=$?
                        printf "  zbx version failed with exit code: %s\n" "${test_result}"
                    fi
                    printf "  "
                fi
            else
                # Silent mode - just check if it works
                if zbx ping >/dev/null 2>&1; then
                    test_result=0
                else
                    # Try version as fallback
                    if zbx version >/dev/null 2>&1; then
                        test_result=0
                    else
                        test_result=1
                    fi
                fi
            fi

            # Clean up temp config
            rm -f "${temp_zbx_config}"
            unset ZBX_CONFIG

            if [ ${test_result} -eq 0 ]; then
                printf "%bOK%b\n" "${GREEN}" "${NC}"
            else
                printf "%bFAILED%b\n" "${RED}" "${NC}"
                if [ "${VERBOSE}" = "1" ] || [ "${DEBUG}" = "1" ]; then
                    printf "  Hint: Check zbx doctor output above for details\n"
                fi
            fi
        elif [ -z "${ZABBIX_URL}" ]; then
            printf "%bUNCONFIGURED%b\n" "${YELLOW}" "${NC}"
        else
            printf "%bzbx CLI not found%b\n" "${YELLOW}" "${NC}"
        fi

        # Test Topdesk API
        printf "Testing Topdesk API connection... "
        if [ -n "${TOPDESK_URL}" ] && command -v topdesk >/dev/null 2>&1; then
            # Create temporary config file for topdesk to ensure our config takes precedence
            local temp_td_config="${TMP_DIR:-/tmp}/topdesk_test_$$.sh"

            # Create the temp config based on our settings (assuming shell format like zbx)
            {
                echo "#!/bin/sh"
                echo "# Temporary topdesk config for testing"
                echo "export TOPDESK_URL='${TOPDESK_URL:-}'"
                if [ -n "${TOPDESK_API_TOKEN:-}" ]; then
                    echo "export TOPDESK_API_TOKEN='${TOPDESK_API_TOKEN}'"
                else
                    echo "export TOPDESK_USER='${TOPDESK_USER:-}'"
                    echo "export TOPDESK_PASSWORD='${TOPDESK_PASSWORD:-}'"
                fi
                # Map VERIFY_SSL to TOPDESK_VERIFY_SSL (use same format as engine config)
                if [ "${VERIFY_SSL:-true}" = "false" ]; then
                    echo "export TOPDESK_VERIFY_SSL=false"
                else
                    echo "export TOPDESK_VERIFY_SSL=true"
                fi
                # Use configured timeout or default to 30
                echo "export TOPDESK_TIMEOUT=${TOPDESK_TIMEOUT:-${CONNECT_TIMEOUT:-30}}"
            } > "${temp_td_config}"
            chmod +x "${temp_td_config}"

            # Check if topdesk supports a config environment variable
            # If not, we'll just export the variables directly
            export TOPDESK_CONFIG="${temp_td_config}"

            # Also export directly in case topdesk doesn't use TOPDESK_CONFIG
            export TOPDESK_URL="${TOPDESK_URL:-}"
            export TOPDESK_USER="${TOPDESK_USER:-}"
            export TOPDESK_PASSWORD="${TOPDESK_PASSWORD:-}"
            export TOPDESK_API_TOKEN="${TOPDESK_API_TOKEN:-}"

            if [ "${DEBUG}" = "1" ]; then
                printf "\n  Testing with: topdesk test/version\n"
                printf "  URL: %s\n" "${TOPDESK_URL}"
                if [ -n "${TOPDESK_API_TOKEN:-}" ]; then
                    printf "  Auth: API Token\n"
                elif [ -n "${TOPDESK_USER:-}" ]; then
                    printf "  Auth: User/Password (user: %s)\n" "${TOPDESK_USER}"
                fi
                printf "  "
            fi

            # Try topdesk test commands
            local test_result
            if [ "${DEBUG}" = "1" ]; then
                # Try various test commands
                printf "Trying topdesk commands...\n"
                if topdesk test >/dev/null 2>&1; then
                    test_result=0
                elif topdesk version >/dev/null 2>&1; then
                    test_result=0
                elif topdesk --version >/dev/null 2>&1; then
                    test_result=0
                else
                    test_result=1
                    printf "  No working test command found\n"
                fi
                printf "  "
            else
                # Silent mode
                if topdesk test >/dev/null 2>&1; then
                    test_result=0
                elif topdesk version >/dev/null 2>&1; then
                    test_result=0
                elif topdesk --version >/dev/null 2>&1; then
                    test_result=0
                else
                    test_result=1
                fi
            fi

            if [ ${test_result} -eq 0 ]; then
                printf "%bCLI OK%b\n" "${GREEN}" "${NC}"
            else
                printf "%bCLI ERROR%b\n" "${YELLOW}" "${NC}"
                if [ "${VERBOSE}" = "1" ] || [ "${DEBUG}" = "1" ]; then
                    printf "  Note: Topdesk CLI found but test commands failed\n"
                fi
            fi

            # Clean up temp config
            rm -f "${temp_td_config}"
            unset TOPDESK_CONFIG
        elif [ -n "${TOPDESK_URL}" ]; then
            # Fallback to basic HTTP check if no CLI
            local td_url="${TOPDESK_URL}"
            if ! echo "${td_url}" | grep -q "/api"; then
                td_url="${td_url}/tas/api"
            fi

            local http_code
            http_code=$(curl -s -o /dev/null -w "%{http_code}" -k -L --connect-timeout 5 -m 10 "${td_url}" 2>/dev/null)

            if [ "${DEBUG}" = "1" ]; then
                printf "\n  No topdesk CLI, using curl test\n"
                printf "  URL: %s\n" "${td_url}"
                printf "  HTTP Code: %s\n  " "${http_code}"
            fi

            if echo "${http_code}" | grep -q "200\|401\|403"; then
                printf "%bREACHABLE%b (HTTP %s)\n" "${GREEN}" "${NC}" "${http_code}"
            else
                printf "%bUNREACHABLE%b (HTTP %s)\n" "${YELLOW}" "${NC}" "${http_code}"
            fi
        else
            printf "%bUNCONFIGURED%b\n" "${YELLOW}" "${NC}"
        fi

        # Run CLI doctor commands in debug mode
        if [ "${DEBUG}" = "1" ]; then
            printf "\n%bCLI Tool Diagnostics:%b\n" "${BOLD}" "${NC}"

            # Run zbx doctor if available
            if command -v zbx >/dev/null 2>&1; then
                printf "\n%bZabbix CLI Doctor:%b\n" "${CYAN}" "${NC}"

                # Create temporary config file for zbx doctor to use our settings (zbx uses shell format)
                local temp_zbx_config="${TMP_DIR:-/tmp}/zbx_doctor_$$.sh"
                {
                    echo "#!/bin/sh"
                    echo "# Temporary zbx config for doctor diagnostics"
                    echo "export ZABBIX_URL='${ZABBIX_URL:-}'"
                    if [ -n "${ZABBIX_API_TOKEN:-}" ]; then
                        echo "export ZABBIX_API_TOKEN='${ZABBIX_API_TOKEN}'"
                    else
                        echo "export ZABBIX_USER='${ZABBIX_USER:-}'"
                        # zbx uses ZABBIX_PASS, not ZABBIX_PASSWORD
                        echo "export ZABBIX_PASS='${ZABBIX_PASSWORD:-}'"
                    fi
                    # Map VERIFY_SSL to ZABBIX_VERIFY_TLS (zbx expects 0 or 1)
                    if [ "${VERIFY_SSL:-true}" = "false" ]; then
                        echo "export ZABBIX_VERIFY_TLS=0"
                    else
                        echo "export ZABBIX_VERIFY_TLS=1"
                    fi
                    echo "export ZABBIX_CURL_TIMEOUT=30"
                } > "${temp_zbx_config}"
                chmod +x "${temp_zbx_config}"

                export ZBX_CONFIG="${temp_zbx_config}"

                printf "Using temporary config: %s\n" "${temp_zbx_config}"
                printf "%s\n" "----------------------------------------"

                # Run doctor command with our config via environment variable
                zbx doctor 2>&1 || printf "zbx doctor command failed with exit code: $?\n"
                printf "%s\n" "----------------------------------------"

                # Also show zbx config if available
                printf "\n%bZabbix CLI Configuration:%b\n" "${CYAN}" "${NC}"
                printf "Running: zbx config list\n"
                printf "%s\n" "----------------------------------------"
                zbx config list 2>&1 || printf "zbx config list failed with exit code: $?\n"
                printf "%s\n" "----------------------------------------"

                # Clean up temp config
                rm -f "${temp_zbx_config}"
                unset ZBX_CONFIG
            else
                printf "\nzbx CLI not found - skipping doctor check\n"
            fi

            # Run topdesk diagnostics if available
            if command -v topdesk >/dev/null 2>&1; then
                printf "\n%bTopdesk CLI Diagnostics:%b\n" "${CYAN}" "${NC}"

                # Create temporary config file for topdesk diagnostics (similar to zbx approach)
                local temp_td_config="${TMP_DIR:-/tmp}/topdesk_doctor_$$.sh"
                {
                    echo "#!/bin/sh"
                    echo "# Temporary topdesk config for diagnostics"
                    echo "export TOPDESK_URL='${TOPDESK_URL:-}'"
                    if [ -n "${TOPDESK_API_TOKEN:-}" ]; then
                        echo "export TOPDESK_API_TOKEN='${TOPDESK_API_TOKEN}'"
                    else
                        echo "export TOPDESK_USER='${TOPDESK_USER:-}'"
                        echo "export TOPDESK_PASSWORD='${TOPDESK_PASSWORD:-}'"
                    fi
                    # Map VERIFY_SSL to TOPDESK_VERIFY_SSL (use same format as engine config)
                    if [ "${VERIFY_SSL:-true}" = "false" ]; then
                        echo "export TOPDESK_VERIFY_SSL=false"
                    else
                        echo "export TOPDESK_VERIFY_SSL=true"
                    fi
                    # Use configured timeout or default to 30
                    echo "export TOPDESK_TIMEOUT=${TOPDESK_TIMEOUT:-${CONNECT_TIMEOUT:-30}}"
                } > "${temp_td_config}"
                chmod +x "${temp_td_config}"

                # Set config if supported, otherwise just export variables
                export TOPDESK_CONFIG="${temp_td_config}"

                # Also export directly for compatibility
                export TOPDESK_URL="${TOPDESK_URL:-}"
                export TOPDESK_USER="${TOPDESK_USER:-}"
                export TOPDESK_PASSWORD="${TOPDESK_PASSWORD:-}"
                export TOPDESK_API_TOKEN="${TOPDESK_API_TOKEN:-}"

                # Try various diagnostic commands
                # First check which commands are available
                local topdesk_has_doctor=0
                local topdesk_has_config=0
                local topdesk_has_test=0

                if topdesk doctor --help >/dev/null 2>&1; then
                    topdesk_has_doctor=1
                fi
                if topdesk config --help >/dev/null 2>&1; then
                    topdesk_has_config=1
                fi
                if topdesk test --help >/dev/null 2>&1; then
                    topdesk_has_test=1
                fi

                if [ $topdesk_has_doctor -eq 1 ]; then
                    printf "Running: topdesk doctor\n"
                    printf "%s\n" "----------------------------------------"
                    topdesk doctor 2>&1 || printf "topdesk doctor failed with exit code: $?\n"
                    printf "%s\n" "----------------------------------------"
                fi

                if [ $topdesk_has_config -eq 1 ]; then
                    printf "\nRunning: topdesk config\n"
                    printf "%s\n" "----------------------------------------"
                    topdesk config 2>&1 || printf "topdesk config failed with exit code: $?\n"
                    printf "%s\n" "----------------------------------------"
                fi

                if [ $topdesk_has_test -eq 1 ]; then
                    printf "\nRunning: topdesk test\n"
                    printf "%s\n" "----------------------------------------"
                    topdesk test 2>&1 || printf "topdesk test failed with exit code: $?\n"
                    printf "%s\n" "----------------------------------------"
                fi

                if [ $topdesk_has_doctor -eq 0 ] && [ $topdesk_has_config -eq 0 ] && [ $topdesk_has_test -eq 0 ]; then
                    printf "No diagnostic commands available for topdesk CLI\n"
                    printf "Trying: topdesk --version\n"
                    printf "%s\n" "----------------------------------------"
                    topdesk --version 2>&1 || printf "topdesk version check failed\n"
                    printf "%s\n" "----------------------------------------"
                fi

                # Always show our Topdesk configuration for debugging
                printf "\n%bTopdesk Configuration (from asset-merger-engine):%b\n" "${CYAN}" "${NC}"
                printf "Using temporary config: %s\n" "${temp_td_config}"
                printf "%s\n" "----------------------------------------"
                printf "TOPDESK_URL=%s\n" "${TOPDESK_URL:-}"
                printf "TOPDESK_USER=%s\n" "${TOPDESK_USER:-}"
                if [ -n "${TOPDESK_PASSWORD:-}" ]; then
                    # Mask password like zbx does
                    local masked_pass=$(printf "%s" "${TOPDESK_PASSWORD}" | sed 's/^\(...\).*/\1***/')
                    printf "TOPDESK_PASSWORD=%s\n" "${masked_pass}"
                else
                    printf "TOPDESK_PASSWORD=\n"
                fi
                printf "TOPDESK_API_TOKEN=%s\n" "${TOPDESK_API_TOKEN:-}"
                if [ "${VERIFY_SSL:-true}" = "false" ]; then
                    printf "TOPDESK_VERIFY_SSL=false\n"
                else
                    printf "TOPDESK_VERIFY_SSL=true\n"
                fi
                printf "TOPDESK_TIMEOUT=%s\n" "${TOPDESK_TIMEOUT:-${CONNECT_TIMEOUT:-30}}"
                printf "%s\n" "----------------------------------------"

                # Clean up temp config
                rm -f "${temp_td_config}"
                unset TOPDESK_CONFIG
            else
                printf "\ntopdesk CLI not found - skipping diagnostic check\n"
            fi

            printf "\n"
        fi
    fi

    # Use Python validator for detailed validation
    if [ -f "${VALIDATOR_MODULE}" ]; then
        printf "\n"
        printf "Running detailed validation...\n"
        python3 "${VALIDATOR_MODULE}" \
            --config "${CONFIG_FILE}" \
            --output "${VALIDATION_REPORT}" || {
            log_error "Detailed validation failed"
        }

        if [ -f "${VALIDATION_REPORT}" ]; then
            printf "\n"
            printf "Validation report: %s\n" "${VALIDATION_REPORT}"
        fi
    fi

    printf "\n"
    printf "%bValidation completed%b\n" "${GREEN}" "${NC}"

    log_info "Validation completed"
    return 0
}

# Command: status
cmd_status() {
    echo "${BOLD}Asset Merger Engine Status${NC}"
    echo ""

    # Check if running
    if [ -f "${PID_FILE}" ]; then
        local pid=$(cat "${PID_FILE}")
        if kill -0 "${pid}" 2>/dev/null; then
            echo "Status: ${GREEN}RUNNING${NC} (PID: ${pid})"
        else
            echo "Status: ${YELLOW}STOPPED${NC} (stale PID file)"
        fi
    else
        echo "Status: ${YELLOW}STOPPED${NC}"
    fi

    echo ""

    # Show file timestamps
    echo "${BOLD}Data Files:${NC}"
    for file in "${ZABBIX_DATA_FILE}" "${TOPDESK_DATA_FILE}" "${DIFF_REPORT_FILE}" "${APPLY_QUEUE_FILE}"; do
        if [ -f "${file}" ]; then
            local timestamp=$(date -r "${file}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date "+%Y-%m-%d %H:%M:%S" -d "@$(stat -c %Y "${file}")" 2>/dev/null)
            local size=$(du -h "${file}" | cut -f1)
            printf "  %-40s ${GREEN}EXISTS${NC} (%s, %s)\n" "$(basename "${file}")" "${size}" "${timestamp}"
        else
            printf "  %-40s ${YELLOW}NOT FOUND${NC}\n" "$(basename "${file}")"
        fi
    done

    echo ""

    # Show log tail
    if [ -f "${LOG_FILE}" ]; then
        echo "${BOLD}Recent Log Entries:${NC}"
        tail -5 "${LOG_FILE}" | sed 's/^/  /'
    fi

    echo ""

    # Show cache status
    if [ -d "${DEFAULT_CACHE_DIR}" ]; then
        local cache_count=$(find "${DEFAULT_CACHE_DIR}" -type f | wc -l)
        local cache_size=$(du -sh "${DEFAULT_CACHE_DIR}" 2>/dev/null | cut -f1)
        echo "${BOLD}Cache:${NC} ${cache_count} files (${cache_size:-0})"
    fi

    return 0
}

# Command: report
cmd_report() {
    log_info "Generating synchronization report..."

    local report_file="${OUTPUT_DIR}/reports/sync_report_$(date +%Y%m%d_%H%M%S).html"
    mkdir -p "$(dirname "${report_file}")"

    # Generate HTML report
    cat > "${report_file}" << 'EOHTML'
<!DOCTYPE html>
<html>
<head>
    <title>Synchronization Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        .summary { background: #f0f0f0; padding: 15px; border-radius: 5px; }
        .success { color: green; }
        .warning { color: orange; }
        .error { color: red; }
        table { border-collapse: collapse; width: 100%; margin-top: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #4CAF50; color: white; }
    </style>
</head>
<body>
    <h1>Asset Merger Engine Synchronization Report</h1>
EOHTML

    echo "    <div class='summary'>" >> "${report_file}"
    echo "        <h2>Summary</h2>" >> "${report_file}"
    echo "        <p>Generated: $(date)</p>" >> "${report_file}"
    echo "        <p>Version: ${SCRIPT_VERSION}</p>" >> "${report_file}"

    # Add statistics if available
    if [ -f "${OUTPUT_DIR}/apply/results.json" ]; then
        local success=$(jq '.summary.successful' "${OUTPUT_DIR}/apply/results.json" 2>/dev/null || echo "0")
        local failed=$(jq '.summary.failed' "${OUTPUT_DIR}/apply/results.json" 2>/dev/null || echo "0")
        echo "        <p>Successful Updates: <span class='success'>${success}</span></p>" >> "${report_file}"
        echo "        <p>Failed Updates: <span class='error'>${failed}</span></p>" >> "${report_file}"
    fi

    echo "    </div>" >> "${report_file}"
    echo "</body></html>" >> "${report_file}"

    log_info "Report generated: ${report_file}"
    echo "Report saved to: ${report_file}"

    return 0
}

# Command: health (comprehensive health check)
cmd_health() {
    log_info "=== Running Comprehensive Health Check ==="

    local health_score=0
    local max_score=10

    echo "System Health Check" || return 1
    echo "==================" || return 1
    echo "" || return 1

    # 1. Configuration
    printf "1. Configuration Status: "
    if [ -f "${CONFIG_FILE}" ]; then
        if [ -r "${CONFIG_FILE}" ]; then
            echo "[OK]"
            health_score=$((health_score + 1))
        else
            echo "[ERROR]"
        fi
    else
        echo "[MISSING]"
    fi

    # 2. Required directories
    printf "2. Directory Structure: "
    local dirs_ok=1
    for dir in "${LIB_DIR}" "${BIN_DIR}" "${OUTPUT_DIR}" "${VAR_DIR}"; do
        if [ ! -d "${dir}" ]; then
            dirs_ok=0
            break
        fi
    done
    if [ ${dirs_ok} -eq 1 ]; then
        echo "[OK]"
        health_score=$((health_score + 1))
    else
        echo "[ERROR]"
    fi

    # 3. Component modules
    printf "3. Core Modules: "
    local modules_ok=1
    for module in "${DATAFETCHER_MODULE}" "${VALIDATOR_MODULE}" "${SORTER_MODULE}" \
                  "${APPLY_MODULE}" "${LOGGER_MODULE}" "${TUI_MODULE}"; do
        if [ ! -f "${module}" ]; then
            modules_ok=0
            break
        fi
    done
    if [ ${modules_ok} -eq 1 ]; then
        echo "[OK]"
        health_score=$((health_score + 1))
    else
        echo "[ERROR]"
    fi

    # 4. Python runtime
    printf "4. Python Runtime: "
    if command -v python3 >/dev/null 2>&1; then
        local py_version=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))' 2>/dev/null)
        if [ -n "${py_version}" ]; then
            echo "[OK] v${py_version}"
            health_score=$((health_score + 1))
        else
            echo "[WARNING] Unknown version"
        fi
    else
        echo "[ERROR] Not found"
    fi

    # 5. Required tools
    printf "5. Required Tools: "
    local tools_missing=""
    for tool in jq curl; do
        if ! command -v "${tool}" >/dev/null 2>&1; then
            tools_missing="${tools_missing} ${tool}"
        fi
    done
    if [ -z "${tools_missing}" ]; then
        echo "[OK]"
        health_score=$((health_score + 1))
    else
        echo "[ERROR] Missing:${tools_missing}"
    fi

    # 6. CLI tools
    printf "6. CLI Tools: "
    local has_zbx=0
    local has_td=0
    command -v zbx >/dev/null 2>&1 && has_zbx=1
    command -v topdesk >/dev/null 2>&1 && has_td=1

    if [ ${has_zbx} -eq 1 ] && [ ${has_td} -eq 1 ]; then
        echo "[OK] Both available"
        health_score=$((health_score + 1))
    elif [ ${has_zbx} -eq 1 ] || [ ${has_td} -eq 1 ]; then
        echo "[WARNING] Partial"
    else
        echo "[INFO] Using API fallback"
    fi

    # 7. Disk space
    printf "7. Disk Space: "
    local available_space=$(df -k "${PROJECT_ROOT}" | awk 'NR==2 {print int($4/1024)}')
    if [ ${available_space} -gt 100 ]; then
        echo "[OK] ${available_space}MB free"
        health_score=$((health_score + 1))
    else
        echo "[WARNING] Low: ${available_space}MB"
    fi

    # 8. Log system
    printf "8. Logging System: "
    if [ -w "${LOG_FILE}" ] || [ -w "$(dirname "${LOG_FILE}")" ]; then
        echo "[OK]"
        health_score=$((health_score + 1))
    else
        echo "[ERROR] Not writable"
    fi

    # 9. Cache status
    printf "9. Cache Status: "
    if [ -d "${DEFAULT_CACHE_DIR}" ]; then
        local cache_files=$(find "${DEFAULT_CACHE_DIR}" -type f 2>/dev/null | wc -l | tr -d ' ')
        echo "[OK] ${cache_files} files"
        health_score=$((health_score + 1))
    else
        echo "[WARNING] Not initialized"
    fi

    # 10. Last sync status
    printf "10. Last Sync: "
    if [ -f "${OUTPUT_DIR}/apply/results.json" ]; then
        local last_mod=$(stat -f %m "${OUTPUT_DIR}/apply/results.json" 2>/dev/null || \
                        stat -c %Y "${OUTPUT_DIR}/apply/results.json" 2>/dev/null)
        if [ -n "${last_mod}" ]; then
            local age_hours=$(( ($(date +%s) - last_mod) / 3600 ))
            echo "${age_hours}h ago"
            health_score=$((health_score + 1))
        else
            echo "Unknown"
        fi
    else
        echo "Never run"
    fi

    # Overall score
    echo ""
    echo "Overall Health Score: ${health_score}/${max_score}"
    echo ""

    # Health status interpretation
    if [ ${health_score} -ge 9 ]; then
        echo "Status: EXCELLENT - System fully operational"
    elif [ ${health_score} -ge 7 ]; then
        echo "Status: GOOD - System operational"
    elif [ ${health_score} -ge 5 ]; then
        echo "Status: FAIR - Some issues detected"
    else
        echo "Status: POOR - Multiple issues require attention"
    fi

    echo ""

    # Recommendations
    if [ ${health_score} -lt ${max_score} ]; then
        echo "Recommendations:"

        if [ ! -f "${CONFIG_FILE}" ]; then
            echo "  - Run 'validate' to create default configuration"
        fi

        if [ ${modules_ok} -eq 0 ]; then
            echo "  - Check module files in ${LIB_DIR}"
        fi

        if [ -n "${tools_missing}" ]; then
            echo "  - Install missing tools:${tools_missing}"
        fi

        if [ ${has_zbx} -eq 0 ]; then
            echo "  - Make sure zbx command is in your PATH"
        fi

        if [ ${has_td} -eq 0 ]; then
            echo "  - Make sure topdesk command is in your PATH"
        fi

        echo ""
    fi

    log_info "Health check completed (score: ${health_score}/${max_score})"
    return 0
}

# Command: profile
cmd_profile() {
    # Source the profile manager
    if [ -f "${LIB_DIR}/profile_manager.sh" ]; then
        . "${LIB_DIR}/profile_manager.sh"
    else
        log_error "Profile manager module not found: ${LIB_DIR}/profile_manager.sh"
        return 5
    fi

    # Get subcommand
    local subcommand="${1:-list}"
    shift 2>/dev/null || true

    case "${subcommand}" in
        create)
            if [ -z "$1" ]; then
                echo "Error: Profile name required" >&2
                echo "Usage: ${SCRIPT_NAME} profile create NAME [OPTIONS]" >&2
                return 1
            fi
            create_profile "$@"
            ;;
        edit)
            if [ -z "$1" ]; then
                echo "Error: Profile name required" >&2
                echo "Usage: ${SCRIPT_NAME} profile edit NAME [OPTIONS]" >&2
                return 1
            fi
            edit_profile "$@"
            ;;
        list)
            list_profiles "${1:-0}"
            ;;
        show)
            if [ -z "$1" ]; then
                echo "Error: Profile name required" >&2
                echo "Usage: ${SCRIPT_NAME} profile show NAME" >&2
                return 1
            fi
            show_profile "$1"
            ;;
        delete)
            if [ -z "$1" ]; then
                echo "Error: Profile name required" >&2
                echo "Usage: ${SCRIPT_NAME} profile delete NAME" >&2
                return 1
            fi
            delete_profile "$1" "${2:-0}"
            ;;
        copy)
            if [ -z "$1" ] || [ -z "$2" ]; then
                echo "Error: Source and destination names required" >&2
                echo "Usage: ${SCRIPT_NAME} profile copy SOURCE DEST" >&2
                return 1
            fi
            copy_profile "$1" "$2"
            ;;
        validate)
            if [ -z "$1" ]; then
                echo "Error: Profile name required" >&2
                echo "Usage: ${SCRIPT_NAME} profile validate NAME" >&2
                return 1
            fi
            validate_profile "$1"
            ;;
        export)
            if [ -z "$1" ]; then
                echo "Error: Profile name required" >&2
                echo "Usage: ${SCRIPT_NAME} profile export NAME [FILE]" >&2
                return 1
            fi
            export_profile "$1" "$2"
            ;;
        import)
            if [ -z "$1" ]; then
                echo "Error: Import file required" >&2
                echo "Usage: ${SCRIPT_NAME} profile import FILE [NAME]" >&2
                return 1
            fi
            import_profile "$1" "$2"
            ;;
        wizard|interactive)
            # Launch the profile wizard
            if [ -x "${BIN_DIR}/profile_wizard.sh" ]; then
                "${BIN_DIR}/profile_wizard.sh"
            elif [ -x "${LIB_DIR}/profile_wizard.sh" ]; then
                "${LIB_DIR}/profile_wizard.sh"
            else
                echo "Error: Profile wizard not found" >&2
                return 5
            fi
            ;;
        help|--help|-h)
            echo "Profile Management Commands:"
            echo ""
            echo "  create NAME [OPTIONS]  Create a new profile"
            echo "  edit NAME [OPTIONS]    Edit an existing profile"
            echo "  list [--verbose]       List all profiles"
            echo "  show NAME              Show profile details"
            echo "  delete NAME [--force]  Delete a profile"
            echo "  copy SOURCE DEST       Copy a profile"
            echo "  validate NAME          Validate a profile"
            echo "  export NAME [FILE]     Export profile to file"
            echo "  import FILE [NAME]     Import profile from file"
            echo "  wizard                 Launch interactive wizard"
            echo ""
            echo "Create Options:"
            echo "  --template TEMPLATE    Use template (production/staging/development/audit)"
            echo "  --strategy STRATEGY    Set merge strategy (update/create/sync)"
            echo "  --conflict RESOLUTION  Set conflict resolution (zabbix/topdesk/manual/newest)"
            echo "  --batch-size SIZE      Set batch size"
            echo "  --workers N            Set max workers"
            echo "  --dry-run true/false   Enable/disable dry run"
            echo "  --set KEY=VALUE        Set custom configuration"
            ;;
        *)
            echo "Unknown subcommand: ${subcommand}" >&2
            echo "Run '${SCRIPT_NAME} profile help' for usage" >&2
            return 1
            ;;
    esac
}

# Command: clean
cmd_clean() {
    log_info "Cleaning temporary and cache files..."

    echo -n "Clean cache files? [y/N] "
    read -r response
    case "${response}" in
        [yY][eE][sS]|[yY])
            rm -rf "${DEFAULT_CACHE_DIR}"/*
            echo "Cache cleaned"
            ;;
    esac

    echo -n "Clean temporary files? [y/N] "
    read -r response
    case "${response}" in
        [yY][eE][sS]|[yY])
            rm -rf "${TMP_DIR}"/*
            echo "Temporary files cleaned"
            ;;
    esac

    echo -n "Clean output files? [y/N] "
    read -r response
    case "${response}" in
        [yY][eE][sS]|[yY])
            rm -f "${OUTPUT_DIR}"/*.json
            rm -rf "${OUTPUT_DIR}/differences"/*
            rm -rf "${OUTPUT_DIR}/apply"/*
            echo "Output files cleaned"
            ;;
    esac

    log_info "Cleanup completed"
    return 0
}

# Main execution
main() {
    # Set up signal handlers - moved after environment init
    # trap cleanup EXIT INT TERM

    # Parse global options
    while [ $# -gt 0 ]; do
        case "$1" in
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -l|--log)
                LOG_FILE="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -d|--debug)
                DEBUG=1
                VERBOSE=1
                set -x  # Enable shell debugging
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=1
                shift
                ;;
            -f|--force)
                FORCE=1
                shift
                ;;
            -i|--interactive)
                INTERACTIVE=1
                shift
                ;;
            -b|--batch)
                INTERACTIVE=0
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -V|--version)
                version
                exit 0
                ;;
            -*)
                echo "Unknown option: $1" >&2
                usage
                exit 1
                ;;
            *)
                break
                ;;
        esac
    done

    # Check for command
    if [ $# -eq 0 ]; then
        usage
        exit 1
    fi

    COMMAND="$1"
    shift

    # Initialize environment
    init_environment || exit 1

    # Set up signal handlers after environment is ready
    trap cleanup EXIT INT TERM

    # Execute command
    case "${COMMAND}" in
        fetch)
            cmd_fetch "$@"
            ;;
        diff)
            cmd_diff "$@"
            ;;
        tui)
            cmd_tui "$@"
            ;;
        apply)
            cmd_apply "$@"
            ;;
        sync)
            cmd_sync "$@"
            ;;
        validate)
            cmd_validate "$@"
            ;;
        health)
            cmd_health "$@"
            ;;
        status)
            cmd_status "$@"
            ;;
        report)
            cmd_report "$@"
            ;;
        clean)
            cmd_clean "$@"
            ;;
        profile)
            cmd_profile "$@"
            ;;
        *)
            echo "Unknown command: ${COMMAND}" >&2
            usage
            exit 1
            ;;
    esac

    exit $?
}

# Run main function with all arguments
main "$@"