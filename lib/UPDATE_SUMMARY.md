# Data Fetcher Updates Summary

## Changes Made to Support Real CLI Tools

### 1. Updated Files

#### datafetcher.sh
- Enhanced `validate_tools()` function to:
  - Check for multiple CLI command variants (zbx-cli, zbx, zabbix-cli)
  - Check for Topdesk CLI variants (topdesk-cli, topdesk, td-cli)
  - Support MOCK_MODE environment variable for testing without actual tools
  - Provide clear installation instructions when tools are missing
  - Export detected command names as environment variables

#### auth_manager.sh
- Added `detect_zbx_command()` function to find available Zabbix CLI
- Added `detect_topdesk_command()` function to find available Topdesk CLI
- Updated authentication functions to use detected command names
- Enhanced error messages with installation instructions

#### zbx_cli_wrapper.sh
- Updated to use `ZBX_CLI_COMMAND` environment variable
- Modified command syntax to match actual zbx-cli patterns:
  - `show_hosts --hostgroup` instead of `host list --group`
  - `show_host_inventory` instead of `host inventory`
  - `show_host_interfaces` instead of `host interface`
- Added comments noting actual CLI syntax variations

#### topdesk_cli_wrapper.sh
- Updated to use `TOPDESK_CLI_COMMAND` environment variable
- Modified command syntax to match common topdesk-cli patterns:
  - `asset list` instead of `assets list`
  - `asset get` instead of `assets get`
  - `location list` instead of `locations list`
- Added comments noting actual CLI syntax variations

#### config.template
- Added installation instructions for CLI tools
- Added `ZBX_CLI_COMMAND` and `TOPDESK_CLI_COMMAND` configuration options
- Enhanced comments with actual CLI documentation links

### 2. New Files Created

#### check_cli_tools.sh
- Comprehensive tool to check CLI installation status
- Tests for multiple command variants
- Creates sample configuration files
- Tests connections if tools are configured
- Provides colored output for easy reading
- Shows installation instructions for missing tools

#### cli_wrapper.sh
- Unified wrapper supporting both real and mock modes
- Auto-detects available CLI tools
- Falls back to mock mode when tools are missing
- Allows explicit mode control via MOCK_MODE variable
- Provides test data for development and testing

#### CLI_TOOLS_README.md
- Complete documentation for CLI tool setup
- Installation instructions for both tools
- Configuration examples
- Command syntax reference
- Troubleshooting guide
- Environment variable documentation

### 3. Key Features Added

#### Multi-Command Support
The system now checks for multiple command name variants:
- Zabbix: zbx-cli, zbx, zabbix-cli
- Topdesk: topdesk-cli, topdesk, td-cli

#### Mock Mode
- `MOCK_MODE=auto`: Automatically use mock if tools not found (default)
- `MOCK_MODE=true`: Force mock mode for testing
- `MOCK_MODE=false`: Require real tools (fail if not found)

#### Enhanced Error Handling
- Clear error messages when tools are missing
- Installation instructions provided inline
- Warnings for missing tools but continue in mock mode
- Debug messages showing which tools were detected

#### Configuration Flexibility
- Support for custom command paths via environment variables
- Multiple configuration file locations checked
- Sample configuration files automatically created
- Existing config files detected and used

## Testing the Updates

### 1. Check Tool Status
```bash
./lib/check_cli_tools.sh
```

### 2. Test in Mock Mode
```bash
# Automatic mock mode (if tools not installed)
./lib/datafetcher.sh validate

# Force mock mode
MOCK_MODE=true ./lib/datafetcher.sh fetch

# Test wrapper
./lib/cli_wrapper.sh test
```

### 3. Test with Real Tools (when installed)
```bash
# Disable mock mode
MOCK_MODE=false ./lib/datafetcher.sh validate

# Fetch real data
./lib/datafetcher.sh fetch
```

## Environment Variables

### Tool Detection
- `ZBX_CLI_COMMAND`: Path to zbx-cli command
- `TOPDESK_CLI_COMMAND`: Path to topdesk-cli command
- `MOCK_MODE`: Control mock mode (auto/true/false)

### Authentication
- `ZABBIX_SERVER`: Zabbix server URL
- `ZABBIX_USER`: Zabbix username
- `ZABBIX_PASS`: Zabbix password
- `TOPDESK_URL`: Topdesk instance URL
- `TOPDESK_API_KEY`: Topdesk API key

## Next Steps

1. **Install CLI Tools** (if available):
   ```bash
   pip install zbx-cli
   # Contact IT for topdesk-cli
   ```

2. **Configure Authentication**:
   - Edit `~/.config/zbx-cli/config.ini`
   - Edit `~/.config/topdesk-cli/config.ini`

3. **Test Connections**:
   ```bash
   ./lib/check_cli_tools.sh
   ```

4. **Run Data Fetcher**:
   ```bash
   ./lib/datafetcher.sh fetch
   ```

## Compatibility Notes

- The system gracefully handles missing CLI tools
- Mock mode allows development and testing without actual tools
- Real CLI syntax may vary by version - commands are documented with notes
- Configuration supports multiple CLI tool versions and installations