# Apply Module - Topdesk Asset Updater

## Overview

The Apply module processes APL (Application Change List) files and applies changes to Topdesk assets using either the `topdesk-cli` command-line tool or direct API calls.

## Quick Start

### 1. Set Up Authentication

```bash
# Set environment variables (recommended)
export TOPDESK_URL=https://your-instance.topdesk.net
export TOPDESK_USERNAME=your-username
export TOPDESK_API_KEY=your-api-key
```

To generate an API key:
1. Log into Topdesk
2. Go to Settings → API Management → Application passwords
3. Create a new application password
4. Copy the generated API key

### 2. Test Your Connection

```bash
# Run the connection test script
python3 lib/test_topdesk_connection.py
```

### 3. Process APL Files

```bash
# Process a single APL file
python3 lib/apply_cli.py changes.apl

# Dry run (preview changes without applying)
python3 lib/apply_cli.py changes.apl --dry-run

# Process all APL files in a directory
python3 lib/apply_cli.py /path/to/apl/directory/

# Verbose mode for debugging
python3 lib/apply_cli.py changes.apl --verbose
```

## Installation

### Option 1: Using topdesk-cli (Recommended)

```bash
# Install the official Topdesk CLI tool
pip install topdesk-cli

# Or if available from your organization
# Follow your organization's installation guide
```

### Option 2: Direct API Calls (Fallback)

```bash
# Install required Python library
pip install requests
```

The module will automatically detect which method is available and use it.

## APL File Format

APL files are JSON files containing asset updates:

```json
[
  {
    "asset_id": "ASSET-001",
    "fields": {
      "ip_address": "192.168.1.100",
      "location": "Server Room A",
      "status": "active",
      "owner": "IT Department"
    }
  },
  {
    "asset_id": "ASSET-002",
    "fields": {
      "hostname": "webserver-01",
      "operating_system": "Ubuntu 22.04"
    }
  }
]
```

## Command-Line Options

```bash
python3 lib/apply_cli.py [OPTIONS] <apl_file_or_directory>
```

### Basic Options

- `--dry-run` - Preview changes without applying them
- `--verbose` - Enable detailed logging
- `--output-dir DIR` - Directory for reports and logs (default: ./output)

### Processing Options

- `--batch-size N` - Number of assets to update in each batch (default: 10)
- `--max-retries N` - Maximum retry attempts for failed operations (default: 3)
- `--retry-delay SECONDS` - Initial delay between retries (default: 2.0)

### Authentication Options

- `--topdesk-url URL` - Topdesk instance URL (overrides env var)
- `--topdesk-username USERNAME` - Topdesk username (overrides env var)
- `--topdesk-api-key KEY` - Topdesk API key (overrides env var)

### Advanced Options

- `--pattern GLOB` - File pattern when processing directory (default: *.apl)
- `--force` - Force processing despite warnings
- `--skip-dependency-check` - Skip checking for required dependencies

## Features

### Error Handling

The module includes comprehensive error handling:

- **Authentication Errors (401)**: Re-validates credentials
- **Not Found Errors (404)**: Skips missing assets
- **Rate Limiting (429)**: Automatic retry with backoff
- **Server Errors (5xx)**: Retry with exponential backoff
- **Connection Errors**: Configurable retry attempts

### Batch Processing

- Processes assets in configurable batches
- Continues processing after individual failures
- Generates detailed reports for each batch

### Rollback Support

- Fetches current asset state before updates
- Can rollback changes if critical errors occur
- Saves rollback data for manual recovery

### Progress Tracking

- Real-time progress updates
- Detailed statistics (successful, failed, partial updates)
- Comprehensive reports saved to output directory

## Output Structure

```
output/
├── apply/
│   ├── reports/         # Processing reports (JSON and text)
│   ├── success/         # Successfully processed APL files
│   ├── failed/          # Failed APL files
│   └── rollback/        # Rollback data for recovery
└── apply.log            # Detailed application log
```

## Troubleshooting

### Common Issues

#### 1. Authentication Failed

```bash
# Check your credentials
echo $TOPDESK_URL
echo $TOPDESK_USERNAME
echo $TOPDESK_API_KEY

# Test connection
python3 lib/test_topdesk_connection.py
```

#### 2. CLI Not Found

```bash
# Install topdesk-cli
pip install topdesk-cli

# Or use direct API (install requests)
pip install requests
```

#### 3. Rate Limiting

The module automatically handles rate limiting with exponential backoff. To reduce rate limiting:

- Decrease batch size: `--batch-size 5`
- Increase retry delay: `--retry-delay 5.0`

#### 4. Asset Not Found

Check that asset IDs in your APL file match exactly with Topdesk:

```bash
# Test with dry run first
python3 lib/apply_cli.py your-file.apl --dry-run --verbose
```

### Debug Mode

For detailed debugging information:

```bash
# Maximum verbosity
python3 lib/apply_cli.py changes.apl --verbose --dry-run

# Check specific asset
python3 -c "
from lib.apply import APLProcessor
p = APLProcessor(dry_run=True, verbose=True)
state = p._get_asset_current_state('ASSET-ID')
print(state)
"
```

## Performance Tips

1. **Batch Size**: Adjust based on your Topdesk instance
   - Smaller batches (5-10) for rate-limited instances
   - Larger batches (20-50) for high-performance instances

2. **Parallel Processing**: Currently experimental
   ```bash
   python3 lib/apply_cli.py changes.apl --parallel --parallel-workers 4
   ```

3. **Caching**: The module caches authentication tokens to reduce API calls

## Security Considerations

1. **API Keys**: Never commit API keys to version control
2. **Environment Variables**: Use environment variables for credentials
3. **Secure Storage**: Store APL files securely
4. **Audit Logging**: All operations are logged for audit purposes

## Integration Examples

### Bash Script

```bash
#!/bin/bash
# process_updates.sh

# Set credentials
export TOPDESK_URL="https://acme.topdesk.net"
export TOPDESK_USERNAME="service-account"
export TOPDESK_API_KEY="$(cat /secure/path/api-key.txt)"

# Process APL files
python3 lib/apply_cli.py /path/to/apl/files/ \
    --batch-size 20 \
    --max-retries 5 \
    --output-dir ./reports

# Check exit code
if [ $? -eq 0 ]; then
    echo "Updates applied successfully"
else
    echo "Some updates failed - check reports"
    exit 1
fi
```

### Python Integration

```python
from lib.apply import APLProcessor

# Initialize processor
processor = APLProcessor(
    output_dir='./output',
    batch_size=10,
    max_retries=3,
    dry_run=False,
    verbose=True
)

# Process APL file
result = processor.process_apl_file('changes.apl')

if result['success']:
    print(f"Processed {result['stats']['total_assets']} assets")
    print(f"Success: {result['stats']['successful_updates']}")
    print(f"Failed: {result['stats']['failed_updates']}")
else:
    print(f"Processing failed: {result.get('error')}")
```

## Support

For issues or questions:

1. Check the troubleshooting section above
2. Run the test script: `python3 lib/test_topdesk_connection.py`
3. Review logs in the output directory
4. Check Topdesk API documentation for field names and formats