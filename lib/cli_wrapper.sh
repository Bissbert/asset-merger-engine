#!/bin/sh
# cli_wrapper.sh - Unified CLI wrapper with fallback/mock support

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/common.sh" 2>/dev/null || true

# Configuration
MOCK_MODE="${MOCK_MODE:-auto}"  # auto, true, false
MOCK_DATA_DIR="${MOCK_DATA_DIR:-${SCRIPT_DIR}/../test/mock_data}"

# Detect if CLI tools are available
detect_cli_tools() {
    local zbx_found=0
    local td_found=0

    # Check for Zabbix CLI
    if command -v "zbx" >/dev/null 2>&1; then
        export ZBX_CLI_COMMAND="zbx"
        zbx_found=1
    fi

    # Check for Topdesk CLI
    if command -v "topdesk" >/dev/null 2>&1; then
        export TOPDESK_CLI_COMMAND="topdesk"
        td_found=1
    fi

    if [ "$MOCK_MODE" = "auto" ]; then
        if [ $zbx_found -eq 0 ] || [ $td_found -eq 0 ]; then
            export MOCK_MODE="true"
            log_warning "CLI tools not found, enabling mock mode"
        else
            export MOCK_MODE="false"
        fi
    fi
}

# Execute Zabbix command (with mock fallback)
zbx_execute_wrapper() {
    local command="$*"

    if [ "$MOCK_MODE" = "true" ]; then
        log_debug "Mock mode: zbx command: $command"
        generate_mock_zbx_data "$command"
    else
        local zbx_cmd="${ZBX_CLI_COMMAND:-zbx}"
        if ! command -v "$zbx_cmd" >/dev/null 2>&1; then
            log_error "Zabbix CLI not found and mock mode disabled"
            return 1
        fi

        # Source the actual wrapper
        . "${SCRIPT_DIR}/zbx_cli_wrapper.sh"
        zbx_execute "$command"
    fi
}

# Execute Topdesk command (with mock fallback)
td_execute_wrapper() {
    local command="$*"

    if [ "$MOCK_MODE" = "true" ]; then
        log_debug "Mock mode: topdesk command: $command"
        generate_mock_td_data "$command"
    else
        local td_cmd="${TOPDESK_CLI_COMMAND:-topdesk}"
        if ! command -v "$td_cmd" >/dev/null 2>&1; then
            log_error "Topdesk CLI not found and mock mode disabled"
            return 1
        fi

        # Source the actual wrapper
        . "${SCRIPT_DIR}/topdesk_cli_wrapper.sh"
        td_execute "$command"
    fi
}

# Generate mock Zabbix data
generate_mock_zbx_data() {
    local command="$1"

    cat <<'EOF'
{
  "result": [
    {
      "hostid": "10001",
      "host": "server01.example.com",
      "name": "Server 01",
      "status": "0",
      "description": "Production web server",
      "inventory": {
        "location": "DC1-Rack-A1",
        "serialno_a": "SRV2023001",
        "contact": "admin@example.com",
        "os": "Ubuntu 22.04 LTS"
      },
      "interfaces": [
        {
          "type": "1",
          "ip": "192.168.1.10",
          "dns": "server01.example.com",
          "port": "10050"
        }
      ]
    },
    {
      "hostid": "10002",
      "host": "server02.example.com",
      "name": "Server 02",
      "status": "0",
      "description": "Database server",
      "inventory": {
        "location": "DC1-Rack-A2",
        "serialno_a": "SRV2023002",
        "contact": "admin@example.com",
        "os": "RHEL 8.5"
      },
      "interfaces": [
        {
          "type": "1",
          "ip": "192.168.1.11",
          "dns": "server02.example.com",
          "port": "10050"
        }
      ]
    }
  ]
}
EOF
}

# Generate mock Topdesk data
generate_mock_td_data() {
    local command="$1"

    cat <<'EOF'
{
  "assets": [
    {
      "id": "TD-001",
      "unid": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      "name": "SERVER01",
      "type": "Server",
      "status": "Active",
      "location": "Data Center 1",
      "branch": {
        "name": "Main Office"
      },
      "specifications": {
        "model": "Dell PowerEdge R740",
        "cpu": "Intel Xeon Gold 6248",
        "memory": "128GB",
        "storage": "4TB SSD"
      },
      "serialNumber": "SRV2023001",
      "ipAddress": "192.168.1.10",
      "purchaseDate": "2023-01-15",
      "warrantyExpiryDate": "2026-01-15"
    },
    {
      "id": "TD-002",
      "unid": "b2c3d4e5-f6a7-8901-bcde-f12345678901",
      "name": "SERVER02",
      "type": "Server",
      "status": "Active",
      "location": "Data Center 1",
      "branch": {
        "name": "Main Office"
      },
      "specifications": {
        "model": "HP ProLiant DL380",
        "cpu": "Intel Xeon Gold 6242",
        "memory": "256GB",
        "storage": "8TB SSD"
      },
      "serialNumber": "SRV2023002",
      "ipAddress": "192.168.1.11",
      "purchaseDate": "2023-02-20",
      "warrantyExpiryDate": "2026-02-20"
    }
  ]
}
EOF
}

# Initialize wrapper
init_wrapper() {
    detect_cli_tools

    if [ "$MOCK_MODE" = "true" ]; then
        log_info "Running in MOCK mode (no actual CLI tools will be used)"
        log_info "To disable mock mode, set MOCK_MODE=false"
    else
        log_debug "Running in REAL mode with detected CLI tools"
        log_debug "Zabbix CLI: ${ZBX_CLI_COMMAND:-not found}"
        log_debug "Topdesk CLI: ${TOPDESK_CLI_COMMAND:-not found}"
    fi
}

# Main function
main() {
    local action="${1:-help}"
    shift

    init_wrapper

    case "$action" in
        zbx|zabbix)
            zbx_execute_wrapper "$@"
            ;;
        td|topdesk)
            td_execute_wrapper "$@"
            ;;
        test)
            echo "Testing CLI wrapper..."
            echo "Mock mode: $MOCK_MODE"
            echo ""
            echo "Zabbix test:"
            zbx_execute_wrapper "show_hosts --limit 1"
            echo ""
            echo "Topdesk test:"
            td_execute_wrapper "asset list --limit 1"
            ;;
        *)
            echo "Usage: $0 {zbx|zabbix|td|topdesk|test} [command] [options]" >&2
            echo "" >&2
            echo "Examples:" >&2
            echo "  $0 zbx show_hosts --group Topdesk" >&2
            echo "  $0 td asset list --filter 'status=active'" >&2
            echo "  $0 test" >&2
            echo "" >&2
            echo "Environment variables:" >&2
            echo "  MOCK_MODE={auto|true|false}  - Control mock mode (default: auto)" >&2
            exit 1
            ;;
    esac
}

# Run if executed directly
if [ "${0##*/}" = "cli_wrapper.sh" ]; then
    main "$@"
fi