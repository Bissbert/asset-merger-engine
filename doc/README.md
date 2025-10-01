# Topdesk-Zabbix Merger Tool

## Overview
The topdesk-zbx-merger is a POSIX-compliant shell tool designed to synchronize asset data between Zabbix monitoring system and Topdesk asset management system.

## Features
- Fetch asset data from Zabbix
- Merge with existing Topdesk assets
- Update Topdesk with synchronized data
- Configurable field mappings
- Batch processing support
- Comprehensive logging
- Dry-run capability

## Requirements
- POSIX-compliant shell (sh, bash, dash, etc.)
- zbx-cli - Zabbix command-line interface
- topdesk-cli - Topdesk command-line interface
- jq - JSON processor
- Standard Unix utilities (sed, awk, grep, etc.)

## Installation
```bash
# Clone or download the tool
cd /path/to/installation

# Make scripts executable
chmod +x bin/merger.sh

# Copy sample configuration
cp etc/merger.conf.sample etc/merger.conf

# Edit configuration with your credentials
vi etc/merger.conf
```

## Quick Start
```bash
# Validate configuration
./bin/merger.sh validate

# Perform dry-run synchronization
./bin/merger.sh -n sync

# Run full synchronization
./bin/merger.sh sync

# Generate report
./bin/merger.sh report
```

## Directory Structure
```
topdesk-zbx-merger/
├── bin/           # Executable scripts
│   └── merger.sh  # Main merger script
├── lib/           # Shared libraries
│   ├── common.sh  # Common functions
│   ├── zabbix.sh  # Zabbix-specific functions
│   └── topdesk.sh # Topdesk-specific functions
├── etc/           # Configuration files
│   └── merger.conf # Main configuration
├── var/           # Runtime data
│   ├── log/       # Log files
│   ├── run/       # PID and lock files
│   └── cache/     # Cache directory
├── output/        # Output files
│   ├── processed/ # Successfully processed data
│   ├── failed/    # Failed items
│   └── reports/   # Generated reports
├── tmp/           # Temporary files
└── doc/           # Documentation
    └── README.md  # This file
```

## Configuration
See `etc/merger.conf` for all available configuration options.

## Documentation
- [CLI Reference](CLI_REFERENCE.md)
- [Field Mappings](FIELD_MAPPINGS.md)
- [Troubleshooting](TROUBLESHOOTING.md)

## License
Internal use only

## Support
Contact your system administrator for support.