# CLI Tools Setup Guide

This guide explains how to set up and configure the actual Zabbix and Topdesk CLI tools for the merger system.

## Prerequisites

The merger requires the following CLI tools:

1. **zbx-cli** - Zabbix command-line interface
2. **topdesk-cli** - Topdesk command-line interface
3. **Python 3** - For data processing

## Installation

### 1. Check Current Status

First, check which tools are already installed:

```bash
./lib/check_cli_tools.sh
```

This script will:
- Check for available CLI tools
- Show installation instructions for missing tools
- Create sample configuration files
- Test connections if tools are configured

### 2. Install Zabbix CLI (zbx-cli)

The Zabbix CLI can be installed in several ways:

#### Option A: Using pip (Recommended)
```bash
pip install zbx-cli
```

#### Option B: From source
```bash
git clone https://github.com/unioslo/zabbix-cli.git
cd zabbix-cli
pip install .
```

#### Option C: Package managers
```bash
# Debian/Ubuntu
apt-get install zabbix-cli

# RHEL/CentOS
yum install zabbix-cli

# macOS with Homebrew
brew install zbx-cli  # if available
```

### 3. Install Topdesk CLI

The Topdesk CLI installation depends on your organization's setup:

- Check with your IT department or Topdesk vendor
- May be available in internal package repositories
- Could require special access or licenses

Common installation methods:
- Download from internal repository
- Install via company package manager
- Request from IT support

### 4. Configure Zabbix CLI

Create or edit `~/.config/zbx-cli/config.ini`:

```ini
[zabbix]
# Your Zabbix server URL
server = https://zabbix.example.com

# Authentication method: password or token
auth_method = password

# For password authentication
username = your_username
password = your_password

# For token authentication (comment out username/password above)
# auth_token = your_api_token

# SSL verification
verify_ssl = true

# Request timeout in seconds
timeout = 30

[output]
# Default output format: json, text, or csv
format = json
```

### 5. Configure Topdesk CLI

Create or edit `~/.config/topdesk-cli/config.ini`:

```ini
[topdesk]
# Your Topdesk instance URL
url = https://topdesk.example.com

# Authentication method: api_key or password
auth_method = api_key

# For API key authentication
api_key = your_api_key

# For password authentication (comment out api_key above)
# username = your_username
# password = your_password

# SSL verification
verify_ssl = true

# Request timeout in seconds
timeout = 30

[output]
# Default output format: json, text, or csv
format = json
```

## Command Syntax

### Zabbix CLI Commands

The merger uses the following zbx-cli commands:

```bash
# List hosts in a group
zbx-cli show_hosts --hostgroup "Topdesk"

# List hosts with a specific tag
zbx-cli show_hosts --tag "topdesk_sync"
zbx-cli show_hosts --tag "environment:production"

# Get host details
zbx-cli show_host "hostname"

# Get host inventory
zbx-cli show_host_inventory "hostname"

# Get host interfaces
zbx-cli show_host_interfaces "hostname"
```

### Topdesk CLI Commands

The merger uses the following topdesk-cli commands:

```bash
# List all assets
topdesk-cli asset list

# List assets with filter
topdesk-cli asset list --filter "status=active"

# Get specific asset
topdesk-cli asset get "asset-id"

# Search assets
topdesk-cli asset search --query "server" --field "name"

# List with pagination
topdesk-cli asset list --limit 100 --offset 0
```

## Testing the Setup

### 1. Test Individual Tools

Test Zabbix CLI:
```bash
zbx-cli --config ~/.config/zbx-cli/config.ini show_hosts --limit 1
```

Test Topdesk CLI:
```bash
topdesk-cli --config ~/.config/topdesk-cli/config.ini asset list --limit 1
```

### 2. Test with Wrapper

The merger includes a wrapper that can work with or without the actual CLI tools:

```bash
# Test both systems
./lib/cli_wrapper.sh test

# Test Zabbix only
./lib/cli_wrapper.sh zbx show_hosts --limit 1

# Test Topdesk only
./lib/cli_wrapper.sh td asset list --limit 1
```

### 3. Test Data Fetcher

Once the CLI tools are configured:

```bash
# Validate tools
./lib/datafetcher.sh validate

# Fetch from Zabbix only
./lib/datafetcher.sh zabbix "Topdesk"

# Fetch from Topdesk only
./lib/datafetcher.sh topdesk

# Fetch from both systems
./lib/datafetcher.sh fetch
```

## Mock Mode

If the CLI tools are not available, the system can run in mock mode for testing:

```bash
# Enable mock mode explicitly
export MOCK_MODE=true
./lib/datafetcher.sh fetch

# Disable mock mode (requires actual CLI tools)
export MOCK_MODE=false
./lib/datafetcher.sh fetch

# Auto mode (uses mock if tools not found)
export MOCK_MODE=auto
./lib/datafetcher.sh fetch
```

## Environment Variables

The following environment variables can be used to configure the CLI tools:

```bash
# Zabbix Configuration
export ZABBIX_SERVER="https://zabbix.example.com"
export ZABBIX_USER="username"
export ZABBIX_PASS="password"
export ZBX_CLI_CONFIG="$HOME/.config/zbx-cli/config.ini"
export ZBX_CLI_COMMAND="/usr/local/bin/zbx-cli"  # If not in PATH

# Topdesk Configuration
export TOPDESK_URL="https://topdesk.example.com"
export TOPDESK_API_KEY="your-api-key"
export TOPDESK_CLI_CONFIG="$HOME/.config/topdesk-cli/config.ini"
export TOPDESK_CLI_COMMAND="/usr/local/bin/topdesk-cli"  # If not in PATH

# General Settings
export LOG_LEVEL="INFO"
export CACHE_DIR="/tmp/asset-merger-engine/cache"
export CACHE_TTL=300
export MOCK_MODE="auto"  # auto, true, or false
```

## Troubleshooting

### CLI Tools Not Found

If the check script can't find the CLI tools:

1. Verify installation:
   ```bash
   which zbx-cli
   which topdesk-cli
   ```

2. Check PATH:
   ```bash
   echo $PATH
   ```

3. Try full path:
   ```bash
   /usr/local/bin/zbx-cli --version
   ```

4. Set command path explicitly:
   ```bash
   export ZBX_CLI_COMMAND="/usr/local/bin/zbx-cli"
   export TOPDESK_CLI_COMMAND="/usr/local/bin/topdesk-cli"
   ```

### Authentication Failures

1. Check config file permissions:
   ```bash
   ls -la ~/.config/zbx-cli/config.ini
   ls -la ~/.config/topdesk-cli/config.ini
   ```

2. Test authentication manually:
   ```bash
   zbx-cli --config ~/.config/zbx-cli/config.ini test_auth
   topdesk-cli --config ~/.config/topdesk-cli/config.ini test
   ```

3. Check logs:
   ```bash
   tail -f /tmp/asset-merger-engine/merger.log
   ```

### Connection Timeouts

1. Increase timeout values:
   ```bash
   export ZBX_TIMEOUT=60
   export TD_TIMEOUT=60
   ```

2. Check network connectivity:
   ```bash
   curl -I https://zabbix.example.com
   curl -I https://topdesk.example.com
   ```

### SSL Certificate Issues

If you encounter SSL verification errors:

1. For testing only (not recommended for production):
   ```ini
   # In config files
   verify_ssl = false
   ```

2. Better solution - add certificates:
   ```bash
   export REQUESTS_CA_BUNDLE=/path/to/ca-bundle.crt
   ```

## API Documentation

- **Zabbix CLI**: https://github.com/unioslo/zabbix-cli
- **Zabbix API**: https://www.zabbix.com/documentation/current/manual/api
- **Topdesk API**: Check your Topdesk instance documentation

## Support

For issues specific to:
- **Zabbix CLI**: File issues at https://github.com/unioslo/zabbix-cli/issues
- **Topdesk CLI**: Contact your Topdesk vendor or IT support
- **This merger tool**: Check the project documentation