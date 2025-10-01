# Topdesk-Zabbix Merger - Main Script Documentation

## Overview

The `merger.sh` script is the main orchestration tool for synchronizing asset information between Zabbix monitoring and Topdesk ITSM systems. Version 3.0.0 provides a comprehensive, production-ready implementation with full POSIX compliance.

## Features

- **Complete workflow automation** from data retrieval to application
- **Multi-agent coordination** integrating all system components
- **Interactive and batch modes** for flexible operation
- **Comprehensive health checks** and validation
- **Centralized logging** with multiple severity levels
- **Error handling and recovery** mechanisms
- **Caching support** for improved performance

## Installation

1. Ensure the script is executable:
```bash
chmod +x /path/to/topdesk-zbx-merger/bin/merger.sh
```

2. Run initial validation:
```bash
./merger.sh validate
```

3. Edit the generated configuration file:
```bash
vi /path/to/topdesk-zbx-merger/etc/merger.conf
```

## Usage

### Basic Commands

```bash
# Show help
./merger.sh --help

# Check system health
./merger.sh health

# Validate configuration
./merger.sh validate

# Full synchronization workflow
./merger.sh sync

# Fetch data from both systems
./merger.sh fetch

# Compare and identify differences
./merger.sh diff

# Interactive field selection
./merger.sh tui

# Apply changes to Topdesk
./merger.sh apply

# Show current status
./merger.sh status

# Clean temporary files
./merger.sh clean
```

### Options

- `-c, --config FILE` - Specify configuration file
- `-o, --output DIR` - Set output directory
- `-l, --log FILE` - Set log file path
- `-v, --verbose` - Enable verbose output
- `-d, --debug` - Enable debug mode
- `-n, --dry-run` - Perform dry run without changes
- `-f, --force` - Force operation without confirmation
- `-b, --batch` - Run in batch mode (non-interactive)
- `-i, --interactive` - Run in interactive mode (default)

### Command-Specific Options

#### fetch
```bash
./merger.sh fetch --group "Linux servers" --tag "production" --limit 100 --cache
```

#### diff
```bash
./merger.sh diff --fields "name,ip,location" --format json --threshold 80
```

#### tui
```bash
./merger.sh tui --mode dialog --auto-select
```

#### apply
```bash
./merger.sh apply --queue /path/to/queue.json --batch-size 50 --no-confirm
```

#### sync
```bash
./merger.sh sync --auto --profile production
```

## Workflow

The complete synchronization workflow consists of four main steps:

1. **Fetch**: Retrieve asset data from Zabbix and Topdesk
2. **Diff**: Compare assets and identify differences
3. **TUI**: Interactive selection of fields to update
4. **Apply**: Apply selected changes to Topdesk

### Automatic Workflow

For fully automated synchronization:
```bash
./merger.sh -b sync --auto
```

### Manual Step-by-Step

For controlled execution:
```bash
# Step 1: Fetch data
./merger.sh fetch --group "Topdesk"

# Step 2: Analyze differences
./merger.sh diff --fields "all"

# Step 3: Select changes interactively
./merger.sh tui

# Step 4: Apply changes
./merger.sh apply
```

## Health Check

The health check provides a comprehensive system assessment:

```bash
./merger.sh health
```

Output includes:
- Configuration status
- Directory structure validation
- Core module availability
- Python runtime check
- Required tools verification
- CLI tools detection
- Disk space monitoring
- Logging system status
- Cache status
- Last sync information

Health scores:
- 9-10: EXCELLENT - System fully operational
- 7-8: GOOD - System operational
- 5-6: FAIR - Some issues detected
- 0-4: POOR - Multiple issues require attention

## Configuration

Default configuration file: `/etc/merger.conf`

Key configuration sections:
- **Zabbix Settings**: URL, credentials, filters
- **Topdesk Settings**: URL, credentials, branch
- **Merge Settings**: Strategy, conflict resolution, batch size
- **Field Mapping**: Sync fields, custom prefixes
- **Processing Options**: Caching, retries, timeouts
- **Validation Rules**: IP, hostname, email validation
- **Output Options**: Format, reports, compression
- **Logging**: Level, rotation, file limits
- **Performance**: Parallel processing, workers

## Components

The merger integrates these agent modules:

1. **datafetcher** (`lib/datafetcher.sh`) - Data retrieval from external systems
2. **validator** (`lib/validator.py`) - Data and configuration validation
3. **sorter** (`lib/sorter.py`) - Asset comparison and difference analysis
4. **tui_operator** (`bin/tui_operator.sh`) - Terminal user interface
5. **apply** (`lib/apply.py`) - Change application to Topdesk
6. **logger** (`lib/logger.py`) - Centralized logging system

## Directory Structure

```
topdesk-zbx-merger/
├── bin/
│   ├── merger.sh           # Main orchestration script
│   └── tui_operator.sh     # TUI component
├── lib/
│   ├── common.sh           # Shared utilities
│   ├── datafetcher.sh      # Data retrieval
│   ├── validator.py        # Validation module
│   ├── sorter.py          # Comparison module
│   ├── apply.py           # Application module
│   └── logger.py          # Logging module
├── etc/
│   └── merger.conf        # Configuration file
├── var/
│   ├── log/              # Log files
│   ├── cache/            # Cache directory
│   └── run/              # PID files
└── output/
    ├── differences/      # Diff reports
    ├── apply/           # Apply results
    └── reports/         # Generated reports
```

## Error Handling

The script implements comprehensive error handling:

- **Exit codes**:
  - 0: Success
  - 1: General error
  - 2: Configuration error
  - 3: Connection error
  - 4: Data error
  - 5: Component error

- **Recovery mechanisms**:
  - Automatic retry with exponential backoff
  - Stale PID file detection and cleanup
  - Graceful degradation for missing CLI tools
  - Transaction rollback on apply failures

## Logging

Centralized logging with multiple levels:
- **DEBUG**: Detailed debugging information
- **INFO**: General informational messages
- **WARNING**: Warning conditions
- **ERROR**: Error conditions

Log location: `/var/log/merger.log`

## Performance Optimization

- **Caching**: Reduces API calls with configurable TTL
- **Parallel processing**: Multi-worker support for large datasets
- **Batch operations**: Configurable batch sizes for updates
- **Connection pooling**: Reuses connections where possible

## Security Considerations

- Credentials stored in configuration file (protect with appropriate permissions)
- SSL/TLS verification enabled by default
- No sensitive data in log files
- Support for API tokens instead of passwords
- Keyring integration available for credential storage

## Troubleshooting

### Common Issues

1. **Configuration not found**:
   ```bash
   ./merger.sh validate  # Creates default configuration
   ```

2. **Module not found**:
   ```bash
   ./merger.sh health   # Shows missing components
   ```

3. **Connection failures**:
   ```bash
   ./merger.sh validate  # Tests connectivity
   ```

4. **Stale PID file**:
   ```bash
   rm /var/run/merger.pid
   ```

5. **Permission denied**:
   ```bash
   chmod +x bin/*.sh lib/*.sh
   ```

### Debug Mode

Enable debug mode for detailed output:
```bash
./merger.sh -d sync
```

### Dry Run

Test changes without applying:
```bash
./merger.sh -n sync
```

## Best Practices

1. **Regular health checks**: Run `health` command periodically
2. **Test with dry-run**: Always test with `-n` flag first
3. **Incremental sync**: Use filters to limit scope
4. **Monitor logs**: Check logs for warnings and errors
5. **Backup before major changes**: Export current state before bulk updates
6. **Use profiles**: Create profiles for different environments
7. **Schedule off-peak**: Run intensive operations during low-usage periods

## Support

For issues or questions:
1. Check the health status: `./merger.sh health`
2. Review the log file: `/var/log/merger.log`
3. Run validation: `./merger.sh validate`
4. Enable debug mode: `./merger.sh -d <command>`

## Version History

- **3.0.0** (2025): Complete rewrite with agent integration
- **2.0.0**: Enhanced error handling and validation
- **1.0.0**: Initial release

## License

Internal use only. All rights reserved.