# API Module Reference

## Table of Contents

1. [Module Overview](#module-overview)
2. [DataFetcher Module](#datafetcher-module)
3. [Sorter Module](#sorter-module)
4. [Validator Module](#validator-module)
5. [Apply Module](#apply-module)
6. [Logger Module](#logger-module)
7. [Common Library](#common-library)
8. [TUI Module](#tui-module)
9. [Authentication Manager](#authentication-manager)

---

## Module Overview

The asset-merger-engine consists of modular components that work together to synchronize asset data between Zabbix and Topdesk. Each module has a specific responsibility and communicates through well-defined interfaces.

### Module Communication Flow

```
Input → DataFetcher → Sorter → Validator → TUI → Apply → Logger → Output
         ↓              ↓          ↓         ↓       ↓        ↓
    Common Library (Shared Functions and Configuration)
```

---

## DataFetcher Module

**Location**: `lib/datafetcher.sh`

### Purpose
Retrieves asset data from Zabbix and Topdesk APIs with caching, pagination, and error handling.

### Functions

#### fetch_zabbix()
```bash
fetch_zabbix() {
    # Fetches all hosts from Zabbix with inventory data
    # Arguments:
    #   --group GROUP    : Filter by host group
    #   --tag TAG       : Filter by tag
    #   --limit N       : Maximum number of hosts
    #   --output FILE   : Output JSON file
    #   --cache         : Use cache if available
    # Returns:
    #   0 on success, error code on failure
    # Output:
    #   JSON array of host objects with inventory
}
```

#### fetch_topdesk()
```bash
fetch_topdesk() {
    # Fetches all assets from Topdesk
    # Arguments:
    #   --branch BRANCH : Topdesk branch filter
    #   --limit N       : Maximum number of assets
    #   --output FILE   : Output JSON file
    #   --page-size N   : Items per page (default: 100)
    # Returns:
    #   0 on success, error code on failure
    # Output:
    #   JSON array of asset objects
}
```

#### cache_response()
```bash
cache_response() {
    # Caches API response with TTL
    # Arguments:
    #   $1 - Cache key
    #   $2 - Data to cache
    #   $3 - TTL in seconds (optional)
    # Returns:
    #   0 on success
}
```

#### get_cached_response()
```bash
get_cached_response() {
    # Retrieves cached response if valid
    # Arguments:
    #   $1 - Cache key
    # Returns:
    #   0 if cache hit, 1 if miss
    # Output:
    #   Cached data to stdout
}
```

### Data Structures

#### Zabbix Host Object
```json
{
  "hostid": "10084",
  "host": "web-server-01",
  "name": "Web Server 01",
  "status": "0",
  "interfaces": [
    {
      "ip": "192.168.1.100",
      "type": "1",
      "main": "1"
    }
  ],
  "inventory": {
    "location": "DataCenter-A",
    "contact": "admin@example.com",
    "os": "Linux",
    "hardware": "Dell PowerEdge R740"
  },
  "groups": [
    {"groupid": "2", "name": "Linux servers"}
  ],
  "tags": [
    {"tag": "Environment", "value": "Production"}
  ]
}
```

#### Topdesk Asset Object
```json
{
  "id": "AST-001234",
  "name": "web-server-01",
  "ip_address": "192.168.1.100",
  "location": {
    "id": "LOC-001",
    "name": "DataCenter-A"
  },
  "owner": {
    "id": "PER-001",
    "email": "admin@example.com"
  },
  "specifications": {
    "operating_system": "Linux",
    "hardware_model": "Dell PowerEdge R740"
  },
  "status": "ACTIVE"
}
```

### Error Codes

| Code | Description |
|------|-------------|
| 0 | Success |
| 1 | General error |
| 2 | Authentication failed |
| 3 | Connection timeout |
| 4 | Invalid response |
| 5 | Rate limit exceeded |

---

## Sorter Module

**Location**: `lib/sorter.py`

### Purpose
Compares Zabbix and Topdesk datasets to identify differences and generate changesets.

### Classes

#### AssetSorter
```python
class AssetSorter:
    def __init__(self, config: dict):
        """
        Initialize sorter with configuration

        Args:
            config: Dictionary with sorting configuration
                - match_fields: Fields to use for matching
                - threshold: Similarity threshold (0-100)
                - strategy: Matching strategy
        """

    def load_data(self, zabbix_file: str, topdesk_file: str):
        """
        Load data from JSON files

        Args:
            zabbix_file: Path to Zabbix data file
            topdesk_file: Path to Topdesk data file
        """

    def find_matches(self) -> list:
        """
        Find matching assets between datasets

        Returns:
            List of matched asset pairs
        """

    def compare_fields(self, zbx_asset: dict, td_asset: dict) -> dict:
        """
        Compare fields between matched assets

        Args:
            zbx_asset: Zabbix asset data
            td_asset: Topdesk asset data

        Returns:
            Dictionary of field differences
        """

    def generate_changeset(self) -> dict:
        """
        Generate changeset for updates

        Returns:
            Dictionary with create/update/delete operations
        """
```

### Methods

#### match_assets()
```python
def match_assets(self, zbx_assets: list, td_assets: list) -> dict:
    """
    Match assets between datasets using configured strategy

    Strategies:
        - exact: Exact field matching
        - fuzzy: Fuzzy string matching
        - smart: Combined approach with scoring

    Returns:
        {
            "matched": [(zbx, td), ...],
            "unmatched_zabbix": [...],
            "unmatched_topdesk": [...]
        }
    """
```

#### calculate_similarity()
```python
def calculate_similarity(self, str1: str, str2: str) -> float:
    """
    Calculate similarity score between two strings

    Args:
        str1: First string
        str2: Second string

    Returns:
        Similarity score (0.0 to 1.0)
    """
```

### Output Format

#### Difference Report
```json
{
  "summary": {
    "total_zabbix": 150,
    "total_topdesk": 145,
    "matched": 140,
    "unmatched_zabbix": 10,
    "unmatched_topdesk": 5,
    "total_differences": 85
  },
  "matched_assets": [
    {
      "zabbix_id": "10084",
      "topdesk_id": "AST-001234",
      "hostname": "web-server-01",
      "differences": {
        "location": {
          "zabbix": "DataCenter-A",
          "topdesk": "DataCenter-B",
          "field_type": "string"
        },
        "ip_address": {
          "zabbix": "192.168.1.100",
          "topdesk": "192.168.1.101",
          "field_type": "ip"
        }
      }
    }
  ],
  "unmatched": {
    "zabbix": [...],
    "topdesk": [...]
  }
}
```

---

## Validator Module

**Location**: `lib/validator.py`

### Purpose
Validates data integrity, format compliance, and business rules.

### Classes

#### DataValidator
```python
class DataValidator:
    def __init__(self, rules_file: str = None):
        """
        Initialize validator with validation rules

        Args:
            rules_file: Path to JSON validation rules file
        """

    def validate_record(self, record: dict) -> tuple:
        """
        Validate a single record

        Args:
            record: Asset record to validate

        Returns:
            (is_valid: bool, errors: list)
        """

    def validate_batch(self, records: list) -> dict:
        """
        Validate multiple records

        Args:
            records: List of records to validate

        Returns:
            Validation report dictionary
        """
```

### Validation Rules

#### Field Validators
```python
FIELD_VALIDATORS = {
    "ip_address": validate_ip,
    "email": validate_email,
    "hostname": validate_hostname,
    "url": validate_url,
    "date": validate_date
}

def validate_ip(value: str) -> bool:
    """Validate IPv4/IPv6 address"""

def validate_email(value: str) -> bool:
    """Validate email format"""

def validate_hostname(value: str) -> bool:
    """Validate hostname/FQDN"""
```

#### Business Rules
```python
BUSINESS_RULES = [
    {
        "name": "require_owner",
        "condition": "status == 'ACTIVE'",
        "requirement": "owner is not None"
    },
    {
        "name": "location_format",
        "field": "location",
        "pattern": "^[A-Z]{2}-[0-9]{3}$"
    }
]
```

### Validation Report Format
```json
{
  "timestamp": "2025-01-26T10:30:00Z",
  "total_records": 150,
  "valid_records": 145,
  "invalid_records": 5,
  "validation_errors": [
    {
      "record_id": "10084",
      "field": "ip_address",
      "value": "192.168.1.999",
      "error": "Invalid IP address format"
    }
  ],
  "warnings": [
    {
      "record_id": "10085",
      "message": "Missing optional field: description"
    }
  ]
}
```

---

## Apply Module

**Location**: `lib/apply.py`

### Purpose
Applies validated changes to Topdesk via API with transaction management.

### Classes

#### ChangeApplier
```python
class ChangeApplier:
    def __init__(self, api_config: dict):
        """
        Initialize applier with API configuration

        Args:
            api_config: Topdesk API configuration
        """

    def load_queue(self, queue_file: str):
        """
        Load change queue from file

        Args:
            queue_file: Path to queue JSON file
        """

    def apply_changes(self, dry_run: bool = False) -> dict:
        """
        Apply all queued changes

        Args:
            dry_run: If True, simulate changes only

        Returns:
            Results dictionary with success/failure counts
        """

    def rollback(self, transaction_id: str):
        """
        Rollback a transaction

        Args:
            transaction_id: Transaction to rollback
        """
```

### Queue Format

#### Change Queue
```json
{
  "metadata": {
    "created": "2025-01-26T10:00:00Z",
    "total_changes": 50,
    "source": "interactive_tui"
  },
  "changes": [
    {
      "operation": "update",
      "asset_id": "AST-001234",
      "fields": {
        "location": "DataCenter-A",
        "ip_address": "192.168.1.100"
      },
      "old_values": {
        "location": "DataCenter-B",
        "ip_address": "192.168.1.101"
      }
    },
    {
      "operation": "create",
      "asset_data": {
        "name": "new-server-01",
        "ip_address": "192.168.2.100"
      }
    }
  ]
}
```

### Transaction Management

```python
class TransactionManager:
    def begin_transaction(self) -> str:
        """Start a new transaction"""

    def commit_transaction(self, trans_id: str):
        """Commit transaction"""

    def rollback_transaction(self, trans_id: str):
        """Rollback transaction"""

    def get_transaction_log(self, trans_id: str) -> list:
        """Get all operations in transaction"""
```

### Results Format

```json
{
  "summary": {
    "total": 50,
    "successful": 48,
    "failed": 2,
    "skipped": 0
  },
  "duration_seconds": 45.2,
  "transaction_id": "TXN-20250126-001",
  "successful_operations": [...],
  "failed_operations": [
    {
      "asset_id": "AST-001235",
      "operation": "update",
      "error": "Asset not found",
      "error_code": 404
    }
  ]
}
```

---

## Logger Module

**Location**: `lib/logger.py`

### Purpose
Centralized logging with structured output, metrics tracking, and report generation.

### Classes

#### MergerLogger
```python
class MergerLogger:
    def __init__(self, config: dict):
        """
        Initialize logger with configuration

        Args:
            config: Logger configuration
                - log_file: Path to log file
                - log_level: Logging level
                - format: Log format (json|text)
        """

    def log(self, level: str, message: str, **kwargs):
        """
        Log a message with metadata

        Args:
            level: Log level (DEBUG|INFO|WARNING|ERROR)
            message: Log message
            **kwargs: Additional metadata
        """

    def log_operation(self, operation: str, status: str, details: dict):
        """
        Log an operation with structured data
        """

    def log_metrics(self, metrics: dict):
        """
        Log performance metrics
        """
```

### Log Formats

#### JSON Log Entry
```json
{
  "timestamp": "2025-01-26T10:30:45.123Z",
  "level": "INFO",
  "component": "applier",
  "message": "Asset updated successfully",
  "metadata": {
    "asset_id": "AST-001234",
    "operation": "update",
    "duration_ms": 234,
    "fields_updated": ["location", "ip_address"]
  },
  "correlation_id": "CORR-123456",
  "thread_id": "thread-1"
}
```

#### Metrics Entry
```json
{
  "timestamp": "2025-01-26T10:35:00Z",
  "type": "metrics",
  "metrics": {
    "api_calls": 150,
    "cache_hits": 120,
    "cache_misses": 30,
    "average_response_time_ms": 234,
    "memory_usage_mb": 128,
    "cpu_usage_percent": 45
  }
}
```

### Report Generation

```python
class ReportGenerator:
    def generate_html_report(self, data: dict) -> str:
        """Generate HTML report"""

    def generate_pdf_report(self, data: dict) -> bytes:
        """Generate PDF report"""

    def generate_csv_report(self, data: dict) -> str:
        """Generate CSV report"""

    def send_email_report(self, report: str, recipients: list):
        """Email report to recipients"""
```

---

## Common Library

**Location**: `lib/common.sh`

### Purpose
Shared functions and utilities used across all shell modules.

### Core Functions

#### Logging Functions
```bash
log_info()    # Log info message
log_error()   # Log error message
log_debug()   # Log debug message (if DEBUG=1)
log_warning() # Log warning message
```

#### API Functions
```bash
api_call() {
    # Generic API call wrapper
    # Arguments:
    #   $1 - Method (GET|POST|PUT|DELETE)
    #   $2 - URL
    #   $3 - Data (optional)
    #   $4 - Headers (optional)
    # Returns:
    #   0 on success, error code on failure
}

parse_json() {
    # Parse JSON using jq
    # Arguments:
    #   $1 - JSON data
    #   $2 - JQ filter
    # Output:
    #   Filtered JSON to stdout
}
```

#### File Operations
```bash
ensure_directory()  # Create directory if not exists
rotate_file()       # Rotate log/output file
lock_file()         # Create lock file
unlock_file()       # Remove lock file
```

#### Validation Functions
```bash
validate_ip()       # Validate IP address
validate_hostname() # Validate hostname
validate_email()    # Validate email
validate_url()      # Validate URL
```

### Configuration Management
```bash
load_config() {
    # Load configuration file
    # Arguments:
    #   $1 - Config file path
    # Sets:
    #   All configuration variables
}

get_config_value() {
    # Get specific config value
    # Arguments:
    #   $1 - Config key
    # Output:
    #   Config value to stdout
}

set_config_value() {
    # Set config value
    # Arguments:
    #   $1 - Config key
    #   $2 - Config value
}
```

---

## TUI Module

**Location**: `bin/tui_operator.sh`

### Purpose
Interactive terminal interface for reviewing and selecting field changes.

### Modes

| Mode | Description | Requirements |
|------|-------------|--------------|
| `dialog` | Uses dialog utility | dialog package |
| `whiptail` | Uses whiptail utility | whiptail package |
| `pure` | Pure shell implementation | None |
| `auto` | Auto-detect best option | Checks availability |

### Functions

#### Main Interface
```bash
tui_main() {
    # Launch TUI main interface
    # Arguments:
    #   --input FILE   : Input difference file
    #   --output FILE  : Output queue file
    #   --mode MODE    : TUI mode
    #   --auto-select  : Auto-select all Zabbix values
}
```

#### Asset Selection
```bash
show_asset_list() {
    # Display list of assets with differences
    # Returns:
    #   Selected asset ID
}

show_field_differences() {
    # Display field differences for asset
    # Arguments:
    #   $1 - Asset ID
    # Returns:
    #   Selected action
}
```

#### Field Selection Interface
```
┌─────────────────────────────────────────────┐
│        Field Difference Selection          │
├─────────────────────────────────────────────┤
│ Asset: web-server-01 (AST-001234)          │
│                                             │
│ Field: location                             │
│ ┌─────────────────────────────────────────┐ │
│ │ ( ) Keep Topdesk:    DataCenter-B      │ │
│ │ (•) Use Zabbix:      DataCenter-A      │ │
│ │ ( ) Skip this field                    │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ Field: ip_address                           │
│ ┌─────────────────────────────────────────┐ │
│ │ ( ) Keep Topdesk:    192.168.1.101     │ │
│ │ (•) Use Zabbix:      192.168.1.100     │ │
│ │ ( ) Skip this field                    │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ [Previous] [Next] [Apply] [Cancel]          │
└─────────────────────────────────────────────┘
```

### Key Bindings

| Key | Action |
|-----|--------|
| ↑/↓ | Navigate items |
| Space | Select/toggle |
| Enter | Confirm selection |
| Tab | Next field |
| Shift+Tab | Previous field |
| q/Esc | Quit/cancel |
| a | Select all Zabbix |
| t | Select all Topdesk |
| s | Skip all |

---

## Authentication Manager

**Location**: `lib/auth_manager.sh`

### Purpose
Manages authentication tokens and credentials for API access.

### Functions

#### Token Management
```bash
get_auth_token() {
    # Get or refresh authentication token
    # Arguments:
    #   $1 - Service (zabbix|topdesk)
    # Returns:
    #   0 on success
    # Output:
    #   Token to stdout
}

refresh_token() {
    # Refresh expired token
    # Arguments:
    #   $1 - Service
    #   $2 - Current token
    # Returns:
    #   New token or error
}

validate_token() {
    # Check if token is valid
    # Arguments:
    #   $1 - Service
    #   $2 - Token
    # Returns:
    #   0 if valid, 1 if expired
}
```

#### Credential Storage
```bash
store_credentials() {
    # Securely store credentials
    # Arguments:
    #   $1 - Service
    #   $2 - Username
    #   $3 - Password/Token
    # Uses:
    #   System keyring if available
}

retrieve_credentials() {
    # Retrieve stored credentials
    # Arguments:
    #   $1 - Service
    # Output:
    #   Username and password/token
}
```

#### Session Management
```bash
create_session() {
    # Create new API session
    # Returns:
    #   Session ID
}

maintain_session() {
    # Keep session alive
    # Arguments:
    #   $1 - Session ID
}

destroy_session() {
    # Cleanup session
    # Arguments:
    #   $1 - Session ID
}
```

### Security Features

- Encrypted credential storage
- Token rotation
- Session timeout management
- Audit logging of authentication events
- Multi-factor authentication support (if configured)

---

## Error Handling

All modules use consistent error handling:

### Error Codes

| Code | Description | Recovery Action |
|------|-------------|-----------------|
| 0 | Success | Continue |
| 1 | General error | Check logs |
| 2 | Configuration error | Fix config |
| 3 | Connection error | Check network |
| 4 | Authentication error | Check credentials |
| 5 | Data error | Validate input |
| 6 | Permission error | Check access rights |
| 7 | Timeout | Retry with backoff |
| 8 | Rate limit | Wait and retry |
| 9 | Validation error | Fix data |
| 10 | Transaction error | Rollback |

### Error Response Format

```json
{
  "error": {
    "code": 3,
    "message": "Connection timeout",
    "details": {
      "endpoint": "https://zabbix.example.com/api",
      "timeout_seconds": 30,
      "attempt": 3
    },
    "timestamp": "2025-01-26T10:30:00Z",
    "correlation_id": "ERR-123456",
    "recovery_suggestion": "Check network connectivity and firewall rules"
  }
}
```

---

## Performance Considerations

### Optimization Strategies

1. **Caching**
   - API responses cached with TTL
   - Incremental updates tracked
   - Cache invalidation on changes

2. **Batch Processing**
   - Configurable batch sizes
   - Parallel processing support
   - Memory-efficient streaming

3. **Rate Limiting**
   - Exponential backoff
   - Request throttling
   - Quota management

4. **Resource Management**
   - Connection pooling
   - Memory limits
   - CPU throttling

### Performance Metrics

```json
{
  "performance": {
    "total_duration_seconds": 120.5,
    "api_calls": {
      "zabbix": 25,
      "topdesk": 30
    },
    "cache_hit_rate": 0.75,
    "average_response_time_ms": 234,
    "peak_memory_mb": 256,
    "records_processed": 1500,
    "records_per_second": 12.4
  }
}
```

---

## Module Testing

Each module includes comprehensive test coverage:

### Test Structure
```
tests/
├── unit/
│   ├── test_datafetcher.sh
│   ├── test_sorter.py
│   ├── test_validator.py
│   └── test_apply.py
├── integration/
│   ├── test_workflow.sh
│   └── test_api_integration.py
└── fixtures/
    ├── sample_zabbix.json
    └── sample_topdesk.json
```

### Running Tests
```bash
# Run all tests
make test

# Run specific module tests
./tests/unit/test_datafetcher.sh

# Run with coverage
python -m pytest --cov=lib tests/

# Integration tests
./tests/integration/test_workflow.sh
```

---

## Version Compatibility

| Module | Version | Python | Shell | Dependencies |
|--------|---------|--------|-------|--------------|
| datafetcher | 2.0.0 | - | POSIX | curl, jq |
| sorter | 2.0.0 | 3.7+ | - | json, difflib |
| validator | 2.0.0 | 3.7+ | - | jsonschema |
| apply | 2.0.0 | 3.7+ | - | requests |
| logger | 2.0.0 | 3.7+ | - | logging |
| tui | 2.0.0 | - | POSIX | dialog/whiptail (optional) |

---

## Contributing

To add new modules or extend existing ones:

1. Follow the existing module structure
2. Implement standard interfaces
3. Add comprehensive error handling
4. Include unit tests
5. Update this documentation
6. Submit pull request with examples

For detailed contribution guidelines, see CONTRIBUTING.md