#!/bin/sh
# common.sh - Common functions and utilities for topdesk-zbx-merger
# POSIX-compliant shared library

# JSON manipulation functions (using jq)
# ---------------------------------------

# Extract value from JSON by key path
json_get() {
    local json="$1"
    local path="$2"
    printf '%s' "${json}" | jq -r "${path}" 2>/dev/null || echo ""
}

# Set value in JSON by key path
json_set() {
    local json="$1"
    local path="$2"
    local value="$3"
    printf '%s' "${json}" | jq "${path} = ${value}" 2>/dev/null
}

# Merge two JSON objects
json_merge() {
    local json1="$1"
    local json2="$2"
    printf '%s\n%s' "${json1}" "${json2}" | jq -s '.[0] * .[1]' 2>/dev/null
}

# Data validation functions
# -------------------------

# Validate IP address (IPv4)
is_valid_ipv4() {
    local ip="$1"
    local IFS='.'
    set -- $ip
    [ $# -eq 4 ] || return 1
    for octet; do
        case "${octet}" in
            ''|*[!0-9]*) return 1 ;;
            *) [ "${octet}" -le 255 ] || return 1 ;;
        esac
    done
    return 0
}

# Validate hostname
is_valid_hostname() {
    local hostname="$1"
    case "${hostname}" in
        *[!a-zA-Z0-9.-]*) return 1 ;;
        -*|*-) return 1 ;;
        *) return 0 ;;
    esac
}

# Validate email address (basic check)
is_valid_email() {
    local email="$1"
    case "${email}" in
        *@*.*) return 0 ;;
        *) return 1 ;;
    esac
}

# String manipulation functions
# -----------------------------

# Trim whitespace from string
trim() {
    local string="$1"
    # Remove leading whitespace
    string="${string#"${string%%[![:space:]]*}"}"
    # Remove trailing whitespace
    string="${string%"${string##*[![:space:]]}"}"
    printf '%s' "${string}"
}

# Convert string to lowercase
to_lower() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

# Convert string to uppercase
to_upper() {
    printf '%s' "$1" | tr '[:lower:]' '[:upper:]'
}

# Escape special characters for JSON
json_escape() {
    local string="$1"
    printf '%s' "${string}" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g; s/
/\\n/g; s//\\r/g'
}

# File and directory functions
# ----------------------------

# Create directory with parents if needed
ensure_dir() {
    local dir="$1"
    if [ ! -d "${dir}" ]; then
        mkdir -p "${dir}" || return 1
    fi
    return 0
}

# Safely create temporary file
create_temp_file() {
    local prefix="${1:-tmp}"
    local temp_dir="${TMP_DIR:-/tmp}"
    mktemp "${temp_dir}/${prefix}.XXXXXX"
}

# Clean up temporary files
cleanup_temp() {
    local pattern="${1:-tmp.*}"
    local temp_dir="${TMP_DIR:-/tmp}"
    find "${temp_dir}" -name "${pattern}" -type f -mtime +1 -delete 2>/dev/null
}

# Lock file management
# -------------------

# Acquire lock
acquire_lock() {
    local lock_file="$1"
    local max_wait="${2:-30}"
    local wait_time=0

    while [ -f "${lock_file}" ] && [ ${wait_time} -lt ${max_wait} ]; do
        sleep 1
        wait_time=$((wait_time + 1))
    done

    if [ -f "${lock_file}" ]; then
        return 1
    fi

    printf '%s' "$$" > "${lock_file}"
    return 0
}

# Release lock
release_lock() {
    local lock_file="$1"
    if [ -f "${lock_file}" ]; then
        rm -f "${lock_file}"
    fi
}

# Network functions
# ----------------

# Check if host is reachable
is_reachable() {
    local host="$1"
    local port="${2:-443}"
    local timeout="${3:-5}"

    if command -v nc > /dev/null 2>&1; then
        nc -z -w "${timeout}" "${host}" "${port}" 2>/dev/null
    elif command -v timeout > /dev/null 2>&1; then
        timeout "${timeout}" sh -c "echo > /dev/tcp/${host}/${port}" 2>/dev/null
    else
        ping -c 1 -W "${timeout}" "${host}" > /dev/null 2>&1
    fi
}

# Parse URL components
parse_url() {
    local url="$1"
    local component="${2:-host}"

    case "${component}" in
        protocol)
            printf '%s' "${url}" | sed -n 's/^\([^:]*\):\/\/.*/\1/p'
            ;;
        host)
            printf '%s' "${url}" | sed -n 's/^[^:]*:\/\/\([^:/]*\).*/\1/p'
            ;;
        port)
            printf '%s' "${url}" | sed -n 's/^[^:]*:\/\/[^:]*:\([0-9]*\).*/\1/p'
            ;;
        path)
            printf '%s' "${url}" | sed -n 's/^[^:]*:\/\/[^/]*\(.*\)/\1/p'
            ;;
    esac
}

# Date and time functions
# -----------------------

# Get current timestamp
timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Get epoch time
epoch() {
    date '+%s'
}

# Format duration from seconds
format_duration() {
    local seconds="$1"
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))

    printf '%02d:%02d:%02d' ${hours} ${minutes} ${secs}
}

# Logging functions
# -----------------

# Configure logging
LOG_FILE="${LOG_FILE:-/tmp/topdesk-zbx-merger/merger.log}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"
DEBUG="${DEBUG:-}"

# Ensure log directory exists
init_logging() {
    local log_dir="$(dirname "${LOG_FILE}")"
    ensure_dir "${log_dir}"
}

# Log message with level
log_message() {
    local level="$1"
    shift
    local message="$*"
    local timestamp="$(timestamp)"

    # Initialize logging if needed
    [ -d "$(dirname "${LOG_FILE}")" ] || init_logging

    # Write to log file
    printf '[%s] [%s] %s\n' "${timestamp}" "${level}" "${message}" >> "${LOG_FILE}"

    # Also output to stderr for errors and warnings
    case "${level}" in
        ERROR)
            printf '[ERROR] %s\n' "${message}" >&2
            ;;
        WARNING)
            printf '[WARN] %s\n' "${message}" >&2
            ;;
        INFO)
            [ -t 1 ] && printf '[INFO] %s\n' "${message}" || true
            ;;
        DEBUG)
            [ -n "${DEBUG}" ] && printf '[DEBUG] %s\n' "${message}" >&2 || true
            ;;
    esac

    return 0
}

# Convenience logging functions
log_debug() {
    log_message "DEBUG" "$@"
}

log_info() {
    log_message "INFO" "$@"
}

log_warning() {
    log_message "WARNING" "$@"
}

log_error() {
    log_message "ERROR" "$@"
}

# Error handling
# -------------

# Set error trap
set_error_trap() {
    trap 'error_handler $? $LINENO' ERR
}

# Error handler function
error_handler() {
    local exit_code="$1"
    local line_number="$2"
    log_error "Error occurred at line ${line_number} with exit code ${exit_code}"
}

# Retry command with exponential backoff
retry_command() {
    local max_attempts="${1:-3}"
    local delay="${2:-1}"
    shift 2
    local command="$*"
    local attempt=1

    while [ ${attempt} -le ${max_attempts} ]; do
        if eval "${command}"; then
            return 0
        fi

        if [ ${attempt} -lt ${max_attempts} ]; then
            sleep "${delay}"
            delay=$((delay * 2))
        fi
        attempt=$((attempt + 1))
    done

    return 1
}

# Cache management
# ---------------

# Get cached value
cache_get() {
    local key="$1"
    local cache_dir="${CACHE_DIR:-/tmp/cache}"
    local cache_file="${cache_dir}/${key}.cache"
    local ttl="${2:-3600}"

    if [ ! -f "${cache_file}" ]; then
        return 1
    fi

    local file_age=$(($(epoch) - $(stat -f '%m' "${cache_file}" 2>/dev/null || stat -c '%Y' "${cache_file}" 2>/dev/null)))

    if [ ${file_age} -gt ${ttl} ]; then
        rm -f "${cache_file}"
        return 1
    fi

    cat "${cache_file}"
    return 0
}

# Set cached value
cache_set() {
    local key="$1"
    local value="$2"
    local cache_dir="${CACHE_DIR:-/tmp/cache}"
    local cache_file="${cache_dir}/${key}.cache"

    ensure_dir "${cache_dir}"
    printf '%s' "${value}" > "${cache_file}"
}

# Clear cache
cache_clear() {
    local cache_dir="${CACHE_DIR:-/tmp/cache}"
    if [ -d "${cache_dir}" ]; then
        rm -rf "${cache_dir}"/*
    fi
}