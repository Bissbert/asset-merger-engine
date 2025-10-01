#!/usr/bin/env python3
"""
Test script demonstrating the validator module capabilities.
"""

import json
import tempfile
import logging
from pathlib import Path
from datetime import datetime, timedelta
from validator import (
    MergerValidator,
    ValidationStatus,
    ValidationResult
)


def create_sample_dif_file():
    """Create a sample .dif file for testing."""
    dif_data = {
        "timestamp": datetime.now().isoformat(),
        "source": "zabbix",
        "target": "topdesk",
        "entries": [
            {
                "asset_id": "srv-001",
                "operation": "modify",
                "field": "ip_address",
                "old_value": "192.168.1.100",
                "new_value": "192.168.1.101"
            },
            {
                "asset_id": "srv-002",
                "operation": "add",
                "field": "hostname",
                "value": "server02.domain.com"
            },
            {
                "asset_id": "srv-003",
                "operation": "delete",
                "field": "notes"
            },
            {
                "asset_id": "srv-001",
                "operation": "modify",
                "field": "status",
                "old_value": "active",
                "new_value": "maintenance"
            },
            {
                "asset_id": "srv-004",
                "operation": "create",
                "field": "asset_id",
                "value": "srv-004"
            }
        ]
    }

    with tempfile.NamedTemporaryFile(mode='w', suffix='.dif', delete=False) as f:
        json.dump(dif_data, f, indent=2)
        return f.name


def create_invalid_dif_file():
    """Create an invalid .dif file for testing error handling."""
    dif_data = {
        "entries": [
            {
                # Missing asset_id
                "operation": "modify",
                "field": "ip_address"
            },
            {
                "asset_id": "srv-001",
                "operation": "invalid_op",  # Invalid operation
                "field": "status"
            },
            {
                "asset_id": "srv-002",
                "operation": "modify",
                "field": "hostname"
                # Missing old_value and new_value
            },
            {
                "asset_id": "srv-003",
                "operation": "delete",
                "field": "all"  # Delete with conflicting operations
            },
            {
                "asset_id": "srv-003",
                "operation": "modify",
                "field": "status"
            }
        ]
    }

    with tempfile.NamedTemporaryFile(mode='w', suffix='.dif', delete=False) as f:
        json.dump(dif_data, f, indent=2)
        return f.name


def create_sample_apl_file():
    """Create a sample .apl file for testing."""
    apl_data = {
        "timestamp": datetime.now().isoformat(),
        "user": "merger_tool",
        "summary": {
            "applied": 4,
            "failed": 1,
            "skipped": 0,
            "total": 5
        },
        "entries": [
            {
                "sequence": 1,
                "asset_id": "srv-001",
                "timestamp": datetime.now().isoformat(),
                "status": "applied",
                "command": "topdesk-cli update asset srv-001 --field ip_address=192.168.1.101",
                "duration": 1.23
            },
            {
                "sequence": 2,
                "asset_id": "srv-002",
                "timestamp": datetime.now().isoformat(),
                "status": "applied",
                "command": "topdesk-cli update asset srv-002 --field hostname=server02.domain.com",
                "duration": 0.98
            },
            {
                "sequence": 3,
                "asset_id": "srv-003",
                "timestamp": datetime.now().isoformat(),
                "status": "failed",
                "command": "topdesk-cli update asset srv-003 --remove-field notes",
                "error": "Asset not found",
                "duration": 0.45
            },
            {
                "sequence": 4,
                "asset_id": "srv-001",
                "timestamp": datetime.now().isoformat(),
                "status": "applied",
                "command": "topdesk-cli update asset srv-001 --field status=maintenance",
                "duration": 1.12
            },
            {
                "sequence": 5,
                "asset_id": "srv-004",
                "timestamp": datetime.now().isoformat(),
                "status": "applied",
                "command": "topdesk-cli create asset srv-004",
                "duration": 2.34
            }
        ]
    }

    with tempfile.NamedTemporaryFile(mode='w', suffix='.apl', delete=False) as f:
        json.dump(apl_data, f, indent=2)
        return f.name


def create_sample_assets():
    """Create sample asset data for testing."""
    zabbix_assets = [
        {
            "host": "srv-001",
            "name": "server01.domain.com",
            "ip": "192.168.1.101",
            "serialno_a": "SN123456",
            "tag": "IT",
            "location": "DC-01",
            "model": "Dell R740",
            "vendor": "Dell",
            "status": "active"
        },
        {
            "host": "srv-002",
            "name": "server02.domain.com",
            "ip": "192.168.1.102",
            "serialno_a": "SN123457",
            "tag": "HR",
            "location": "DC-01",
            "model": "HP DL380",
            "vendor": "HP",
            "status": "active"
        },
        {
            "host": "srv-003",
            "name": "server03.domain.com",
            "ip": "192.168.1.103",
            "serialno_a": "SN123458",
            "tag": "Finance",
            "location": "DC-02",
            "model": "IBM x3650",
            "vendor": "IBM",
            "status": "maintenance"
        }
    ]

    topdesk_assets = [
        {
            "asset_id": "srv-001",
            "hostname": "server01.domain.com",
            "ip_address": "192.168.1.101",  # Matches
            "serial_number": "SN123456",
            "department": "IT",
            "location": "DC-01",
            "model": "Dell R740",
            "manufacturer": "Dell",
            "status": "active"
        },
        {
            "asset_id": "srv-002",
            "hostname": "server02.domain.com",
            "ip_address": "192.168.1.200",  # Mismatch!
            "serial_number": "SN123457",
            "department": "Human Resources",  # Different format
            "location": "DC-01",
            "model": "HP DL380",
            "manufacturer": "HP",
            "status": "active"
        }
        # srv-003 is missing in Topdesk
    ]

    return zabbix_assets, topdesk_assets


def create_sample_cache_dir():
    """Create a sample cache directory with files."""
    cache_dir = tempfile.mkdtemp(prefix='cache_test_')
    cache_path = Path(cache_dir)

    # Create valid cache file
    valid_cache = {
        "timestamp": datetime.now().isoformat(),
        "data": {"test": "data"},
        "checksum": "dummy_checksum"
    }
    with open(cache_path / "valid.cache", 'w') as f:
        json.dump(valid_cache, f)

    # Create old cache file
    old_cache = {
        "timestamp": (datetime.now() - timedelta(days=2)).isoformat(),
        "data": {"old": "data"}
    }
    old_file = cache_path / "old.cache"
    with open(old_file, 'w') as f:
        json.dump(old_cache, f)
    # Make it old
    import os
    old_time = (datetime.now() - timedelta(days=2)).timestamp()
    os.utime(old_file, (old_time, old_time))

    # Create corrupted cache file
    with open(cache_path / "corrupted.cache", 'w') as f:
        f.write("{invalid json content")

    return str(cache_dir)


def demo_dif_validation():
    """Demonstrate DIF file validation."""
    print("=" * 60)
    print("DIF FILE VALIDATION DEMONSTRATION")
    print("=" * 60)

    validator = MergerValidator()

    # Test valid DIF file
    print("\n1. Validating VALID DIF file:")
    valid_dif = create_sample_dif_file()
    result = validator.validate_dif_file(valid_dif)
    print(result.generate_report())

    # Test invalid DIF file
    print("\n2. Validating INVALID DIF file:")
    invalid_dif = create_invalid_dif_file()
    result = validator.validate_dif_file(invalid_dif)
    print(result.generate_report())

    # Cleanup
    Path(valid_dif).unlink()
    Path(invalid_dif).unlink()


def demo_apl_validation():
    """Demonstrate APL file validation."""
    print("\n" + "=" * 60)
    print("APL FILE VALIDATION DEMONSTRATION")
    print("=" * 60)

    validator = MergerValidator()

    print("\nValidating APL file:")
    apl_file = create_sample_apl_file()
    result = validator.validate_apl_file(apl_file)
    print(result.generate_report())

    # Cleanup
    Path(apl_file).unlink()


def demo_data_sync_validation():
    """Demonstrate data synchronization validation."""
    print("\n" + "=" * 60)
    print("DATA SYNC VALIDATION DEMONSTRATION")
    print("=" * 60)

    validator = MergerValidator()
    zabbix_assets, topdesk_assets = create_sample_assets()

    print("\nValidating data synchronization:")
    print(f"  Zabbix assets: {len(zabbix_assets)}")
    print(f"  Topdesk assets: {len(topdesk_assets)}")

    result = validator.validate_data_sync(zabbix_assets, topdesk_assets)
    print(result.generate_report())


def demo_asset_validation():
    """Demonstrate asset validation."""
    print("\n" + "=" * 60)
    print("ASSET VALIDATION DEMONSTRATION")
    print("=" * 60)

    validator = MergerValidator()

    # Test assets with various issues
    assets = [
        {"asset_id": "srv-001", "ip_address": "192.168.1.1", "status": "active"},
        {"asset_id": "srv-002", "ip_address": "999.999.999.999", "status": "unknown"},  # Invalid IP
        {"asset_id": "srv-001", "ip_address": "192.168.1.2", "status": "active"},  # Duplicate ID
        {"hostname": "missing_id.com", "ip_address": "192.168.1.3"},  # Missing asset_id
        {"asset_id": "srv-003", "ip_address": "192.168.1.4", "status": "invalid_status"}
    ]

    print("\nValidating assets with various issues:")
    result = validator.validate_assets(assets)
    print(result.generate_report())


def demo_cache_validation():
    """Demonstrate cache integrity validation."""
    print("\n" + "=" * 60)
    print("CACHE INTEGRITY VALIDATION DEMONSTRATION")
    print("=" * 60)

    validator = MergerValidator()
    cache_dir = create_sample_cache_dir()

    print(f"\nValidating cache directory: {cache_dir}")
    result = validator.validate_cache_integrity(cache_dir)
    print(result.generate_report())

    # Cleanup
    import shutil
    shutil.rmtree(cache_dir)


def demo_pre_execution_validation():
    """Demonstrate pre-execution validation."""
    print("\n" + "=" * 60)
    print("PRE-EXECUTION VALIDATION DEMONSTRATION")
    print("=" * 60)

    validator = MergerValidator()

    config = {
        "required_tools": ["python3", "nonexistent_tool"],
        "zabbix": {
            "url": "http://zabbix.example.com",
            "username": "admin"
            # Missing password - should be detected
        },
        "topdesk": {
            "url": "http://topdesk.example.com",
            "username": "admin",
            "password": "secret"
        },
        "output_dir": "/tmp/merger_output",
        "check_connectivity": False  # Skip actual network checks for demo
    }

    print("\nValidating pre-execution requirements:")
    result = validator.validate_pre_execution(config)
    print(result.generate_report())


def demo_comprehensive_report():
    """Demonstrate comprehensive report generation."""
    print("\n" + "=" * 60)
    print("COMPREHENSIVE REPORT DEMONSTRATION")
    print("=" * 60)

    validator = MergerValidator()

    # Run multiple validations
    dif_file = create_sample_dif_file()
    validator.validate_dif_file(dif_file)

    apl_file = create_sample_apl_file()
    validator.validate_apl_file(apl_file)

    zabbix_assets, topdesk_assets = create_sample_assets()
    validator.validate_data_sync(zabbix_assets, topdesk_assets)

    # Generate comprehensive report
    print("\nGenerating comprehensive validation report...")
    report = validator.generate_validation_report()
    print(report)

    # Cleanup
    Path(dif_file).unlink()
    Path(apl_file).unlink()


def main():
    """Main demo function."""
    # Setup logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )

    print("MERGER TOOL VALIDATOR DEMONSTRATION")
    print("=" * 60)
    print("This demo shows various validation capabilities\n")

    # Run demonstrations
    demo_dif_validation()
    demo_apl_validation()
    demo_data_sync_validation()
    demo_asset_validation()
    demo_cache_validation()
    demo_pre_execution_validation()
    demo_comprehensive_report()

    print("\n" + "=" * 60)
    print("DEMONSTRATION COMPLETE")
    print("=" * 60)


if __name__ == '__main__':
    main()