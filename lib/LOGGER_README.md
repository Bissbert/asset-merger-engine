# Merger Tool Logging System

## Overview

The logging system provides comprehensive logging capabilities for the Topdesk-Zabbix merger tool, including:

- **Structured logging** with multiple severity levels
- **Automatic log rotation** when size limits are exceeded
- **JSON and text format** support
- **Context-aware logging** with caller information
- **Performance metrics** and statistics tracking
- **Log analysis utilities** for troubleshooting

## Features

### 1. Log Levels

The system supports six log levels:

- **TRACE (5)**: Very detailed execution flow
- **DEBUG (10)**: Diagnostic information
- **INFO (20)**: Normal operational messages  
- **WARNING (30)**: Non-critical issues or anomalies
- **ERROR (40)**: Critical failures requiring attention
- **CRITICAL (50)**: System-critical failures

### 2. Log Rotation

- Automatic rotation when log files exceed size limit (default: 10MB)
- Configurable number of backup files (default: 5)
- Old logs are compressed and archived

### 3. Output Formats

#### Text Format (Default)
```
[2024-01-15 14:32:45.123] [INFO] [DATAFETCHER] Retrieved 150 assets from Zabbix
```

#### JSON Format
```json
{
  "timestamp": "2024-01-15T14:32:45.123Z",
  "level": "INFO",
  "agent": "DATAFETCHER",
  "message": "Retrieved 150 assets from Zabbix",
  "filename": "data_fetcher.py",
  "function": "fetch_assets",
  "line_number": 45,
  "asset_count": 150
}
```

### 4. Context Information

Each log entry automatically includes:
- Timestamp with millisecond precision
- Log level
- Agent/component name
- Source file, function, and line number
- Custom context data

### 5. Statistics Tracking

The logger tracks:
- Total messages by level
- Messages per agent/component
- Error frequency and patterns
- Performance metrics

## Usage

### Basic Setup

```python
from logger import get_logger

# Get singleton logger instance
logger = get_logger(
    output_dir="./output",
    log_level=logging.INFO,
    console_output=True,
    json_format=False
)
```

### Configuration from Dictionary

```python
from logger import setup_logger

config = {
    'logging': {
        'output_dir': './output',
        'filename': 'merger.log',
        'level': 'INFO',
        'console_output': True,
        'json_format': False,
        'max_bytes': 10485760,  # 10MB
        'backup_count': 5
    }
}

logger = setup_logger(config)
```

### Logging Messages

```python
# Basic logging
logger.info("DATAFETCHER", "Starting data retrieval")
logger.debug("DIFFER", "Comparing field values")
logger.warning("VALIDATOR", "Invalid data format detected")

# With context data
logger.info("APPLIER", "Asset updated", 
           asset_id="asset123", 
           fields_modified=["ip_address", "location"])

# With exceptions
try:
    risky_operation()
except Exception as e:
    logger.error("SYSTEM", "Operation failed", exception=e)
```

### Special Logging Methods

```python
# Log timed operations
start_time = time.time()
# ... do work ...
logger.log_operation("DATAFETCHER", "Data retrieval", start_time=start_time)

# Log batch operations
logger.log_batch_operation("APPLIER", "Asset updates",
                          total=100, processed=95, failed=5)
```

## Log Viewer Utility

### Command Line Interface

```bash
# View last 50 lines
python lib/log_viewer.py output/merger.log tail

# Follow log in real-time
python lib/log_viewer.py output/merger.log tail -f

# View errors
python lib/log_viewer.py output/merger.log errors
python lib/log_viewer.py output/merger.log errors -v  # verbose with tracebacks

# Analyze log
python lib/log_viewer.py output/merger.log analyze
python lib/log_viewer.py output/merger.log analyze --agent DATAFETCHER
python lib/log_viewer.py output/merger.log analyze --level ERROR

# Search in log
python lib/log_viewer.py output/merger.log search "connection failed"
python lib/log_viewer.py output/merger.log search "asset\d+" -C 2  # with context

# Show statistics
python lib/log_viewer.py output/merger.log stats

# Export errors
python lib/log_viewer.py output/merger.log export errors.json --format json
```

### Programmatic Usage

```python
from logger import LogAnalyzer

analyzer = LogAnalyzer("./output/merger.log")

# Analyze log
results = analyzer.analyze(
    start_time=datetime(2024, 1, 15, 14, 0),
    end_time=datetime(2024, 1, 15, 15, 0),
    level_filter="ERROR",
    agent_filter="DATAFETCHER"
)

# Get errors
errors = analyzer.get_errors(last_n=10)

# Search
matches = analyzer.search(r"asset\d+", context_lines=2)

# Get tail
last_lines = analyzer.tail(n=100)
```

## Integration with Agents

### DataFetcher Agent Example

```python
class DataFetcherAgent:
    def __init__(self, logger):
        self.logger = logger
        self.agent_name = "DATAFETCHER"
    
    def fetch_assets(self):
        self.logger.info(self.agent_name, "Starting asset retrieval")
        start = time.time()
        
        try:
            assets = self._fetch_from_api()
            self.logger.log_operation(
                self.agent_name,
                "Asset retrieval completed",
                start_time=start,
                asset_count=len(assets)
            )
            return assets
        except Exception as e:
            self.logger.error(
                self.agent_name,
                "Failed to retrieve assets",
                exception=e
            )
            raise
```

## Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `output_dir` | str | "./output" | Directory for log files |
| `log_filename` | str | "merger.log" | Log file name |
| `max_bytes` | int | 10485760 | Max file size before rotation |
| `backup_count` | int | 5 | Number of backup files |
| `log_level` | int | INFO (20) | Minimum log level |
| `console_output` | bool | True | Mirror logs to console |
| `json_format` | bool | False | Use JSON format |

## Performance Considerations

- **Asynchronous logging**: Non-blocking writes to prevent performance impact
- **Buffered writes**: Efficient disk I/O
- **Selective logging**: Use appropriate log levels to reduce overhead
- **Log rotation**: Automatic management of disk space

## Best Practices

1. **Use appropriate log levels**:
   - TRACE: Only for detailed debugging
   - DEBUG: Development and troubleshooting
   - INFO: Normal operations
   - WARNING/ERROR: Issues requiring attention

2. **Include context data**:
   ```python
   logger.info("AGENT", "Operation completed", 
              asset_id=asset_id, duration=duration)
   ```

3. **Log exceptions properly**:
   ```python
   except Exception as e:
       logger.error("AGENT", "Operation failed", exception=e)
   ```

4. **Use batch operation logging**:
   ```python
   logger.log_batch_operation("AGENT", "Batch process",
                             total=100, processed=95, failed=5)
   ```

5. **Track performance**:
   ```python
   start = time.time()
   # ... operation ...
   logger.log_operation("AGENT", "Operation", start_time=start)
   ```

## Troubleshooting

### Common Issues

1. **Permission denied**: Ensure output directory is writable
2. **Disk full**: Check available space and rotation settings
3. **High memory usage**: Reduce console output or adjust buffer size
4. **Missing logs**: Check log level settings

### Debug Tips

```python
# Enable trace logging
logger.set_level(logger.TRACE)

# Check current statistics
logger.print_statistics()

# Analyze specific timeframe
analyzer = LogAnalyzer("merger.log")
results = analyzer.analyze(
    start_time=datetime.now() - timedelta(hours=1)
)
```

## Examples

See the following files for complete examples:
- `test_logger.py`: Basic functionality test
- `test_json_logger.py`: JSON format example
- `logger_integration.py`: Agent integration examples

## API Reference

### MergerLogger Class

#### Methods

- `trace(agent, message, **kwargs)`: Log TRACE level message
- `debug(agent, message, **kwargs)`: Log DEBUG level message
- `info(agent, message, **kwargs)`: Log INFO level message
- `warning(agent, message, **kwargs)`: Log WARNING level message
- `error(agent, message, exception=None, **kwargs)`: Log ERROR level message
- `critical(agent, message, exception=None, **kwargs)`: Log CRITICAL level message
- `log_operation(agent, operation, start_time=None, **kwargs)`: Log timed operation
- `log_batch_operation(agent, operation, total, processed, failed=0, **kwargs)`: Log batch results
- `get_statistics()`: Get current statistics
- `print_statistics()`: Print formatted statistics
- `clear_statistics()`: Reset statistics
- `set_level(level)`: Change log level dynamically

### LogAnalyzer Class

#### Methods

- `parse_log_line(line)`: Parse single log line
- `analyze(start_time=None, end_time=None, level_filter=None, agent_filter=None)`: Analyze log
- `search(pattern, context_lines=0)`: Search with regex
- `tail(n=50)`: Get last n lines
- `get_errors(last_n=None)`: Extract error entries

## License

Part of the Asset Merger Engine Tool
