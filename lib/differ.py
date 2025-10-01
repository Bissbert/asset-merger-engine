#!/usr/bin/env python3
"""
Differ Agent - Comparison algorithm for Zabbix and Topdesk data
Generates .dif files for field-level differences
"""

import json
import os
from typing import Dict, List, Any, Optional, Tuple
from datetime import datetime
from pathlib import Path


class DifferAgent:
    """
    Comparison specialist for analyzing differences between Zabbix and Topdesk systems
    """

    def __init__(self, output_dir: str = "differences", config: Optional[Dict] = None):
        """
        Initialize the Differ Agent

        Args:
            output_dir: Directory to store .dif files
            config: Configuration for comparison rules
        """
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)

        # Default configuration
        self.config = config or {}
        self.case_sensitive = self.config.get('case_sensitive', False)
        self.normalize_whitespace = self.config.get('normalize_whitespace', True)
        self.excluded_fields = set(self.config.get('excluded_fields', []))
        self.tolerance = self.config.get('numeric_tolerance', 0.01)

        # Statistics tracking
        self.stats = {
            'total_assets_processed': 0,
            'matched_assets': 0,
            'zabbix_only': 0,
            'topdesk_only': 0,
            'assets_with_differences': 0,
            'total_differences': 0
        }

    def normalize_value(self, value: Any) -> Any:
        """
        Normalize values based on configuration

        Args:
            value: The value to normalize

        Returns:
            Normalized value
        """
        if value is None:
            return "null"

        if isinstance(value, str):
            if self.normalize_whitespace:
                value = ' '.join(value.split())
            if not self.case_sensitive:
                value = value.lower()

        return value

    def compare_values(self, zabbix_val: Any, topdesk_val: Any, field_name: str) -> bool:
        """
        Compare two values with tolerance for numeric fields

        Args:
            zabbix_val: Value from Zabbix
            topdesk_val: Value from Topdesk
            field_name: Name of the field being compared

        Returns:
            True if values are considered equal
        """
        # Handle None/null values
        if zabbix_val is None and topdesk_val is None:
            return True
        if zabbix_val is None or topdesk_val is None:
            return False

        # Normalize values
        zabbix_norm = self.normalize_value(zabbix_val)
        topdesk_norm = self.normalize_value(topdesk_val)

        # Numeric comparison with tolerance
        try:
            zabbix_num = float(zabbix_val)
            topdesk_num = float(topdesk_val)
            return abs(zabbix_num - topdesk_num) <= self.tolerance
        except (ValueError, TypeError):
            pass

        # String comparison
        return zabbix_norm == topdesk_norm

    def compare_assets(self, zabbix_data: Dict[str, Dict],
                      topdesk_data: Dict[str, Dict]) -> Dict[str, List[Dict]]:
        """
        Compare assets from both systems and identify differences

        Args:
            zabbix_data: Dictionary of Zabbix assets keyed by asset_id
            topdesk_data: Dictionary of Topdesk assets keyed by asset_id

        Returns:
            Dictionary of differences keyed by asset_id
        """
        all_differences = {}

        # Get all unique asset IDs
        all_asset_ids = set(zabbix_data.keys()) | set(topdesk_data.keys())
        self.stats['total_assets_processed'] = len(all_asset_ids)

        for asset_id in all_asset_ids:
            differences = []
            zabbix_asset = zabbix_data.get(asset_id, {})
            topdesk_asset = topdesk_data.get(asset_id, {})

            # Handle assets present in only one system
            if not zabbix_asset:
                self.stats['topdesk_only'] += 1
                differences = self._handle_single_system_asset(
                    asset_id, topdesk_asset, 'topdesk'
                )
            elif not topdesk_asset:
                self.stats['zabbix_only'] += 1
                differences = self._handle_single_system_asset(
                    asset_id, zabbix_asset, 'zabbix'
                )
            else:
                self.stats['matched_assets'] += 1
                differences = self._compare_matched_assets(
                    zabbix_asset, topdesk_asset
                )

            if differences:
                all_differences[asset_id] = differences
                self.stats['assets_with_differences'] += 1
                self.stats['total_differences'] += len(differences)

        return all_differences

    def _handle_single_system_asset(self, asset_id: str, asset_data: Dict,
                                   system: str) -> List[Dict]:
        """
        Handle assets that exist in only one system

        Args:
            asset_id: The asset identifier
            asset_data: Data from the system where asset exists
            system: Name of the system ('zabbix' or 'topdesk')

        Returns:
            List of differences
        """
        differences = []

        for field_name, value in asset_data.items():
            if field_name not in self.excluded_fields:
                diff = {
                    'field_name': field_name,
                    'zabbix_value': value if system == 'zabbix' else "null",
                    'topdesk_value': value if system == 'topdesk' else "null",
                    'difference_type': f'missing_in_{"topdesk" if system == "zabbix" else "zabbix"}'
                }
                differences.append(diff)

        # Add system presence indicator
        differences.insert(0, {
            'field_name': '_system_presence',
            'zabbix_value': 'present' if system == 'zabbix' else 'absent',
            'topdesk_value': 'present' if system == 'topdesk' else 'absent',
            'difference_type': 'asset_missing'
        })

        return differences

    def _compare_matched_assets(self, zabbix_asset: Dict,
                               topdesk_asset: Dict) -> List[Dict]:
        """
        Compare assets that exist in both systems

        Args:
            zabbix_asset: Asset data from Zabbix
            topdesk_asset: Asset data from Topdesk

        Returns:
            List of differences
        """
        differences = []

        # Get all unique field names
        all_fields = set(zabbix_asset.keys()) | set(topdesk_asset.keys())

        for field_name in all_fields:
            if field_name in self.excluded_fields:
                continue

            zabbix_value = zabbix_asset.get(field_name)
            topdesk_value = topdesk_asset.get(field_name)

            # Check if field exists in both systems
            if field_name not in zabbix_asset:
                diff = {
                    'field_name': field_name,
                    'zabbix_value': "null",
                    'topdesk_value': str(topdesk_value),
                    'difference_type': 'missing_in_zabbix'
                }
                differences.append(diff)
            elif field_name not in topdesk_asset:
                diff = {
                    'field_name': field_name,
                    'zabbix_value': str(zabbix_value),
                    'topdesk_value': "null",
                    'difference_type': 'missing_in_topdesk'
                }
                differences.append(diff)
            elif not self.compare_values(zabbix_value, topdesk_value, field_name):
                diff = {
                    'field_name': field_name,
                    'zabbix_value': str(zabbix_value),
                    'topdesk_value': str(topdesk_value),
                    'difference_type': 'value_mismatch'
                }
                differences.append(diff)

        return differences

    def generate_dif_file(self, asset_id: str, differences: List[Dict]) -> str:
        """
        Generate a .dif file for an asset with all its differences

        Args:
            asset_id: The asset identifier
            differences: List of differences for the asset

        Returns:
            Path to the generated .dif file
        """
        dif_content = {
            'asset_id': asset_id,
            'timestamp': datetime.now().isoformat(),
            'total_differences': len(differences),
            'differences': []
        }

        # Categorize differences
        value_mismatches = []
        missing_in_zabbix = []
        missing_in_topdesk = []
        asset_missing = None

        for diff in differences:
            diff_type = diff.get('difference_type', 'unknown')

            if diff_type == 'asset_missing':
                asset_missing = diff
            elif diff_type == 'value_mismatch':
                value_mismatches.append(diff)
            elif diff_type == 'missing_in_zabbix':
                missing_in_zabbix.append(diff)
            elif diff_type == 'missing_in_topdesk':
                missing_in_topdesk.append(diff)

        # Add asset presence note if applicable
        if asset_missing:
            if asset_missing['zabbix_value'] == 'absent':
                dif_content['note'] = 'Asset exists only in Topdesk system'
            else:
                dif_content['note'] = 'Asset exists only in Zabbix system'

        # Structure differences in the specified format
        for diff in differences:
            if diff.get('field_name') != '_system_presence':
                dif_content['differences'].append({
                    'field_name': diff['field_name'],
                    'zabbix_value': diff['zabbix_value'],
                    'topdesk_value': diff['topdesk_value']
                })

        # Add summary statistics
        dif_content['summary'] = {
            'value_mismatches': len(value_mismatches),
            'missing_in_zabbix': len(missing_in_zabbix),
            'missing_in_topdesk': len(missing_in_topdesk)
        }

        # Calculate similarity score
        if not asset_missing and differences:
            total_fields = len(set(d['field_name'] for d in differences
                                  if d['field_name'] != '_system_presence'))
            matching_fields = total_fields - len(differences)
            if total_fields > 0:
                dif_content['similarity_score'] = round(
                    (matching_fields / total_fields) * 100, 2
                )

        # Write to file
        filename = f"{asset_id}.dif"
        filepath = self.output_dir / filename

        with open(filepath, 'w') as f:
            # Write in the specified DIF format
            f.write(f"asset_id: {asset_id}\n")

            if 'note' in dif_content:
                f.write(f"note: {dif_content['note']}\n")

            f.write("differences:\n")
            for diff in dif_content['differences']:
                f.write(f"  - field_name: {diff['field_name']}\n")
                f.write(f"    zabbix_value: \"{diff['zabbix_value']}\"\n")
                f.write(f"    topdesk_value: \"{diff['topdesk_value']}\"\n")

            # Add metadata as comments
            f.write(f"\n# Generated: {dif_content['timestamp']}\n")
            f.write(f"# Total differences: {dif_content['total_differences']}\n")
            if 'similarity_score' in dif_content:
                f.write(f"# Similarity score: {dif_content['similarity_score']}%\n")
            f.write(f"# Value mismatches: {dif_content['summary']['value_mismatches']}\n")
            f.write(f"# Missing in Zabbix: {dif_content['summary']['missing_in_zabbix']}\n")
            f.write(f"# Missing in Topdesk: {dif_content['summary']['missing_in_topdesk']}\n")

        return str(filepath)

    def process_comparison(self, zabbix_data: Dict[str, Dict],
                          topdesk_data: Dict[str, Dict]) -> Tuple[List[str], Dict]:
        """
        Main entry point for processing comparison

        Args:
            zabbix_data: Dictionary of Zabbix assets
            topdesk_data: Dictionary of Topdesk assets

        Returns:
            Tuple of (list of generated file paths, statistics)
        """
        # Reset statistics
        self.stats = {
            'total_assets_processed': 0,
            'matched_assets': 0,
            'zabbix_only': 0,
            'topdesk_only': 0,
            'assets_with_differences': 0,
            'total_differences': 0
        }

        # Perform comparison
        all_differences = self.compare_assets(zabbix_data, topdesk_data)

        # Generate .dif files
        generated_files = []
        for asset_id, differences in all_differences.items():
            filepath = self.generate_dif_file(asset_id, differences)
            generated_files.append(filepath)

        return generated_files, self.stats

    def generate_summary_report(self) -> str:
        """
        Generate a summary report of the comparison

        Returns:
            Summary report as string
        """
        report = []
        report.append("=" * 60)
        report.append("COMPARISON SUMMARY REPORT")
        report.append("=" * 60)
        report.append(f"Timestamp: {datetime.now().isoformat()}")
        report.append("")
        report.append("STATISTICS:")
        report.append(f"  Total assets processed: {self.stats['total_assets_processed']}")
        report.append(f"  Matched assets: {self.stats['matched_assets']}")
        report.append(f"  Zabbix-only assets: {self.stats['zabbix_only']}")
        report.append(f"  Topdesk-only assets: {self.stats['topdesk_only']}")
        report.append(f"  Assets with differences: {self.stats['assets_with_differences']}")
        report.append(f"  Total differences found: {self.stats['total_differences']}")
        report.append("")

        if self.stats['total_assets_processed'] > 0:
            match_rate = (self.stats['matched_assets'] /
                         self.stats['total_assets_processed']) * 100
            report.append(f"  Match rate: {match_rate:.2f}%")

            if self.stats['matched_assets'] > 0:
                diff_rate = (self.stats['assets_with_differences'] /
                           self.stats['matched_assets']) * 100
                report.append(f"  Difference rate (matched assets): {diff_rate:.2f}%")

        report.append("=" * 60)

        return "\n".join(report)


# Example usage and testing
if __name__ == "__main__":
    # Sample test data
    zabbix_test_data = {
        "ASSET001": {
            "hostname": "server01.domain.com",
            "ip_address": "192.168.1.100",
            "os": "Linux",
            "cpu_cores": 8,
            "ram_gb": 32,
            "location": "DC1-Rack5"
        },
        "ASSET002": {
            "hostname": "server02.domain.com",
            "ip_address": "192.168.1.101",
            "os": "Windows Server 2019",
            "cpu_cores": 16,
            "ram_gb": 64
        },
        "ASSET003": {
            "hostname": "server03.domain.com",
            "ip_address": "192.168.1.102",
            "os": "Linux",
            "cpu_cores": 4,
            "ram_gb": 16
        }
    }

    topdesk_test_data = {
        "ASSET001": {
            "hostname": "server01.domain.com",
            "ip_address": "192.168.1.100",
            "os": "Ubuntu Linux",  # Different value
            "cpu_cores": 8,
            "ram_gb": 32,
            "location": "DC1-Rack5",
            "department": "IT Operations"  # Additional field
        },
        "ASSET002": {
            "hostname": "server02",  # Different value
            "ip_address": "192.168.1.201",  # Different value
            "os": "Windows Server 2019",
            "cpu_cores": 16,
            "ram_gb": 128  # Different value
        },
        "ASSET004": {  # Asset only in Topdesk
            "hostname": "server04.domain.com",
            "ip_address": "192.168.1.103",
            "os": "VMware ESXi",
            "cpu_cores": 32,
            "ram_gb": 256
        }
    }

    # Initialize differ
    differ = DifferAgent(output_dir="/Users/fabian/sources/posix/test_differences")

    # Process comparison
    files, stats = differ.process_comparison(zabbix_test_data, topdesk_test_data)

    # Print summary
    print(differ.generate_summary_report())
    print("\nGenerated DIF files:")
    for filepath in files:
        print(f"  - {filepath}")