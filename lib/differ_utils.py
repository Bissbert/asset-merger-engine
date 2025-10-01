#!/usr/bin/env python3
"""
Differ Agent Utilities - Helper functions for DIF file operations
"""

import json
import yaml
from pathlib import Path
from typing import Dict, List, Any, Optional
import re


class DifFileParser:
    """
    Parser for reading and analyzing .dif files
    """

    @staticmethod
    def parse_dif_file(filepath: str) -> Dict[str, Any]:
        """
        Parse a .dif file and return structured data

        Args:
            filepath: Path to the .dif file

        Returns:
            Dictionary containing parsed data
        """
        parsed_data = {
            'asset_id': None,
            'note': None,
            'differences': [],
            'metadata': {}
        }

        with open(filepath, 'r') as f:
            lines = f.readlines()

        current_section = None
        current_diff = {}

        for line in lines:
            line = line.strip()

            # Skip empty lines
            if not line:
                continue

            # Parse metadata comments
            if line.startswith('#'):
                match = re.match(r'# (\w[\w\s]+): (.+)', line)
                if match:
                    key, value = match.groups()
                    parsed_data['metadata'][key.replace(' ', '_').lower()] = value
                continue

            # Parse asset_id
            if line.startswith('asset_id:'):
                parsed_data['asset_id'] = line.split(':', 1)[1].strip()

            # Parse note
            elif line.startswith('note:'):
                parsed_data['note'] = line.split(':', 1)[1].strip()

            # Parse differences section
            elif line == 'differences:':
                current_section = 'differences'

            # Parse individual differences
            elif current_section == 'differences':
                if line.startswith('- field_name:'):
                    if current_diff:
                        parsed_data['differences'].append(current_diff)
                    current_diff = {'field_name': line.split(':', 1)[1].strip()}
                elif line.startswith('zabbix_value:'):
                    value = line.split(':', 1)[1].strip()
                    current_diff['zabbix_value'] = value.strip('"')
                elif line.startswith('topdesk_value:'):
                    value = line.split(':', 1)[1].strip()
                    current_diff['topdesk_value'] = value.strip('"')

        # Add last difference if exists
        if current_diff:
            parsed_data['differences'].append(current_diff)

        return parsed_data

    @staticmethod
    def dif_to_json(dif_filepath: str, json_filepath: Optional[str] = None) -> str:
        """
        Convert a .dif file to JSON format

        Args:
            dif_filepath: Path to the .dif file
            json_filepath: Optional path for JSON output

        Returns:
            Path to the generated JSON file
        """
        parsed_data = DifFileParser.parse_dif_file(dif_filepath)

        if not json_filepath:
            json_filepath = str(Path(dif_filepath).with_suffix('.json'))

        with open(json_filepath, 'w') as f:
            json.dump(parsed_data, f, indent=2)

        return json_filepath


class DifferenceAnalyzer:
    """
    Advanced analysis of differences between systems
    """

    @staticmethod
    def analyze_difference_patterns(dif_files: List[str]) -> Dict[str, Any]:
        """
        Analyze patterns across multiple .dif files

        Args:
            dif_files: List of paths to .dif files

        Returns:
            Dictionary containing analysis results
        """
        analysis = {
            'total_files': len(dif_files),
            'field_frequency': {},
            'common_differences': {},
            'system_coverage': {
                'both_systems': 0,
                'zabbix_only': 0,
                'topdesk_only': 0
            },
            'field_statistics': {}
        }

        parser = DifFileParser()

        for filepath in dif_files:
            data = parser.parse_dif_file(filepath)

            # Analyze system coverage
            if data['note']:
                if 'Zabbix' in data['note']:
                    analysis['system_coverage']['zabbix_only'] += 1
                elif 'Topdesk' in data['note']:
                    analysis['system_coverage']['topdesk_only'] += 1
            else:
                analysis['system_coverage']['both_systems'] += 1

            # Analyze field differences
            for diff in data['differences']:
                field_name = diff['field_name']

                # Track field frequency
                if field_name not in analysis['field_frequency']:
                    analysis['field_frequency'][field_name] = 0
                analysis['field_frequency'][field_name] += 1

                # Track common difference patterns
                if diff['zabbix_value'] == 'null':
                    pattern = f"{field_name}_missing_in_zabbix"
                elif diff['topdesk_value'] == 'null':
                    pattern = f"{field_name}_missing_in_topdesk"
                else:
                    pattern = f"{field_name}_value_mismatch"

                if pattern not in analysis['common_differences']:
                    analysis['common_differences'][pattern] = 0
                analysis['common_differences'][pattern] += 1

        # Calculate field statistics
        total_occurrences = sum(analysis['field_frequency'].values())
        for field, count in analysis['field_frequency'].items():
            analysis['field_statistics'][field] = {
                'occurrences': count,
                'percentage': round((count / total_occurrences) * 100, 2)
            }

        return analysis

    @staticmethod
    def generate_reconciliation_report(dif_files: List[str]) -> str:
        """
        Generate a reconciliation report from .dif files

        Args:
            dif_files: List of paths to .dif files

        Returns:
            Reconciliation report as string
        """
        parser = DifFileParser()
        report_lines = []

        report_lines.append("=" * 70)
        report_lines.append("DATA RECONCILIATION REPORT")
        report_lines.append("=" * 70)
        report_lines.append("")

        # Categorize assets
        perfect_matches = []
        minor_differences = []
        major_differences = []
        single_system = []

        for filepath in dif_files:
            data = parser.parse_dif_file(filepath)
            asset_id = data['asset_id']
            diff_count = len(data['differences'])

            if data['note']:
                single_system.append((asset_id, data['note']))
            elif diff_count == 0:
                perfect_matches.append(asset_id)
            elif diff_count <= 3:
                minor_differences.append((asset_id, diff_count))
            else:
                major_differences.append((asset_id, diff_count))

        # Generate report sections
        report_lines.append(f"PERFECT MATCHES ({len(perfect_matches)} assets):")
        for asset in perfect_matches[:5]:
            report_lines.append(f"  ✓ {asset}")
        if len(perfect_matches) > 5:
            report_lines.append(f"  ... and {len(perfect_matches) - 5} more")
        report_lines.append("")

        report_lines.append(f"MINOR DIFFERENCES ({len(minor_differences)} assets):")
        for asset, count in minor_differences[:5]:
            report_lines.append(f"  ⚠ {asset} - {count} differences")
        if len(minor_differences) > 5:
            report_lines.append(f"  ... and {len(minor_differences) - 5} more")
        report_lines.append("")

        report_lines.append(f"MAJOR DIFFERENCES ({len(major_differences)} assets):")
        for asset, count in major_differences[:5]:
            report_lines.append(f"  ⚠ {asset} - {count} differences")
        if len(major_differences) > 5:
            report_lines.append(f"  ... and {len(major_differences) - 5} more")
        report_lines.append("")

        report_lines.append(f"SINGLE SYSTEM ASSETS ({len(single_system)} assets):")
        for asset, note in single_system[:5]:
            report_lines.append(f"  ✗ {asset} - {note}")
        if len(single_system) > 5:
            report_lines.append(f"  ... and {len(single_system) - 5} more")
        report_lines.append("")

        # Summary
        report_lines.append("SUMMARY:")
        total_assets = len(dif_files)
        report_lines.append(f"  Total assets analyzed: {total_assets}")
        if total_assets > 0:
            match_rate = (len(perfect_matches) / total_assets) * 100
            report_lines.append(f"  Perfect match rate: {match_rate:.2f}%")
            reconciliation_needed = len(minor_differences) + len(major_differences)
            report_lines.append(f"  Assets needing reconciliation: {reconciliation_needed}")

        report_lines.append("=" * 70)

        return "\n".join(report_lines)


class DifferenceExporter:
    """
    Export differences to various formats for external processing
    """

    @staticmethod
    def export_to_csv(dif_files: List[str], csv_filepath: str) -> str:
        """
        Export all differences to CSV format

        Args:
            dif_files: List of paths to .dif files
            csv_filepath: Path for CSV output

        Returns:
            Path to the generated CSV file
        """
        import csv

        parser = DifFileParser()

        with open(csv_filepath, 'w', newline='') as csvfile:
            fieldnames = ['asset_id', 'field_name', 'zabbix_value',
                         'topdesk_value', 'difference_type', 'note']
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()

            for filepath in dif_files:
                data = parser.parse_dif_file(filepath)
                asset_id = data['asset_id']
                note = data.get('note', '')

                for diff in data['differences']:
                    # Determine difference type
                    if diff['zabbix_value'] == 'null':
                        diff_type = 'missing_in_zabbix'
                    elif diff['topdesk_value'] == 'null':
                        diff_type = 'missing_in_topdesk'
                    else:
                        diff_type = 'value_mismatch'

                    row = {
                        'asset_id': asset_id,
                        'field_name': diff['field_name'],
                        'zabbix_value': diff['zabbix_value'],
                        'topdesk_value': diff['topdesk_value'],
                        'difference_type': diff_type,
                        'note': note
                    }
                    writer.writerow(row)

        return csv_filepath

    @staticmethod
    def export_to_excel(dif_files: List[str], excel_filepath: str) -> str:
        """
        Export differences to Excel format with multiple sheets

        Args:
            dif_files: List of paths to .dif files
            excel_filepath: Path for Excel output

        Returns:
            Path to the generated Excel file
        """
        try:
            import pandas as pd
        except ImportError:
            return "Error: pandas library required for Excel export"

        parser = DifFileParser()

        # Collect all data
        all_differences = []
        summary_data = []

        for filepath in dif_files:
            data = parser.parse_dif_file(filepath)
            asset_id = data['asset_id']

            # Summary row
            summary_row = {
                'asset_id': asset_id,
                'total_differences': len(data['differences']),
                'has_note': bool(data.get('note')),
                'note': data.get('note', '')
            }
            summary_data.append(summary_row)

            # Difference rows
            for diff in data['differences']:
                diff_row = {
                    'asset_id': asset_id,
                    'field_name': diff['field_name'],
                    'zabbix_value': diff['zabbix_value'],
                    'topdesk_value': diff['topdesk_value']
                }
                all_differences.append(diff_row)

        # Create Excel writer and write sheets
        with pd.ExcelWriter(excel_filepath, engine='openpyxl') as writer:
            # Summary sheet
            summary_df = pd.DataFrame(summary_data)
            summary_df.to_excel(writer, sheet_name='Summary', index=False)

            # All differences sheet
            diff_df = pd.DataFrame(all_differences)
            diff_df.to_excel(writer, sheet_name='All_Differences', index=False)

            # Pivot analysis sheet
            if all_differences:
                pivot_df = diff_df.pivot_table(
                    index='field_name',
                    aggfunc='count',
                    values='asset_id'
                ).rename(columns={'asset_id': 'occurrence_count'})
                pivot_df.to_excel(writer, sheet_name='Field_Analysis')

        return excel_filepath


# Example usage
if __name__ == "__main__":
    # Test DIF file parsing
    test_dif_content = """asset_id: ASSET001
note: Asset exists in both systems
differences:
  - field_name: hostname
    zabbix_value: "server01.domain.com"
    topdesk_value: "server01"
  - field_name: ip_address
    zabbix_value: "192.168.1.100"
    topdesk_value: "192.168.1.200"
  - field_name: department
    zabbix_value: "null"
    topdesk_value: "IT Operations"

# Generated: 2025-01-26T10:00:00
# Total differences: 3
# Similarity score: 66.67%
# Value mismatches: 2
# Missing in Zabbix: 1
# Missing in Topdesk: 0
"""

    # Create test file
    test_file_path = "/Users/fabian/sources/posix/test_asset.dif"
    with open(test_file_path, 'w') as f:
        f.write(test_dif_content)

    # Test parser
    parser = DifFileParser()
    parsed = parser.parse_dif_file(test_file_path)
    print("Parsed DIF file:")
    print(json.dumps(parsed, indent=2))