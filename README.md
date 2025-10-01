# Asset Merger Engine (`merger`)

A **POSIX-compliant toolkit** for synchronizing asset data between [Zabbix](https://www.zabbix.com/) and [Topdesk](https://www.topdesk.com/) systems, built around the Unix philosophy: modular components, composable workflows, and text-based data interchange.

---

## Features

* **`merger <subcommand>`** style CLI interface (like `git`).
* **Agent-based architecture** with specialized components for each task:
  - `datafetcher` — Retrieves assets from both Zabbix and Topdesk
  - `differ` — Compares and identifies field-level differences
  - `sorter` — Ensures deterministic ordering of all data
  - `tuioperator` — Interactive terminal UI for manual field selection
  - `applier` — Applies changes to Topdesk system
  - `validator` — Validates data integrity and configuration
  - `logger` — Comprehensive logging and monitoring
* **Multiple output formats**: DIF files, APL files, JSON, CSV for easy integration
* **Three TUI backends**: dialog, whiptail, or pure POSIX shell
* **Batch processing** with configurable sizes and retry logic
* **Dry-run mode** for safe testing without making changes
* **Health monitoring** with 10-point scoring system

---

## Requirements

* **POSIX shell** (sh, bash, dash)
* **Python 3** (3.8+)
* **zbx** — Zabbix CLI toolkit (see [zbx-cli](https://github.com/Bissbert/zbx-cli))
* **topdesk** — Topdesk CLI toolkit (see [topdesk-cli](https://github.com/Bissbert/topdesk-cli))
* Optional: **dialog** or **whiptail** for enhanced TUI experience
* Optional: **jq** for advanced JSON processing

---

## Installation

System-wide (default prefix `/usr/local`):

```bash
cd asset-merger-engine
make install        # installs scripts, libraries, and configuration
```

Per-user (no root required):

```bash
make install-user   # installs into ~/.local/bin and ~/.config/merger/
```

Quick test installation:

```bash
./test_merger.sh    # runs comprehensive test suite
```

---

## Quickstart

```bash
# 1. Configure both zbx and topdesk CLIs first
zbx config init
topdesk config init

# 2. Initialize merger configuration
export MERGER_CONFIG=$HOME/.config/merger/merger.conf
cp etc/merger.conf.sample $MERGER_CONFIG

# 3. Edit configuration with your settings
vi $MERGER_CONFIG

# 4. Validate system setup
./bin/merger.sh validate

# 5. Check system health
./bin/merger.sh health

# 6. Fetch data from both systems
./bin/merger.sh fetch Topdesk

# 7. Generate difference reports
./bin/merger.sh diff

# 8. Review differences interactively
./bin/merger.sh tui

# 9. Apply selected changes
./bin/merger.sh apply

# Or run the complete sync workflow
./bin/merger.sh sync
```

---

## Configuration

Configuration is read from (in order):
1. Environment variables
2. `$MERGER_CONFIG` file path
3. `~/.config/merger/merger.conf`
4. `/etc/merger/merger.conf`

Example configuration:

```bash
# Zabbix Settings
ZABBIX_GROUP="Topdesk"              # Host group to fetch
ZABBIX_TAG=""                        # Optional tag filter

# Topdesk Settings
TOPDESK_FILTER=""                    # Optional asset filter

# Processing Options
BATCH_SIZE=10                        # Items per batch
MAX_RETRIES=3                        # Retry attempts
RETRY_DELAY=2                        # Seconds between retries
CACHE_TTL=300                        # Cache lifetime in seconds

# Output Settings
OUTPUT_DIR="./output"                # Output directory
LOG_LEVEL="INFO"                     # DEBUG|INFO|WARNING|ERROR
DRY_RUN=false                        # Test mode without changes

# Field Mappings (Zabbix -> Topdesk)
FIELD_MAP_hostname="name"
FIELD_MAP_ip_address="ipAddress"
FIELD_MAP_location="location"
FIELD_MAP_asset_tag="assetTag"
```

---

## Commands

### Core Commands

* **`merger fetch [group] [filter]`** — Retrieve assets from both systems
* **`merger diff`** — Compare assets and generate .dif files
* **`merger tui`** — Interactive field-by-field comparison UI
* **`merger apply [file.apl]`** — Apply changes to Topdesk
* **`merger sync`** — Run complete workflow (fetch → diff → tui → apply)

### Utility Commands

* **`merger validate`** — Validate configuration and tools
* **`merger health`** — System health check with scoring
* **`merger status`** — Show current process status
* **`merger clean`** — Clean cache and temporary files

### Options

* **`--config FILE`** — Use alternate configuration file
* **`--dry-run`** — Preview changes without applying
* **`--verbose`** — Detailed output
* **`--debug`** — Debug mode with trace logging
* **`--help`** — Show help message
* **`--version`** — Show version information

---

## Data Flow

```
┌─────────┐      ┌─────────┐
│ Zabbix  │      │ Topdesk │
└────┬────┘      └────┬────┘
     │                │
     ▼                ▼
┌─────────────────────────┐
│    DataFetcher Agent    │ ← Retrieves assets
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│     Differ Agent        │ ← Compares fields
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│     Sorter Agent        │ ← Ensures order
└───────────┬─────────────┘
            │
         .dif files
            │
            ▼
┌─────────────────────────┐
│   TUI Operator Agent    │ ← Manual selection
└───────────┬─────────────┘
            │
         .apl files
            │
            ▼
┌─────────────────────────┐
│     Applier Agent       │ ← Updates Topdesk
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│    Validator Agent      │ ← Verifies changes
└─────────────────────────┘
```

---

## File Formats

### DIF Files (Difference Format)

```yaml
asset_id: ASSET001
differences:
  - field_name: ip_address
    zabbix_value: "10.0.1.10"
    topdesk_value: "10.0.1.11"
  - field_name: location
    zabbix_value: "DataCenter-1"
    topdesk_value: "null"
```

### APL Files (Apply Format)

```json
[
  {
    "asset_id": "ASSET001",
    "fields": {
      "ip_address": "10.0.1.10",
      "location": "DataCenter-1"
    }
  }
]
```

---

## TUI (Terminal User Interface)

Three backends available (auto-detected):

1. **Dialog** — Feature-rich with colors and mouse support
2. **Whiptail** — Lightweight, commonly available
3. **Pure Shell** — No dependencies, works everywhere

Launch with:
```bash
./bin/tui_launcher.sh    # Auto-selects best available
```

---

## Logging

All operations are logged to:
- **Console** — Colored output based on log level
- **File** — `output/merger.log` with rotation
- **Syslog** — Optional system logging

View logs:
```bash
./lib/log_viewer.py tail -n 50           # Last 50 lines
./lib/log_viewer.py errors --verbose     # Show all errors
./lib/log_viewer.py stats                # Statistics
```

---

## Testing

Run the comprehensive test suite:

```bash
./test_merger.sh        # Full integration tests
```

Test individual components:
```bash
./lib/datafetcher.sh validate     # Test data fetching
python3 lib/test_validator.py     # Test validation
python3 lib/test_sorter.py        # Test sorting
```

---

## Troubleshooting

### Common Issues

**CLI tools not found**
```bash
# Check if zbx and topdesk are in PATH
which zbx topdesk

# Run health check
./bin/merger.sh health
```

**Authentication failures**
```bash
# Test Zabbix connection
zbx ping

# Test Topdesk connection
topdesk call GET /tas/api/version
```

**Permission denied**
```bash
# Check file permissions
ls -la bin/*.sh lib/*.sh

# Make scripts executable
chmod +x bin/*.sh lib/*.sh
```

**Python module errors**
```bash
# Install required Python packages
pip3 install pyyaml requests
```

---

## Architecture

The merger tool follows a **multi-agent architecture** where specialized agents handle specific tasks:

- **agent-datafetcher** — API interaction and data retrieval
- **agent-differ** — Field-level comparison logic
- **agent-sorter** — Deterministic ordering algorithms
- **agent-tuioperator** — User interface and interaction
- **agent-applier** — Change application and rollback
- **agent-validator** — Data and configuration validation
- **agent-logger** — Logging and monitoring
- **agent-docwriter** — Documentation generation

Each agent can be invoked independently for debugging:
```bash
./lib/datafetcher.sh fetch Topdesk
python3 lib/differ.py --input1 zabbix.json --input2 topdesk.json
```

---

## Advanced Usage

### Batch Processing

Process multiple APL files:
```bash
for file in output/apply/*.apl; do
    ./bin/merger.sh apply "$file" --batch-size 20
done
```

### Custom Field Mappings

Add to configuration:
```bash
FIELD_MAP_custom_field="topdeskFieldName"
FIELD_MAP_serial_number="serialNumber"
```

### Parallel Processing

Enable parallel fetching:
```bash
PARALLEL_FETCH=true ./bin/merger.sh fetch
```

### Scheduled Synchronization

Add to crontab:
```bash
# Run sync every hour
0 * * * * /path/to/merger.sh sync --quiet >> /var/log/merger.log 2>&1
```

---

## Contributing

1. Fork the repository
2. Create a feature branch
3. Follow POSIX shell standards
4. Add tests for new features
5. Update documentation
6. Submit a pull request

---

## License

This project is provided as-is for internal use. See LICENSE file for details.

---

## Support

- **Documentation**: See `doc/` directory for detailed guides
- **API Reference**: `doc/API_MODULE_REFERENCE.md`
- **Scenarios**: `doc/SCENARIOS_AND_EXAMPLES.md`
- **CLI Reference**: `doc/CLI_REFERENCE.md`

---

## Version

Current version: **3.0.0**

Check version:
```bash
./bin/merger.sh --version
```

---

## Credits

Built with the Unix philosophy in mind, leveraging:
- **zbx** toolkit for Zabbix integration
- **topdesk** toolkit for Topdesk integration
- POSIX shell for maximum portability
- Python for complex data processing

Developed as a composable, maintainable solution for asset synchronization.
