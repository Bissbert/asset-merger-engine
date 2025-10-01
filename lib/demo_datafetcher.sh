#!/bin/sh
# demo_datafetcher.sh - Demonstration of data fetcher capabilities

# Source modules
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/common.sh"

# Colors for output
if [ -t 1 ]; then
    CYAN='\033[0;36m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m' # No Color
else
    CYAN=''
    GREEN=''
    YELLOW=''
    NC=''
fi

echo "${CYAN}========================================${NC}"
echo "${CYAN}   Data Fetcher Module Demonstration    ${NC}"
echo "${CYAN}========================================${NC}"
echo

# Demo 1: Show configuration
demo_configuration() {
    echo "${GREEN}1. Configuration Setup${NC}"
    echo "   The data fetcher uses environment variables or config files:"
    echo
    echo "   ${YELLOW}Zabbix Settings:${NC}"
    echo "   - ZABBIX_SERVER: ${ZABBIX_SERVER:-not set}"
    echo "   - ZABBIX_USER: ${ZABBIX_USER:-not set}"
    echo "   - ZABBIX_PASS: ***hidden***"
    echo
    echo "   ${YELLOW}Topdesk Settings:${NC}"
    echo "   - TOPDESK_URL: ${TOPDESK_URL:-not set}"
    echo "   - TOPDESK_API_KEY: ***hidden***"
    echo
    echo "   ${YELLOW}General Settings:${NC}"
    echo "   - LOG_FILE: ${LOG_FILE:-/tmp/topdesk-zbx-merger/merger.log}"
    echo "   - CACHE_DIR: ${CACHE_DIR:-/tmp/topdesk-zbx-merger/cache}"
    echo "   - CACHE_TTL: ${CACHE_TTL:-300} seconds"
    echo
}

# Demo 2: Mock data fetching
demo_mock_fetch() {
    echo "${GREEN}2. Mock Data Fetching${NC}"
    echo "   Simulating asset retrieval from both systems..."
    echo

    # Mock Zabbix response
    local mock_zabbix_data='{
  "source": "zabbix",
  "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",
  "assets": [
    {
      "asset_id": "10001",
      "fields": {
        "name": "web-server-01",
        "display_name": "Production Web Server 01",
        "status": "enabled",
        "inventory": {
          "location": "DC1-Rack-A12",
          "serialno_a": "SN123456789",
          "tag": "PROD-WEB",
          "os": "Ubuntu 22.04 LTS"
        },
        "interfaces": [
          {
            "type": "agent",
            "ip": "10.0.1.10",
            "dns": "web01.example.com",
            "port": "10050"
          }
        ]
      }
    },
    {
      "asset_id": "10002",
      "fields": {
        "name": "db-server-01",
        "display_name": "Production Database Server 01",
        "status": "enabled",
        "inventory": {
          "location": "DC1-Rack-B08",
          "serialno_a": "SN987654321",
          "tag": "PROD-DB",
          "os": "CentOS 8"
        },
        "interfaces": [
          {
            "type": "agent",
            "ip": "10.0.2.20",
            "dns": "db01.example.com",
            "port": "10050"
          }
        ]
      }
    }
  ]
}'

    # Mock Topdesk response
    local mock_topdesk_data='{
  "source": "topdesk",
  "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",
  "assets": [
    {
      "asset_id": "TD-001",
      "fields": {
        "name": "web-server-01",
        "type": "Server",
        "status": "active",
        "location": "DataCenter 1 - Rack A12",
        "serialNumber": "SN123456789",
        "ipAddress": "10.0.1.10",
        "specifications": {
          "cpu": "Intel Xeon E5-2680",
          "ram": "64GB",
          "storage": "2TB SSD"
        }
      }
    },
    {
      "asset_id": "TD-002",
      "fields": {
        "name": "db-server-01",
        "type": "Server",
        "status": "active",
        "location": "DataCenter 1 - Rack B08",
        "serialNumber": "SN987654321",
        "ipAddress": "10.0.2.20",
        "specifications": {
          "cpu": "Intel Xeon Gold 6248",
          "ram": "256GB",
          "storage": "10TB HDD"
        }
      }
    },
    {
      "asset_id": "TD-003",
      "fields": {
        "name": "backup-server-01",
        "type": "Server",
        "status": "inactive",
        "location": "DataCenter 2 - Rack C01",
        "serialNumber": "SN555555555",
        "ipAddress": "10.0.3.30"
      }
    }
  ]
}'

    echo "   ${YELLOW}Zabbix Assets Found: 2${NC}"
    echo "   - web-server-01 (10.0.1.10)"
    echo "   - db-server-01 (10.0.2.20)"
    echo
    echo "   ${YELLOW}Topdesk Assets Found: 3${NC}"
    echo "   - web-server-01 (10.0.1.10)"
    echo "   - db-server-01 (10.0.2.20)"
    echo "   - backup-server-01 (10.0.3.30) [inactive]"
    echo

    # Save mock data for next demo
    mkdir -p /tmp/demo_data
    echo "${mock_zabbix_data}" > /tmp/demo_data/zabbix.json
    echo "${mock_topdesk_data}" > /tmp/demo_data/topdesk.json
}

# Demo 3: Data normalization
demo_normalization() {
    echo "${GREEN}3. Data Normalization${NC}"
    echo "   Converting different formats to unified structure..."
    echo

    echo "   ${YELLOW}Normalized Fields:${NC}"
    echo "   Zabbix                    -> Common Format"
    echo "   - hostid                  -> asset_id"
    echo "   - host                    -> fields.name"
    echo "   - inventory.location      -> fields.inventory.location"
    echo "   - interfaces[].ip         -> fields.interfaces[].ip"
    echo
    echo "   Topdesk                   -> Common Format"
    echo "   - id                      -> asset_id"
    echo "   - name                    -> fields.name"
    echo "   - location                -> fields.location"
    echo "   - ipAddress               -> fields.ipAddress"
    echo
}

# Demo 4: Caching mechanism
demo_caching() {
    echo "${GREEN}4. Caching Mechanism${NC}"
    echo "   Demonstrating cache operations..."
    echo

    local cache_dir="/tmp/topdesk-zbx-merger/cache"
    mkdir -p "${cache_dir}"

    echo "   Creating cache entry..."
    local cache_file="${cache_dir}/demo_cache_$(date +%s).json"
    echo '{"demo": "data", "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}' > "${cache_file}"

    echo "   ${YELLOW}Cache Statistics:${NC}"
    echo "   - Cache directory: ${cache_dir}"
    echo "   - Cache files: $(ls -1 ${cache_dir}/*.json 2>/dev/null | wc -l | tr -d ' ')"
    echo "   - Total size: $(du -sh ${cache_dir} 2>/dev/null | cut -f1)"
    echo "   - TTL: ${CACHE_TTL:-300} seconds"
    echo
}

# Demo 5: Error handling
demo_error_handling() {
    echo "${GREEN}5. Error Handling & Retry Logic${NC}"
    echo "   Showing retry mechanism with exponential backoff..."
    echo

    echo "   Simulating connection failure to Zabbix..."
    echo "   Attempt 1/3... ${YELLOW}Failed${NC} (waiting 2s)"
    echo "   Attempt 2/3... ${YELLOW}Failed${NC} (waiting 4s)"
    echo "   Attempt 3/3... ${GREEN}Success${NC}"
    echo
    echo "   ${YELLOW}Error Recovery Actions:${NC}"
    echo "   - Logged error to: /tmp/topdesk-zbx-merger/merger.log"
    echo "   - Cached partial results for recovery"
    echo "   - Notified monitoring system"
    echo
}

# Demo 6: Parallel fetching
demo_parallel() {
    echo "${GREEN}6. Parallel Data Fetching${NC}"
    echo "   Fetching from both systems simultaneously..."
    echo

    echo "   Starting parallel fetch..."
    echo "   [${GREEN}====>${NC}            ] Zabbix:  25% (10/40 hosts)"
    echo "   [${GREEN}========>${NC}        ] Topdesk: 40% (20/50 assets)"
    sleep 1
    printf "\033[2A"  # Move cursor up 2 lines
    echo "   [${GREEN}============>${NC}    ] Zabbix:  60% (24/40 hosts)"
    echo "   [${GREEN}===============>${NC} ] Topdesk: 80% (40/50 assets)"
    sleep 1
    printf "\033[2A"
    echo "   [${GREEN}================>${NC}] Zabbix:  100% (40/40 hosts)"
    echo "   [${GREEN}================>${NC}] Topdesk: 100% (50/50 assets)"
    echo
    echo "   ${GREEN}✓ Parallel fetch completed in 2.3 seconds${NC}"
    echo "   Sequential would have taken ~4.6 seconds"
    echo
}

# Demo 7: Output format
demo_output() {
    echo "${GREEN}7. Output Format Example${NC}"
    echo "   Combined JSON output structure:"
    echo

    cat <<'EOF'
   {
     "zabbix": {
       "source": "zabbix",
       "timestamp": "2024-01-01T12:00:00Z",
       "assets": [...2 assets...]
     },
     "topdesk": {
       "source": "topdesk",
       "timestamp": "2024-01-01T12:00:01Z",
       "assets": [...3 assets...]
     }
   }
EOF
    echo
}

# Demo 8: Integration example
demo_integration() {
    echo "${GREEN}8. Integration with Other Modules${NC}"
    echo "   Data flow through the pipeline:"
    echo

    echo "   ${CYAN}[Data Fetcher]${NC}"
    echo "         |"
    echo "         v"
    echo "   Fetch from Zabbix & Topdesk"
    echo "         |"
    echo "         v"
    echo "   Normalize to common format"
    echo "         |"
    echo "         v"
    echo "   ${CYAN}[Differ Module]${NC}"
    echo "         |"
    echo "         v"
    echo "   Compare assets"
    echo "         |"
    echo "         v"
    echo "   ${CYAN}[Sorter Module]${NC}"
    echo "         |"
    echo "         v"
    echo "   Categorize differences"
    echo "         |"
    echo "         v"
    echo "   ${CYAN}[Apply Module]${NC}"
    echo "         |"
    echo "         v"
    echo "   Update systems"
    echo
}

# Main demo flow
main() {
    demo_configuration
    read -p "Press Enter to continue..." dummy

    demo_mock_fetch
    read -p "Press Enter to continue..." dummy

    demo_normalization
    read -p "Press Enter to continue..." dummy

    demo_caching
    read -p "Press Enter to continue..." dummy

    demo_error_handling
    read -p "Press Enter to continue..." dummy

    demo_parallel
    read -p "Press Enter to continue..." dummy

    demo_output
    read -p "Press Enter to continue..." dummy

    demo_integration

    echo "${CYAN}========================================${NC}"
    echo "${GREEN}   Demo Complete!${NC}"
    echo "${CYAN}========================================${NC}"
    echo
    echo "To use the data fetcher in production:"
    echo "1. Configure credentials in ~/.config/topdesk-zbx-merger/merger.conf"
    echo "2. Run: ./datafetcher.sh fetch"
    echo "3. Process output with other modules"
    echo
    echo "For more information, see README_DATAFETCHER.md"
}

# Run demo
main "$@"