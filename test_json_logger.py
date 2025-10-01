#!/usr/bin/env python3
"""
Test JSON format logging.
"""

import sys
from pathlib import Path

# Add lib directory to path
sys.path.insert(0, str(Path(__file__).parent / 'lib'))

from logger import get_logger

# Create logger with JSON format
logger = get_logger(
    output_dir="./test_output",
    log_filename="merger_json.log",
    log_level=10,  # DEBUG
    console_output=False,  # No console output for cleaner JSON
    json_format=True
)

# Log some test messages
logger.info("DATAFETCHER", "Fetching data from Zabbix", 
           endpoint="https://zabbix.example.com/api", assets_count=150)

logger.warning("DIFFER", "Field mismatch detected", 
              asset_id="asset123", field="ip_address", 
              zabbix_value="192.168.1.10", topdesk_value="192.168.1.11")

try:
    raise ValueError("Test exception for JSON logging")
except ValueError as e:
    logger.error("APPLIER", "Failed to apply changes", exception=e, 
                asset_id="asset456", operation="update")

logger.info("SYSTEM", "Process completed", 
           duration_seconds=45.3, total_assets=150, modified=23, failed=2)

print("JSON log created at: test_output/merger_json.log")
print("\nSample JSON entries:")
with open("test_output/merger_json.log", "r") as f:
    for line in f:
        print(line.strip())
