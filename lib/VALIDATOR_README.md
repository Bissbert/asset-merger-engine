# Validation Module for Topdesk-Zabbix Merger

## Overview

The validation module provides comprehensive validation capabilities for the Topdesk-Zabbix merger tool. It ensures data integrity, validates file formats, and verifies that sync operations complete successfully.

## Components

### 1. `validator.py` - Core Validation Module
The main validation engine that provides:
- DIF file format validation
- APL file structure validation
- Asset data validation
- Data sync verification
- Cache integrity checks
- Pre-execution validation
- Comprehensive reporting

### 2. `validator_integration.py` - Workflow Integration
Integration module that:
- Validates each phase of the merger workflow
- Manages validation reports
- Provides summary statistics
- Enables automated validation checkpoints

### 3. `test_validator.py` - Test & Demo Suite
Demonstration script showing:
- All validation capabilities
- Error detection examples
- Report generation
- Edge case handling

## Features

### File Format Validation

#### DIF Files (.dif)
- JSON structure validation
- Operation type verification (add, modify, delete, create)
- Field presence checks
- Value consistency validation
- Conflict detection (e.g., delete with other operations)

#### APL Files (.apl)
- JSON structure validation
- Status verification (applied, failed, skipped, pending)
- Sequence number uniqueness
- Timestamp format validation
- Command structure checks
- Error message presence for failures

### Data Validation

#### Asset Validation
- Required field presence (asset_id)
- Data type verification
- IP address format validation
- Serial number reasonableness
- Status value validation
- Duplicate ID detection

#### Sync Validation
- Field mapping verification
- Missing asset detection
- Value comparison
- Synchronization completeness
- Improvement metrics

### System Validation

#### Pre-Execution Checks
- Tool availability verification
- Configuration completeness
- Permission checks
- Network connectivity (optional)

#### Cache Integrity
- File readability
- JSON structure validation
- Checksum verification (if present)
- Cache age monitoring
- Corruption detection

## Usage

### Basic Command-Line Usage

```bash
# Validate a DIF file
python validator.py --dif /path/to/file.dif

# Validate an APL file
python validator.py --apl /path/to/file.apl

# Validate cache directory
python validator.py --cache-dir /path/to/cache

# Generate comprehensive report
python validator.py --report --output validation_report.txt

# Verbose output
python validator.py --dif file.dif --verbose
```

### Python API Usage

```python
from validator import MergerValidator

# Create validator instance
validator = MergerValidator()

# Validate DIF file
result = validator.validate_dif_file('changes.dif')
print(result.generate_report())

# Validate assets
assets = [{'asset_id': 'srv-001', 'ip_address': '192.168.1.1'}]
result = validator.validate_assets(assets)

# Check validation status
if result.status == ValidationStatus.PASSED:
    print("Validation passed!")
elif result.status == ValidationStatus.PASSED_WITH_WARNINGS:
    print(f"Passed with {len(result.warnings)} warnings")
else:
    print(f"Failed with {len(result.errors)} errors")
```

### Integration Usage

```python
from validator_integration import ValidatorIntegration

# Create integration instance
integration = ValidatorIntegration(output_dir='./output')

# Validate workflow phases
success = integration.validate_retrieval_phase(zabbix_data, topdesk_data)
success = integration.validate_comparison_phase(dif_files)
success = integration.validate_tui_selections(apl_file)
success = integration.validate_application_phase(apl_file, applied_changes)

# Or validate entire workflow
workflow_data = {
    'config': config,
    'zabbix_data': zabbix_assets,
    'topdesk_data': topdesk_assets,
    'dif_files': ['changes.dif'],
    'apl_file': 'applied.apl'
}
success = integration.perform_full_validation(workflow_data)
```

## Validation Rules

### Critical Errors (Halt Execution)
- Missing required tools
- No write permissions
- Invalid JSON structure
- Missing configuration
- File not found

### Recoverable Errors (Log and Continue)
- Single asset validation failure
- Missing optional fields
- Format warnings
- Old cache files

### Warnings (Monitor)
- Unexpected field values
- Performance issues
- Missing optional data
- High failure rates

## Validation Reports

### Report Structure
```
Validation Report - [Name]
===============================
Status: PASSED_WITH_WARNINGS
Checks Performed: 15
Passed: 13
Failed: 2

Warnings:
  ⚠ 3 assets have empty owner fields
  ⚠ API response time exceeds threshold

Errors:
  ✗ Invalid IP address format: 999.999.999.999

Information:
  ℹ Found 150 entries
  ℹ Processing took 2.3 seconds

Metadata:
  total_assets: 150
  unique_ids: 150
  duplicates: 0
```

### Comprehensive Reports
The validator can generate comprehensive reports covering all validations:
- Summary statistics
- Individual validation results
- Recommendations
- Timeline of validations
- Error aggregation

## Configuration

### Validator Configuration File
```json
{
  "validation": {
    "strict_mode": false,
    "skip_warnings": false,
    "max_errors": 100,
    "timeout_seconds": 300
  },
  "field_mappings": {
    "host": "asset_id",
    "name": "hostname",
    "ip": "ip_address"
  },
  "thresholds": {
    "max_cache_age_days": 7,
    "max_failure_rate": 0.1,
    "min_success_rate": 0.9
  }
}
```

## Performance Metrics

The validator tracks:
- Validation execution time
- Number of checks performed
- Pass/fail ratios
- Warning counts
- Error detection rates

## Best Practices

1. **Always validate before applying changes**
   - Run pre-execution validation
   - Validate APL files before application
   - Check sync completeness after

2. **Review warnings**
   - Warnings may indicate data quality issues
   - Address warnings to prevent future errors

3. **Use comprehensive reports**
   - Generate reports for audit trails
   - Review recommendations
   - Track improvement over time

4. **Handle validation failures**
   - Critical errors should halt execution
   - Log all validation results
   - Implement rollback for failures

## Error Recovery

When validation fails:
1. Check the validation report for specific errors
2. Address critical errors first
3. Re-run validation after fixes
4. Consider rollback if application phase fails
5. Use validation history for troubleshooting

## Testing

Run the test suite:
```bash
# Run all validation demos
python test_validator.py

# Run specific validation tests
python -m pytest test_validator.py -v
```

## Troubleshooting

### Common Issues

1. **JSON Decode Errors**
   - Check file encoding (should be UTF-8)
   - Validate JSON structure with external tool
   - Look for trailing commas or missing brackets

2. **Missing Required Fields**
   - Ensure asset_id is present for all assets
   - Check field mappings configuration
   - Verify data source completeness

3. **High Failure Rates**
   - Review field mappings
   - Check data quality from sources
   - Verify API permissions

4. **Cache Corruption**
   - Clear cache directory
   - Check disk space
   - Verify file permissions

## Dependencies

- Python 3.8+
- Standard library modules (json, logging, pathlib, etc.)
- No external dependencies required

## Extension Points

The validator can be extended with:
- Custom validation rules
- Additional file format support
- External schema validation
- Database integrity checks
- API response validation
- Custom report formats

## Support

For issues or questions:
1. Check validation reports for detailed error messages
2. Enable verbose logging for debugging
3. Review test cases for usage examples
4. Consult workflow integration examples