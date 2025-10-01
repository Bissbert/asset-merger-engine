#!/usr/bin/env python3
"""
Sorter Module - Deterministic Sorting Strategy for Merger Tool
Ensures consistent and reproducible ordering of all data structures.
"""

import re
from typing import Any, Dict, List, Optional, Union, Callable
from functools import cmp_to_key
import logging

logger = logging.getLogger(__name__)


class SortingStrategy:
    """
    Implements deterministic sorting strategies for merger tool data structures.
    """

    # Field priority order for within-record sorting
    FIELD_PRIORITY = {
        'asset_id': 1,
        'ip_address': 2,
        'hostname': 3,
        'serial_number': 4,
        'model': 5,
        'manufacturer': 6,
        'location': 7,
        'department': 8,
        'status': 9,
        'last_updated': 90,
        'created_date': 91,
        'notes': 99,
    }

    @staticmethod
    def natural_sort_key(text: str) -> List[Union[int, str]]:
        """
        Generate a key for natural sorting (handles mixed alphanumeric).

        Examples:
            asset1 < asset2 < asset10 < asset20
            srv001 < srv002 < srv010 < srv100

        Args:
            text: String to generate sort key for

        Returns:
            List of mixed int/str for sorting
        """
        if text is None:
            return [float('inf'), '']  # Null values sort to end

        # Handle special characters and normalize
        text = str(text).strip().lower()

        # Split into numeric and non-numeric parts
        parts = []
        for part in re.split(r'(\d+)', text):
            if part.isdigit():
                parts.append(int(part))
            elif part:
                parts.append(part)

        return parts if parts else ['']

    @staticmethod
    def asset_id_comparator(a: Dict[str, Any], b: Dict[str, Any]) -> int:
        """
        Compare two assets by their asset_id using natural sorting.

        Args:
            a: First asset dictionary
            b: Second asset dictionary

        Returns:
            -1 if a < b, 0 if a == b, 1 if a > b
        """
        # Handle missing asset_ids
        a_id = a.get('asset_id', '')
        b_id = b.get('asset_id', '')

        # Null/empty handling
        if not a_id and not b_id:
            return 0
        if not a_id:
            return 1  # Empty IDs sort to end
        if not b_id:
            return -1

        # Natural sort comparison
        a_key = SortingStrategy.natural_sort_key(a_id)
        b_key = SortingStrategy.natural_sort_key(b_id)

        if a_key < b_key:
            return -1
        elif a_key > b_key:
            return 1
        return 0

    @classmethod
    def sort_assets(cls, assets: List[Dict[str, Any]],
                   reverse: bool = False) -> List[Dict[str, Any]]:
        """
        Sort a list of assets by asset_id using natural sorting.

        Args:
            assets: List of asset dictionaries
            reverse: Sort in descending order if True

        Returns:
            Sorted list of assets
        """
        try:
            sorted_assets = sorted(
                assets,
                key=cmp_to_key(cls.asset_id_comparator),
                reverse=reverse
            )

            # Also sort fields within each asset
            for asset in sorted_assets:
                cls.sort_asset_fields(asset)

            return sorted_assets

        except Exception as e:
            logger.error(f"Error sorting assets: {e}")
            # Return original list if sorting fails
            return assets

    @classmethod
    def sort_asset_fields(cls, asset: Dict[str, Any]) -> Dict[str, Any]:
        """
        Sort fields within an asset dictionary by priority and name.

        Args:
            asset: Asset dictionary to sort

        Returns:
            Dictionary with sorted fields
        """
        if not isinstance(asset, dict):
            return asset

        def field_sort_key(field: str) -> tuple:
            """Generate sort key for field names."""
            # Check priority first
            priority = cls.FIELD_PRIORITY.get(field.lower(), 50)
            # Then alphabetical
            return (priority, field.lower())

        # Create new dict with sorted fields
        sorted_asset = {}
        for key in sorted(asset.keys(), key=field_sort_key):
            sorted_asset[key] = asset[key]

        # Update original dict to maintain references
        asset.clear()
        asset.update(sorted_asset)

        return asset

    @staticmethod
    def sort_dif_entries(entries: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Sort difference file entries for consistent output.

        Args:
            entries: List of difference entries

        Returns:
            Sorted list of entries
        """
        def dif_sort_key(entry: Dict[str, Any]) -> tuple:
            """Generate sort key for dif entries."""
            # Primary: asset_id
            asset_id = entry.get('asset_id', '')
            # Secondary: operation type (add < modify < delete)
            op_order = {'add': 1, 'modify': 2, 'delete': 3}
            operation = entry.get('operation', 'modify')
            # Tertiary: field name
            field = entry.get('field', '')

            return (
                SortingStrategy.natural_sort_key(asset_id),
                op_order.get(operation, 99),
                field.lower()
            )

        return sorted(entries, key=dif_sort_key)

    @staticmethod
    def sort_apl_entries(entries: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Sort application file entries for consistent output.

        Args:
            entries: List of apl entries

        Returns:
            Sorted list of entries
        """
        def apl_sort_key(entry: Dict[str, Any]) -> tuple:
            """Generate sort key for apl entries."""
            # Primary: timestamp (if present)
            timestamp = entry.get('timestamp', '9999-99-99')
            # Secondary: asset_id
            asset_id = entry.get('asset_id', '')
            # Tertiary: sequence number (if present)
            sequence = entry.get('sequence', 999999)

            return (
                timestamp,
                SortingStrategy.natural_sort_key(asset_id),
                sequence
            )

        return sorted(entries, key=apl_sort_key)

    @staticmethod
    def handle_edge_cases(value: Any) -> str:
        """
        Handle edge cases for sorting (null, special chars, etc).

        Args:
            value: Value to process

        Returns:
            Normalized string for sorting
        """
        if value is None:
            return ''

        if isinstance(value, bool):
            return '0' if value else '1'

        if isinstance(value, (int, float)):
            return str(value)

        # Convert to string and handle special characters
        text = str(value)

        # Remove or replace problematic characters
        replacements = {
            '\n': ' ',
            '\r': ' ',
            '\t': ' ',
            '\0': '',
        }

        for old, new in replacements.items():
            text = text.replace(old, new)

        # Normalize whitespace
        text = ' '.join(text.split())

        return text.strip()

    @staticmethod
    def validate_sort_order(items: List[Dict[str, Any]],
                           key_field: str = 'asset_id') -> bool:
        """
        Validate that a list is properly sorted.

        Args:
            items: List to validate
            key_field: Field to check sorting on

        Returns:
            True if properly sorted, False otherwise
        """
        if len(items) <= 1:
            return True

        for i in range(1, len(items)):
            prev_val = items[i-1].get(key_field)
            curr_val = items[i].get(key_field)

            # Handle None values - they should be at the end
            if prev_val is None and curr_val is not None:
                logger.warning(
                    f"Sort order violation at index {i}: "
                    f"None value before non-None value"
                )
                return False

            # If both are None or current is None, that's valid
            if prev_val is None or curr_val is None:
                continue

            prev_key = SortingStrategy.natural_sort_key(str(prev_val))
            curr_key = SortingStrategy.natural_sort_key(str(curr_val))

            if prev_key > curr_key:
                logger.warning(
                    f"Sort order violation at index {i}: "
                    f"{prev_val} > {curr_val}"
                )
                return False

        return True


class FileSorter:
    """
    Handles sorting of file contents for .dif and .apl files.
    """

    @staticmethod
    def sort_dif_file(filepath: str, backup: bool = True) -> None:
        """
        Sort a .dif file in place.

        Args:
            filepath: Path to .dif file
            backup: Create backup before sorting
        """
        import json
        import shutil
        from pathlib import Path

        path = Path(filepath)

        if not path.exists():
            raise FileNotFoundError(f"File not found: {filepath}")

        if backup:
            backup_path = path.with_suffix('.dif.bak')
            shutil.copy2(path, backup_path)
            logger.info(f"Created backup: {backup_path}")

        try:
            with open(path, 'r') as f:
                data = json.load(f)

            # Sort based on data structure
            if isinstance(data, list):
                data = SortingStrategy.sort_dif_entries(data)
            elif isinstance(data, dict):
                if 'entries' in data:
                    data['entries'] = SortingStrategy.sort_dif_entries(
                        data['entries']
                    )
                if 'assets' in data:
                    data['assets'] = SortingStrategy.sort_assets(
                        data['assets']
                    )

            # Write sorted data back
            with open(path, 'w') as f:
                json.dump(data, f, indent=2, sort_keys=False)

            logger.info(f"Sorted file: {filepath}")

        except Exception as e:
            logger.error(f"Error sorting file {filepath}: {e}")
            if backup:
                # Restore from backup on error
                backup_path = path.with_suffix('.dif.bak')
                shutil.copy2(backup_path, path)
                logger.info("Restored from backup due to error")
            raise

    @staticmethod
    def sort_apl_file(filepath: str, backup: bool = True) -> None:
        """
        Sort a .apl file in place.

        Args:
            filepath: Path to .apl file
            backup: Create backup before sorting
        """
        import json
        import shutil
        from pathlib import Path

        path = Path(filepath)

        if not path.exists():
            raise FileNotFoundError(f"File not found: {filepath}")

        if backup:
            backup_path = path.with_suffix('.apl.bak')
            shutil.copy2(path, backup_path)
            logger.info(f"Created backup: {backup_path}")

        try:
            with open(path, 'r') as f:
                data = json.load(f)

            # Sort based on data structure
            if isinstance(data, list):
                data = SortingStrategy.sort_apl_entries(data)
            elif isinstance(data, dict):
                if 'entries' in data:
                    data['entries'] = SortingStrategy.sort_apl_entries(
                        data['entries']
                    )
                if 'changes' in data:
                    data['changes'] = SortingStrategy.sort_apl_entries(
                        data['changes']
                    )

            # Write sorted data back
            with open(path, 'w') as f:
                json.dump(data, f, indent=2, sort_keys=False)

            logger.info(f"Sorted file: {filepath}")

        except Exception as e:
            logger.error(f"Error sorting file {filepath}: {e}")
            if backup:
                # Restore from backup on error
                backup_path = path.with_suffix('.apl.bak')
                shutil.copy2(backup_path, path)
                logger.info("Restored from backup due to error")
            raise


class SortingConfig:
    """
    Configuration for sorting behavior.
    """

    def __init__(self):
        self.case_sensitive = False
        self.reverse_order = False
        self.null_position = 'last'  # 'first' or 'last'
        self.numeric_handling = 'natural'  # 'natural' or 'lexical'
        self.locale = 'en_US'
        self.stable_sort = True
        self.duplicate_handling = 'keep_first'  # 'keep_first', 'keep_last', 'error'

    def to_dict(self) -> Dict[str, Any]:
        """Convert config to dictionary."""
        return {
            'case_sensitive': self.case_sensitive,
            'reverse_order': self.reverse_order,
            'null_position': self.null_position,
            'numeric_handling': self.numeric_handling,
            'locale': self.locale,
            'stable_sort': self.stable_sort,
            'duplicate_handling': self.duplicate_handling,
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'SortingConfig':
        """Create config from dictionary."""
        config = cls()
        for key, value in data.items():
            if hasattr(config, key):
                setattr(config, key, value)
        return config


# Module-level convenience functions
def sort_assets(assets: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Sort assets using default strategy."""
    return SortingStrategy.sort_assets(assets)


def sort_dif_file(filepath: str) -> None:
    """Sort a .dif file in place."""
    FileSorter.sort_dif_file(filepath)


def sort_apl_file(filepath: str) -> None:
    """Sort a .apl file in place."""
    FileSorter.sort_apl_file(filepath)


def validate_sort_order(items: List[Dict[str, Any]]) -> bool:
    """Validate sort order of items."""
    return SortingStrategy.validate_sort_order(items)


if __name__ == "__main__":
    # Example usage and testing
    import json

    # Test data
    test_assets = [
        {'asset_id': 'srv10', 'hostname': 'server10'},
        {'asset_id': 'srv2', 'hostname': 'server2'},
        {'asset_id': 'srv1', 'hostname': 'server1'},
        {'asset_id': 'srv20', 'hostname': 'server20'},
        {'asset_id': None, 'hostname': 'unknown'},
        {'asset_id': 'srv3', 'hostname': 'server3'},
    ]

    print("Original assets:")
    for asset in test_assets:
        print(f"  {asset}")

    sorted_assets = sort_assets(test_assets)

    print("\nSorted assets:")
    for asset in sorted_assets:
        print(f"  {asset}")

    print(f"\nSort order valid: {validate_sort_order(sorted_assets)}")