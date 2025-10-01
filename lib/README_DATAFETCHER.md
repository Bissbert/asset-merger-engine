# Data Fetcher Module Documentation

## Overview

The Data Fetcher module is responsible for retrieving asset information from both Zabbix and Topdesk systems using their respective command-line interfaces (`zbx-cli` and `topdesk-cli`). It handles authentication, caching, error recovery, and data normalization.

## Components

### Core Scripts

1. **datafetcher.sh** - Main data fetching logic
   - Fetches assets from both systems
   - Normalizes data to common format
   - Implements caching and retry logic
   - Handles parallel fetching

2. **auth_manager.sh** - Authentication and session management
   - Manages credentials securely
   - Handles session refresh
   - Stores encrypted credentials

3. **zbx_cli_wrapper.sh** - Zabbix CLI wrapper
   - Provides high-level Zabbix operations
   - Handles pagination and batch operations
   - Exports data in multiple formats

4. **topdesk_cli_wrapper.sh** - Topdesk CLI wrapper
   - Provides high-level Topdesk operations
   - Handles automatic pagination
   - Provides asset statistics

5. **common.sh** - Shared utilities
   - Logging functions
   - JSON manipulation
   - Cache management
   - Error handling

6. **test_datafetcher.sh** - Test suite
   - Unit tests for all components
   - Integration tests
   - Mock data testing

## Installation

### Prerequisites

1. Install required CLI tools:
   ```bash
   # Install zbx-cli (example using pip)
   pip install zbx-cli

   # Install topdesk-cli (example)
   pip install topdesk-cli

   # Ensure Python 3 is installed
   python3 --version
   ```

2. Set up configuration:
   ```bash
   # Copy config template
   cp lib/config.template ~/.config/topdesk-zbx-merger/merger.conf

   # Edit with your credentials
   vi ~/.config/topdesk-zbx-merger/merger.conf
   ```

3. Make scripts executable:
   ```bash
   chmod +x lib/*.sh
   ```

## Configuration

### Environment Variables

```bash
# Zabbix settings
export ZABBIX_SERVER="https://zabbix.example.com"
export ZABBIX_USER="username"
export ZABBIX_PASS="password"

# Topdesk settings
export TOPDESK_URL="https://topdesk.example.com"
export TOPDESK_API_KEY="your-api-key"

# General settings
export LOG_LEVEL="INFO"
export CACHE_TTL=300
```

### Configuration File

Create `~/.config/topdesk-zbx-merger/merger.conf` based on the template.

## Usage

### Basic Operations

```bash
# Test connections
./lib/datafetcher.sh validate

# Fetch from both systems
./lib/datafetcher.sh fetch

# Fetch from Zabbix only
./lib/datafetcher.sh zabbix "GroupName"

# Fetch from Topdesk only
./lib/datafetcher.sh topdesk "filter-expression"

# Clear cache
./lib/datafetcher.sh clear-cache
```

### Authentication

```bash
# Set up authentication
./lib/auth_manager.sh setup

# Store credentials securely
./lib/auth_manager.sh store zabbix
./lib/auth_manager.sh store topdesk

# Refresh sessions
./lib/auth_manager.sh refresh
```

### Advanced Usage

```bash
# Fetch with custom parameters
CACHE_TTL=600 MAX_RETRIES=5 ./lib/datafetcher.sh fetch

# Enable debug mode
DEBUG=1 ./lib/datafetcher.sh fetch

# Use parallel fetching
ENABLE_PARALLEL_FETCH=true ./lib/datafetcher.sh fetch
```

## Output Format

The module outputs normalized JSON data:

```json
{
  "zabbix": {
    "source": "zabbix",
    "timestamp": "2024-01-01T12:00:00Z",
    "assets": [
      {
        "asset_id": "123",
        "fields": {
          "name": "server01",
          "status": "enabled",
          "inventory": {...},
          "interfaces": [...]
        }
      }
    ]
  },
  "topdesk": {
    "source": "topdesk",
    "timestamp": "2024-01-01T12:00:00Z",
    "assets": [
      {
        "asset_id": "456",
        "fields": {
          "name": "server01",
          "type": "Server",
          "status": "active",
          "specifications": {...}
        }
      }
    ]
  }
}
```

## Error Handling

### Retry Logic

- Automatic retry with exponential backoff
- Configurable max attempts and delays
- Detailed error logging

### Error Recovery

```bash
# Check logs for errors
tail -f /tmp/topdesk-zbx-merger/merger.log

# Clear corrupted cache
./lib/datafetcher.sh clear-cache

# Reset authentication
./lib/auth_manager.sh clear
./lib/auth_manager.sh setup
```

## Testing

Run the test suite:

```bash
# Run all tests
./lib/test_datafetcher.sh test

# Clean test artifacts
./lib/test_datafetcher.sh clean
```

## Performance Optimization

### Caching

- Results cached for 5 minutes by default
- Session cached for 1 hour
- Cache location: `/tmp/topdesk-zbx-merger/cache`

### Parallel Processing

- Fetches from both systems simultaneously
- Configurable via `ENABLE_PARALLEL_FETCH`

### Pagination

- Automatic handling of large datasets
- Configurable page size via `TD_PAGE_SIZE`

## Troubleshooting

### Common Issues

1. **Authentication failures**
   ```bash
   # Clear and reset auth
   ./lib/auth_manager.sh clear
   ./lib/auth_manager.sh setup
   ```

2. **Connection timeouts**
   ```bash
   # Increase timeout
   export ZBX_TIMEOUT=60
   export TD_TIMEOUT=60
   ```

3. **Cache issues**
   ```bash
   # Clear all cache
   rm -rf /tmp/topdesk-zbx-merger/cache/*
   ```

4. **Missing tools**
   ```bash
   # Validate tool availability
   ./lib/datafetcher.sh validate
   ```

### Debug Mode

Enable detailed debugging:

```bash
export DEBUG=1
export LOG_LEVEL=DEBUG
./lib/datafetcher.sh fetch 2>&1 | tee debug.log
```

## Integration with Other Modules

The data fetcher outputs structured JSON that can be consumed by:

- **@differ** - For comparing assets between systems
- **@sorter** - For categorizing differences
- **@logger** - For audit logging
- **@apply** - For applying changes

Example pipeline:

```bash
# Fetch data and pipe to differ
./lib/datafetcher.sh fetch | ./lib/differ.sh compare

# Full pipeline
./lib/datafetcher.sh fetch | \
  ./lib/differ.sh compare | \
  ./lib/sorter.sh categorize | \
  ./lib/apply.sh execute
```

## Security Considerations

1. **Credential Storage**
   - Credentials are base64 encoded (use GPG for production)
   - Stored with 600 permissions
   - Located in user's home directory

2. **Session Management**
   - Sessions expire after configurable TTL
   - Automatic refresh on expiry

3. **Logging**
   - Sensitive data is not logged
   - Log files have appropriate permissions

## API Compatibility

- Compatible with zbx-cli version 2.x and above
- Compatible with topdesk-cli version 1.x and above
- Requires Python 3.6 or higher for JSON processing