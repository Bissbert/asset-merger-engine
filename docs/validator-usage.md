# Validator Module Usage Guide

## Overview
The validator module provides comprehensive validation for the Topdesk-Zabbix merger tool, ensuring data integrity and proper system configuration before and during operations.

## Pre-Execution Validation

The validator now includes extensive pre-execution checks to verify system readiness:

### Phase 1: Tool Availability
- Checks if `zbx` command exists in PATH
- Checks if `topdesk` command exists in PATH
- Verifies both commands are executable
- Attempts to retrieve version information
- Provides installation instructions if tools are missing

### Phase 2: Configuration and Authentication
- Checks for Zabbix configuration files:
  - `~/.zabbix/config.yaml`
  - `~/.zabbix/config.yml`
  - `~/.config/zabbix-cli/config.yaml`
- Checks for Zabbix environment variables:
  - `ZABBIX_URL`
  - `ZABBIX_USERNAME`
  - `ZABBIX_PASSWORD`
  - `ZABBIX_TOKEN`
- Checks for Topdesk configuration files:
  - `~/.topdesk/config.yaml`
  - `~/.topdesk/config.yml`
  - `~/.config/topdesk/config.yaml`
- Checks for Topdesk environment variables:
  - `TOPDESK_URL`
  - `TOPDESK_USERNAME`
  - `TOPDESK_PASSWORD`
  - `TOPDESK_API_KEY`
  - `TOPDESK_TOKEN`

### Phase 3: Permissions
- Verifies write permissions for:
  - Current working directory
  - Output directory (default: `./output`)
  - Cache directory (default: `./cache`)
  - Temp directory (`/tmp`)
- Attempts to create directories if they don't exist

### Phase 4: Connection Testing
- Tests Zabbix API connection with: `zbx host list --limit 1`
- Tests Topdesk API connection with: `topdesk asset list --limit 1`
- Provides specific error messages for:
  - Authentication failures
  - Connection timeouts
  - Configuration errors
  - Network issues

## Usage Examples

### Run Pre-Execution Checks
```bash
# Basic pre-execution validation
./bin/validator --pre-check

# With custom configuration
./bin/validator --pre-check --config config.json

# Verbose output for debugging
./bin/validator --pre-check --verbose
```

### Validate DIF Files
```bash
# Validate a specific DIF file
./bin/validator --dif output/asset_123.dif

# Validate with verbose output
./bin/validator --dif output/asset_123.dif --verbose
```

### Validate APL Files
```bash
# Validate an application file
./bin/validator --apl output/changes.apl

# Generate report to file
./bin/validator --apl output/changes.apl --output validation_report.txt
```

### Validate Cache Integrity
```bash
# Check cache directory integrity
./bin/validator --cache-dir ./cache

# With custom cache location
./bin/validator --cache-dir /tmp/merger_cache
```

### Generate Comprehensive Reports
```bash
# Generate report for all validations
./bin/validator --report

# Save report to file
./bin/validator --report --output full_validation_report.txt
```

## Configuration File Format

Create a `config.json` file with the following structure:

```json
{
  "zabbix": {
    "url": "https://zabbix.example.com",
    "username": "admin"
  },
  "topdesk": {
    "url": "https://topdesk.example.com",
    "username": "api_user"
  },
  "output_dir": "./output",
  "cache_dir": "./cache",
  "required_tools": ["zbx", "topdesk"],
  "check_connectivity": true
}
```

## Error Messages and Solutions

### Tool Not Found
**Error**: "Zabbix CLI not found in PATH"
**Solution**: Install with `pip install zabbix-cli`

**Error**: "Topdesk CLI not found in PATH"
**Solution**: Install with `pip install topdesk-cli`

### Configuration Missing
**Error**: "No Zabbix configuration found"
**Solution**:
1. Run `zbx init` to configure interactively, or
2. Set environment variables:
   ```bash
   export ZABBIX_URL=https://zabbix.example.com
   export ZABBIX_USERNAME=your_username
   export ZABBIX_PASSWORD=your_password
   ```

### Authentication Failed
**Error**: "Zabbix authentication failed"
**Solution**:
1. Check credentials in configuration file
2. Verify API token is valid
3. Ensure user has proper permissions

### Connection Issues
**Error**: "Cannot connect to Zabbix server"
**Solution**:
1. Verify server URL is correct
2. Check network connectivity
3. Ensure firewall allows connection
4. Verify VPN connection if required

### Permission Denied
**Error**: "No write permission for directory"
**Solution**:
1. Check directory ownership
2. Adjust permissions with `chmod`
3. Run with appropriate user privileges

## Validation Status Levels

- **PASSED**: All checks completed successfully
- **PASSED_WITH_WARNINGS**: Checks passed but some issues detected
- **FAILED**: Critical errors found, operation should not proceed
- **SKIPPED**: Validation was skipped (e.g., optional checks)
- **ERROR**: Validation process itself encountered an error

## Exit Codes

When running pre-execution checks:
- `0`: All validations passed
- `1`: Critical errors found, do not proceed with merger

## Integration with Merger Tool

The validator should be run before any merger operation:

```bash
# Pre-flight check before running merger
./bin/validator --pre-check || exit 1

# If successful, proceed with merger
./bin/merger --sync
```

## Troubleshooting

### Debug Mode
Enable verbose output to see detailed validation steps:
```bash
./bin/validator --pre-check --verbose
```

### Quick Mode
Skip connection tests for faster validation (not recommended for production):
```bash
./bin/validator --pre-check --quick
```

### Check Individual Components
Test specific aspects:
```bash
# Only check tool availability
python3 -c "from lib.validator import MergerValidator; v = MergerValidator(); r = v._validate_tools(); print(r.generate_report())"
```

## Best Practices

1. **Always run pre-execution checks** before starting merger operations
2. **Keep configurations in environment variables** for security
3. **Review warnings** even if validation passes
4. **Save validation reports** for audit trails
5. **Run with --verbose** when troubleshooting
6. **Ensure both CLIs are properly configured** before validation
7. **Test connections periodically** to catch authentication expiry

## Support

For issues or questions:
1. Check error messages for specific guidance
2. Run with `--verbose` for detailed output
3. Review configuration files and environment variables
4. Ensure network connectivity to both servers
5. Verify tool installations with `which zbx` and `which topdesk`