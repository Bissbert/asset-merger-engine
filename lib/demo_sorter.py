#!/usr/bin/env python3
"""
Demo script showing sorting strategy capabilities and edge case handling.
"""

import json
import tempfile
from pathlib import Path
from sorter import SortingStrategy, FileSorter, sort_assets, validate_sort_order


def demo_natural_sorting():
    """Demonstrate natural sorting vs standard sorting."""
    print("=" * 60)
    print("NATURAL SORTING DEMONSTRATION")
    print("=" * 60)

    # Test data with numeric sequences
    test_ids = [
        'asset100', 'asset2', 'asset1', 'asset20', 'asset10',
        'SRV-001', 'SRV-010', 'SRV-002', 'SRV-100',
        'node1', 'node10', 'node2', 'node20',
    ]

    print("\nOriginal order:")
    for id in test_ids:
        print(f"  {id}")

    # Standard Python sort (wrong for numeric sequences)
    standard_sorted = sorted(test_ids)
    print("\nStandard Python sort (INCORRECT for mixed alphanumeric):")
    for id in standard_sorted:
        print(f"  {id}")

    # Natural sort (correct)
    natural_sorted = sorted(test_ids, key=SortingStrategy.natural_sort_key)
    print("\nNatural sort (CORRECT):")
    for id in natural_sorted:
        print(f"  {id}")


def demo_edge_cases():
    """Demonstrate edge case handling."""
    print("\n" + "=" * 60)
    print("EDGE CASE HANDLING DEMONSTRATION")
    print("=" * 60)

    # Test data with edge cases
    assets = [
        {'asset_id': 'normal_id', 'status': 'active'},
        {'asset_id': None, 'status': 'unknown'},
        {'asset_id': '', 'status': 'empty'},
        {'asset_id': '  spaces  ', 'status': 'has_spaces'},
        {'asset_id': 'UPPERCASE', 'status': 'caps'},
        {'asset_id': 'lowercase', 'status': 'lower'},
        {'asset_id': 'special!@#$', 'status': 'special_chars'},
        {'asset_id': 'tab\ttab', 'status': 'has_tabs'},
        {'asset_id': 'new\nline', 'status': 'has_newline'},
        {'hostname': 'no_asset_id'},  # Missing asset_id field
    ]

    print("\nOriginal assets:")
    for asset in assets:
        print(f"  {asset}")

    sorted_assets = sort_assets(assets)

    print("\nSorted assets (nulls and missing IDs at end):")
    for asset in sorted_assets:
        print(f"  {asset}")


def demo_field_sorting():
    """Demonstrate field sorting within assets."""
    print("\n" + "=" * 60)
    print("FIELD SORTING DEMONSTRATION")
    print("=" * 60)

    # Asset with randomly ordered fields
    asset = {
        'notes': 'Last priority field',
        'random_field': 'Not in priority list',
        'asset_id': 'srv001',
        'created_date': 'Metadata field',
        'hostname': 'server01.domain.com',
        'model': 'Dell PowerEdge R740',
        'ip_address': '192.168.1.100',
        'department': 'IT',
        'serial_number': 'SN123456',
        'status': 'active',
    }

    print("\nOriginal field order:")
    for key in asset.keys():
        print(f"  {key}: {asset[key]}")

    sorted_asset = SortingStrategy.sort_asset_fields(asset.copy())

    print("\nSorted field order (by priority):")
    for key in sorted_asset.keys():
        print(f"  {key}: {sorted_asset[key]}")


def demo_file_sorting():
    """Demonstrate file sorting capabilities."""
    print("\n" + "=" * 60)
    print("FILE SORTING DEMONSTRATION")
    print("=" * 60)

    # Create test .dif file
    dif_data = {
        'entries': [
            {'asset_id': 'srv10', 'operation': 'modify', 'field': 'status'},
            {'asset_id': 'srv2', 'operation': 'add', 'field': 'hostname'},
            {'asset_id': 'srv1', 'operation': 'delete', 'field': 'notes'},
            {'asset_id': 'srv2', 'operation': 'modify', 'field': 'ip_address'},
            {'asset_id': 'srv10', 'operation': 'add', 'field': 'location'},
        ]
    }

    # Create temporary file
    with tempfile.NamedTemporaryFile(mode='w', suffix='.dif', delete=False) as f:
        json.dump(dif_data, f, indent=2)
        temp_path = f.name

    print(f"\nCreated test .dif file: {temp_path}")

    print("\nOriginal .dif entries:")
    for entry in dif_data['entries']:
        print(f"  {entry['asset_id']}: {entry['operation']} {entry['field']}")

    # Sort the file
    FileSorter.sort_dif_file(temp_path, backup=False)

    # Read sorted file
    with open(temp_path, 'r') as f:
        sorted_data = json.load(f)

    print("\nSorted .dif entries (by asset_id, then operation, then field):")
    for entry in sorted_data['entries']:
        print(f"  {entry['asset_id']}: {entry['operation']} {entry['field']}")

    # Cleanup
    Path(temp_path).unlink()


def demo_duplicate_handling():
    """Demonstrate handling of duplicate asset IDs."""
    print("\n" + "=" * 60)
    print("DUPLICATE HANDLING DEMONSTRATION")
    print("=" * 60)

    assets = [
        {'asset_id': 'dup001', 'instance': 'first', 'value': 1},
        {'asset_id': 'unique001', 'instance': 'single', 'value': 2},
        {'asset_id': 'dup001', 'instance': 'second', 'value': 3},
        {'asset_id': 'dup001', 'instance': 'third', 'value': 4},
        {'asset_id': 'unique002', 'instance': 'single', 'value': 5},
    ]

    print("\nOriginal assets with duplicates:")
    for asset in assets:
        print(f"  {asset['asset_id']}: instance={asset['instance']}, value={asset['value']}")

    sorted_assets = sort_assets(assets)

    print("\nSorted assets (duplicates preserved, order stable):")
    for asset in sorted_assets:
        print(f"  {asset['asset_id']}: instance={asset['instance']}, value={asset['value']}")

    print("\nNote: Duplicates are preserved and maintain their relative order (stable sort)")


def demo_validation():
    """Demonstrate sort order validation."""
    print("\n" + "=" * 60)
    print("VALIDATION DEMONSTRATION")
    print("=" * 60)

    # Correctly sorted list
    correct_assets = [
        {'asset_id': 'asset1'},
        {'asset_id': 'asset2'},
        {'asset_id': 'asset10'},
        {'asset_id': 'asset20'},
        {'asset_id': None},  # Nulls at end
    ]

    print("\nCorrectly sorted assets:")
    for asset in correct_assets:
        print(f"  {asset}")
    print(f"Validation result: {validate_sort_order(correct_assets)}")

    # Incorrectly sorted list
    incorrect_assets = [
        {'asset_id': 'asset10'},
        {'asset_id': 'asset2'},  # Wrong order
        {'asset_id': 'asset1'},
        {'asset_id': None},
    ]

    print("\nIncorrectly sorted assets:")
    for asset in incorrect_assets:
        print(f"  {asset}")
    print(f"Validation result: {validate_sort_order(incorrect_assets)}")


def main():
    """Run all demonstrations."""
    print("\n" + "#" * 60)
    print("# SORTER MODULE DEMONSTRATION")
    print("#" * 60)

    demo_natural_sorting()
    demo_edge_cases()
    demo_field_sorting()
    demo_file_sorting()
    demo_duplicate_handling()
    demo_validation()

    print("\n" + "#" * 60)
    print("# DEMONSTRATION COMPLETE")
    print("#" * 60)
    print("\nThe sorter module ensures:")
    print("  1. Natural sorting of alphanumeric IDs")
    print("  2. Consistent handling of edge cases")
    print("  3. Priority-based field ordering")
    print("  4. Stable sorting with duplicate preservation")
    print("  5. Validation of sort order")
    print("  6. Reproducible results across runs")


if __name__ == "__main__":
    main()