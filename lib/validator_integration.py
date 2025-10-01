#!/usr/bin/env python3
"""
Integration module showing how the validator fits into the merger workflow.
"""

import json
import logging
from pathlib import Path
from typing import Dict, Any, List, Optional
from datetime import datetime

from validator import MergerValidator, ValidationStatus


class ValidatorIntegration:
    """
    Integration class for using the validator in the merger workflow.
    """

    def __init__(self, output_dir: str = './output', config: Optional[Dict] = None):
        """
        Initialize the validator integration.

        Args:
            output_dir: Output directory for validation reports
            config: Optional configuration dictionary
        """
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)

        self.reports_dir = self.output_dir / 'reports'
        self.reports_dir.mkdir(exist_ok=True)

        self.validator = MergerValidator(config_path=config.get('validator_config') if config else None)
        self.logger = logging.getLogger(__name__)
        self.config = config or {}

    def validate_retrieval_phase(self,
                                zabbix_data: List[Dict],
                                topdesk_data: List[Dict]) -> bool:
        """
        Validate data retrieval phase.

        Args:
            zabbix_data: Retrieved Zabbix assets
            topdesk_data: Retrieved Topdesk assets

        Returns:
            True if validation passes, False otherwise
        """
        self.logger.info("Validating data retrieval phase...")

        # Validate Zabbix data
        zabbix_result = self.validator.validate_assets(zabbix_data)
        self._save_validation_result(zabbix_result, "retrieval_zabbix")

        # Validate Topdesk data
        topdesk_result = self.validator.validate_assets(topdesk_data)
        self._save_validation_result(topdesk_result, "retrieval_topdesk")

        # Check if both validations passed
        if zabbix_result.status == ValidationStatus.FAILED:
            self.logger.error("Zabbix data validation failed")
            return False

        if topdesk_result.status == ValidationStatus.FAILED:
            self.logger.error("Topdesk data validation failed")
            return False

        # Log summary
        self.logger.info(f"✓ Zabbix assets validated: {len(zabbix_data)}")
        self.logger.info(f"✓ Topdesk assets validated: {len(topdesk_data)}")

        if zabbix_result.warnings or topdesk_result.warnings:
            self.logger.warning("Validation passed with warnings - review before proceeding")

        return True

    def validate_comparison_phase(self, dif_files: List[str]) -> bool:
        """
        Validate comparison phase outputs.

        Args:
            dif_files: List of generated .dif file paths

        Returns:
            True if all validations pass, False otherwise
        """
        self.logger.info(f"Validating {len(dif_files)} DIF files...")

        all_passed = True
        total_entries = 0

        for dif_file in dif_files:
            result = self.validator.validate_dif_file(dif_file)

            # Save individual validation
            filename = Path(dif_file).stem
            self._save_validation_result(result, f"comparison_{filename}")

            if result.status == ValidationStatus.FAILED:
                self.logger.error(f"DIF validation failed: {dif_file}")
                all_passed = False

            # Count entries
            try:
                with open(dif_file, 'r') as f:
                    data = json.load(f)
                    if isinstance(data, dict) and 'entries' in data:
                        total_entries += len(data['entries'])
                    elif isinstance(data, list):
                        total_entries += len(data)
            except Exception as e:
                self.logger.warning(f"Could not count entries in {dif_file}: {e}")

        self.logger.info(f"✓ Validated {len(dif_files)} DIF files with {total_entries} total entries")

        return all_passed

    def validate_tui_selections(self, apl_file: str) -> bool:
        """
        Validate TUI-generated APL file before application.

        Args:
            apl_file: Path to the APL file

        Returns:
            True if validation passes, False otherwise
        """
        self.logger.info(f"Validating APL file: {apl_file}")

        result = self.validator.validate_apl_file(apl_file)
        self._save_validation_result(result, "tui_selections")

        if result.status == ValidationStatus.FAILED:
            self.logger.error("APL validation failed - do not proceed with application")
            return False

        # Check for high failure rate
        if 'failed' in result.metadata and 'applied' in result.metadata:
            total = result.metadata.get('applied', 0) + result.metadata.get('failed', 0)
            if total > 0:
                failure_rate = result.metadata['failed'] / total
                if failure_rate > 0.1:  # More than 10% failures
                    self.logger.warning(f"High failure rate in APL: {failure_rate:.1%}")

        self.logger.info("✓ APL file validated and ready for application")
        return True

    def validate_application_phase(self,
                                  apl_file: str,
                                  applied_changes: List[Dict]) -> bool:
        """
        Validate that changes were correctly applied.

        Args:
            apl_file: Path to the APL file that was applied
            applied_changes: List of changes that were applied

        Returns:
            True if validation passes, False otherwise
        """
        self.logger.info("Validating application phase...")

        # Load APL file
        try:
            with open(apl_file, 'r') as f:
                apl_data = json.load(f)
        except Exception as e:
            self.logger.error(f"Could not load APL file: {e}")
            return False

        # Check application results
        expected_count = len(apl_data.get('entries', []))
        actual_count = len(applied_changes)

        if actual_count < expected_count:
            self.logger.warning(f"Not all changes applied: {actual_count}/{expected_count}")

        # Analyze failures
        failures = [c for c in applied_changes if c.get('status') == 'failed']
        if failures:
            self.logger.warning(f"Found {len(failures)} failed applications")
            for failure in failures[:5]:  # Show first 5 failures
                self.logger.warning(f"  - Asset {failure.get('asset_id')}: {failure.get('error')}")

        success_rate = (actual_count - len(failures)) / expected_count if expected_count > 0 else 0
        self.logger.info(f"✓ Application phase complete: {success_rate:.1%} success rate")

        return len(failures) == 0

    def validate_sync_completeness(self,
                                  original_zabbix: List[Dict],
                                  original_topdesk: List[Dict],
                                  updated_topdesk: List[Dict]) -> bool:
        """
        Validate that the sync operation achieved its goals.

        Args:
            original_zabbix: Original Zabbix data
            original_topdesk: Original Topdesk data
            updated_topdesk: Updated Topdesk data after sync

        Returns:
            True if sync is complete, False otherwise
        """
        self.logger.info("Validating sync completeness...")

        # Compare original vs updated
        result = self.validator.validate_data_sync(original_zabbix, updated_topdesk)
        self._save_validation_result(result, "sync_completeness")

        if result.status == ValidationStatus.FAILED:
            self.logger.error("Sync validation failed - data not properly synchronized")
            return False

        # Check improvements
        original_sync = self.validator.validate_data_sync(original_zabbix, original_topdesk)

        original_errors = original_sync.metadata.get('sync_errors', 0)
        current_errors = result.metadata.get('sync_errors', 0)

        if current_errors < original_errors:
            improvement = ((original_errors - current_errors) / original_errors * 100
                         if original_errors > 0 else 0)
            self.logger.info(f"✓ Sync improved data consistency by {improvement:.1f}%")
        elif current_errors > original_errors:
            self.logger.warning("Sync degraded data consistency!")
            return False

        self.logger.info("✓ Sync validation complete")
        return True

    def perform_full_validation(self, workflow_data: Dict[str, Any]) -> bool:
        """
        Perform complete validation of the entire workflow.

        Args:
            workflow_data: Dictionary containing all workflow data

        Returns:
            True if all validations pass, False otherwise
        """
        self.logger.info("=" * 60)
        self.logger.info("Starting full workflow validation...")
        self.logger.info("=" * 60)

        all_passed = True

        # Pre-execution validation
        if 'config' in workflow_data:
            pre_result = self.validator.validate_pre_execution(workflow_data['config'])
            self._save_validation_result(pre_result, "pre_execution")
            if pre_result.status == ValidationStatus.FAILED:
                self.logger.error("Pre-execution validation failed - cannot proceed")
                return False

        # Data retrieval validation
        if 'zabbix_data' in workflow_data and 'topdesk_data' in workflow_data:
            if not self.validate_retrieval_phase(
                workflow_data['zabbix_data'],
                workflow_data['topdesk_data']
            ):
                all_passed = False

        # Comparison validation
        if 'dif_files' in workflow_data:
            if not self.validate_comparison_phase(workflow_data['dif_files']):
                all_passed = False

        # TUI validation
        if 'apl_file' in workflow_data:
            if not self.validate_tui_selections(workflow_data['apl_file']):
                all_passed = False

        # Application validation
        if 'apl_file' in workflow_data and 'applied_changes' in workflow_data:
            if not self.validate_application_phase(
                workflow_data['apl_file'],
                workflow_data['applied_changes']
            ):
                all_passed = False

        # Sync completeness validation
        if all(['original_zabbix' in workflow_data,
                'original_topdesk' in workflow_data,
                'updated_topdesk' in workflow_data]):
            if not self.validate_sync_completeness(
                workflow_data['original_zabbix'],
                workflow_data['original_topdesk'],
                workflow_data['updated_topdesk']
            ):
                all_passed = False

        # Generate comprehensive report
        report_file = self.reports_dir / f"validation_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
        report = self.validator.generate_validation_report(str(report_file))

        self.logger.info(f"✓ Validation report saved: {report_file}")
        self.logger.info("=" * 60)

        if all_passed:
            self.logger.info("✅ ALL VALIDATIONS PASSED")
        else:
            self.logger.error("❌ VALIDATION FAILURES DETECTED")

        self.logger.info("=" * 60)

        return all_passed

    def _save_validation_result(self, result: Any, name: str):
        """Save individual validation result to file."""
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = self.reports_dir / f"{name}_{timestamp}.json"

        try:
            with open(filename, 'w') as f:
                json.dump(result.get_summary(), f, indent=2)
            self.logger.debug(f"Saved validation result: {filename}")
        except Exception as e:
            self.logger.warning(f"Could not save validation result: {e}")

    def get_validation_summary(self) -> Dict[str, Any]:
        """
        Get summary of all validations performed.

        Returns:
            Summary dictionary
        """
        history = self.validator.validation_history

        return {
            'total_validations': len(history),
            'passed': sum(1 for v in history if v.status == ValidationStatus.PASSED),
            'passed_with_warnings': sum(1 for v in history
                                       if v.status == ValidationStatus.PASSED_WITH_WARNINGS),
            'failed': sum(1 for v in history if v.status == ValidationStatus.FAILED),
            'total_warnings': sum(len(v.warnings) for v in history),
            'total_errors': sum(len(v.errors) for v in history),
            'timestamp': datetime.now().isoformat()
        }


def main():
    """Example usage of the validator integration."""
    import logging

    # Setup logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )

    # Create integration
    integration = ValidatorIntegration(output_dir='./output')

    # Example workflow data
    workflow_data = {
        'config': {
            'required_tools': ['python3'],
            'zabbix': {
                'url': 'http://zabbix.example.com',
                'username': 'admin',
                'password': 'secret'
            },
            'topdesk': {
                'url': 'http://topdesk.example.com',
                'username': 'admin',
                'password': 'secret'
            }
        },
        'zabbix_data': [
            {'host': 'srv-001', 'ip': '192.168.1.1'},
            {'host': 'srv-002', 'ip': '192.168.1.2'}
        ],
        'topdesk_data': [
            {'asset_id': 'srv-001', 'ip_address': '192.168.1.1'},
            {'asset_id': 'srv-002', 'ip_address': '192.168.1.2'}
        ]
    }

    # Perform validation
    success = integration.perform_full_validation(workflow_data)

    # Get summary
    summary = integration.get_validation_summary()
    print(f"\nValidation Summary: {json.dumps(summary, indent=2)}")

    return success


if __name__ == '__main__':
    success = main()
    exit(0 if success else 1)