#!/usr/bin/env python3
"""
Integration example showing how the sorter module integrates
with the merger tool workflow.
"""

import json
from pathlib import Path
from sorter import SortingStrategy, FileSorter, sort_assets, validate_sort_order


class MergerSorterIntegration:
    """
    Example integration class showing how sorter fits into the merger workflow.
    """

    def __init__(self, output_dir='/Users/fabian/sources/posix/topdesk-zbx-merger/output'):
        self.output_dir = Path(output_dir)
        self.sorter = SortingStrategy()

    def process_differ_output(self, diff_data):
        """
        Process and sort output from the @differ agent.

        Args:
            diff_data: Unsorted difference data from differ

        Returns:
            Sorted difference data ready for output
        """
        print("Processing differ output...")

        # Sort the difference entries
        if isinstance(diff_data, list):
            sorted_data = self.sorter.sort_dif_entries(diff_data)
        elif isinstance(diff_data, dict) and 'entries' in diff_data:
            diff_data['entries'] = self.sorter.sort_dif_entries(diff_data['entries'])
            sorted_data = diff_data
        else:
            sorted_data = diff_data

        print(f"  Sorted {len(sorted_data if isinstance(sorted_data, list) else sorted_data.get('entries', []))} difference entries")
        return sorted_data

    def prepare_for_tuioperator(self, assets):
        """
        Prepare sorted asset list for TUI display.

        Args:
            assets: List of assets to display

        Returns:
            Sorted assets ready for TUI display
        """
        print("Preparing assets for TUI display...")

        # Sort assets by ID
        sorted_assets = sort_assets(assets)

        # Validate sort order
        if validate_sort_order(sorted_assets):
            print(f"  Successfully sorted {len(sorted_assets)} assets for display")
        else:
            print("  Warning: Sort validation failed, but continuing...")

        return sorted_assets

    def organize_applier_changes(self, changes):
        """
        Organize changes for the @applier agent.

        Args:
            changes: List of changes to apply

        Returns:
            Sorted changes ready for application
        """
        print("Organizing changes for applier...")

        # Sort by timestamp, then asset_id
        sorted_changes = self.sorter.sort_apl_entries(changes)

        print(f"  Organized {len(sorted_changes)} changes for application")
        return sorted_changes

    def sort_output_files(self):
        """
        Sort all .dif and .apl files in the output directory.
        """
        print(f"\nSorting output files in {self.output_dir}...")

        # Sort all .dif files
        dif_files = list(self.output_dir.glob('*.dif'))
        for dif_file in dif_files:
            print(f"  Sorting {dif_file.name}...")
            try:
                FileSorter.sort_dif_file(str(dif_file), backup=True)
                print(f"    ✓ Sorted successfully")
            except Exception as e:
                print(f"    ✗ Error: {e}")

        # Sort all .apl files
        apl_files = list(self.output_dir.glob('*.apl'))
        for apl_file in apl_files:
            print(f"  Sorting {apl_file.name}...")
            try:
                FileSorter.sort_apl_file(str(apl_file), backup=True)
                print(f"    ✓ Sorted successfully")
            except Exception as e:
                print(f"    ✗ Error: {e}")

    def generate_sorted_report(self, assets):
        """
        Generate a sorted report of assets with statistics.

        Args:
            assets: List of assets to report on

        Returns:
            Report dictionary with sorted data
        """
        print("\nGenerating sorted report...")

        sorted_assets = sort_assets(assets)

        # Detect duplicates
        seen_ids = {}
        duplicates = []
        for asset in sorted_assets:
            asset_id = asset.get('asset_id')
            if asset_id:
                if asset_id in seen_ids:
                    duplicates.append(asset_id)
                else:
                    seen_ids[asset_id] = True

        # Count null IDs
        null_count = sum(1 for a in sorted_assets if not a.get('asset_id'))

        report = {
            'total_assets': len(sorted_assets),
            'unique_ids': len(seen_ids),
            'duplicate_ids': len(set(duplicates)),
            'null_ids': null_count,
            'sorted_assets': sorted_assets,
            'validation_passed': validate_sort_order(sorted_assets)
        }

        print(f"  Total assets: {report['total_assets']}")
        print(f"  Unique IDs: {report['unique_ids']}")
        print(f"  Duplicate IDs: {report['duplicate_ids']}")
        print(f"  Null/missing IDs: {report['null_ids']}")
        print(f"  Sort validation: {'PASSED' if report['validation_passed'] else 'FAILED'}")

        return report


def main():
    """
    Demonstrate the integration workflow.
    """
    print("=" * 60)
    print("SORTER INTEGRATION WORKFLOW DEMONSTRATION")
    print("=" * 60)

    # Initialize integration
    integration = MergerSorterIntegration()

    # Example 1: Process differ output
    print("\n1. Processing Differ Output")
    print("-" * 40)
    diff_data = [
        {'asset_id': 'srv10', 'operation': 'modify', 'field': 'status', 'old': 'active', 'new': 'inactive'},
        {'asset_id': 'srv2', 'operation': 'add', 'field': 'location', 'value': 'DC-01'},
        {'asset_id': 'srv1', 'operation': 'delete', 'field': 'notes'},
    ]
    sorted_diff = integration.process_differ_output(diff_data)
    for entry in sorted_diff:
        print(f"  {entry['asset_id']}: {entry['operation']} {entry['field']}")

    # Example 2: Prepare for TUI
    print("\n2. Preparing for TUI Display")
    print("-" * 40)
    assets = [
        {'asset_id': 'web10', 'hostname': 'web10.example.com', 'status': 'active'},
        {'asset_id': 'web2', 'hostname': 'web2.example.com', 'status': 'active'},
        {'asset_id': 'web1', 'hostname': 'web1.example.com', 'status': 'maintenance'},
        {'asset_id': None, 'hostname': 'unknown.example.com', 'status': 'unknown'},
    ]
    tui_assets = integration.prepare_for_tuioperator(assets)
    for asset in tui_assets:
        print(f"  {asset.get('asset_id', 'NO_ID')}: {asset.get('hostname', 'N/A')}")

    # Example 3: Organize applier changes
    print("\n3. Organizing Applier Changes")
    print("-" * 40)
    changes = [
        {'asset_id': 'db3', 'timestamp': '2024-01-02T10:00:00', 'change': 'update_config'},
        {'asset_id': 'db1', 'timestamp': '2024-01-01T09:00:00', 'change': 'restart_service'},
        {'asset_id': 'db2', 'timestamp': '2024-01-01T09:00:00', 'change': 'apply_patch'},
    ]
    sorted_changes = integration.organize_applier_changes(changes)
    for change in sorted_changes:
        print(f"  {change['timestamp']}: {change['asset_id']} - {change['change']}")

    # Example 4: Generate report
    print("\n4. Generating Sorted Report")
    print("-" * 40)
    all_assets = [
        {'asset_id': 'app1', 'type': 'application'},
        {'asset_id': 'app2', 'type': 'application'},
        {'asset_id': 'app1', 'type': 'duplicate'},  # Duplicate
        {'asset_id': None, 'type': 'unknown'},
        {'asset_id': 'db1', 'type': 'database'},
    ]
    report = integration.generate_sorted_report(all_assets)

    # Example 5: Sort output files (simulated)
    print("\n5. Sorting Output Files")
    print("-" * 40)
    # This would actually sort files in the output directory
    print("  Would sort all .dif and .apl files in output directory")
    print("  Creating backups before sorting")
    print("  Validating sort order after completion")

    print("\n" + "=" * 60)
    print("INTEGRATION DEMONSTRATION COMPLETE")
    print("=" * 60)


if __name__ == "__main__":
    main()