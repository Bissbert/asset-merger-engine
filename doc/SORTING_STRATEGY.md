# Sorting Strategy Documentation

## Overview

The sorter module ensures deterministic and reproducible ordering of all data structures in the merger tool. This guarantees consistent output across different runs and environments.

## Core Principles

1. **Deterministic Ordering**: Same input always produces same output
2. **Natural Sorting**: Handles mixed alphanumeric values intelligently
3. **Null Safety**: Gracefully handles missing or null values
4. **Performance**: Efficient algorithms for large datasets
5. **Stability**: Maintains relative order of equal elements

## Sorting Rules

### Asset ID Sorting

Assets are sorted using natural sorting algorithm which correctly handles numeric sequences:

```
Standard Sort:      Natural Sort:
asset1              asset1
asset10             asset2
asset2              asset3
asset20             asset10
asset3              asset20
```

### Field Priority Order

Fields within asset records are sorted by priority:

1. **Critical Fields** (Priority 1-5)
   - asset_id (always first)
   - ip_address
   - hostname
   - serial_number
   - model

2. **Configuration Fields** (Priority 6-50)
   - manufacturer
   - location
   - department
   - status
   - Other standard fields

3. **Metadata Fields** (Priority 90-99)
   - last_updated
   - created_date
   - notes (always near last)

### Edge Case Handling

#### Null Values
- Null or missing asset_ids sort to the end
- Empty strings are treated as null
- Assets without asset_id field sort after those with

#### Special Characters
- Newlines, tabs, and null bytes are normalized
- Unicode characters are handled correctly
- Whitespace is normalized (multiple spaces become single)

#### Duplicate IDs
- Duplicates are preserved (not deduplicated)
- Original order maintained (stable sort)
- Warning logged for tracking

## File Sorting

### .dif Files

Difference files are sorted by:
1. Asset ID (natural sort)
2. Operation type (add < modify < delete)
3. Field name (alphabetical)

Example sorted order:
```json
[
  {"asset_id": "srv1", "operation": "add", "field": "hostname"},
  {"asset_id": "srv1", "operation": "modify", "field": "ip_address"},
  {"asset_id": "srv2", "operation": "modify", "field": "location"},
  {"asset_id": "srv2", "operation": "delete", "field": "notes"},
  {"asset_id": "srv10", "operation": "add", "field": "model"}
]
```

### .apl Files

Application files are sorted by:
1. Timestamp (chronological)
2. Asset ID (natural sort)
3. Sequence number (if present)

Example sorted order:
```json
[
  {"timestamp": "2024-01-01", "asset_id": "srv1", "sequence": 1},
  {"timestamp": "2024-01-01", "asset_id": "srv2", "sequence": 2},
  {"timestamp": "2024-01-02", "asset_id": "srv1", "sequence": 1}
]
```

## API Usage

### Basic Sorting

```python
from sorter import sort_assets

# Sort list of assets
assets = [
    {'asset_id': 'srv10', 'name': 'Server 10'},
    {'asset_id': 'srv2', 'name': 'Server 2'},
    {'asset_id': 'srv1', 'name': 'Server 1'}
]

sorted_assets = sort_assets(assets)
# Result: srv1, srv2, srv10
```

### File Sorting

```python
from sorter import sort_dif_file, sort_apl_file

# Sort .dif file in place
sort_dif_file('/path/to/changes.dif')

# Sort .apl file in place
sort_apl_file('/path/to/applied.apl')
```

### Validation

```python
from sorter import validate_sort_order

# Check if list is properly sorted
is_sorted = validate_sort_order(assets)
if not is_sorted:
    print("Assets are not in correct order!")
```

### Custom Configuration

```python
from sorter import SortingConfig

config = SortingConfig()
config.reverse_order = False
config.null_position = 'last'
config.numeric_handling = 'natural'
config.duplicate_handling = 'keep_first'
```

## Performance Characteristics

- **Time Complexity**: O(n log n) for sorting operations
- **Space Complexity**: O(n) for sort key generation
- **Stable Sort**: Maintains relative order of equal elements
- **In-place Options**: Available for file sorting operations

## Integration Points

### Input Sources
- Receives unsorted data from @differ
- Gets asset lists from @datafetcher
- Processes field collections from various sources

### Output Consumers
- Provides sorted assets to @tuioperator for display
- Sends ordered change sets to @applier
- Supplies sorted data to @logger for reporting

## Testing

Run the test suite to validate sorting behavior:

```bash
python lib/test_sorter.py
```

Run the demonstration to see capabilities:

```bash
python lib/demo_sorter.py
```

Tests cover:
- Natural sorting algorithm
- Asset ID sorting with various formats
- Field priority ordering
- Edge case handling (nulls, special chars, Unicode)
- File sorting operations
- Sort order validation

## Configuration File

Create `etc/sorting_config.json` for custom settings:

```json
{
  "case_sensitive": false,
  "reverse_order": false,
  "null_position": "last",
  "numeric_handling": "natural",
  "locale": "en_US",
  "stable_sort": true,
  "duplicate_handling": "keep_first"
}
```

## Best Practices

1. **Always Sort Before Output**: Sort data before writing to files
2. **Validate After Sorting**: Use validation function to ensure correctness
3. **Handle Errors Gracefully**: Sorting failures should not crash the application
4. **Log Anomalies**: Record duplicate IDs and sort violations
5. **Maintain Backups**: Create backups before in-place file sorting

## Troubleshooting

### Common Issues

1. **Unexpected Sort Order**
   - Check for mixed case (sorting is case-insensitive by default)
   - Verify natural sorting is enabled for numeric sequences
   - Look for hidden characters in asset IDs

2. **Null Values Not at End**
   - Ensure null_position config is set to 'last'
   - Check for empty strings vs actual nulls

3. **Duplicates Causing Issues**
   - Review duplicate_handling configuration
   - Check logs for duplicate warnings
   - Consider deduplication before sorting

4. **Performance Problems**
   - For large datasets, consider batch processing
   - Use in-place sorting when possible
   - Profile to identify bottlenecks

## Future Enhancements

- Locale-specific sorting rules
- Configurable field priorities
- Parallel sorting for large datasets
- Custom comparator support
- Sort index caching