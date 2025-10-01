# CLI Tools Analysis for Data Fetcher Agent
## Zabbix and Topdesk Asset Retrieval Capabilities

---

## Executive Summary

This document provides a comprehensive analysis of the `zbx-cli` and `topdesk-cli` command-line tools for retrieving asset information from Zabbix (specifically items in the "Topdesk" group/tag) and Topdesk systems. Both tools follow Unix philosophy with composable commands, structured output formats, and robust error handling suitable for automated data retrieval and merging operations.

---

## 1. ZBX-CLI (Zabbix Toolkit)

### 1.1 Architecture Overview
- **Style**: Git-style CLI (`zbx <subcommand>`)
- **Dependencies**: bash, curl, jq
- **Configuration**: Stored in `~/.config/zbx/config.sh` or via environment variables
- **Session Management**: Automatic token caching with 30-minute lifetime
- **Output Formats**: TSV, CSV, JSON

### 1.2 Configuration

```bash
# Initialize configuration
zbx config init

# Set credentials and endpoint
zbx config set ZABBIX_URL https://zabbix.example.com/api_jsonrpc.php
zbx config set ZABBIX_USER apiuser
zbx config set ZABBIX_PASS secret123

# Alternative: API token
zbx config set ZABBIX_API_TOKEN "your-api-token"

# TLS/Certificate options
zbx config set ZABBIX_VERIFY_TLS 1
zbx config set ZABBIX_CA_CERT /path/to/ca.pem
```

### 1.3 Key Commands for Asset Retrieval

#### 1.3.1 Host Group Filtering

```bash
# List all host groups to identify "Topdesk" group
zbx host-groups --format json
zbx host-groups --format tsv --headers

# Output columns: groupid, name
```

#### 1.3.2 Search Commands

```bash
# Search for hosts in specific groups (flexible search)
zbx search hosts <pattern> --format json
zbx search hosts Topdesk --like --format csv --headers
zbx search hosts ".*Topdesk.*" --regex --limit 1000

# Search host groups
zbx search hostgroups Topdesk --format json
```

#### 1.3.3 Inventory Export

```bash
# Export full inventory with asset details
zbx inventory --format csv --headers
zbx inventory --format json

# Output fields:
# - hostid
# - host (technical name)
# - name (display name)
# - status
# - asset_tag
# - hardware
# - location
# - site_address_a
# - site_city
# - site_country
```

#### 1.3.4 Low-Level API Access

```bash
# Direct API call for custom filtering by group
echo '{
  "output": ["hostid", "host", "name", "status"],
  "selectInventory": "extend",
  "selectGroups": ["groupid", "name"],
  "filter": {
    "groups": {
      "name": ["Topdesk"]
    }
  }
}' | zbx call host.get

# Get hosts with specific tags
echo '{
  "output": ["hostid", "host", "name"],
  "selectTags": "extend",
  "tags": [
    {"tag": "Topdesk", "value": "", "operator": 0}
  ]
}' | zbx call host.get
```

#### 1.3.5 Host Details Retrieval

```bash
# Get complete host information
zbx host-get <hostname> --format json

# List all hosts (basic)
zbx hosts-list --format tsv --headers
```

### 1.4 Output Format Examples

#### JSON Output
```json
{
  "hostid": "10084",
  "host": "web-server-01",
  "name": "Web Server 01",
  "status": "0",
  "inventory": {
    "asset_tag": "AST-001234",
    "hardware": "Dell PowerEdge R640",
    "location": "Datacenter A, Rack 15",
    "site_address_a": "123 Tech Street",
    "site_city": "Amsterdam",
    "site_country": "Netherlands"
  }
}
```

#### CSV Output
```csv
hostid,host,name,status,asset_tag,hardware,location,site_address_a,site_city,site_country
10084,web-server-01,Web Server 01,0,AST-001234,Dell PowerEdge R640,"Datacenter A, Rack 15",123 Tech Street,Amsterdam,Netherlands
```

---

## 2. TOPDESK-CLI (Topdesk Toolkit)

### 2.1 Architecture Overview
- **Style**: Dispatcher pattern (`topdesk <command>`)
- **Dependencies**: POSIX sh, curl, jq (for formatting)
- **Configuration**: `~/.config/topdesk/config` or environment variables
- **Authentication**: Bearer token, Basic auth, or custom headers
- **Output Formats**: JSON (default), TSV, CSV

### 2.2 Configuration

```bash
# Initialize configuration
topdesk config init

# Edit configuration
topdesk config edit

# Configuration file content:
TDX_BASE_URL="https://topdesk.example.com"
TDX_AUTH_TOKEN="Bearer eyJ..."  # Or "Basic base64string"
# Alternative: Basic auth
TDX_USER="apiuser"
TDX_PASS="apipass"

# Pagination defaults
TDX_PAGE_SIZE=100
TDX_PAGE_PARAM=pageSize
TDX_OFFSET_PARAM=start

# Default fields for assets
TDX_ASSET_FIELDS=id,objectNumber,name,type.name,branch.name,location.name
```

### 2.3 Key Commands for Asset Retrieval

#### 2.3.1 Assets Commands

```bash
# List all assets (paginated)
topdesk assets --format json --pretty
topdesk assets --format csv --headers
topdesk assets --format tsv --headers

# Retrieve ALL assets (auto-pagination)
topdesk assets --all --format json
topdesk assets --all --limit 500 --format csv --headers

# Custom field selection
topdesk assets --fields "id,name,objectNumber,status" --format tsv

# Custom query parameters
topdesk assets --param archived=false
topdesk assets --param name="*server*"
```

#### 2.3.2 Asset Search

```bash
# Search assets with query string
topdesk assets-search --query "name=*server*"
topdesk assets-search --param type="Computer"
topdesk assets-search --param location="Datacenter"
```

#### 2.3.3 Individual Asset Retrieval

```bash
# Get specific asset by ID
topdesk assets-get --id "asset-uuid-123"
```

#### 2.3.4 Low-Level API Calls

```bash
# Direct API call with full control
topdesk call GET /tas/api/assetmgmt/assets --pretty
topdesk call GET /tas/api/assetmgmt/assets --param pageSize=200
topdesk call GET /tas/api/assetmgmt/assets --param archived=false --format csv
```

### 2.4 Output Format Examples

#### JSON Output
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "objectNumber": "AST-001234",
  "name": "Web Server 01",
  "type": {
    "id": "type-id",
    "name": "Server"
  },
  "branch": {
    "id": "branch-id",
    "name": "IT Department"
  },
  "location": {
    "id": "location-id",
    "name": "Datacenter A"
  },
  "status": "Operational"
}
```

#### CSV Output
```csv
id,objectNumber,name,type.name,branch.name,location.name
550e8400-e29b-41d4-a716-446655440000,AST-001234,Web Server 01,Server,IT Department,Datacenter A
```

---

## 3. Data Retrieval Strategies

### 3.1 Zabbix - Filtering by "Topdesk" Group

```bash
#!/bin/bash
# Strategy 1: Using search
GROUP_NAME="Topdesk"
zbx search hosts "$GROUP_NAME" --like --format json > zabbix_hosts.json

# Strategy 2: Direct API call with group filter
echo '{
  "output": "extend",
  "selectInventory": "extend",
  "selectGroups": ["name"],
  "filter": {
    "groups": {
      "name": ["'$GROUP_NAME'"]
    }
  }
}' | zbx call host.get > zabbix_filtered.json

# Strategy 3: Get group ID first, then filter
GROUP_ID=$(zbx host-groups --format json | jq -r '.[] | select(.name == "'$GROUP_NAME'") | .groupid')
echo '{
  "output": "extend",
  "selectInventory": "extend",
  "groupids": ["'$GROUP_ID'"]
}' | zbx call host.get > zabbix_by_groupid.json
```

### 3.2 Zabbix - Filtering by Tags

```bash
#!/bin/bash
# Get hosts with specific tag
TAG_NAME="Topdesk"
echo '{
  "output": ["hostid", "host", "name"],
  "selectInventory": "extend",
  "selectTags": "extend",
  "tags": [
    {"tag": "'$TAG_NAME'", "operator": 0}
  ],
  "evaltype": 0
}' | zbx call host.get > zabbix_tagged.json
```

### 3.3 Topdesk - Full Asset Export

```bash
#!/bin/bash
# Export all assets with retry logic
MAX_RETRIES=3
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if topdesk assets --all --format json > topdesk_assets.json; then
    echo "Successfully retrieved Topdesk assets"
    break
  else
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "Retry $RETRY_COUNT of $MAX_RETRIES..."
    sleep 5
  fi
done
```

---

## 4. Error Handling and Logging

### 4.1 Zabbix Error Codes
- Exit code 0: Success
- Exit code 1: API error or host not found
- Exit code 2: Usage/argument error
- Network errors: Handled by curl with configurable retry

### 4.2 Topdesk Error Codes
- HTTP status codes passed through
- Exit codes follow standard Unix conventions
- Detailed error messages to stderr

### 4.3 Logging Integration

```bash
#!/bin/bash
# Example with logging
LOG_FILE="merger.log"

# Function to log with timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Zabbix retrieval with error handling
if ! zbx inventory --format json > zabbix_data.json 2>> "$LOG_FILE"; then
    log_message "ERROR: Failed to retrieve Zabbix data"
    exit 1
fi

# Topdesk retrieval with error handling
if ! topdesk assets --all --format json > topdesk_data.json 2>> "$LOG_FILE"; then
    log_message "ERROR: Failed to retrieve Topdesk data"
    exit 1
fi
```

---

## 5. Performance Optimization

### 5.1 Batch Processing
- Both tools support configurable page sizes
- Zabbix: Use `limit` parameter in API calls
- Topdesk: Use `--page-size` parameter

### 5.2 Parallel Processing
```bash
# Parallel retrieval example
zbx inventory --format json > zabbix_data.json &
PID_ZBX=$!

topdesk assets --all --format json > topdesk_data.json &
PID_TD=$!

wait $PID_ZBX $PID_TD
echo "Both retrievals complete"
```

### 5.3 Caching Strategy
- Zabbix: Session tokens cached for 30 minutes
- Implement local caching for frequently accessed data
- Use timestamps to track data freshness

---

## 6. Data Normalization Requirements

### 6.1 Common Field Mapping

| Zabbix Field | Topdesk Field | Normalized Field |
|--------------|---------------|------------------|
| hostid | id | asset_id |
| host | objectNumber | asset_number |
| name | name | display_name |
| inventory.location | location.name | location |
| inventory.asset_tag | objectNumber | asset_tag |
| status | status | status |

### 6.2 Data Type Conversions
- Zabbix status: "0" (enabled), "1" (disabled) → "Operational", "Disabled"
- Topdesk dates: ISO 8601 format
- Ensure consistent NULL handling

---

## 7. Integration Script Template

```bash
#!/bin/bash
set -euo pipefail

# Source configuration
source ~/.config/merger/config.sh

# Initialize
LOG_FILE="${LOG_DIR}/merger.log"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
WORK_DIR="${TMP_DIR}/merger_${TIMESTAMP}"
mkdir -p "$WORK_DIR"

# Function definitions
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
error_exit() { log "ERROR: $1"; exit 1; }

# Retrieve Zabbix data
log "Fetching Zabbix assets from group: ${ZABBIX_GROUP}"
if ! echo '{
  "output": "extend",
  "selectInventory": "extend",
  "selectGroups": ["name"],
  "filter": {"groups": {"name": ["'"${ZABBIX_GROUP}"'"]}}
}' | zbx call host.get > "${WORK_DIR}/zabbix_raw.json"; then
    error_exit "Failed to retrieve Zabbix data"
fi

# Retrieve Topdesk data
log "Fetching all Topdesk assets"
if ! topdesk assets --all --format json > "${WORK_DIR}/topdesk_raw.json"; then
    error_exit "Failed to retrieve Topdesk data"
fi

# Normalize and process data
log "Processing retrieved data"
# ... normalization logic here ...

log "Data retrieval complete"
```

---

## 8. Testing and Validation

### 8.1 Connection Testing
```bash
# Test Zabbix connection
zbx ping  # Should return "pong"
zbx version  # Shows API version and user

# Test Topdesk connection
topdesk call GET /tas/api/version
```

### 8.2 Data Validation
- Verify JSON structure with jq
- Check for required fields
- Validate data types and formats

---

## 9. Security Considerations

### 9.1 Credential Management
- Never hardcode credentials
- Use secure config files with restricted permissions
- Consider using credential management tools

### 9.2 TLS/SSL
- Both tools support custom CA certificates
- Verify TLS by default
- Use `--insecure` only for testing

### 9.3 Audit Logging
- Log all API calls with timestamps
- Track data access patterns
- Monitor for anomalies

---

## 10. Conclusion

Both `zbx-cli` and `topdesk-cli` provide robust, Unix-philosophy-compliant tools for asset data retrieval. Key capabilities for the merger tool:

1. **Zabbix**: Can filter by host groups or tags to retrieve "Topdesk" assets with full inventory details
2. **Topdesk**: Provides comprehensive asset management API access with flexible querying
3. **Output formats**: Both support JSON for easy parsing and merging
4. **Error handling**: Both provide clear error codes and messages
5. **Performance**: Support for pagination and parallel processing
6. **Security**: Proper credential management and TLS support

The tools are well-suited for automated data retrieval, comparison, and synchronization workflows as required by the merger tool architecture.