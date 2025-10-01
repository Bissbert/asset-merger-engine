#!/usr/bin/env python3
"""
Test script to demonstrate the logging system functionality.
"""

import sys
import time
import random
from pathlib import Path

# Add lib directory to path
sys.path.insert(0, str(Path(__file__).parent / 'lib'))

from logger import get_logger, setup_logger


def simulate_data_fetcher(logger):
    """Simulate DataFetcher agent operations."""
    logger.info("DATAFETCHER", "Starting data retrieval process")
    
    # Simulate fetching from Zabbix
    start_time = time.time()
    time.sleep(0.5)  # Simulate network delay
    
    assets_count = random.randint(100, 200)
    logger.log_operation("DATAFETCHER", f"Retrieved {assets_count} assets from Zabbix",
                        start_time=start_time, source="zabbix", count=assets_count)
    
    # Simulate fetching from Topdesk with some failures
    start_time = time.time()
    time.sleep(0.3)
    
    success = random.randint(80, 95)
    failed = random.randint(5, 20)
    total = success + failed
    
    logger.log_batch_operation("DATAFETCHER", "Topdesk asset retrieval",
                              total=total, processed=success, failed=failed)
    
    # Simulate an occasional error
    if random.random() < 0.3:
        try:
            raise ConnectionError("Connection timeout to Topdesk API")
        except ConnectionError as e:
            logger.error("DATAFETCHER", "Failed to connect to Topdesk", exception=e)


def simulate_differ(logger):
    """Simulate Differ agent operations."""
    logger.info("DIFFER", "Starting asset comparison")
    
    # Log some differences found
    differences = [
        ("asset001", "ip_address", "192.168.1.10", "192.168.1.11"),
        ("asset002", "location", "Building A", "Building B"),
        ("asset003", "owner", "John Doe", "Jane Smith"),
    ]
    
    for asset_id, field, old_val, new_val in differences:
        logger.debug("DIFFER", f"Difference found in {asset_id}",
                    field=field, old_value=old_val, new_value=new_val)
    
    logger.info("DIFFER", f"Comparison completed: {len(differences)} differences found")


def simulate_tui_operator(logger):
    """Simulate TUI Operator agent operations."""
    logger.info("TUIOPERATOR", "TUI session started", user="admin")
    
    # Simulate user interactions
    actions = [
        ("Selected Zabbix value", {"field": "ip_address", "value": "192.168.1.11"}),
        ("Selected Topdesk value", {"field": "location", "value": "Building A"}),
        ("Entered custom value", {"field": "owner", "value": "Bob Smith"}),
        ("Skipped field", {"field": "description"}),
    ]
    
    for action, context in actions:
        time.sleep(0.1)
        logger.info("TUIOPERATOR", f"User action: {action}", **context)
    
    logger.info("TUIOPERATOR", "TUI session completed", 
               total_actions=len(actions), duration_seconds=1.5)


def simulate_applier(logger):
    """Simulate Applier agent operations."""
    logger.info("APPLIER", "Starting change application")
    
    # Simulate applying changes
    changes = [
        ("asset001", True, None),
        ("asset002", True, None),
        ("asset003", False, "Permission denied"),
        ("asset004", True, None),
        ("asset005", False, "Asset not found"),
    ]
    
    successful = 0
    failed = 0
    
    for asset_id, success, error in changes:
        if success:
            logger.info("APPLIER", f"Successfully updated {asset_id}",
                       asset_id=asset_id, fields_updated=random.randint(1, 5))
            successful += 1
        else:
            logger.error("APPLIER", f"Failed to update {asset_id}: {error}",
                        asset_id=asset_id, error=error)
            failed += 1
        time.sleep(0.05)
    
    logger.log_batch_operation("APPLIER", "Change application",
                              total=len(changes), processed=successful, failed=failed)


def simulate_validator(logger):
    """Simulate Validator agent operations."""
    logger.info("VALIDATOR", "Starting validation process")
    
    # Simulate various validation checks
    logger.debug("VALIDATOR", "Checking data integrity", total_records=150)
    logger.trace("VALIDATOR", "Validating field: ip_address", field="ip_address", valid=True)
    logger.trace("VALIDATOR", "Validating field: hostname", field="hostname", valid=True)
    
    # Simulate a validation warning
    logger.warning("VALIDATOR", "Invalid data format detected",
                  field="serial_number", value="", expected="non-empty string")
    
    logger.info("VALIDATOR", "Validation completed", 
               passed=148, failed=2, warnings=1)


def test_log_levels(logger):
    """Test all log levels."""
    logger.trace("SYSTEM", "This is a TRACE message - very detailed")
    logger.debug("SYSTEM", "This is a DEBUG message - diagnostic info")
    logger.info("SYSTEM", "This is an INFO message - normal operation")
    logger.warning("SYSTEM", "This is a WARNING message - potential issue")
    logger.error("SYSTEM", "This is an ERROR message - something failed")
    
    try:
        raise ValueError("Critical system failure simulation")
    except ValueError as e:
        logger.critical("SYSTEM", "This is a CRITICAL message", exception=e)


def main():
    """Main test function."""
    # Configuration
    config = {
        'logging': {
            'output_dir': './test_output',
            'filename': 'merger.log',
            'level': 'DEBUG',  # Show DEBUG and above
            'console_output': True,
            'json_format': False,  # Use text format for readability
            'max_bytes': 10 * 1024 * 1024,  # 10MB
            'backup_count': 3
        }
    }
    
    # Setup logger
    logger = setup_logger(config)
    
    print("\n" + "=" * 60)
    print("MERGER TOOL LOGGING SYSTEM TEST")
    print("=" * 60)
    print("\nRunning simulation of various agents...\n")
    
    # Test log levels
    print("Testing log levels...")
    test_log_levels(logger)
    time.sleep(0.5)
    
    # Simulate different agents
    print("\nSimulating DataFetcher agent...")
    simulate_data_fetcher(logger)
    time.sleep(0.5)
    
    print("Simulating Differ agent...")
    simulate_differ(logger)
    time.sleep(0.5)
    
    print("Simulating TUI Operator agent...")
    simulate_tui_operator(logger)
    time.sleep(0.5)
    
    print("Simulating Applier agent...")
    simulate_applier(logger)
    time.sleep(0.5)
    
    print("Simulating Validator agent...")
    simulate_validator(logger)
    
    # Print statistics
    print("\n" + "=" * 60)
    logger.print_statistics()
    
    # Show log file location
    log_path = Path(config['logging']['output_dir']) / config['logging']['filename']
    print(f"\nLog file created at: {log_path.absolute()}")
    print(f"Log file size: {log_path.stat().st_size:,} bytes")
    
    # Demonstrate log viewer
    print("\n" + "=" * 60)
    print("LOG VIEWER EXAMPLES")
    print("=" * 60)
    print("\nYou can now use the log viewer to analyze the log:")
    print(f"  python lib/log_viewer.py {log_path} tail")
    print(f"  python lib/log_viewer.py {log_path} errors")
    print(f"  python lib/log_viewer.py {log_path} stats")
    print(f"  python lib/log_viewer.py {log_path} search 'ERROR'")
    print(f"  python lib/log_viewer.py {log_path} analyze --agent APPLIER")


if __name__ == "__main__":
    main()
