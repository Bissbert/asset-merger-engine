#!/usr/bin/env python3
"""
Comprehensive validation system for the Topdesk-Zabbix merger tool.

This module provides validation for:
- Data sync operations
- .dif file format and content
- .apl file structure
- Topdesk changes verification
- Cached data integrity
- Validation reports generation
"""

import json
import re
import hashlib
import os
import sys
import time
import logging
import subprocess
import shutil
from datetime import datetime
from typing import Dict, Any, List, Optional, Tuple, Set
from pathlib import Path
from collections import defaultdict
from enum import Enum


class ValidationStatus(Enum):
    """Validation status levels."""
    PASSED = "PASSED"
    PASSED_WITH_WARNINGS = "PASSED_WITH_WARNINGS"
    FAILED = "FAILED"
    SKIPPED = "SKIPPED"
    ERROR = "ERROR"


class ValidationResult:
    """Container for validation results."""

    def __init__(self, name: str):
        self.name = name
        self.status = ValidationStatus.PASSED
        self.checks_performed = 0
        self.passed_checks = 0
        self.warnings = []
        self.errors = []
        self.critical_errors = []
        self.info_messages = []
        self.start_time = None
        self.end_time = None
        self.metadata = {}

    def add_check(self, passed: bool, message: str = None):
        """Add a check result."""
        self.checks_performed += 1
        if passed:
            self.passed_checks += 1
        elif message:
            self.errors.append(message)

    def add_warning(self, message: str):
        """Add a warning message."""
        self.warnings.append(message)
        if self.status == ValidationStatus.PASSED:
            self.status = ValidationStatus.PASSED_WITH_WARNINGS

    def add_error(self, message: str, critical: bool = False):
        """Add an error message."""
        if critical:
            self.critical_errors.append(message)
            self.status = ValidationStatus.FAILED
        else:
            self.errors.append(message)
            if self.status in [ValidationStatus.PASSED, ValidationStatus.PASSED_WITH_WARNINGS]:
                self.status = ValidationStatus.FAILED

    def add_info(self, message: str):
        """Add an informational message."""
        self.info_messages.append(message)

    def get_summary(self) -> Dict[str, Any]:
        """Get validation summary."""
        duration = None
        if self.start_time and self.end_time:
            duration = (self.end_time - self.start_time).total_seconds()

        return {
            'name': self.name,
            'status': self.status.value,
            'checks_performed': self.checks_performed,
            'passed_checks': self.passed_checks,
            'failed_checks': self.checks_performed - self.passed_checks,
            'warnings_count': len(self.warnings),
            'errors_count': len(self.errors),
            'critical_errors_count': len(self.critical_errors),
            'duration_seconds': duration,
            'timestamp': datetime.now().isoformat()
        }

    def generate_report(self) -> str:
        """Generate a formatted validation report."""
        lines = []
        lines.append(f"Validation Report - {self.name}")
        lines.append("=" * 60)
        lines.append(f"Status: {self.status.value}")
        lines.append(f"Checks Performed: {self.checks_performed}")
        lines.append(f"Passed: {self.passed_checks}")
        lines.append(f"Failed: {self.checks_performed - self.passed_checks}")

        if self.critical_errors:
            lines.append("\nCritical Errors:")
            for error in self.critical_errors:
                lines.append(f"  ✗ {error}")

        if self.errors:
            lines.append("\nErrors:")
            for error in self.errors:
                lines.append(f"  ✗ {error}")

        if self.warnings:
            lines.append("\nWarnings:")
            for warning in self.warnings:
                lines.append(f"  ⚠ {warning}")

        if self.info_messages:
            lines.append("\nInformation:")
            for info in self.info_messages:
                lines.append(f"  ℹ {info}")

        if self.metadata:
            lines.append("\nMetadata:")
            for key, value in self.metadata.items():
                lines.append(f"  {key}: {value}")

        return "\n".join(lines)


class MergerValidator:
    """Main validator class for the merger tool."""

    # Expected field mappings between Zabbix and Topdesk
    FIELD_MAPPINGS = {
        'host': 'asset_id',
        'name': 'hostname',
        'ip': 'ip_address',
        'serialno_a': 'serial_number',
        'tag': 'department',
        'location': 'location',
        'model': 'model',
        'vendor': 'manufacturer',
        'status': 'status',
        'notes': 'notes'
    }

    # Required fields for assets
    REQUIRED_ASSET_FIELDS = {'asset_id'}

    # Optional but expected fields
    EXPECTED_ASSET_FIELDS = {
        'asset_id', 'hostname', 'ip_address', 'serial_number',
        'model', 'manufacturer', 'location', 'department',
        'status', 'notes', 'last_updated'
    }

    # Valid operations in .dif files
    VALID_DIF_OPERATIONS = {'add', 'modify', 'delete', 'create'}

    # Valid status values for .apl files
    VALID_APL_STATUS = {'applied', 'failed', 'skipped', 'pending'}

    def __init__(self, config_path: Optional[str] = None):
        """
        Initialize the validator.

        Args:
            config_path: Path to configuration file
        """
        self.logger = logging.getLogger(__name__)
        self.config = self._load_config(config_path) if config_path else {}
        self.validation_history = []
        self.cache_checksums = {}

    def _load_config(self, config_path: str) -> Dict[str, Any]:
        """Load configuration from file."""
        try:
            with open(config_path, 'r') as f:
                return json.load(f)
        except Exception as e:
            self.logger.warning(f"Could not load config: {e}")
            return {}

    def validate_dif_file(self, filepath: str) -> ValidationResult:
        """
        Validate a .dif file structure and content.

        Args:
            filepath: Path to .dif file

        Returns:
            ValidationResult object
        """
        result = ValidationResult(f"DIF File: {Path(filepath).name}")
        result.start_time = datetime.now()

        try:
            # Check file exists
            if not Path(filepath).exists():
                result.add_error(f"File not found: {filepath}", critical=True)
                return result

            # Load and parse JSON
            with open(filepath, 'r') as f:
                data = json.load(f)

            result.add_check(True, "JSON structure valid")

            # Check structure
            if isinstance(data, dict):
                if 'entries' in data:
                    entries = data['entries']
                    result.add_info(f"Found {len(entries)} entries")
                    self._validate_dif_entries(entries, result)
                elif 'assets' in data:
                    assets = data['assets']
                    result.add_info(f"Found {len(assets)} assets")
                    self._validate_assets(assets, result)
                else:
                    result.add_error("Unknown DIF structure: missing 'entries' or 'assets'")
            elif isinstance(data, list):
                result.add_info(f"Found {len(data)} items")
                self._validate_dif_entries(data, result)
            else:
                result.add_error("Invalid DIF structure: expected dict or list")

        except json.JSONDecodeError as e:
            result.add_error(f"Invalid JSON: {e}", critical=True)
        except Exception as e:
            result.add_error(f"Validation error: {e}", critical=True)
        finally:
            result.end_time = datetime.now()

        self.validation_history.append(result)
        return result

    def _validate_dif_entries(self, entries: List[Dict], result: ValidationResult):
        """Validate DIF entries."""
        asset_operations = defaultdict(list)

        for i, entry in enumerate(entries):
            # Check required fields
            if 'asset_id' not in entry:
                result.add_error(f"Entry {i}: Missing asset_id")
                continue

            asset_id = entry['asset_id']

            # Check operation
            if 'operation' in entry:
                op = entry['operation']
                if op not in self.VALID_DIF_OPERATIONS:
                    result.add_error(f"Entry {i}: Invalid operation '{op}'")
                asset_operations[asset_id].append(op)

            # Check field modifications
            if 'field' in entry and 'operation' in entry:
                field = entry['field']
                if entry['operation'] == 'modify':
                    if 'old_value' not in entry or 'new_value' not in entry:
                        result.add_warning(f"Entry {i}: Modify operation missing old/new values")

            # Check for data integrity
            if 'value' in entry:
                value = entry['value']
                if value is None:
                    result.add_warning(f"Entry {i}: Null value for {entry.get('field', 'unknown field')}")

        # Check for conflicting operations
        for asset_id, ops in asset_operations.items():
            if 'delete' in ops and len(ops) > 1:
                result.add_warning(f"Asset {asset_id}: Delete operation with other operations")
            if ops.count('create') > 1:
                result.add_error(f"Asset {asset_id}: Multiple create operations")

        result.add_check(len(result.errors) == 0, "DIF entries validation")

    def validate_apl_file(self, filepath: str) -> ValidationResult:
        """
        Validate an .apl file structure.

        Args:
            filepath: Path to .apl file

        Returns:
            ValidationResult object
        """
        result = ValidationResult(f"APL File: {Path(filepath).name}")
        result.start_time = datetime.now()

        try:
            # Check file exists
            if not Path(filepath).exists():
                result.add_error(f"File not found: {filepath}", critical=True)
                return result

            # Load and parse JSON
            with open(filepath, 'r') as f:
                data = json.load(f)

            result.add_check(True, "JSON structure valid")

            # Check structure
            if isinstance(data, dict):
                if 'entries' in data:
                    entries = data['entries']
                    result.add_info(f"Found {len(entries)} entries")
                    self._validate_apl_entries(entries, result)

                # Check metadata
                if 'timestamp' in data:
                    self._validate_timestamp(data['timestamp'], result)
                if 'user' in data:
                    result.add_info(f"Applied by user: {data['user']}")
                if 'summary' in data:
                    stats = data['summary']
                    result.metadata['applied'] = stats.get('applied', 0)
                    result.metadata['failed'] = stats.get('failed', 0)
                    result.metadata['skipped'] = stats.get('skipped', 0)
            elif isinstance(data, list):
                result.add_info(f"Found {len(data)} items")
                self._validate_apl_entries(data, result)
            else:
                result.add_error("Invalid APL structure: expected dict or list")

        except json.JSONDecodeError as e:
            result.add_error(f"Invalid JSON: {e}", critical=True)
        except Exception as e:
            result.add_error(f"Validation error: {e}", critical=True)
        finally:
            result.end_time = datetime.now()

        self.validation_history.append(result)
        return result

    def _validate_apl_entries(self, entries: List[Dict], result: ValidationResult):
        """Validate APL entries."""
        seen_sequences = set()

        for i, entry in enumerate(entries):
            # Check required fields
            if 'asset_id' not in entry:
                result.add_error(f"Entry {i}: Missing asset_id")
                continue

            # Check status
            if 'status' in entry:
                status = entry['status']
                if status not in self.VALID_APL_STATUS:
                    result.add_error(f"Entry {i}: Invalid status '{status}'")
                if status == 'failed' and 'error' not in entry:
                    result.add_warning(f"Entry {i}: Failed status without error message")

            # Check sequence numbers
            if 'sequence' in entry:
                seq = entry['sequence']
                if seq in seen_sequences:
                    result.add_error(f"Entry {i}: Duplicate sequence number {seq}")
                seen_sequences.add(seq)

            # Check timestamp
            if 'timestamp' in entry:
                self._validate_timestamp(entry['timestamp'], result, f"Entry {i}")

            # Check command structure
            if 'command' in entry:
                cmd = entry['command']
                if not isinstance(cmd, str) or not cmd.strip():
                    result.add_error(f"Entry {i}: Invalid command")

        result.add_check(len(result.errors) == 0, "APL entries validation")

    def _validate_timestamp(self, timestamp: str, result: ValidationResult, context: str = ""):
        """Validate timestamp format."""
        try:
            datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
            result.add_check(True, f"{context} timestamp valid" if context else "Timestamp valid")
        except ValueError:
            result.add_error(f"{context} Invalid timestamp format: {timestamp}" if context
                           else f"Invalid timestamp format: {timestamp}")

    def validate_assets(self, assets: List[Dict]) -> ValidationResult:
        """
        Validate a list of assets.

        Args:
            assets: List of asset dictionaries

        Returns:
            ValidationResult object
        """
        result = ValidationResult("Assets Validation")
        result.start_time = datetime.now()

        try:
            self._validate_assets(assets, result)
        except Exception as e:
            result.add_error(f"Validation error: {e}", critical=True)
        finally:
            result.end_time = datetime.now()

        self.validation_history.append(result)
        return result

    def _validate_assets(self, assets: List[Dict], result: ValidationResult):
        """Internal method to validate assets."""
        seen_ids = set()
        duplicate_ids = set()

        for i, asset in enumerate(assets):
            # Check for required fields
            for field in self.REQUIRED_ASSET_FIELDS:
                if field not in asset or asset[field] is None:
                    result.add_error(f"Asset {i}: Missing required field '{field}'")

            # Check for duplicate IDs
            if 'asset_id' in asset:
                asset_id = asset['asset_id']
                if asset_id in seen_ids:
                    duplicate_ids.add(asset_id)
                    result.add_error(f"Duplicate asset_id: {asset_id}")
                seen_ids.add(asset_id)

            # Validate data types
            self._validate_asset_fields(asset, result, i)

            # Check for unexpected fields
            unexpected = set(asset.keys()) - self.EXPECTED_ASSET_FIELDS
            if unexpected and len(unexpected) <= 3:
                result.add_info(f"Asset {i}: Unexpected fields: {unexpected}")

        # Summary statistics
        result.metadata['total_assets'] = len(assets)
        result.metadata['unique_ids'] = len(seen_ids)
        result.metadata['duplicates'] = len(duplicate_ids)

        if duplicate_ids:
            result.add_error(f"Found {len(duplicate_ids)} duplicate asset IDs")

        result.add_check(len(duplicate_ids) == 0, "Asset ID uniqueness")

    def _validate_asset_fields(self, asset: Dict, result: ValidationResult, index: int):
        """Validate individual asset field types and values."""
        # IP address validation
        if 'ip_address' in asset and asset['ip_address']:
            ip = asset['ip_address']
            if not self._is_valid_ip(ip):
                result.add_warning(f"Asset {index}: Invalid IP address format: {ip}")

        # Serial number validation
        if 'serial_number' in asset and asset['serial_number']:
            serial = asset['serial_number']
            if len(serial) > 100:
                result.add_warning(f"Asset {index}: Unusually long serial number")

        # Status validation
        if 'status' in asset and asset['status']:
            status = asset['status'].lower()
            valid_statuses = {'active', 'inactive', 'maintenance', 'retired', 'unknown'}
            if status not in valid_statuses:
                result.add_warning(f"Asset {index}: Unusual status value: {asset['status']}")

    def _is_valid_ip(self, ip: str) -> bool:
        """Check if string is a valid IP address."""
        # Simple IPv4 validation
        parts = ip.split('.')
        if len(parts) != 4:
            return False
        try:
            return all(0 <= int(part) <= 255 for part in parts)
        except ValueError:
            return False

    def validate_data_sync(self,
                          source_data: List[Dict],
                          target_data: List[Dict],
                          field_mappings: Optional[Dict] = None) -> ValidationResult:
        """
        Validate data synchronization between source and target.

        Args:
            source_data: Source data (e.g., from Zabbix)
            target_data: Target data (e.g., from Topdesk)
            field_mappings: Optional field mapping dictionary

        Returns:
            ValidationResult object
        """
        result = ValidationResult("Data Sync Validation")
        result.start_time = datetime.now()

        try:
            mappings = field_mappings or self.FIELD_MAPPINGS

            # Build lookup dictionaries
            source_by_id = {}
            for item in source_data:
                asset_id = self._get_mapped_value(item, 'asset_id', mappings)
                if asset_id:
                    source_by_id[asset_id] = item

            target_by_id = {}
            for item in target_data:
                asset_id = item.get('asset_id')
                if asset_id:
                    target_by_id[asset_id] = item

            # Check for missing assets
            missing_in_target = set(source_by_id.keys()) - set(target_by_id.keys())
            missing_in_source = set(target_by_id.keys()) - set(source_by_id.keys())

            if missing_in_target:
                result.add_warning(f"{len(missing_in_target)} assets in source not found in target")
                result.metadata['missing_in_target'] = list(missing_in_target)[:10]

            if missing_in_source:
                result.add_info(f"{len(missing_in_source)} assets in target not found in source")

            # Check field synchronization
            sync_errors = 0
            for asset_id in source_by_id.keys() & target_by_id.keys():
                source_asset = source_by_id[asset_id]
                target_asset = target_by_id[asset_id]

                for source_field, target_field in mappings.items():
                    source_value = source_asset.get(source_field)
                    target_value = target_asset.get(target_field)

                    if source_value and target_value:
                        if str(source_value).strip() != str(target_value).strip():
                            sync_errors += 1
                            if sync_errors <= 5:  # Limit detailed error reporting
                                result.add_warning(
                                    f"Asset {asset_id}: Field mismatch {target_field}: "
                                    f"'{source_value}' != '{target_value}'"
                                )

            result.metadata['sync_errors'] = sync_errors
            result.metadata['assets_compared'] = len(source_by_id.keys() & target_by_id.keys())

            result.add_check(sync_errors == 0, f"Field synchronization ({sync_errors} mismatches)")

        except Exception as e:
            result.add_error(f"Sync validation error: {e}", critical=True)
        finally:
            result.end_time = datetime.now()

        self.validation_history.append(result)
        return result

    def _get_mapped_value(self, data: Dict, target_field: str, mappings: Dict) -> Any:
        """Get value from data using field mapping."""
        # Reverse lookup in mappings
        for source_field, mapped_field in mappings.items():
            if mapped_field == target_field:
                return data.get(source_field)
        return data.get(target_field)

    def validate_cache_integrity(self, cache_dir: str) -> ValidationResult:
        """
        Validate integrity of cached data files.

        Args:
            cache_dir: Directory containing cache files

        Returns:
            ValidationResult object
        """
        result = ValidationResult("Cache Integrity Validation")
        result.start_time = datetime.now()

        try:
            cache_path = Path(cache_dir)
            if not cache_path.exists():
                result.add_error(f"Cache directory not found: {cache_dir}", critical=True)
                return result

            cache_files = list(cache_path.glob('*.json')) + list(cache_path.glob('*.cache'))
            result.add_info(f"Found {len(cache_files)} cache files")

            for cache_file in cache_files:
                # Check file readability
                try:
                    with open(cache_file, 'r') as f:
                        data = json.load(f)
                    result.add_check(True, f"Cache file readable: {cache_file.name}")

                    # Check structure
                    if isinstance(data, dict):
                        if 'timestamp' in data:
                            self._validate_timestamp(data['timestamp'], result, cache_file.name)
                        if 'checksum' in data:
                            # Verify checksum
                            self._verify_checksum(cache_file, data.get('checksum'), result)

                except json.JSONDecodeError:
                    result.add_error(f"Corrupted cache file: {cache_file.name}")
                except Exception as e:
                    result.add_error(f"Cannot read cache file {cache_file.name}: {e}")

            # Check cache age
            self._check_cache_age(cache_files, result)

        except Exception as e:
            result.add_error(f"Cache validation error: {e}", critical=True)
        finally:
            result.end_time = datetime.now()

        self.validation_history.append(result)
        return result

    def _verify_checksum(self, filepath: Path, expected_checksum: str, result: ValidationResult):
        """Verify file checksum."""
        try:
            with open(filepath, 'rb') as f:
                content = f.read()
            actual_checksum = hashlib.sha256(content).hexdigest()

            if actual_checksum != expected_checksum:
                result.add_error(f"Checksum mismatch for {filepath.name}")
            else:
                result.add_check(True, f"Checksum valid for {filepath.name}")
        except Exception as e:
            result.add_error(f"Checksum verification failed for {filepath.name}: {e}")

    def _check_cache_age(self, cache_files: List[Path], result: ValidationResult):
        """Check age of cache files."""
        current_time = time.time()
        old_files = []

        for cache_file in cache_files:
            file_age = current_time - cache_file.stat().st_mtime
            if file_age > 86400:  # 24 hours
                old_files.append(cache_file.name)

        if old_files:
            result.add_warning(f"{len(old_files)} cache files older than 24 hours")
            result.metadata['old_cache_files'] = old_files[:5]

    def validate_pre_execution(self, config: Optional[Dict[str, Any]] = None) -> ValidationResult:
        """
        Comprehensive pre-execution validation.

        Validates:
        - Tool availability (zbx, topdesk)
        - Tool executability and versions
        - Configuration files and authentication
        - Required permissions
        - API connectivity

        Args:
            config: Optional configuration dictionary

        Returns:
            ValidationResult object
        """
        result = ValidationResult("Pre-Execution Validation")
        result.start_time = datetime.now()

        try:
            # Phase 1: Check tool availability and versions
            result.add_info("Phase 1: Checking tool availability...")
            self._validate_tools(result)

            # Phase 2: Check configuration files and authentication
            result.add_info("\nPhase 2: Checking configuration and authentication...")
            self._validate_configuration(result, config)

            # Phase 3: Check permissions
            result.add_info("\nPhase 3: Checking permissions...")
            self._validate_permissions(result, config)

            # Phase 4: Test API connections
            result.add_info("\nPhase 4: Testing API connections...")
            self._test_connections(result)

        except Exception as e:
            result.add_error(f"Pre-execution validation error: {e}", critical=True)
        finally:
            result.end_time = datetime.now()

        self.validation_history.append(result)
        return result

    def _validate_tools(self, result: ValidationResult):
        """
        Validate tool availability and versions.

        Args:
            result: ValidationResult to update
        """
        tools = [
            {
                'name': 'zbx',
                'display_name': 'zbx command',
                'version_cmd': ['zbx', '--version'],
                'install_hint': 'Make sure zbx command is in your PATH'
            },
            {
                'name': 'topdesk',
                'display_name': 'topdesk command',
                'version_cmd': ['topdesk', '--version'],
                'install_hint': 'Make sure topdesk command is in your PATH'
            }
        ]

        for tool in tools:
            tool_path = shutil.which(tool['name'])

            if not tool_path:
                result.add_error(
                    f"{tool['display_name']} not found in PATH. {tool['install_hint']}",
                    critical=True
                )
                continue

            result.add_check(True, f"{tool['display_name']} found at: {tool_path}")

            # Check if executable
            if not os.access(tool_path, os.X_OK):
                result.add_error(
                    f"{tool['display_name']} is not executable at: {tool_path}",
                    critical=True
                )
                continue

            # Try to get version
            try:
                version_result = subprocess.run(
                    tool['version_cmd'],
                    capture_output=True,
                    text=True,
                    timeout=5
                )

                if version_result.returncode == 0:
                    version_output = version_result.stdout.strip() or version_result.stderr.strip()
                    if version_output:
                        # Extract version number if possible
                        version_lines = version_output.split('\n')
                        version_info = version_lines[0] if version_lines else version_output
                        result.add_info(f"{tool['display_name']} version: {version_info}")
                else:
                    result.add_warning(
                        f"Could not determine {tool['display_name']} version (command may not support --version)"
                    )

            except subprocess.TimeoutExpired:
                result.add_warning(f"{tool['display_name']} version check timed out")
            except Exception as e:
                result.add_warning(f"Could not check {tool['display_name']} version: {e}")

    def _validate_configuration(self, result: ValidationResult, config: Optional[Dict[str, Any]]):
        """
        Validate configuration files and authentication.

        Args:
            result: ValidationResult to update
            config: Optional configuration dictionary
        """
        # Check Zabbix configuration
        zabbix_configs = [
            Path.home() / '.zabbix' / 'config.yaml',
            Path.home() / '.zabbix' / 'config.yml',
            Path.home() / '.config' / 'zabbix-cli' / 'config.yaml'
        ]

        zabbix_config_found = False
        for config_path in zabbix_configs:
            if config_path.exists():
                result.add_check(True, f"Zabbix config found: {config_path}")
                zabbix_config_found = True

                # Try to validate config structure
                try:
                    with open(config_path, 'r') as f:
                        import yaml
                        zabbix_data = yaml.safe_load(f)

                        if isinstance(zabbix_data, dict):
                            # Check for required fields
                            if 'url' in zabbix_data or 'server' in zabbix_data:
                                result.add_check(True, "Zabbix config has server URL")
                            else:
                                result.add_warning("Zabbix config missing server URL")

                            if 'username' in zabbix_data or 'user' in zabbix_data:
                                result.add_check(True, "Zabbix config has username")
                            else:
                                result.add_warning("Zabbix config missing username")

                except ImportError:
                    result.add_info("PyYAML not installed, skipping YAML validation")
                except Exception as e:
                    result.add_warning(f"Could not parse Zabbix config: {e}")
                break

        # Check environment variables for Zabbix
        zabbix_env_vars = {
            'ZABBIX_URL': os.environ.get('ZABBIX_URL'),
            'ZABBIX_USERNAME': os.environ.get('ZABBIX_USERNAME'),
            'ZABBIX_PASSWORD': os.environ.get('ZABBIX_PASSWORD'),
            'ZABBIX_TOKEN': os.environ.get('ZABBIX_TOKEN')
        }

        zabbix_env_configured = any(zabbix_env_vars.values())

        if not zabbix_config_found and not zabbix_env_configured:
            result.add_error(
                "No Zabbix configuration found. Please configure zbx or set environment variables.",
                critical=True
            )
        elif zabbix_env_configured:
            configured_vars = [k for k, v in zabbix_env_vars.items() if v]
            result.add_info(f"Zabbix environment variables set: {', '.join(configured_vars)}")

        # Check Topdesk configuration
        topdesk_env_vars = {
            'TOPDESK_URL': os.environ.get('TOPDESK_URL'),
            'TOPDESK_USERNAME': os.environ.get('TOPDESK_USERNAME'),
            'TOPDESK_PASSWORD': os.environ.get('TOPDESK_PASSWORD'),
            'TOPDESK_API_KEY': os.environ.get('TOPDESK_API_KEY'),
            'TOPDESK_TOKEN': os.environ.get('TOPDESK_TOKEN')
        }

        topdesk_env_configured = any(topdesk_env_vars.values())

        # Check for Topdesk config file
        topdesk_configs = [
            Path.home() / '.topdesk' / 'config.yaml',
            Path.home() / '.topdesk' / 'config.yml',
            Path.home() / '.config' / 'topdesk' / 'config.yaml'
        ]

        topdesk_config_found = False
        for config_path in topdesk_configs:
            if config_path.exists():
                result.add_check(True, f"Topdesk config found: {config_path}")
                topdesk_config_found = True
                break

        if not topdesk_config_found and not topdesk_env_configured:
            result.add_error(
                "No Topdesk configuration found. Please configure topdesk or set environment variables.",
                critical=True
            )
        elif topdesk_env_configured:
            configured_vars = [k for k, v in topdesk_env_vars.items() if v]
            result.add_info(f"Topdesk environment variables set: {', '.join(configured_vars)}")

    def _validate_permissions(self, result: ValidationResult, config: Optional[Dict[str, Any]]):
        """
        Validate required permissions.

        Args:
            result: ValidationResult to update
            config: Optional configuration dictionary
        """
        # Default directories to check
        directories_to_check = [
            Path.cwd(),  # Current working directory
            Path('./output'),  # Default output directory
            Path('./cache'),  # Default cache directory
            Path('/tmp')  # Temp directory for processing
        ]

        # Add directories from config if provided
        if config:
            if 'output_dir' in config:
                directories_to_check.append(Path(config['output_dir']))
            if 'cache_dir' in config:
                directories_to_check.append(Path(config['cache_dir']))

        for directory in directories_to_check:
            if not directory.exists():
                # Try to create it
                try:
                    directory.mkdir(parents=True, exist_ok=True)
                    result.add_check(True, f"Created directory: {directory}")
                except PermissionError:
                    result.add_error(f"Cannot create directory: {directory}", critical=True)
                except Exception as e:
                    result.add_warning(f"Error creating directory {directory}: {e}")

            # Check write permissions
            if directory.exists():
                test_file = directory / '.write_test'
                try:
                    test_file.touch()
                    test_file.unlink()
                    result.add_check(True, f"Write permission verified: {directory}")
                except PermissionError:
                    result.add_error(
                        f"No write permission for directory: {directory}",
                        critical=True if directory == Path.cwd() else False
                    )
                except Exception as e:
                    result.add_warning(f"Cannot verify write permission for {directory}: {e}")

    def _test_connections(self, result: ValidationResult):
        """
        Test API connections to Zabbix and Topdesk.

        Args:
            result: ValidationResult to update
        """
        # Test Zabbix connection
        result.add_info("Testing Zabbix connection...")
        try:
            zbx_result = subprocess.run(
                ['zbx', 'host', 'list', '--limit', '1'],
                capture_output=True,
                text=True,
                timeout=10
            )

            if zbx_result.returncode == 0:
                result.add_check(True, "Zabbix connection successful")
                # Try to parse output to get server info
                if zbx_result.stdout:
                    lines = zbx_result.stdout.strip().split('\n')
                    if lines:
                        result.add_info(f"Zabbix server responding (retrieved {len(lines)} host entries)")
            else:
                error_msg = zbx_result.stderr.strip() if zbx_result.stderr else "Unknown error"

                # Provide specific error guidance
                if 'authentication' in error_msg.lower() or 'unauthorized' in error_msg.lower():
                    result.add_error(
                        f"Zabbix authentication failed. Please check credentials. Error: {error_msg}",
                        critical=True
                    )
                elif 'connection' in error_msg.lower() or 'timeout' in error_msg.lower():
                    result.add_error(
                        f"Cannot connect to Zabbix server. Please check URL and network. Error: {error_msg}",
                        critical=True
                    )
                elif 'config' in error_msg.lower():
                    result.add_error(
                        f"Zabbix configuration error. Please run 'zbx init' to configure. Error: {error_msg}",
                        critical=True
                    )
                else:
                    result.add_error(f"Zabbix connection test failed: {error_msg}", critical=True)

        except subprocess.TimeoutExpired:
            result.add_error(
                "Zabbix connection timed out. Server may be unreachable.",
                critical=True
            )
        except FileNotFoundError:
            result.add_error(
                "zbx command not found. Please ensure it's installed and in PATH.",
                critical=True
            )
        except Exception as e:
            result.add_error(f"Zabbix connection test error: {e}", critical=True)

        # Test Topdesk connection
        result.add_info("Testing Topdesk connection...")
        try:
            topdesk_result = subprocess.run(
                ['topdesk', 'asset', 'list', '--limit', '1'],
                capture_output=True,
                text=True,
                timeout=10
            )

            if topdesk_result.returncode == 0:
                result.add_check(True, "Topdesk connection successful")
                # Try to parse output to get server info
                if topdesk_result.stdout:
                    lines = topdesk_result.stdout.strip().split('\n')
                    if lines:
                        result.add_info(f"Topdesk server responding (retrieved {len(lines)} asset entries)")
            else:
                error_msg = topdesk_result.stderr.strip() if topdesk_result.stderr else "Unknown error"

                # Provide specific error guidance
                if 'authentication' in error_msg.lower() or 'unauthorized' in error_msg.lower():
                    result.add_error(
                        f"Topdesk authentication failed. Please check API key or credentials. Error: {error_msg}",
                        critical=True
                    )
                elif 'connection' in error_msg.lower() or 'timeout' in error_msg.lower():
                    result.add_error(
                        f"Cannot connect to Topdesk server. Please check URL and network. Error: {error_msg}",
                        critical=True
                    )
                elif 'config' in error_msg.lower():
                    result.add_error(
                        f"Topdesk configuration error. Please configure authentication. Error: {error_msg}",
                        critical=True
                    )
                else:
                    result.add_error(f"Topdesk connection test failed: {error_msg}", critical=True)

        except subprocess.TimeoutExpired:
            result.add_error(
                "Topdesk connection timed out. Server may be unreachable.",
                critical=True
            )
        except FileNotFoundError:
            result.add_error(
                "topdesk command not found. Please ensure it's installed and in PATH.",
                critical=True
            )
        except Exception as e:
            result.add_error(f"Topdesk connection test error: {e}", critical=True)

    def _check_tool_availability(self, tool: str) -> bool:
        """Check if a tool is available in PATH."""
        import shutil
        return shutil.which(tool) is not None

    def _check_write_permission(self, directory: str) -> bool:
        """Check write permission for directory."""
        try:
            path = Path(directory)
            if not path.exists():
                path.mkdir(parents=True, exist_ok=True)
            test_file = path / '.test_write'
            test_file.touch()
            test_file.unlink()
            return True
        except Exception:
            return False

    def _check_connectivity(self, url: str) -> bool:
        """Check network connectivity to URL."""
        try:
            import urllib.request
            import urllib.parse

            parsed = urllib.parse.urlparse(url)
            host = parsed.netloc or parsed.path

            # Simple connectivity check
            import socket
            socket.gethostbyname(host.split(':')[0])
            return True
        except Exception:
            return False

    def generate_validation_report(self, output_file: Optional[str] = None) -> str:
        """
        Generate comprehensive validation report.

        Args:
            output_file: Optional output file path

        Returns:
            Report as string
        """
        lines = []
        lines.append("=" * 80)
        lines.append("COMPREHENSIVE VALIDATION REPORT")
        lines.append("=" * 80)
        lines.append(f"Generated: {datetime.now().isoformat()}")
        lines.append(f"Total Validations: {len(self.validation_history)}")
        lines.append("")

        # Summary statistics
        passed = sum(1 for v in self.validation_history if v.status == ValidationStatus.PASSED)
        passed_with_warnings = sum(1 for v in self.validation_history
                                  if v.status == ValidationStatus.PASSED_WITH_WARNINGS)
        failed = sum(1 for v in self.validation_history if v.status == ValidationStatus.FAILED)

        lines.append("Summary:")
        lines.append(f"  Passed: {passed}")
        lines.append(f"  Passed with Warnings: {passed_with_warnings}")
        lines.append(f"  Failed: {failed}")
        lines.append("")

        # Individual validation reports
        for validation in self.validation_history:
            lines.append("-" * 60)
            lines.append(validation.generate_report())
            lines.append("")

        # Recommendations
        lines.append("-" * 60)
        lines.append("Recommendations:")
        recommendations = self._generate_recommendations()
        for rec in recommendations:
            lines.append(f"  • {rec}")

        report = "\n".join(lines)

        if output_file:
            with open(output_file, 'w') as f:
                f.write(report)
            self.logger.info(f"Validation report written to: {output_file}")

        return report

    def _generate_recommendations(self) -> List[str]:
        """Generate recommendations based on validation results."""
        recommendations = []

        total_warnings = sum(len(v.warnings) for v in self.validation_history)
        total_errors = sum(len(v.errors) for v in self.validation_history)

        if total_errors > 0:
            recommendations.append("Address critical errors before proceeding with sync")

        if total_warnings > 10:
            recommendations.append("Review warnings to improve data quality")

        # Check for specific patterns
        for validation in self.validation_history:
            if 'sync_errors' in validation.metadata:
                if validation.metadata['sync_errors'] > 0:
                    recommendations.append("Investigate field mapping discrepancies")

            if 'duplicates' in validation.metadata:
                if validation.metadata['duplicates'] > 0:
                    recommendations.append("Resolve duplicate asset IDs before sync")

        if not recommendations:
            recommendations.append("All validations passed successfully")

        return recommendations


def main():
    """Command-line interface for the validator."""
    import argparse

    parser = argparse.ArgumentParser(description='Validate merger tool files and operations')
    parser.add_argument('--pre-check', action='store_true',
                       help='Run pre-execution validation checks')
    parser.add_argument('--dif', help='Validate a .dif file')
    parser.add_argument('--apl', help='Validate an .apl file')
    parser.add_argument('--cache-dir', help='Validate cache directory')
    parser.add_argument('--config', help='Configuration file path')
    parser.add_argument('--report', help='Generate validation report')
    parser.add_argument('--output', help='Output file for report')
    parser.add_argument('--verbose', action='store_true', help='Verbose output')
    parser.add_argument('--quick', action='store_true',
                       help='Quick validation (skip connection tests)')

    args = parser.parse_args()

    # Setup logging
    log_level = logging.DEBUG if args.verbose else logging.INFO
    logging.basicConfig(level=log_level, format='%(asctime)s - %(levelname)s - %(message)s')

    # Create validator
    validator = MergerValidator(config_path=args.config)

    # Load config if provided
    config = {}
    if args.config:
        try:
            with open(args.config, 'r') as f:
                config = json.load(f)
        except Exception as e:
            print(f"Warning: Could not load config file: {e}")

    # Run pre-execution checks if requested or if no other action specified
    if args.pre_check or (not args.dif and not args.apl and not args.cache_dir
                         and not args.report and not args.output):
        result = validator.validate_pre_execution(config)
        print(result.generate_report())

        # Exit with error code if critical errors found
        if result.critical_errors:
            sys.exit(1)

    # Perform other validations
    if args.dif:
        result = validator.validate_dif_file(args.dif)
        print(result.generate_report())

    if args.apl:
        result = validator.validate_apl_file(args.apl)
        print(result.generate_report())

    if args.cache_dir:
        result = validator.validate_cache_integrity(args.cache_dir)
        print(result.generate_report())

    if args.report or args.output:
        report = validator.generate_validation_report(output_file=args.output)
        if not args.output:
            print(report)


if __name__ == '__main__':
    main()