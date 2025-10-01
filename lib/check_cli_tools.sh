#!/bin/sh
# check_cli_tools.sh - Check and validate CLI tools installation

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check for command existence
check_command() {
    local cmd="$1"
    local name="$2"
    local install_info="$3"

    if command -v "$cmd" >/dev/null 2>&1; then
        echo "${GREEN}✓${NC} $name found: $(command -v $cmd)"
        return 0
    else
        echo "${RED}✗${NC} $name not found"
        echo "  ${YELLOW}Installation:${NC} $install_info"
        return 1
    fi
}

# Check for Zabbix CLI variants
check_zbx_cli() {
    echo "\nChecking for Zabbix CLI..."
    local found=0

    for cmd in zbx-cli zbx zabbix-cli; do
        if command -v "$cmd" >/dev/null 2>&1; then
            echo "${GREEN}✓${NC} Found Zabbix CLI: $cmd ($(command -v $cmd))"

            # Try to get version
            if $cmd --version 2>/dev/null; then
                echo "  Version: $($cmd --version 2>/dev/null | head -1)"
            fi

            # Check for config file
            local config_paths="
                ${HOME}/.config/zbx-cli/config.ini
                ${HOME}/.zbx-cli.conf
                ${HOME}/.zabbix-cli.conf
                /etc/zbx-cli/config.ini
            "

            echo "  Checking for config files:"
            for config in $config_paths; do
                if [ -f "$config" ]; then
                    echo "    ${GREEN}✓${NC} $config"
                fi
            done

            found=1
            export ZBX_CLI_COMMAND="$cmd"
            break
        fi
    done

    if [ $found -eq 0 ]; then
        echo "${RED}✗${NC} Zabbix CLI not found"
        echo ""
        echo "  ${YELLOW}Installation options:${NC}"
        echo "  1. Using pip (recommended):"
        echo "     pip install zbx-cli"
        echo ""
        echo "  2. From source:"
        echo "     git clone https://github.com/unioslo/zabbix-cli.git"
        echo "     cd zabbix-cli"
        echo "     pip install ."
        echo ""
        echo "  3. Using package manager (if available):"
        echo "     apt-get install zabbix-cli  # Debian/Ubuntu"
        echo "     yum install zabbix-cli      # RHEL/CentOS"
        echo ""
        echo "  Documentation: https://github.com/unioslo/zabbix-cli"
    fi

    return $((1 - found))
}

# Check for Topdesk CLI variants
check_topdesk_cli() {
    echo "\nChecking for Topdesk CLI..."
    local found=0

    for cmd in topdesk-cli topdesk td-cli; do
        if command -v "$cmd" >/dev/null 2>&1; then
            echo "${GREEN}✓${NC} Found Topdesk CLI: $cmd ($(command -v $cmd))"

            # Try to get version
            if $cmd --version 2>/dev/null; then
                echo "  Version: $($cmd --version 2>/dev/null | head -1)"
            fi

            # Check for config file
            local config_paths="
                ${HOME}/.config/topdesk-cli/config.ini
                ${HOME}/.topdesk-cli.conf
                ${HOME}/.topdesk.conf
                /etc/topdesk-cli/config.ini
            "

            echo "  Checking for config files:"
            for config in $config_paths; do
                if [ -f "$config" ]; then
                    echo "    ${GREEN}✓${NC} $config"
                fi
            done

            found=1
            export TOPDESK_CLI_COMMAND="$cmd"
            break
        fi
    done

    if [ $found -eq 0 ]; then
        echo "${RED}✗${NC} Topdesk CLI not found"
        echo ""
        echo "  ${YELLOW}Installation:${NC}"
        echo "  Please check your Topdesk documentation for CLI installation instructions."
        echo "  The CLI tool may be provided by your Topdesk vendor or IT department."
        echo ""
        echo "  Common installation methods:"
        echo "  - Download from internal repository"
        echo "  - Install via company package manager"
        echo "  - Request from IT support"
    fi

    return $((1 - found))
}

# Check Python
check_python() {
    echo "\nChecking for Python..."

    if command -v python3 >/dev/null 2>&1; then
        echo "${GREEN}✓${NC} Python 3 found: $(command -v python3)"
        echo "  Version: $(python3 --version)"

        # Check for required modules
        echo "  Checking Python modules:"
        for module in json datetime csv base64; do
            if python3 -c "import $module" 2>/dev/null; then
                echo "    ${GREEN}✓${NC} $module"
            else
                echo "    ${RED}✗${NC} $module"
            fi
        done
        return 0
    else
        echo "${RED}✗${NC} Python 3 not found"
        echo "  ${YELLOW}Installation:${NC}"
        echo "  - macOS: brew install python3"
        echo "  - Ubuntu/Debian: apt-get install python3"
        echo "  - RHEL/CentOS: yum install python3"
        return 1
    fi
}

# Test Zabbix connection
test_zbx_connection() {
    local zbx_cmd="${ZBX_CLI_COMMAND:-zbx-cli}"

    echo "\nTesting Zabbix CLI connection..."

    if [ -z "$ZBX_CLI_COMMAND" ]; then
        echo "${YELLOW}!${NC} Zabbix CLI not detected, skipping connection test"
        return 1
    fi

    # Check if we have config
    if [ -f "${HOME}/.config/zbx-cli/config.ini" ]; then
        echo "  Using config: ${HOME}/.config/zbx-cli/config.ini"
        if $zbx_cmd --config "${HOME}/.config/zbx-cli/config.ini" show_hosts --limit 1 >/dev/null 2>&1; then
            echo "  ${GREEN}✓${NC} Connection successful"
            return 0
        else
            echo "  ${RED}✗${NC} Connection failed"
            echo "  Check your configuration in ${HOME}/.config/zbx-cli/config.ini"
            return 1
        fi
    else
        echo "  ${YELLOW}!${NC} No config file found"
        echo "  Create ${HOME}/.config/zbx-cli/config.ini with your Zabbix credentials"
        return 1
    fi
}

# Test Topdesk connection
test_topdesk_connection() {
    local td_cmd="${TOPDESK_CLI_COMMAND:-topdesk-cli}"

    echo "\nTesting Topdesk CLI connection..."

    if [ -z "$TOPDESK_CLI_COMMAND" ]; then
        echo "${YELLOW}!${NC} Topdesk CLI not detected, skipping connection test"
        return 1
    fi

    # Check if we have config
    if [ -f "${HOME}/.config/topdesk-cli/config.ini" ]; then
        echo "  Using config: ${HOME}/.config/topdesk-cli/config.ini"
        if $td_cmd --config "${HOME}/.config/topdesk-cli/config.ini" asset list --limit 1 >/dev/null 2>&1; then
            echo "  ${GREEN}✓${NC} Connection successful"
            return 0
        else
            echo "  ${RED}✗${NC} Connection failed"
            echo "  Check your configuration in ${HOME}/.config/topdesk-cli/config.ini"
            return 1
        fi
    else
        echo "  ${YELLOW}!${NC} No config file found"
        echo "  Create ${HOME}/.config/topdesk-cli/config.ini with your Topdesk credentials"
        return 1
    fi
}

# Create sample config files
create_sample_configs() {
    echo "\nCreating sample configuration files..."

    local config_dir="${HOME}/.config/topdesk-zbx-merger"
    mkdir -p "$config_dir"

    # Create sample merger config
    if [ ! -f "$config_dir/merger.conf" ]; then
        cp "$(dirname "$0")/config.template" "$config_dir/merger.conf.sample"
        echo "  ${GREEN}✓${NC} Created $config_dir/merger.conf.sample"
        echo "    Edit this file with your credentials and save as merger.conf"
    fi

    # Create sample zbx-cli config
    local zbx_config_dir="${HOME}/.config/zbx-cli"
    mkdir -p "$zbx_config_dir"

    if [ ! -f "$zbx_config_dir/config.ini" ]; then
        cat > "$zbx_config_dir/config.ini.sample" <<'EOF'
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

# Pretty print JSON output
pretty = true

[logging]
# Log level: DEBUG, INFO, WARNING, ERROR
level = INFO

# Log file path (optional)
# file = /var/log/zbx-cli.log
EOF
        echo "  ${GREEN}✓${NC} Created $zbx_config_dir/config.ini.sample"
        echo "    Edit this file with your Zabbix credentials and save as config.ini"
    fi

    # Create sample topdesk-cli config
    local td_config_dir="${HOME}/.config/topdesk-cli"
    mkdir -p "$td_config_dir"

    if [ ! -f "$td_config_dir/config.ini" ]; then
        cat > "$td_config_dir/config.ini.sample" <<'EOF'
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

# Pretty print JSON output
pretty = true

[pagination]
# Default page size for list operations
page_size = 100

# Maximum number of pages to fetch
max_pages = 100
EOF
        echo "  ${GREEN}✓${NC} Created $td_config_dir/config.ini.sample"
        echo "    Edit this file with your Topdesk credentials and save as config.ini"
    fi
}

# Main execution
main() {
    echo "========================================="
    echo "Topdesk-Zabbix Merger CLI Tools Check"
    echo "========================================="

    local errors=0

    # Check each component
    check_zbx_cli || errors=$((errors + 1))
    check_topdesk_cli || errors=$((errors + 1))
    check_python || errors=$((errors + 1))

    # Additional checks
    echo "\nChecking for additional tools..."
    check_command "jq" "jq (JSON processor)" "brew install jq (macOS) or apt-get install jq (Linux)"
    check_command "curl" "curl" "Usually pre-installed, or: apt-get install curl"

    # Test connections if tools are available
    if [ -n "$ZBX_CLI_COMMAND" ]; then
        test_zbx_connection
    fi

    if [ -n "$TOPDESK_CLI_COMMAND" ]; then
        test_topdesk_connection
    fi

    # Create sample configs
    create_sample_configs

    # Summary
    echo "\n========================================="
    if [ $errors -eq 0 ]; then
        echo "${GREEN}All required tools are installed!${NC}"
        echo ""
        echo "Next steps:"
        echo "1. Configure your credentials in the sample config files"
        echo "2. Test the connections using: ./datafetcher.sh validate"
        echo "3. Fetch data using: ./datafetcher.sh fetch"
    else
        echo "${YELLOW}Some tools are missing.${NC}"
        echo ""
        echo "Please install the missing tools using the instructions above."
        echo "After installation, run this script again to verify."
    fi
    echo "========================================="

    return $errors
}

# Run if executed directly
if [ "${0##*/}" = "check_cli_tools.sh" ] || [ "${0##*/}" = "bash" ]; then
    main "$@"
fi