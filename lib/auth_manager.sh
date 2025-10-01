#!/bin/sh
# auth_manager.sh - Authentication and session management for CLI tools

# Configuration
AUTH_DIR="${AUTH_DIR:-${HOME}/.config/asset-merger-engine}"
AUTH_CACHE_TTL="${AUTH_CACHE_TTL:-3600}"  # Session TTL in seconds (1 hour)
LOG_FILE="${LOG_FILE:-/tmp/asset-merger-engine/merger.log}"

# Initialize authentication directory
init_auth_dir() {
    mkdir -p "$AUTH_DIR" || {
        log_error "Failed to create auth directory: $AUTH_DIR"
        return 1
    }
    chmod 700 "$AUTH_DIR"  # Secure the directory
}

# Detect available Zabbix CLI command
detect_zbx_command() {
    if command -v "zbx" >/dev/null 2>&1; then
        echo "zbx"
        return 0
    fi
    return 1
}

# Zabbix authentication
authenticate_zabbix() {
    local server="${ZABBIX_SERVER:-}"
    local username="${ZABBIX_USER:-}"
    local password="${ZABBIX_PASS:-}"
    local config_file="${ZABBIX_CONFIG:-${AUTH_DIR}/zbx-cli.conf}"
    local session_file="${AUTH_DIR}/.zbx_session"

    # Detect zbx command
    local zbx_cmd="$(detect_zbx_command)"
    if [ -z "$zbx_cmd" ]; then
        log_error "No Zabbix CLI command found (zbx)"
        log_error "Please ensure 'zbx' command is installed and in PATH"
        return 1
    fi
    export ZBX_CLI_COMMAND="$zbx_cmd"

    # Check for required parameters
    if [ -z "$server" ] || [ -z "$username" ] || [ -z "$password" ]; then
        # Try to read from config file
        if [ -f "$config_file" ]; then
            log_debug "Using Zabbix config from $config_file"
            export ZBX_CLI_CONFIG="$config_file"
            return 0
        else
            log_error "Zabbix authentication requires ZABBIX_SERVER, ZABBIX_USER, and ZABBIX_PASS"
            return 1
        fi
    fi

    # Check existing session
    if [ -f "$session_file" ]; then
        local session_age=$(($(date +%s) - $(stat -f %m "$session_file" 2>/dev/null || stat -c %Y "$session_file" 2>/dev/null || echo 0)))
        if [ "$session_age" -lt "$AUTH_CACHE_TTL" ]; then
            log_debug "Using cached Zabbix session"
            export ZBX_SESSION=$(cat "$session_file")
            return 0
        fi
    fi

    log_info "Authenticating with Zabbix server: $server"

    # Create config file if it doesn't exist
    if [ ! -f "$config_file" ]; then
        cat > "$config_file" <<EOF
[zabbix]
server = $server
username = $username
password = $password
verify_ssl = true
timeout = 30

[output]
format = json
EOF
        chmod 600 "$config_file"
        log_debug "Created Zabbix config file: $config_file"
    fi

    # Test authentication
    if $zbx_cmd --config "$config_file" host list --limit 1 >/dev/null 2>&1; then
        log_info "Zabbix authentication successful"
        touch "$session_file"
        export ZBX_CLI_CONFIG="$config_file"
        return 0
    else
        log_error "Zabbix authentication failed"
        rm -f "$session_file"
        return 1
    fi
}

# Detect available Topdesk CLI command
detect_topdesk_command() {
    if command -v "topdesk" >/dev/null 2>&1; then
        echo "topdesk"
        return 0
    fi
    return 1
}

# Topdesk authentication
authenticate_topdesk() {
    local url="${TOPDESK_URL:-}"
    local username="${TOPDESK_USER:-}"
    local password="${TOPDESK_PASS:-}"
    local api_key="${TOPDESK_API_KEY:-}"
    local config_file="${TOPDESK_CONFIG:-${AUTH_DIR}/topdesk-cli.conf}"
    local session_file="${AUTH_DIR}/.topdesk_session"

    # Detect topdesk command
    local td_cmd="$(detect_topdesk_command)"
    if [ -z "$td_cmd" ]; then
        log_error "No Topdesk CLI command found (topdesk)"
        log_error "Please ensure 'topdesk' command is installed and in PATH"
        return 1
    fi
    export TOPDESK_CLI_COMMAND="$td_cmd"

    # Check for required parameters
    if [ -z "$url" ]; then
        # Try to read from config file
        if [ -f "$config_file" ]; then
            log_debug "Using Topdesk config from $config_file"
            export TOPDESK_CLI_CONFIG="$config_file"
            return 0
        else
            log_error "Topdesk authentication requires TOPDESK_URL and credentials"
            return 1
        fi
    fi

    # Check existing session
    if [ -f "$session_file" ]; then
        local session_age=$(($(date +%s) - $(stat -f %m "$session_file" 2>/dev/null || stat -c %Y "$session_file" 2>/dev/null || echo 0)))
        if [ "$session_age" -lt "$AUTH_CACHE_TTL" ]; then
            log_debug "Using cached Topdesk session"
            export TOPDESK_SESSION=$(cat "$session_file")
            return 0
        fi
    fi

    log_info "Authenticating with Topdesk: $url"

    # Create config file if it doesn't exist
    if [ ! -f "$config_file" ]; then
        if [ -n "$api_key" ]; then
            # API key authentication
            cat > "$config_file" <<EOF
[topdesk]
url = $url
api_key = $api_key
verify_ssl = true
timeout = 30

[output]
format = json
EOF
        elif [ -n "$username" ] && [ -n "$password" ]; then
            # Username/password authentication
            cat > "$config_file" <<EOF
[topdesk]
url = $url
username = $username
password = $password
verify_ssl = true
timeout = 30

[output]
format = json
EOF
        else
            log_error "Topdesk authentication requires either API_KEY or USER/PASS"
            return 1
        fi
        chmod 600 "$config_file"
        log_debug "Created Topdesk config file: $config_file"
    fi

    # Test authentication
    if $td_cmd --config "$config_file" assets list --limit 1 >/dev/null 2>&1; then
        log_info "Topdesk authentication successful"
        touch "$session_file"
        export TOPDESK_CLI_CONFIG="$config_file"
        return 0
    else
        log_error "Topdesk authentication failed"
        rm -f "$session_file"
        return 1
    fi
}

# Refresh all sessions
refresh_sessions() {
    log_info "Refreshing authentication sessions"

    local zabbix_result=0
    local topdesk_result=0

    # Force refresh by removing session files
    rm -f "${AUTH_DIR}/.zbx_session" "${AUTH_DIR}/.topdesk_session"

    if authenticate_zabbix; then
        log_info "Zabbix session refreshed"
    else
        log_warning "Failed to refresh Zabbix session"
        zabbix_result=1
    fi

    if authenticate_topdesk; then
        log_info "Topdesk session refreshed"
    else
        log_warning "Failed to refresh Topdesk session"
        topdesk_result=1
    fi

    return $((zabbix_result + topdesk_result))
}

# Clear all authentication data
clear_auth() {
    log_info "Clearing authentication data"
    rm -f "${AUTH_DIR}"/.zbx_session "${AUTH_DIR}"/.topdesk_session
    unset ZBX_CLI_CONFIG ZBX_SESSION TOPDESK_CLI_CONFIG TOPDESK_SESSION
    log_info "Authentication data cleared"
}

# Setup authentication from environment or config file
setup_auth() {
    local config_file="${1:-${AUTH_DIR}/merger.conf}"

    # Load config file if it exists
    if [ -f "$config_file" ]; then
        log_debug "Loading configuration from $config_file"
        . "$config_file"
    fi

    # Initialize directory
    init_auth_dir || return 1

    # Authenticate both systems
    local errors=0

    if ! authenticate_zabbix; then
        log_error "Zabbix authentication setup failed"
        errors=$((errors + 1))
    fi

    if ! authenticate_topdesk; then
        log_error "Topdesk authentication setup failed"
        errors=$((errors + 1))
    fi

    if [ "$errors" -gt 0 ]; then
        log_error "Authentication setup completed with $errors error(s)"
        return 1
    fi

    log_info "Authentication setup completed successfully"
    return 0
}

# Store credentials securely
store_credentials() {
    local system="$1"
    local config_file="${AUTH_DIR}/${system}-credentials.enc"

    echo "Enter credentials for $system:"

    case "$system" in
        zabbix)
            printf "Server URL: "
            read -r server
            printf "Username: "
            read -r username
            printf "Password: "
            stty -echo
            read -r password
            stty echo
            echo

            # Store encrypted (base64 for simplicity, use GPG for production)
            {
                echo "ZABBIX_SERVER='$server'"
                echo "ZABBIX_USER='$username'"
                echo "ZABBIX_PASS='$password'"
            } | base64 > "$config_file"
            ;;

        topdesk)
            printf "Server URL: "
            read -r url
            printf "Use API key? (y/n): "
            read -r use_api_key

            if [ "$use_api_key" = "y" ]; then
                printf "API Key: "
                stty -echo
                read -r api_key
                stty echo
                echo

                {
                    echo "TOPDESK_URL='$url'"
                    echo "TOPDESK_API_KEY='$api_key'"
                } | base64 > "$config_file"
            else
                printf "Username: "
                read -r username
                printf "Password: "
                stty -echo
                read -r password
                stty echo
                echo

                {
                    echo "TOPDESK_URL='$url'"
                    echo "TOPDESK_USER='$username'"
                    echo "TOPDESK_PASS='$password'"
                } | base64 > "$config_file"
            fi
            ;;

        *)
            echo "Unknown system: $system" >&2
            return 1
            ;;
    esac

    chmod 600 "$config_file"
    echo "Credentials stored in $config_file"
}

# Load stored credentials
load_credentials() {
    local system="$1"
    local config_file="${AUTH_DIR}/${system}-credentials.enc"

    if [ ! -f "$config_file" ]; then
        log_error "No stored credentials for $system"
        return 1
    fi

    # Decrypt and load (base64 for simplicity, use GPG for production)
    eval "$(base64 -d < "$config_file")"
    log_debug "Loaded credentials for $system"
}

# Main function for standalone execution
main() {
    local action="${1:-setup}"
    shift

    case "$action" in
        setup)
            setup_auth "$@"
            ;;
        refresh)
            refresh_sessions
            ;;
        clear)
            clear_auth
            ;;
        store)
            store_credentials "$@"
            ;;
        load)
            load_credentials "$@"
            ;;
        *)
            echo "Usage: $0 {setup|refresh|clear|store|load} [options]" >&2
            echo "  setup [config_file]  - Setup authentication for both systems" >&2
            echo "  refresh              - Refresh all sessions" >&2
            echo "  clear                - Clear all authentication data" >&2
            echo "  store <system>       - Store credentials for system" >&2
            echo "  load <system>        - Load stored credentials" >&2
            exit 1
            ;;
    esac
}

# Run main if executed directly
if [ "${0##*/}" = "auth_manager.sh" ]; then
    # Source logging functions
    . "$(dirname "$0")/common.sh" 2>/dev/null || {
        log_info() { echo "[INFO] $*"; }
        log_error() { echo "[ERROR] $*" >&2; }
        log_warning() { echo "[WARN] $*" >&2; }
        log_debug() { [ -n "$DEBUG" ] && echo "[DEBUG] $*" >&2; }
    }
    main "$@"
fi