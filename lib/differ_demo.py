#!/usr/bin/env python3
"""
Demonstration of the Differ Agent comparison algorithm
Shows complete workflow from data input to DIF file generation
"""

import json
from pathlib import Path
from differ import DifferAgent
from differ_utils import DifFileParser, DifferenceAnalyzer, DifferenceExporter


def create_sample_data():
    """
    Create sample Zabbix and Topdesk data for demonstration
    """
    # Zabbix sample data
    zabbix_data = {
        "SRV-001": {
            "hostname": "webserver01.company.com",
            "ip_address": "10.0.1.10",
            "os": "Ubuntu 22.04 LTS",
            "cpu_cores": 8,
            "memory_gb": 16,
            "disk_gb": 500,
            "location": "DataCenter-A",
            "rack": "A-12",
            "status": "active",
            "environment": "production"
        },
        "SRV-002": {
            "hostname": "dbserver01.company.com",
            "ip_address": "10.0.1.20",
            "os": "Red Hat Enterprise Linux 8",
            "cpu_cores": 16,
            "memory_gb": 64,
            "disk_gb": 2000,
            "location": "DataCenter-A",
            "rack": "A-15",
            "status": "active",
            "environment": "production",
            "database_type": "PostgreSQL"
        },
        "SRV-003": {
            "hostname": "appserver01.company.com",
            "ip_address": "10.0.1.30",
            "os": "Windows Server 2022",
            "cpu_cores": 12,
            "memory_gb": 32,
            "disk_gb": 1000,
            "location": "DataCenter-B",
            "rack": "B-05",
            "status": "active"
        },
        "SRV-004": {  # Only in Zabbix
            "hostname": "monitor01.company.com",
            "ip_address": "10.0.1.40",
            "os": "CentOS 7",
            "cpu_cores": 4,
            "memory_gb": 8,
            "disk_gb": 200,
            "location": "DataCenter-A",
            "rack": "A-20",
            "status": "active",
            "role": "monitoring"
        }
    }

    # Topdesk sample data
    topdesk_data = {
        "SRV-001": {
            "hostname": "webserver01",  # Missing domain
            "ip_address": "10.0.1.10",
            "os": "Ubuntu Linux",  # Less specific
            "cpu_cores": 8,
            "memory_gb": 16,
            "disk_gb": 512,  # Different value
            "location": "DataCenter-A",
            "rack": "A-12",
            "status": "active",
            "environment": "production",
            "owner": "Web Team",  # Additional field
            "cost_center": "CC-100"  # Additional field
        },
        "SRV-002": {
            "hostname": "dbserver01.company.com",
            "ip_address": "10.0.1.21",  # Different IP
            "os": "RHEL 8",  # Different naming
            "cpu_cores": 16,
            "memory_gb": 64,
            "disk_gb": 2048,  # Different value
            "location": "DataCenter-A",
            "rack": "A-16",  # Different rack
            "status": "maintenance",  # Different status
            "environment": "production",
            "owner": "Database Team"
        },
        "SRV-003": {
            "hostname": "appserver01.company.com",
            "ip_address": "10.0.1.30",
            "os": "Windows Server 2022 Datacenter",  # More specific
            "cpu_cores": 12,
            "memory_gb": 32,
            "disk_gb": 1000,
            "location": "DataCenter-B",
            "status": "active",
            "environment": "staging",  # Additional field
            "license_key": "WIN-2022-DC-XXX"  # Additional field
        },
        "SRV-005": {  # Only in Topdesk
            "hostname": "testserver01.company.com",
            "ip_address": "10.0.2.10",
            "os": "Debian 11",
            "cpu_cores": 2,
            "memory_gb": 4,
            "disk_gb": 100,
            "location": "DataCenter-B",
            "rack": "B-10",
            "status": "inactive",
            "environment": "test"
        }
    }

    return zabbix_data, topdesk_data


def demonstrate_comparison():
    """
    Demonstrate the complete comparison workflow
    """
    print("=" * 80)
    print("DIFFER AGENT DEMONSTRATION")
    print("=" * 80)
    print()

    # Create output directory
    output_dir = "/Users/fabian/sources/posix/demo_differences"
    Path(output_dir).mkdir(exist_ok=True)

    # Step 1: Create sample data
    print("Step 1: Creating sample data...")
    zabbix_data, topdesk_data = create_sample_data()
    print(f"  - Zabbix assets: {len(zabbix_data)}")
    print(f"  - Topdesk assets: {len(topdesk_data)}")
    print()

    # Step 2: Initialize Differ Agent with configuration
    print("Step 2: Initializing Differ Agent...")
    config = {
        'case_sensitive': False,
        'normalize_whitespace': True,
        'numeric_tolerance': 0.01,
        'excluded_fields': []  # Could exclude fields like 'last_updated'
    }
    differ = DifferAgent(output_dir=output_dir, config=config)
    print("  - Configuration applied")
    print()

    # Step 3: Process comparison
    print("Step 3: Processing comparison...")
    generated_files, stats = differ.process_comparison(zabbix_data, topdesk_data)
    print(f"  - Generated {len(generated_files)} DIF files")
    print()

    # Step 4: Display statistics
    print("Step 4: Comparison Statistics:")
    for key, value in stats.items():
        print(f"  - {key.replace('_', ' ').title()}: {value}")
    print()

    # Step 5: Show sample DIF file content
    print("Step 5: Sample DIF File Content:")
    if generated_files:
        sample_file = generated_files[0]
        print(f"\nFile: {sample_file}")
        print("-" * 40)
        with open(sample_file, 'r') as f:
            content = f.read()
            # Show first 20 lines
            lines = content.split('\n')[:20]
            for line in lines:
                print(line)
        if len(content.split('\n')) > 20:
            print("... (truncated)")
        print("-" * 40)
    print()

    # Step 6: Parse and analyze DIF files
    print("Step 6: Analyzing DIF Files...")
    analyzer = DifferenceAnalyzer()
    analysis = analyzer.analyze_difference_patterns(generated_files)

    print("\nField Frequency Analysis:")
    for field, stats in sorted(analysis['field_statistics'].items(),
                              key=lambda x: x[1]['occurrences'], reverse=True)[:5]:
        print(f"  - {field}: {stats['occurrences']} occurrences ({stats['percentage']}%)")

    print("\nSystem Coverage:")
    for key, value in analysis['system_coverage'].items():
        print(f"  - {key.replace('_', ' ').title()}: {value}")
    print()

    # Step 7: Generate reconciliation report
    print("Step 7: Generating Reconciliation Report...")
    report = analyzer.generate_reconciliation_report(generated_files)
    print(report)
    print()

    # Step 8: Export to different formats
    print("Step 8: Exporting Results...")
    exporter = DifferenceExporter()

    # Export to CSV
    csv_file = f"{output_dir}/differences_export.csv"
    exporter.export_to_csv(generated_files, csv_file)
    print(f"  - Exported to CSV: {csv_file}")

    # Convert a DIF to JSON
    if generated_files:
        parser = DifFileParser()
        json_file = parser.dif_to_json(generated_files[0])
        print(f"  - Converted to JSON: {json_file}")
    print()

    # Step 9: Generate summary report
    print("Step 9: Final Summary Report:")
    print(differ.generate_summary_report())

    return generated_files, stats


def demonstrate_dif_format():
    """
    Demonstrate the DIF file format structure
    """
    print("\n" + "=" * 80)
    print("DIF FILE FORMAT SPECIFICATION")
    print("=" * 80)
    print()

    format_spec = """
DIF File Format Structure:
--------------------------

1. Standard Format (Assets in Both Systems):

   asset_id: {unique_identifier}
   differences:
     - field_name: {field}
       zabbix_value: "{value}"
       topdesk_value: "{value}"
     - field_name: {field}
       zabbix_value: "{value}"
       topdesk_value: "{value}"

   # Generated: {timestamp}
   # Total differences: {count}
   # Similarity score: {percentage}%
   # Value mismatches: {count}
   # Missing in Zabbix: {count}
   # Missing in Topdesk: {count}

2. Asset Missing Format (Asset in One System Only):

   asset_id: {unique_identifier}
   note: Asset exists only in {system} system
   differences:
     - field_name: {field}
       zabbix_value: "null"
       topdesk_value: "{value}"
     - field_name: {field}
       zabbix_value: "null"
       topdesk_value: "{value}"

   # Generated: {timestamp}
   # Total differences: {count}

3. Field Value Types:
   - String values: Enclosed in quotes
   - Null/missing: Represented as "null"
   - Numeric values: Converted to string format
   - Boolean values: "true" or "false"

4. Difference Types:
   - value_mismatch: Different values in both systems
   - missing_in_zabbix: Field exists only in Topdesk
   - missing_in_topdesk: Field exists only in Zabbix
   - asset_missing: Entire asset exists in only one system

5. Metadata Section (Comments):
   - Generated timestamp
   - Total difference count
   - Similarity score (for matched assets)
   - Category counts (mismatches, missing fields)
"""

    print(format_spec)


if __name__ == "__main__":
    # Run demonstration
    demonstrate_dif_format()
    files, stats = demonstrate_comparison()

    print("\n" + "=" * 80)
    print("DEMONSTRATION COMPLETE")
    print("=" * 80)
    print(f"\nGenerated {len(files)} DIF files in demo_differences/")
    print("Each file contains field-level differences for one asset")
    print("\nThe Differ Agent is ready for integration with the data pipeline.")