# CLI Reference Documentation

## Table of Contents

1. [zbx-cli Command Reference](#zbx-cli-command-reference)
2. [topdesk-cli Command Reference](#topdesk-cli-command-reference)
3. [merger.sh Usage Documentation](#mergersh-usage-documentation)
4. [Configuration File Format](#configuration-file-format)
5. [Workflow Overview](#workflow-overview)
6. [Example Scenarios](#example-scenarios)
7. [Troubleshooting Guide](#troubleshooting-guide)
8. [API Reference](#api-reference)

---

## zbx-cli Command Reference

The `zbx-cli` is a comprehensive command-line interface for interacting with Zabbix API. It provides modular commands organized by functionality.

### Synopsis

```bash
zbx <command> [args...]
zbx help                    # show all commands (grouped)
zbx help <command>          # show help for a subcommand
zbx --list                  # list subcommands (plain)
zbx --where <command>       # print resolved path to a subcommand
```

### Command Groups

#### Hosts Management

| Command | Description | Syntax |
|---------|-------------|---------|
| `hosts-list` | List hosts (hostid and host) | `zbx hosts-list [--group GROUP] [--tag TAG]` |
| `host-get` | Show full JSON for a host | `zbx host-get <host_id>` |
| `host-create` | Create an agent host (IPv4) | `zbx host-create <hostname> <ip> [--group GROUP]` |
| `host-enable` | Enable a host | `zbx host-enable <host_id>` |
| `host-disable` | Disable a host | `zbx host-disable <host_id>` |
| `host-del` | Delete a host | `zbx host-del <host_id>` |
| `host-groups` | List host groups | `zbx host-groups [--filter PATTERN]` |

##### Examples

```bash
# List all hosts
zbx hosts-list

# List hosts in specific group
zbx hosts-list --group "Linux servers"

# Get detailed host information
zbx host-get 10084

# Create a new host
zbx host-create "web-server-01" "192.168.1.100" --group "Web Servers"

# Enable/disable monitoring
zbx host-disable 10084
zbx host-enable 10084
```

#### Templates Management

| Command | Description | Syntax |
|---------|-------------|---------|
| `template-list` | List templates | `zbx template-list [--filter PATTERN]` |
| `template-link` | Link template to host | `zbx template-link <host_id> <template_id>` |
| `template-unlink` | Unlink template from host | `zbx template-unlink <host_id> <template_id>` |

##### Examples

```bash
# List all templates
zbx template-list

# Link template to host
zbx template-link 10084 10001

# Unlink template from host
zbx template-unlink 10084 10001
```

#### Macros Management

| Command | Description | Syntax |
|---------|-------------|---------|
| `macro-get` | List macros for a host | `zbx macro-get <host_id>` |
| `macro-set` | Set/update a macro on a host | `zbx macro-set <host_id> <macro> <value>` |
| `macro-del` | Delete a macro on a host | `zbx macro-del <host_id> <macro>` |
| `macro-bulk-set` | Bulk set macros from TSV | `zbx macro-bulk-set < macros.tsv` |

##### Examples

```bash
# Get all macros for a host
zbx macro-get 10084

# Set a macro value
zbx macro-set 10084 '{$SNMP_COMMUNITY}' 'public'

# Delete a macro
zbx macro-del 10084 '{$CUSTOM_MACRO}'

# Bulk update macros from file
cat macros.tsv | zbx macro-bulk-set
```

#### Problems & Triggers

| Command | Description | Syntax |
|---------|-------------|---------|
| `problems` | List current problems | `zbx problems [--host HOST] [--severity MIN]` |
| `ack` | Acknowledge problem/event | `zbx ack <event_id> "message"` |
| `triggers` | List triggers for a host | `zbx triggers <host_id>` |
| `trigger-enable` | Enable a trigger | `zbx trigger-enable <trigger_id>` |
| `trigger-disable` | Disable a trigger | `zbx trigger-disable <trigger_id>` |

##### Examples

```bash
# List all current problems
zbx problems

# List problems for specific host
zbx problems --host "web-server-01"

# List critical problems only
zbx problems --severity 4

# Acknowledge a problem
zbx ack 123456 "Working on fix"

# Manage triggers
zbx triggers 10084
zbx trigger-disable 15234
zbx trigger-enable 15234
```

#### Maintenance Windows

| Command | Description | Syntax |
|---------|-------------|---------|
| `maint-create` | Create maintenance window | `zbx maint-create <name> <start> <duration> [hosts...]` |
| `maint-list` | List maintenance windows | `zbx maint-list [--active]` |
| `maint-del` | Delete maintenance window | `zbx maint-del <maintenance_id>` |

##### Examples

```bash
# Create 2-hour maintenance window
zbx maint-create "System Update" "2025-01-27 02:00" "2h" 10084 10085

# List all maintenance windows
zbx maint-list

# List active maintenance only
zbx maint-list --active

# Delete maintenance window
zbx maint-del 5
```

#### Items, History & Trends

| Command | Description | Syntax |
|---------|-------------|---------|
| `item-find` | Find itemids by host + key | `zbx item-find <host_id> <key_pattern>` |
| `history` | Fetch numeric history to TSV | `zbx history <item_id> [--from TIME] [--to TIME]` |
| `trends` | Fetch numeric trends to TSV | `zbx trends <item_id> [--from TIME] [--to TIME]` |

##### Examples

```bash
# Find CPU load items
zbx item-find 10084 "system.cpu.load"

# Get last 24 hours of history
zbx history 28533 --from "24h ago"

# Get trends for past month
zbx trends 28533 --from "1 month ago"
```

#### Discovery & Inventory

| Command | Description | Syntax |
|---------|-------------|---------|
| `discovery` | Show discovery (LLD) items | `zbx discovery <host_id>` |
| `inventory` | Export host inventory (CSV) | `zbx inventory [--group GROUP] [--output FILE]` |

##### Examples

```bash
# Show discovery rules for host
zbx discovery 10084

# Export inventory to CSV
zbx inventory --group "Production" --output inventory.csv
```

#### Authentication & Health

| Command | Description | Syntax |
|---------|-------------|---------|
| `login` | Ensure a valid API session | `zbx login` |
| `version` | Show API version and user | `zbx version` |
| `ping` | Lightweight API health check | `zbx ping` |
| `doctor` | Environment and config checks | `zbx doctor` |

##### Examples

```bash
# Verify authentication
zbx login

# Check API version
zbx version

# Quick health check
zbx ping

# Full diagnostic check
zbx doctor
```

#### Search & Configuration

| Command | Description | Syntax |
|---------|-------------|---------|
| `search` | Search across entities | `zbx search <query> [--type TYPE]` |
| `config` | Manage config | `zbx config get\|set\|list\|edit [key] [value]` |

##### Examples

```bash
# Search for hosts containing "web"
zbx search "web" --type host

# Manage configuration
zbx config list
zbx config get api.url
zbx config set api.timeout 30
zbx config edit
```

#### Low-level API Access

| Command | Description | Syntax |
|---------|-------------|---------|
| `call` | Low-level JSON-RPC invoker | `zbx call <method> [params]` |

##### Examples

```bash
# Direct API call with JSON
echo '{"output": ["hostid", "host"]}' | zbx call host.get

# With jq filtering
echo '{}' | zbx call host.get '.[] | {hostid,host}'
```

### Environment Variables

```bash
# Authentication
export ZBX_URL="https://zabbix.example.com/api_jsonrpc.php"
export ZBX_USER="admin"
export ZBX_PASSWORD="password"

# Optional settings
export ZBX_TIMEOUT=30
export ZBX_VERIFY_SSL=true
export ZBX_DEBUG=false
```

---

## topdesk-cli Command Reference

The `topdesk-cli` provides a unified interface for interacting with Topdesk API, managing assets, incidents, operators, and persons.

### Synopsis

```bash
topdesk [global-options] <command> [args]
```

### Global Options

| Option | Description |
|--------|-------------|
| `-h, --help` | Show help message |
| `-V, --version` | Show version information |
| `--no-color` | Disable colored output |
| `--log-level LVL` | Set log level (debug,info,warn,error) |
| `--config FILE` | Use specific config file |

### Assets Management

| Command | Description | Syntax |
|---------|-------------|---------|
| `assets` | List assets with filters | `topdesk assets [--filter FILTER] [--page PAGE]` |
| `assets-get` | Get specific asset | `topdesk assets-get <asset_id>` |
| `assets-create` | Create new asset | `topdesk assets-create <json_data>` |
| `assets-update` | Update asset | `topdesk assets-update <asset_id> <json_data>` |
| `assets-search` | Search assets | `topdesk assets-search <query> [--field FIELD]` |

#### Examples

```bash
# List all assets
topdesk assets

# Get specific asset
topdesk assets-get "AST-001234"

# Search assets by name
topdesk assets-search "server" --field name

# Create new asset
echo '{"name": "web-server-01", "ip_address": "192.168.1.100"}' | topdesk assets-create

# Update asset
echo '{"location": "DataCenter-A"}' | topdesk assets-update "AST-001234"
```

### Incidents Management

| Command | Description | Syntax |
|---------|-------------|---------|
| `incidents` | List incidents | `topdesk incidents [--status STATUS] [--page PAGE]` |
| `incidents-get` | Get incident details | `topdesk incidents-get <incident_id>` |
| `incidents-create` | Create incident | `topdesk incidents-create <json_data>` |
| `incidents-update` | Update incident | `topdesk incidents-update <incident_id> <json_data>` |
| `incidents-add-note` | Add note to incident | `topdesk incidents-add-note <incident_id> "note"` |
| `incidents-attachments-upload` | Upload attachment | `topdesk incidents-attachments-upload <incident_id> <file>` |
| `incidents-attachments-download` | Download attachment | `topdesk incidents-attachments-download <incident_id> <attachment_id>` |

#### Examples

```bash
# List open incidents
topdesk incidents --status open

# Get incident details
topdesk incidents-get "INC-123456"

# Create new incident
echo '{"brief_description": "Server down", "request": "web-server-01 not responding"}' | topdesk incidents-create

# Update incident status
echo '{"processing_status": "in_progress"}' | topdesk incidents-update "INC-123456"

# Add progress note
topdesk incidents-add-note "INC-123456" "Investigating network connectivity"

# Attach log file
topdesk incidents-attachments-upload "INC-123456" /var/log/error.log
```

### Operators Management

| Command | Description | Syntax |
|---------|-------------|---------|
| `operators` | List operators | `topdesk operators [--page PAGE]` |
| `operators-get` | Get operator details | `topdesk operators-get <operator_id>` |
| `operators-create` | Create operator | `topdesk operators-create <json_data>` |
| `operators-update` | Update operator | `topdesk operators-update <operator_id> <json_data>` |
| `operators-search` | Search operators | `topdesk operators-search <query>` |

#### Examples

```bash
# List all operators
topdesk operators

# Get operator details
topdesk operators-get "OP-001"

# Search operators by name
topdesk operators-search "john"

# Create new operator
echo '{"surname": "Smith", "first_name": "John", "email": "john.smith@example.com"}' | topdesk operators-create

# Update operator
echo '{"telephone": "+1-555-0123"}' | topdesk operators-update "OP-001"
```

### Persons Management

| Command | Description | Syntax |
|---------|-------------|---------|
| `persons` | List persons | `topdesk persons [--page PAGE]` |
| `persons-get` | Get person details | `topdesk persons-get <person_id>` |
| `persons-create` | Create person | `topdesk persons-create <json_data>` |
| `persons-update` | Update person | `topdesk persons-update <person_id> <json_data>` |
| `persons-search` | Search persons | `topdesk persons-search <query>` |

#### Examples

```bash
# List all persons
topdesk persons

# Get person details
topdesk persons-get "PER-001234"

# Search persons by email
topdesk persons-search "user@example.com"

# Create new person
echo '{"surname": "Doe", "first_name": "Jane", "email": "jane.doe@example.com"}' | topdesk persons-create

# Update person
echo '{"mobile_phone": "+1-555-9876"}' | topdesk persons-update "PER-001234"
```

### Low-level API Call

| Command | Description | Syntax |
|---------|-------------|---------|
| `call` | Direct API call | `topdesk call <method> <endpoint> [data]` |

#### Examples

```bash
# GET request
topdesk call GET "/tas/api/assetmgmt/assets"

# POST request with data
echo '{"name": "test"}' | topdesk call POST "/tas/api/assetmgmt/assets"

# PUT request
echo '{"status": "active"}' | topdesk call PUT "/tas/api/assetmgmt/assets/AST-001"

# DELETE request
topdesk call DELETE "/tas/api/assetmgmt/assets/AST-001"
```

### Environment Variables

```bash
# Authentication
export TOPDESK_URL="https://topdesk.example.com"
export TOPDESK_USER="apiuser"
export TOPDESK_PASSWORD="password"

# Optional settings
export TOPDESK_TIMEOUT=30
export TOPDESK_PAGE_SIZE=100
export TOPDESK_VERIFY_SSL=true
```

---

## merger.sh Usage Documentation

The `merger.sh` script is the main orchestrator for synchronizing Zabbix monitoring data with Topdesk asset management.

### Synopsis

```bash
merger.sh [OPTIONS] COMMAND [ARGUMENTS]
```

### Commands

#### Core Commands

| Command | Description | Usage |
|---------|-------------|-------|
| `fetch` | Fetch data from Zabbix | `merger.sh fetch [--group GROUP] [--tag TAG]` |
| `merge` | Merge Zabbix data with Topdesk | `merger.sh merge [--strategy STRATEGY]` |
| `sync` | Full synchronization (fetch + merge + update) | `merger.sh sync` |
| `update` | Update Topdesk with merged data | `merger.sh update [--batch-size SIZE]` |
| `validate` | Validate configuration and connectivity | `merger.sh validate` |
| `report` | Generate synchronization report | `merger.sh report [--format FORMAT]` |

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `-c, --config FILE` | Configuration file | `etc/merger.conf` |
| `-o, --output DIR` | Output directory | `output/` |
| `-l, --log FILE` | Log file | `var/log/merger.log` |
| `-v, --verbose` | Enable verbose output | Off |
| `-d, --debug` | Enable debug mode | Off |
| `-n, --dry-run` | Perform dry run without changes | Off |
| `-h, --help` | Show help message | - |
| `-V, --version` | Show version information | - |

### Detailed Command Usage

#### fetch - Retrieve Data from Zabbix

```bash
# Fetch all hosts
merger.sh fetch

# Fetch hosts from specific group
merger.sh fetch --group "Production Servers"

# Fetch hosts with specific tag
merger.sh fetch --tag "topdesk-managed"

# Fetch with multiple filters
merger.sh fetch --group "Linux" --tag "critical" --output /tmp/zabbix-data.json
```

**Output**: Creates JSON file with Zabbix host data including:
- Host ID, name, and status
- IP addresses and interfaces
- Inventory data
- Tags and groups
- Custom macros

#### merge - Merge Data Sources

```bash
# Merge using default strategy
merger.sh merge

# Update existing assets only
merger.sh merge --strategy update

# Create new assets only
merger.sh merge --strategy create

# Full synchronization
merger.sh merge --strategy sync

# Custom conflict resolution
merger.sh merge --conflict-resolution topdesk
```

**Merge Strategies**:
- `update`: Only update existing Topdesk assets
- `create`: Only create new assets in Topdesk
- `sync`: Full synchronization (create + update + delete)

**Conflict Resolution**:
- `zabbix`: Zabbix data takes precedence
- `topdesk`: Topdesk data takes precedence
- `manual`: Prompt for each conflict

#### sync - Complete Synchronization

```bash
# Full sync with default settings
merger.sh sync

# Verbose sync with specific group
merger.sh -v sync --group "Web Servers"

# Dry run to preview changes
merger.sh -n sync

# Sync with custom batch size
merger.sh sync --batch-size 50 --batch-delay 2
```

**Process Flow**:
1. Fetch data from Zabbix
2. Fetch data from Topdesk
3. Merge datasets
4. Validate changes
5. Apply updates to Topdesk
6. Generate report

#### update - Apply Changes to Topdesk

```bash
# Update from merged data file
merger.sh update

# Update with custom batch settings
merger.sh update --batch-size 25 --batch-delay 5

# Update specific assets only
merger.sh update --filter "location=DataCenter-A"

# Continue on errors
merger.sh update --continue-on-error --error-threshold 10
```

#### validate - Configuration Validation

```bash
# Full validation
merger.sh validate

# Validate Zabbix connection only
merger.sh validate --zabbix-only

# Validate Topdesk connection only
merger.sh validate --topdesk-only

# Validate with specific config
merger.sh -c custom.conf validate
```

**Validation Checks**:
- Configuration file syntax
- API endpoint connectivity
- Authentication credentials
- Required permissions
- Network connectivity
- SSL certificate validation

#### report - Generate Reports

```bash
# Generate default HTML report
merger.sh report

# Generate JSON report
merger.sh report --format json

# Generate PDF report with email
merger.sh report --format pdf --email admin@example.com

# Custom report with date range
merger.sh report --from "2025-01-01" --to "2025-01-31"
```

**Report Formats**:
- `html`: Interactive HTML report
- `pdf`: Printable PDF report
- `json`: Machine-readable JSON
- `csv`: Spreadsheet-compatible CSV
- `text`: Plain text summary

### Examples

#### Example 1: Daily Synchronization

```bash
#!/bin/sh
# daily-sync.sh - Run daily at 2 AM via cron

# Load configuration
export CONFIG_FILE="/etc/topdesk-zbx-merger/production.conf"

# Run sync with logging
/usr/local/bin/merger.sh \
  -c "$CONFIG_FILE" \
  -v \
  sync \
  --group "Production" \
  --batch-size 100 \
  2>&1 | tee -a /var/log/merger-daily.log

# Generate and email report
/usr/local/bin/merger.sh \
  -c "$CONFIG_FILE" \
  report \
  --format pdf \
  --email ops-team@example.com
```

#### Example 2: Selective Update

```bash
# Update only critical servers
merger.sh \
  -v \
  fetch --tag "critical" && \
merger.sh \
  merge --strategy update && \
merger.sh \
  update --continue-on-error
```

#### Example 3: Dry Run Testing

```bash
# Test configuration changes
merger.sh -c new-config.conf validate && \
merger.sh -c new-config.conf -n sync | tee dry-run-results.txt
```

#### Example 4: Parallel Processing

```bash
# Process multiple groups in parallel
for group in "Web" "Database" "Application"; do
  merger.sh fetch --group "$group" --output "data-$group.json" &
done
wait

# Merge all results
merger.sh merge --input-dir .
```

---

## Configuration File Format

The configuration file (`merger.conf`) controls all aspects of the merger operation.

### File Location

Default locations (searched in order):
1. `$CONFIG_FILE` environment variable
2. `./merger.conf`
3. `$HOME/.config/topdesk-zbx-merger/merger.conf`
4. `/etc/topdesk-zbx-merger/merger.conf`

### Configuration Sections

#### Zabbix Configuration

```bash
# API Endpoint
ZABBIX_URL="https://zabbix.example.com/api_jsonrpc.php"

# Authentication (choose one method)
# Method 1: Username/Password
ZABBIX_USER="admin"
ZABBIX_PASSWORD="secure_password"

# Method 2: API Token
ZABBIX_API_TOKEN="your-api-token-here"

# Query Parameters
ZABBIX_GROUP_FILTER=""      # Comma-separated host groups
ZABBIX_TAG_FILTER=""        # Comma-separated tags
ZABBIX_TIMEOUT="30"         # API timeout in seconds
ZABBIX_PAGE_SIZE="500"      # Items per API call
```

#### Topdesk Configuration

```bash
# API Endpoint
TOPDESK_URL="https://topdesk.example.com/tas/api"

# Authentication (choose one method)
# Method 1: Username/Password
TOPDESK_USER="apiuser"
TOPDESK_PASSWORD="secure_password"

# Method 2: API Token
TOPDESK_API_TOKEN="your-api-token-here"

# Connection Parameters
TOPDESK_TIMEOUT="30"        # API timeout in seconds
TOPDESK_PAGE_SIZE="100"     # Items per page
TOPDESK_MAX_RETRIES="3"     # Retry attempts
```

#### Merge Settings

```bash
# Merge Strategy
MERGE_STRATEGY="update"      # update|create|sync

# Conflict Resolution
CONFLICT_RESOLUTION="zabbix" # zabbix|topdesk|manual

# Batch Processing
BATCH_SIZE="100"            # Items per batch
BATCH_DELAY="1"             # Seconds between batches
MAX_PARALLEL="4"            # Parallel workers

# Error Handling
CONTINUE_ON_ERROR="true"    # Continue on errors
ERROR_THRESHOLD="10"        # Stop after N errors
RETRY_FAILED="true"         # Retry failed items
```

#### Field Mappings

```bash
# Standard Mappings
MAP_HOST_TO_ASSET="true"
MAP_IP_TO_IP="true"
MAP_LOCATION_TO_LOCATION="true"
MAP_INVENTORY_TO_CUSTOM="true"
MAP_TAGS_TO_CATEGORIES="false"

# Custom Field Mappings (JSON format)
CUSTOM_FIELD_MAP='{
  "host": "name",
  "ip": "ip_address",
  "location": "location_name",
  "contact": "owner_email",
  "os": "operating_system",
  "hardware": "hardware_info"
}'

# Field Transformations
TRANSFORM_HOSTNAME="lowercase"  # lowercase|uppercase|none
TRANSFORM_IP="validate"        # validate|none
NORMALIZE_LOCATION="true"      # Standardize location names
```

#### Processing Options

```bash
# Caching
ENABLE_CACHING="true"
CACHE_DIR="/var/cache/topdesk-zbx-merger"
CACHE_TTL="3600"            # Seconds

# Performance
ENABLE_PARALLEL="true"
MAX_WORKERS="4"
MAX_MEMORY_MB="512"
CONNECT_TIMEOUT="10"
READ_TIMEOUT="30"

# Data Validation
STRICT_VALIDATION="true"
VALIDATE_IP_FORMAT="true"
VALIDATE_HOSTNAME_FORMAT="true"
VALIDATE_EMAIL_FORMAT="true"
REQUIRED_FIELDS="host,ip"   # Comma-separated
```

#### Output Options

```bash
# Directories
OUTPUT_DIR="${PROJECT_ROOT}/output"
PROCESSED_DIR="${OUTPUT_DIR}/processed"
FAILED_DIR="${OUTPUT_DIR}/failed"
REPORTS_DIR="${OUTPUT_DIR}/reports"

# Output Format
OUTPUT_FORMAT="json"        # json|csv|xml
PRETTY_PRINT="true"         # Format JSON output
INCLUDE_METADATA="true"     # Add processing metadata

# Report Generation
GENERATE_REPORTS="true"
REPORT_FORMAT="html"        # html|pdf|json|text
REPORT_RECIPIENTS=""        # Email addresses
INCLUDE_STATISTICS="true"   # Processing statistics
INCLUDE_ERRORS="true"       # Error details
```

#### Logging Options

```bash
# Log Level and File
LOG_LEVEL="INFO"            # ERROR|WARNING|INFO|DEBUG
LOG_FILE="${PROJECT_ROOT}/var/log/merger.log"
LOG_MAX_SIZE="10485760"     # 10MB
LOG_ROTATE_COUNT="5"
LOG_FORMAT="json"           # json|text

# Syslog Integration
USE_SYSLOG="false"
SYSLOG_FACILITY="local0"
SYSLOG_TAG="topdesk-zbx-merger"

# Audit Logging
AUDIT_LOG="true"
AUDIT_FILE="${PROJECT_ROOT}/var/log/audit.log"
LOG_API_CALLS="false"       # Log all API calls
```

#### Security Options

```bash
# SSL/TLS
VERIFY_SSL="true"
CA_CERT_PATH="/etc/ssl/certs/ca-bundle.crt"
CLIENT_CERT_PATH=""         # Client certificate
CLIENT_KEY_PATH=""          # Client key

# Proxy Settings
USE_PROXY="false"
HTTP_PROXY=""
HTTPS_PROXY=""
NO_PROXY="localhost,127.0.0.1,10.0.0.0/8"

# Secrets Management
USE_KEYRING="false"         # Use system keyring
SECRETS_FILE=""             # Encrypted secrets file
MASK_SENSITIVE="true"       # Mask passwords in logs
```

#### Notification Options

```bash
# Notifications
NOTIFY_ON_SUCCESS="false"
NOTIFY_ON_FAILURE="true"
NOTIFICATION_METHOD="email"  # email|webhook|syslog

# Email Settings
SMTP_SERVER="smtp.example.com"
SMTP_PORT="587"
SMTP_USE_TLS="true"
SMTP_USER="notifications@example.com"
SMTP_PASSWORD="smtp_password"
SMTP_FROM="noreply@example.com"
SMTP_TO="admin@example.com"
SMTP_SUBJECT="Merger Report: {STATUS}"

# Webhook Settings
WEBHOOK_URL="https://hooks.example.com/merger"
WEBHOOK_METHOD="POST"
WEBHOOK_HEADERS="Content-Type: application/json"
WEBHOOK_AUTH_TYPE="bearer"  # none|basic|bearer
WEBHOOK_TOKEN=""
```

#### Advanced Options

```bash
# Scheduling
LOCK_FILE="${PROJECT_ROOT}/var/run/merger.lock"
LOCK_TIMEOUT="3600"
STALE_LOCK_OVERRIDE="false"

# Custom Scripts
PRE_SYNC_SCRIPT=""          # Run before sync
POST_SYNC_SCRIPT=""         # Run after sync
ERROR_HANDLER_SCRIPT=""     # Run on error
VALIDATION_SCRIPT=""        # Custom validation

# Debug Options
DEBUG_MODE="false"
DEBUG_OUTPUT_RAW="false"    # Output raw responses
DEBUG_KEEP_TEMP="false"     # Keep temp files
DEBUG_TRACE_CALLS="false"   # Trace function calls
DEBUG_DUMP_CONFIG="false"   # Dump parsed config
```

### Environment Variable Override

All configuration options can be overridden via environment variables:

```bash
# Override specific settings
export ZABBIX_URL="https://new-zabbix.example.com/api"
export LOG_LEVEL="DEBUG"
export DRY_RUN="true"

# Run with overrides
merger.sh sync
```

### Configuration Validation

```bash
# Validate configuration file syntax
merger.sh validate --config-only

# Test configuration with dry run
merger.sh -c test.conf -n validate

# Show effective configuration
merger.sh config show --effective
```

---

## Workflow Overview

### System Architecture

```
┌─────────────────┐     ┌─────────────────┐
│   Zabbix API    │────▶│  DataFetcher    │
└─────────────────┘     └─────────────────┘
                               │
                               ▼
┌─────────────────┐     ┌─────────────────┐
│  Topdesk API    │────▶│     Merger      │
└─────────────────┘     └─────────────────┘
                               │
                               ▼
                        ┌─────────────────┐
                        │   Validator     │
                        └─────────────────┘
                               │
                               ▼
                        ┌─────────────────┐
                        │    Applier      │
                        └─────────────────┘
                               │
                               ▼
                        ┌─────────────────┐
                        │  Logger/Report  │
                        └─────────────────┘
```

### Agent Responsibilities

#### DataFetcher Agent (`datafetcher.sh`)

**Purpose**: Retrieve data from external sources

**Responsibilities**:
- Connect to Zabbix API
- Fetch host and inventory data
- Connect to Topdesk API
- Fetch asset information
- Cache API responses
- Handle pagination
- Manage rate limiting

**Key Functions**:
```bash
fetch_zabbix_hosts()      # Get all hosts from Zabbix
fetch_zabbix_inventory()  # Get inventory data
fetch_topdesk_assets()    # Get assets from Topdesk
fetch_with_retry()        # Retry logic for API calls
cache_response()          # Cache management
```

#### Merger Agent (`merger.py`)

**Purpose**: Combine and reconcile data from multiple sources

**Responsibilities**:
- Load data from both sources
- Match records by key fields
- Apply field mappings
- Resolve conflicts
- Generate change sets
- Handle duplicates

**Key Functions**:
```python
merge_datasets()          # Main merge logic
match_records()           # Record matching algorithm
apply_mappings()          # Field mapping
resolve_conflicts()       # Conflict resolution
generate_changeset()      # Create update/create lists
```

#### Validator Agent (`validator.py`)

**Purpose**: Ensure data quality and consistency

**Responsibilities**:
- Validate field formats
- Check required fields
- Verify data types
- Validate relationships
- Check business rules
- Generate validation report

**Key Functions**:
```python
validate_record()         # Single record validation
validate_ip_address()     # IP format validation
validate_hostname()       # Hostname validation
validate_email()          # Email validation
check_required_fields()   # Required field check
validate_relationships()  # Reference integrity
```

#### Applier Agent (`apply.py`)

**Purpose**: Apply changes to target system

**Responsibilities**:
- Execute create operations
- Execute update operations
- Execute delete operations
- Handle batch processing
- Manage transactions
- Rollback on failure

**Key Functions**:
```python
apply_changes()           # Main apply logic
create_assets()           # Create new assets
update_assets()           # Update existing
delete_assets()           # Remove assets
batch_process()           # Batch operations
rollback_changes()        # Rollback logic
```

#### Logger Agent (`logger.py`)

**Purpose**: Comprehensive logging and reporting

**Responsibilities**:
- Log all operations
- Track metrics
- Generate reports
- Send notifications
- Maintain audit trail
- Archive logs

**Key Functions**:
```python
log_operation()           # Log single operation
log_metrics()             # Performance metrics
generate_report()         # Create reports
send_notification()       # Send alerts
rotate_logs()             # Log rotation
archive_logs()            # Log archival
```

### Data Flow

1. **Initialization**
   - Load configuration
   - Validate settings
   - Initialize agents

2. **Data Fetching**
   - DataFetcher connects to Zabbix
   - Retrieves host and inventory data
   - DataFetcher connects to Topdesk
   - Retrieves asset data
   - Cache responses

3. **Data Merging**
   - Merger loads both datasets
   - Matches records by key fields
   - Applies field mappings
   - Resolves conflicts
   - Generates change sets

4. **Validation**
   - Validator checks data quality
   - Validates formats and types
   - Verifies business rules
   - Reports validation errors

5. **Application**
   - Applier processes change sets
   - Creates new assets
   - Updates existing assets
   - Handles errors and retries

6. **Reporting**
   - Logger generates reports
   - Sends notifications
   - Archives results

### Error Handling Flow

```
Error Detected
      │
      ▼
Log Error ───────▶ Retry Logic
      │                 │
      ▼                 ▼
Check Threshold    Success? ──Yes──▶ Continue
      │                 │
      │                No
      ▼                 ▼
Above Limit? ───No──▶ Queue for Manual Review
      │
     Yes
      ▼
Stop Processing ──▶ Rollback ──▶ Send Alert
```

---

## Example Scenarios

### Scenario 1: Initial Setup and Test

```bash
# 1. Copy and customize configuration
cp etc/merger.conf.sample etc/merger.conf
vi etc/merger.conf

# 2. Validate configuration
./bin/merger.sh validate

# 3. Test Zabbix connection
zbx-cli login
zbx-cli version
zbx-cli hosts-list | head -10

# 4. Test Topdesk connection
topdesk assets --page 1

# 5. Dry run test
./bin/merger.sh -n sync

# 6. Review dry run results
cat output/dry-run-report.json
```

### Scenario 2: Production Deployment

```bash
#!/bin/bash
# production-sync.sh

# Set production environment
export ENV="production"
export CONFIG_FILE="/etc/topdesk-zbx-merger/production.conf"
export LOG_LEVEL="INFO"

# Pre-sync validation
echo "Validating configuration..."
/opt/merger/bin/merger.sh validate || exit 1

# Backup current state
echo "Creating backup..."
topdesk assets > /backup/topdesk-assets-$(date +%Y%m%d).json

# Run synchronization
echo "Starting synchronization..."
/opt/merger/bin/merger.sh \
    -c "$CONFIG_FILE" \
    sync \
    --batch-size 50 \
    --batch-delay 2 \
    --continue-on-error \
    --error-threshold 20

# Check results
if [ $? -eq 0 ]; then
    echo "Sync completed successfully"
    /opt/merger/bin/merger.sh report --format html
    mail -s "Merger Success" ops@example.com < output/reports/latest.html
else
    echo "Sync failed"
    mail -s "Merger Failed" ops@example.com < var/log/merger.log
    exit 1
fi
```

### Scenario 3: Incremental Updates

```bash
# Only update changed items since last run

# 1. Fetch recent changes from Zabbix
./bin/merger.sh fetch \
    --since "$(cat var/last-sync-time)" \
    --output output/incremental.json

# 2. Merge with existing Topdesk data
./bin/merger.sh merge \
    --input output/incremental.json \
    --strategy update

# 3. Apply updates
./bin/merger.sh update \
    --batch-size 10 \
    --verbose

# 4. Update timestamp
date -Iseconds > var/last-sync-time
```

### Scenario 4: Disaster Recovery

```bash
#!/bin/bash
# disaster-recovery.sh

# Restore from backup
echo "Starting disaster recovery..."

# 1. Stop regular sync
systemctl stop topdesk-merger.service

# 2. Load backup configuration
export CONFIG_FILE="/etc/topdesk-zbx-merger/recovery.conf"

# 3. Fetch all data from Zabbix
./bin/merger.sh fetch --all --output recovery-data.json

# 4. Validate data integrity
./bin/merger.sh validate --input recovery-data.json

# 5. Force sync with Topdesk
./bin/merger.sh sync \
    --force \
    --strategy sync \
    --conflict-resolution zabbix

# 6. Generate recovery report
./bin/merger.sh report \
    --format pdf \
    --title "Disaster Recovery Report" \
    --email management@example.com

# 7. Restart regular sync
systemctl start topdesk-merger.service
```

### Scenario 5: Selective Group Sync

```bash
# Sync specific groups on different schedules

# Critical servers - every hour
0 * * * * /opt/merger/bin/merger.sh sync --group "Critical" --tag "production"

# Standard servers - every 4 hours
0 */4 * * * /opt/merger/bin/merger.sh sync --group "Standard"

# Development - once daily
0 2 * * * /opt/merger/bin/merger.sh sync --group "Development" --tag "non-prod"

# Archive old systems - weekly
0 3 * * 0 /opt/merger/bin/merger.sh sync --group "Archive" --strategy update
```

### Scenario 6: Custom Field Mapping

```bash
# Configure custom field mappings

# 1. Export current mappings
./bin/merger.sh config get CUSTOM_FIELD_MAP > mappings.json

# 2. Edit mappings
cat > mappings.json <<EOF
{
  "host": "name",
  "interfaces.0.ip": "ip_address",
  "inventory.location": "location_name",
  "inventory.contact": "owner_email",
  "inventory.os": "operating_system",
  "inventory.hardware": "hardware_info",
  "tags": "categories",
  "status": "monitoring_status"
}
EOF

# 3. Apply new mappings
./bin/merger.sh config set CUSTOM_FIELD_MAP "$(cat mappings.json)"

# 4. Test with dry run
./bin/merger.sh -n merge

# 5. Apply if successful
./bin/merger.sh sync
```

---

## Troubleshooting Guide

### Common Issues and Solutions

#### Connection Errors

##### Zabbix Connection Failed

**Symptom**:
```
ERROR: Unable to connect to Zabbix API
Connection refused: https://zabbix.example.com/api_jsonrpc.php
```

**Possible Causes**:
1. Incorrect URL
2. Network connectivity issues
3. Firewall blocking connection
4. SSL certificate issues

**Resolution**:
```bash
# 1. Test network connectivity
ping zabbix.example.com
curl -I https://zabbix.example.com/api_jsonrpc.php

# 2. Check SSL certificate
openssl s_client -connect zabbix.example.com:443

# 3. Test with curl
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"apiinfo.version","params":{},"id":1}' \
  https://zabbix.example.com/api_jsonrpc.php

# 4. Verify credentials
zbx-cli config set api.url https://zabbix.example.com/api_jsonrpc.php
zbx-cli login

# 5. Check firewall
sudo iptables -L -n | grep 443
```

##### Topdesk Authentication Failed

**Symptom**:
```
ERROR: Authentication failed for Topdesk API
401 Unauthorized
```

**Possible Causes**:
1. Invalid credentials
2. Account locked
3. Missing permissions
4. API not enabled

**Resolution**:
```bash
# 1. Test credentials manually
curl -u "user:password" https://topdesk.example.com/tas/api/version

# 2. Check API permissions in Topdesk
# Login to Topdesk web interface
# Navigate to Settings > API Access
# Verify account has API permissions

# 3. Test with token instead
export TOPDESK_API_TOKEN="your-token"
topdesk call GET /version

# 4. Reset password if needed
# Contact Topdesk administrator
```

#### Data Issues

##### Field Mapping Errors

**Symptom**:
```
ERROR: Field mapping failed
KeyError: 'inventory.location'
```

**Resolution**:
```bash
# 1. Check available fields
zbx-cli call host.get '{"output": "extend", "limit": 1}' | jq 'keys'

# 2. Verify inventory is enabled
zbx-cli inventory --limit 1

# 3. Update field mappings
vi etc/merger.conf
# Remove or fix invalid mapping

# 4. Test with minimal mappings
export CUSTOM_FIELD_MAP='{"host":"name","ip":"ip_address"}'
./bin/merger.sh -n merge
```

##### Duplicate Records

**Symptom**:
```
WARNING: Duplicate asset found
Multiple assets match hostname: web-server-01
```

**Resolution**:
```bash
# 1. Find duplicates in Topdesk
topdesk assets-search "web-server-01"

# 2. Check matching criteria
grep MATCH_FIELDS etc/merger.conf

# 3. Use stricter matching
export MATCH_FIELDS="hostname,ip_address"

# 4. Clean up duplicates
# Manual review and cleanup in Topdesk

# 5. Add duplicate prevention
export PREVENT_DUPLICATES="true"
export DUPLICATE_ACTION="skip"  # or "update_first"
```

#### Performance Issues

##### Slow API Responses

**Symptom**:
```
WARNING: API response time exceeded threshold
Zabbix API took 45 seconds to respond
```

**Resolution**:
```bash
# 1. Reduce page size
export ZABBIX_PAGE_SIZE=100
export TOPDESK_PAGE_SIZE=50

# 2. Enable caching
export ENABLE_CACHING=true
export CACHE_TTL=3600

# 3. Use filtering
./bin/merger.sh fetch --group "Critical" --limit 100

# 4. Enable parallel processing
export ENABLE_PARALLEL=true
export MAX_WORKERS=4

# 5. Optimize API queries
# Use specific output fields
zbx-cli call host.get '{"output": ["hostid","host","status"]}'
```

##### Memory Exhaustion

**Symptom**:
```
ERROR: Out of memory
Cannot allocate memory
```

**Resolution**:
```bash
# 1. Check memory usage
free -h
ps aux | grep merger

# 2. Limit batch size
export BATCH_SIZE=50
export MAX_MEMORY_MB=256

# 3. Process in chunks
for group in $(zbx-cli host-groups | cut -f2); do
    ./bin/merger.sh sync --group "$group"
    sleep 60  # Allow memory to clear
done

# 4. Enable swap if needed
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

#### Process Errors

##### Lock File Issues

**Symptom**:
```
ERROR: Another instance is running
Lock file exists: /var/run/merger.lock
```

**Resolution**:
```bash
# 1. Check if process is running
ps aux | grep merger

# 2. Check lock file age
ls -la /var/run/merger.lock
stat /var/run/merger.lock

# 3. Remove stale lock
# Only if process is NOT running
rm /var/run/merger.lock

# 4. Use lock timeout
export LOCK_TIMEOUT=3600
export STALE_LOCK_OVERRIDE=true
```

##### Partial Sync Failure

**Symptom**:
```
ERROR: Sync failed after processing 234 of 500 items
Transaction rolled back
```

**Resolution**:
```bash
# 1. Check error log
tail -n 100 var/log/merger.log | grep ERROR

# 2. Identify failed items
cat output/failed/*.json

# 3. Fix and retry failed items
./bin/merger.sh update --input output/failed/ --retry

# 4. Continue from checkpoint
export ENABLE_CHECKPOINT=true
export CHECKPOINT_INTERVAL=50
./bin/merger.sh sync --resume

# 5. Process remaining manually
for file in output/failed/*.json; do
    ./bin/merger.sh update --input "$file" --force
done
```

### Debug Mode

Enable comprehensive debugging:

```bash
# Maximum debug output
export DEBUG=true
export LOG_LEVEL=DEBUG
export DEBUG_OUTPUT_RAW=true
export DEBUG_TRACE_CALLS=true

# Run with debug
./bin/merger.sh -d validate 2>&1 | tee debug.log

# Analyze debug log
grep -E "ERROR|WARNING|TRACE" debug.log
```

### Log Analysis

```bash
# Parse JSON logs
cat var/log/merger.log | jq '.level == "ERROR"'

# Count errors by type
cat var/log/merger.log | jq -r '.error_type' | sort | uniq -c

# Find slow operations
cat var/log/merger.log | jq 'select(.duration > 1000)'

# Track specific asset
grep "AST-001234" var/log/merger.log
```

### Health Checks

```bash
#!/bin/bash
# health-check.sh

# Check services
echo "Checking Zabbix..."
zbx-cli ping || echo "Zabbix FAILED"

echo "Checking Topdesk..."
topdesk call GET /version || echo "Topdesk FAILED"

# Check disk space
df -h /var/log /var/cache

# Check memory
free -h

# Check last sync
if [ -f var/last-sync-time ]; then
    last_sync=$(cat var/last-sync-time)
    echo "Last sync: $last_sync"

    # Alert if too old
    if [ $(date -d "$last_sync" +%s) -lt $(date -d "1 day ago" +%s) ]; then
        echo "WARNING: Last sync is more than 24 hours old"
    fi
fi

# Check error rate
errors=$(grep ERROR var/log/merger.log | wc -l)
if [ $errors -gt 100 ]; then
    echo "WARNING: High error count: $errors"
fi
```

---

## API Reference

### DataFetcher Module

#### Functions

##### fetch_zabbix_hosts()
```bash
# Fetch hosts from Zabbix
# Arguments:
#   $1 - Group filter (optional)
#   $2 - Tag filter (optional)
#   $3 - Output file (optional)
# Returns:
#   0 - Success
#   1 - Connection error
#   2 - Authentication error
#   3 - API error
```

##### fetch_topdesk_assets()
```bash
# Fetch assets from Topdesk
# Arguments:
#   $1 - Filter query (optional)
#   $2 - Page size (optional)
#   $3 - Output file (optional)
# Returns:
#   0 - Success
#   1 - Connection error
#   2 - Authentication error
#   3 - API error
```

### Merger Module

#### Classes

##### Merger
```python
class Merger:
    def __init__(self, config: dict):
        """Initialize merger with configuration"""

    def merge_datasets(self, zabbix_data: dict, topdesk_data: dict) -> dict:
        """Merge two datasets based on matching rules"""

    def apply_mappings(self, record: dict) -> dict:
        """Apply field mappings to a record"""

    def resolve_conflict(self, zabbix_value, topdesk_value, field: str):
        """Resolve conflicting values based on strategy"""

    def generate_changeset(self, merged_data: dict) -> dict:
        """Generate create/update/delete changesets"""
```

### Validator Module

#### Classes

##### Validator
```python
class Validator:
    def __init__(self, rules: dict):
        """Initialize validator with validation rules"""

    def validate_record(self, record: dict) -> tuple[bool, list]:
        """Validate a single record, return (is_valid, errors)"""

    def validate_batch(self, records: list) -> dict:
        """Validate a batch of records"""

    def check_required_fields(self, record: dict) -> list:
        """Check for required fields"""

    def validate_format(self, value: str, format_type: str) -> bool:
        """Validate value against format (ip, email, hostname)"""
```

### Applier Module

#### Classes

##### Applier
```python
class Applier:
    def __init__(self, api_client, config: dict):
        """Initialize applier with API client and config"""

    def apply_changes(self, changeset: dict) -> dict:
        """Apply all changes in changeset"""

    def create_asset(self, asset_data: dict) -> dict:
        """Create a new asset in Topdesk"""

    def update_asset(self, asset_id: str, updates: dict) -> dict:
        """Update existing asset"""

    def delete_asset(self, asset_id: str) -> bool:
        """Delete an asset"""

    def batch_process(self, operations: list, batch_size: int) -> dict:
        """Process operations in batches"""
```

### Logger Module

#### Classes

##### Logger
```python
class Logger:
    def __init__(self, config: dict):
        """Initialize logger with configuration"""

    def log(self, level: str, message: str, **kwargs):
        """Log a message with metadata"""

    def log_operation(self, operation: str, status: str, details: dict):
        """Log an operation with full details"""

    def generate_report(self, format: str = "html") -> str:
        """Generate report in specified format"""

    def send_notification(self, subject: str, body: str, recipients: list):
        """Send notification via configured method"""
```

### REST API Endpoints

#### Zabbix API Methods Used

| Method | Description | Parameters |
|--------|-------------|------------|
| `host.get` | Get hosts | output, groupids, tags |
| `hostgroup.get` | Get host groups | output, filter |
| `item.get` | Get items | output, hostids, search |
| `history.get` | Get history | output, itemids, time_from |
| `problem.get` | Get problems | output, hostids, severities |

#### Topdesk API Endpoints Used

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/tas/api/assetmgmt/assets` | GET | List assets |
| `/tas/api/assetmgmt/assets/{id}` | GET | Get asset |
| `/tas/api/assetmgmt/assets` | POST | Create asset |
| `/tas/api/assetmgmt/assets/{id}` | PUT | Update asset |
| `/tas/api/assetmgmt/assets/{id}` | DELETE | Delete asset |

---

## Appendix

### File Structure

```
topdesk-zbx-merger/
├── bin/
│   ├── merger.sh           # Main orchestrator
│   ├── tui_launcher.sh     # TUI interface
│   └── tui_operator.sh     # TUI operations
├── lib/
│   ├── datafetcher.sh      # Data fetching module
│   ├── merger.py           # Merge logic
│   ├── validator.py        # Validation module
│   ├── apply.py            # Apply changes module
│   ├── logger.py           # Logging module
│   ├── sorter.py           # Sorting module
│   ├── auth_manager.sh     # Authentication
│   └── common.sh           # Common functions
├── etc/
│   ├── merger.conf.sample  # Sample configuration
│   └── merger.conf         # Active configuration
├── var/
│   ├── log/                # Log files
│   ├── cache/              # Cache directory
│   └── run/                # Runtime files
├── output/
│   ├── processed/          # Processed items
│   ├── failed/             # Failed items
│   └── reports/            # Generated reports
├── doc/
│   ├── README.md           # Main documentation
│   ├── CLI_REFERENCE.md    # This document
│   └── SORTING_STRATEGY.md # Sorting documentation
└── tests/
    ├── test_datafetcher.sh # DataFetcher tests
    ├── test_merger.py      # Merger tests
    └── test_integration.sh # Integration tests
```

### Exit Codes

| Code | Description |
|------|-------------|
| 0 | Success |
| 1 | General error |
| 2 | Configuration error |
| 3 | Connection error |
| 4 | Authentication error |
| 5 | Validation error |
| 6 | Processing error |
| 7 | Lock file exists |
| 8 | Insufficient permissions |
| 9 | Dependency missing |
| 10 | Timeout exceeded |

### Required Permissions

#### Zabbix Permissions
- Read access to hosts
- Read access to host groups
- Read access to inventory
- Read access to items and history
- Read access to problems

#### Topdesk Permissions
- Read asset management data
- Create assets
- Update assets
- Delete assets (if sync mode)
- Read persons and operators

### Dependencies

#### System Requirements
- POSIX-compliant shell (sh/bash)
- Python 3.7+
- curl or wget
- jq (JSON processor)
- Standard UNIX tools (grep, sed, awk)

#### Python Libraries
- requests
- json
- argparse
- logging
- datetime

#### Network Requirements
- HTTPS access to Zabbix API
- HTTPS access to Topdesk API
- DNS resolution
- Proxy support (optional)

### Performance Considerations

#### API Rate Limits
- Zabbix: Typically 1000 requests/hour
- Topdesk: Typically 100 requests/minute
- Implement exponential backoff
- Use caching to reduce API calls

#### Memory Usage
- Small deployment (<1000 assets): 256MB
- Medium deployment (<10000 assets): 512MB
- Large deployment (>10000 assets): 1GB+
- Use batch processing for large datasets

#### Processing Time
- Initial sync: 1-2 minutes per 1000 assets
- Incremental update: 10-30 seconds per 100 changes
- Validation: 5-10 seconds per 1000 records
- Report generation: 5-15 seconds

### Security Best Practices

1. **Credential Management**
   - Use environment variables
   - Implement secret management
   - Rotate API tokens regularly
   - Use read-only accounts where possible

2. **Network Security**
   - Always use HTTPS
   - Verify SSL certificates
   - Use VPN for sensitive networks
   - Implement IP whitelisting

3. **Data Protection**
   - Encrypt sensitive data at rest
   - Mask sensitive data in logs
   - Implement audit logging
   - Regular backup of configurations

4. **Access Control**
   - Principle of least privilege
   - Regular permission audits
   - Multi-factor authentication
   - Session timeout implementation

### Support and Resources

- **Documentation**: `/doc/` directory
- **Examples**: `/examples/` directory
- **Issue Tracker**: GitHub Issues
- **Community Forum**: Discord/Slack
- **Email Support**: support@example.com

### Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-01-26 | Initial release |
| 1.1.0 | TBD | Performance improvements |
| 1.2.0 | TBD | Additional field mappings |

### License

This software is provided under the MIT License. See LICENSE file for details.

---

End of CLI Reference Documentation