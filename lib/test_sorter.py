#!/usr/bin/env python3
"""
Test Suite for Sorter Module
Validates deterministic sorting behavior and edge case handling.
"""

import unittest
import json
import tempfile
from pathlib import Path
from sorter import (
    SortingStrategy,
    FileSorter,
    SortingConfig,
    sort_assets,
    validate_sort_order
)


class TestNaturalSorting(unittest.TestCase):
    """Test natural sorting algorithm."""

    def test_numeric_sorting(self):
        """Test sorting of numeric sequences."""
        items = ['10', '2', '1', '20', '3']
        sorted_items = sorted(items, key=SortingStrategy.natural_sort_key)
        self.assertEqual(sorted_items, ['1', '2', '3', '10', '20'])

    def test_alphanumeric_sorting(self):
        """Test mixed alphanumeric sorting."""
        items = ['srv10', 'srv2', 'srv1', 'srv20', 'srv3']
        sorted_items = sorted(items, key=SortingStrategy.natural_sort_key)
        self.assertEqual(sorted_items, ['srv1', 'srv2', 'srv3', 'srv10', 'srv20'])

    def test_complex_asset_ids(self):
        """Test various asset ID formats."""
        items = [
            'ASSET-001',
            'ASSET-10',
            'ASSET-2',
            'SRV-A01',
            'SRV-B02',
            'srv-a10',
            'srv-a2',
        ]
        sorted_items = sorted(items, key=SortingStrategy.natural_sort_key)

        # Verify natural sorting is applied (numbers sorted correctly)
        # Find indices of numbered assets to verify order
        asset_indices = [i for i, item in enumerate(sorted_items) if 'ASSET' in item.upper()]
        asset_values = [sorted_items[i] for i in asset_indices]

        # Check that ASSET-001, ASSET-2, ASSET-10 are in correct order
        self.assertIn('ASSET-001', asset_values[0].upper())
        self.assertIn('ASSET-2', asset_values[1].upper())
        self.assertIn('ASSET-10', asset_values[2].upper())


class TestAssetSorting(unittest.TestCase):
    """Test asset dictionary sorting."""

    def test_basic_asset_sorting(self):
        """Test basic asset sorting by ID."""
        assets = [
            {'asset_id': 'asset10', 'name': 'Ten'},
            {'asset_id': 'asset2', 'name': 'Two'},
            {'asset_id': 'asset1', 'name': 'One'},
        ]
        sorted_assets = sort_assets(assets)
        expected_order = ['asset1', 'asset2', 'asset10']
        actual_order = [a['asset_id'] for a in sorted_assets]
        self.assertEqual(actual_order, expected_order)

    def test_null_asset_handling(self):
        """Test handling of null/missing asset IDs."""
        assets = [
            {'asset_id': 'asset1'},
            {'asset_id': None},
            {'asset_id': 'asset2'},
            {'asset_id': ''},
            {'hostname': 'no_id'},
        ]
        sorted_assets = sort_assets(assets)

        # Assets with IDs should come first
        self.assertEqual(sorted_assets[0]['asset_id'], 'asset1')
        self.assertEqual(sorted_assets[1]['asset_id'], 'asset2')

        # Null/empty IDs should be at the end
        self.assertIn(sorted_assets[-1].get('asset_id'), [None, ''])

    def test_field_sorting(self):
        """Test sorting of fields within assets."""
        asset = {
            'notes': 'Some notes',
            'asset_id': 'srv001',
            'model': 'Dell R740',
            'hostname': 'server01',
            'created_date': '2024-01-01',
            'ip_address': '192.168.1.10',
        }

        sorted_asset = SortingStrategy.sort_asset_fields(asset)
        fields = list(sorted_asset.keys())

        # Check priority fields come first
        self.assertEqual(fields[0], 'asset_id')
        self.assertIn('ip_address', fields[:3])
        self.assertIn('hostname', fields[:3])

        # Check low priority fields come last
        notes_index = fields.index('notes')
        created_index = fields.index('created_date')
        self.assertGreater(notes_index, created_index)


class TestEdgeCases(unittest.TestCase):
    """Test edge case handling."""

    def test_special_characters(self):
        """Test handling of special characters."""
        value = "test\nwith\ttabs\rand\0nulls"
        normalized = SortingStrategy.handle_edge_cases(value)
        self.assertNotIn('\n', normalized)
        self.assertNotIn('\t', normalized)
        self.assertNotIn('\r', normalized)
        self.assertNotIn('\0', normalized)

    def test_unicode_sorting(self):
        """Test Unicode character handling."""
        items = ['café', 'zebra', 'åpple', 'éclair']
        sorted_items = sorted(items, key=SortingStrategy.natural_sort_key)
        self.assertEqual(len(sorted_items), 4)

    def test_duplicate_asset_ids(self):
        """Test handling of duplicate asset IDs."""
        assets = [
            {'asset_id': 'dup1', 'value': 'first'},
            {'asset_id': 'dup1', 'value': 'second'},
            {'asset_id': 'unique', 'value': 'single'},
        ]
        sorted_assets = sort_assets(assets)

        # Should maintain both duplicates
        self.assertEqual(len(sorted_assets), 3)

        # Check sort stability (first occurrence should stay first)
        dup_assets = [a for a in sorted_assets if a['asset_id'] == 'dup1']
        if len(dup_assets) == 2:
            self.assertEqual(dup_assets[0]['value'], 'first')


class TestDifSorting(unittest.TestCase):
    """Test .dif file entry sorting."""

    def test_dif_entry_sorting(self):
        """Test sorting of difference entries."""
        entries = [
            {'asset_id': 'srv2', 'operation': 'delete', 'field': 'status'},
            {'asset_id': 'srv1', 'operation': 'add', 'field': 'hostname'},
            {'asset_id': 'srv2', 'operation': 'modify', 'field': 'ip'},
            {'asset_id': 'srv1', 'operation': 'modify', 'field': 'location'},
        ]

        sorted_entries = SortingStrategy.sort_dif_entries(entries)

        # Check asset_id ordering
        self.assertEqual(sorted_entries[0]['asset_id'], 'srv1')
        self.assertEqual(sorted_entries[1]['asset_id'], 'srv1')

        # Check operation ordering within same asset
        srv1_entries = [e for e in sorted_entries if e['asset_id'] == 'srv1']
        self.assertEqual(srv1_entries[0]['operation'], 'add')
        self.assertEqual(srv1_entries[1]['operation'], 'modify')


class TestAplSorting(unittest.TestCase):
    """Test .apl file entry sorting."""

    def test_apl_entry_sorting(self):
        """Test sorting of application entries."""
        entries = [
            {'asset_id': 'srv3', 'timestamp': '2024-01-03', 'sequence': 1},
            {'asset_id': 'srv1', 'timestamp': '2024-01-01', 'sequence': 2},
            {'asset_id': 'srv2', 'timestamp': '2024-01-01', 'sequence': 1},
        ]

        sorted_entries = SortingStrategy.sort_apl_entries(entries)

        # Check timestamp is primary sort key
        self.assertEqual(sorted_entries[0]['timestamp'], '2024-01-01')
        self.assertEqual(sorted_entries[1]['timestamp'], '2024-01-01')
        self.assertEqual(sorted_entries[2]['timestamp'], '2024-01-03')

        # Check that entries are sorted by timestamp, then asset_id, then sequence
        jan1_entries = [e for e in sorted_entries if e['timestamp'] == '2024-01-01']
        # srv1 comes before srv2 in natural sort
        self.assertEqual(jan1_entries[0]['asset_id'], 'srv1')
        self.assertEqual(jan1_entries[1]['asset_id'], 'srv2')


class TestFileSorting(unittest.TestCase):
    """Test file-based sorting operations."""

    def test_dif_file_sorting(self):
        """Test sorting of .dif file contents."""
        # Create temp file with unsorted data
        data = {
            'entries': [
                {'asset_id': 'srv10', 'change': 'update'},
                {'asset_id': 'srv2', 'change': 'create'},
                {'asset_id': 'srv1', 'change': 'delete'},
            ]
        }

        with tempfile.NamedTemporaryFile(
            mode='w',
            suffix='.dif',
            delete=False
        ) as f:
            json.dump(data, f)
            temp_path = f.name

        try:
            # Sort the file
            FileSorter.sort_dif_file(temp_path, backup=False)

            # Read and verify
            with open(temp_path, 'r') as f:
                sorted_data = json.load(f)

            entries = sorted_data['entries']
            self.assertEqual(entries[0]['asset_id'], 'srv1')
            self.assertEqual(entries[1]['asset_id'], 'srv2')
            self.assertEqual(entries[2]['asset_id'], 'srv10')

        finally:
            Path(temp_path).unlink(missing_ok=True)


class TestValidation(unittest.TestCase):
    """Test sort order validation."""

    def test_valid_sort_order(self):
        """Test validation of correctly sorted data."""
        assets = [
            {'asset_id': 'asset1'},
            {'asset_id': 'asset2'},
            {'asset_id': 'asset10'},
        ]
        self.assertTrue(validate_sort_order(assets))

    def test_invalid_sort_order(self):
        """Test detection of incorrect sort order."""
        assets = [
            {'asset_id': 'asset10'},
            {'asset_id': 'asset2'},
            {'asset_id': 'asset1'},
        ]
        self.assertFalse(validate_sort_order(assets))


class TestSortingConfig(unittest.TestCase):
    """Test sorting configuration."""

    def test_config_creation(self):
        """Test creation and serialization of config."""
        config = SortingConfig()
        config.reverse_order = True
        config.case_sensitive = True

        # Convert to dict
        config_dict = config.to_dict()
        self.assertEqual(config_dict['reverse_order'], True)
        self.assertEqual(config_dict['case_sensitive'], True)

        # Create from dict
        new_config = SortingConfig.from_dict(config_dict)
        self.assertEqual(new_config.reverse_order, True)
        self.assertEqual(new_config.case_sensitive, True)


if __name__ == '__main__':
    # Run tests with verbose output
    unittest.main(verbosity=2)