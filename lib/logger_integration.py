#!/usr/bin/env python3
"""
Integration examples showing how to use the logger in merger tool agents.
This file demonstrates best practices for integrating the logger.
"""

import time
from typing import Dict, List, Any, Optional
from logger import get_logger, MergerLogger


class DataFetcherAgent:
    """Example integration for DataFetcher agent."""
    
    def __init__(self, logger: MergerLogger):
        self.logger = logger
        self.agent_name = "DATAFETCHER"
    
    def fetch_zabbix_assets(self) -> List[Dict[str, Any]]:
        """Fetch assets from Zabbix with logging."""
        self.logger.info(self.agent_name, "Starting Zabbix asset retrieval")
        start_time = time.time()
        
        try:
            # Simulated Zabbix API call
            self.logger.debug(self.agent_name, "Connecting to Zabbix API",
                            endpoint="https://zabbix.example.com/api")
            
            # ... actual API call here ...
            assets = [{"id": f"asset{i}", "name": f"Asset {i}"} for i in range(150)]
            
            self.logger.log_operation(
                self.agent_name, 
                f"Zabbix retrieval successful",
                start_time=start_time,
                asset_count=len(assets)
            )
            
            return assets
            
        except Exception as e:
            self.logger.error(
                self.agent_name,
                "Zabbix API call failed",
                exception=e,
                endpoint="https://zabbix.example.com/api"
            )
            raise


class DifferAgent:
    """Example integration for Differ agent."""
    
    def __init__(self, logger: MergerLogger):
        self.logger = logger
        self.agent_name = "DIFFER"
    
    def compare_assets(self, zabbix_assets: List, topdesk_assets: List) -> List:
        """Compare assets with detailed logging."""
        self.logger.info(
            self.agent_name,
            "Starting asset comparison",
            zabbix_count=len(zabbix_assets),
            topdesk_count=len(topdesk_assets)
        )
        
        differences = []
        processed = 0
        not_found = 0
        
        for z_asset in zabbix_assets:
            asset_id = z_asset.get('id')
            
            self.logger.trace(
                self.agent_name,
                f"Comparing asset {asset_id}",
                asset_id=asset_id
            )
            
            # Find corresponding Topdesk asset
            t_asset = self._find_topdesk_asset(asset_id, topdesk_assets)
            
            if not t_asset:
                self.logger.warning(
                    self.agent_name,
                    f"Asset not found in Topdesk",
                    asset_id=asset_id
                )
                not_found += 1
                continue
            
            # Compare fields
            asset_diffs = self._compare_fields(z_asset, t_asset)
            if asset_diffs:
                differences.extend(asset_diffs)
                self.logger.debug(
                    self.agent_name,
                    f"Found {len(asset_diffs)} differences in asset",
                    asset_id=asset_id,
                    fields=list(asset_diffs.keys()) if isinstance(asset_diffs, dict) else len(asset_diffs)
                )
            
            processed += 1
        
        self.logger.log_batch_operation(
            self.agent_name,
            "Asset comparison",
            total=len(zabbix_assets),
            processed=processed,
            failed=not_found,
            total_differences=len(differences)
        )
        
        return differences
    
    def _find_topdesk_asset(self, asset_id: str, topdesk_assets: List) -> Optional[Dict]:
        """Helper method to find asset in Topdesk list."""
        # Implementation here
        return None
    
    def _compare_fields(self, z_asset: Dict, t_asset: Dict) -> List:
        """Helper method to compare asset fields."""
        # Implementation here
        return []


class ApplierAgent:
    """Example integration for Applier agent."""
    
    def __init__(self, logger: MergerLogger):
        self.logger = logger
        self.agent_name = "APPLIER"
    
    def apply_changes(self, changes: List[Dict]) -> Dict[str, int]:
        """Apply changes with comprehensive logging."""
        self.logger.info(
            self.agent_name,
            "Starting change application",
            total_changes=len(changes)
        )
        
        results = {"success": 0, "failed": 0, "skipped": 0}
        start_time = time.time()
        
        for change in changes:
            asset_id = change.get('asset_id')
            
            try:
                self.logger.trace(
                    self.agent_name,
                    f"Applying change to asset",
                    asset_id=asset_id,
                    change_type=change.get('type')
                )
                
                # ... actual change application ...
                
                self.logger.info(
                    self.agent_name,
                    f"Successfully updated asset",
                    asset_id=asset_id,
                    fields_modified=change.get('fields', [])
                )
                results["success"] += 1
                
            except PermissionError as e:
                self.logger.error(
                    self.agent_name,
                    f"Permission denied for asset update",
                    exception=e,
                    asset_id=asset_id
                )
                results["failed"] += 1
                
            except Exception as e:
                self.logger.error(
                    self.agent_name,
                    f"Unexpected error updating asset",
                    exception=e,
                    asset_id=asset_id
                )
                results["failed"] += 1
        
        # Log final results
        self.logger.log_operation(
            self.agent_name,
            "Change application completed",
            start_time=start_time,
            **results
        )
        
        if results["failed"] > 0:
            self.logger.warning(
                self.agent_name,
                f"{results['failed']} changes failed to apply",
                **results
            )
        
        return results


class TUIOperatorAgent:
    """Example integration for TUI Operator agent."""
    
    def __init__(self, logger: MergerLogger):
        self.logger = logger
        self.agent_name = "TUIOPERATOR"
        self.session_start = None
    
    def start_session(self, user: str = "unknown"):
        """Start TUI session with logging."""
        self.session_start = time.time()
        self.logger.info(
            self.agent_name,
            "TUI session started",
            user=user,
            timestamp=time.time()
        )
    
    def log_user_action(self, action: str, **context):
        """Log user actions in TUI."""
        self.logger.info(
            self.agent_name,
            f"User action: {action}",
            **context
        )
    
    def log_field_selection(self, field: str, source: str, value: Any):
        """Log field value selection."""
        self.logger.info(
            self.agent_name,
            f"User selected {source} value for field",
            field=field,
            source=source,
            value=value
        )
    
    def end_session(self, changes_made: int = 0):
        """End TUI session with summary."""
        if self.session_start:
            duration = time.time() - self.session_start
            self.logger.log_operation(
                self.agent_name,
                "TUI session completed",
                start_time=self.session_start,
                changes_made=changes_made
            )
        else:
            self.logger.info(
                self.agent_name,
                "TUI session ended",
                changes_made=changes_made
            )


class ValidatorAgent:
    """Example integration for Validator agent."""
    
    def __init__(self, logger: MergerLogger):
        self.logger = logger
        self.agent_name = "VALIDATOR"
    
    def validate_data(self, data: List[Dict]) -> Dict[str, Any]:
        """Validate data with detailed logging."""
        self.logger.info(
            self.agent_name,
            "Starting data validation",
            total_records=len(data)
        )
        
        validation_results = {
            "valid": 0,
            "invalid": 0,
            "warnings": [],
            "errors": []
        }
        
        for record in data:
            record_id = record.get('id', 'unknown')
            
            self.logger.trace(
                self.agent_name,
                f"Validating record",
                record_id=record_id
            )
            
            # Validate required fields
            for field in ['id', 'name', 'asset_id']:
                if field not in record or not record[field]:
                    self.logger.warning(
                        self.agent_name,
                        f"Missing required field",
                        record_id=record_id,
                        field=field
                    )
                    validation_results["warnings"].append({
                        "record": record_id,
                        "issue": f"Missing field: {field}"
                    })
            
            # Validate data types and formats
            if 'ip_address' in record:
                if not self._validate_ip(record['ip_address']):
                    self.logger.warning(
                        self.agent_name,
                        "Invalid IP address format",
                        record_id=record_id,
                        ip_address=record['ip_address']
                    )
                    validation_results["invalid"] += 1
                    continue
            
            validation_results["valid"] += 1
        
        # Log summary
        self.logger.info(
            self.agent_name,
            "Validation completed",
            valid=validation_results["valid"],
            invalid=validation_results["invalid"],
            warnings=len(validation_results["warnings"])
        )
        
        if validation_results["errors"]:
            self.logger.error(
                self.agent_name,
                f"Critical validation errors found",
                error_count=len(validation_results["errors"])
            )
        
        return validation_results
    
    def _validate_ip(self, ip: str) -> bool:
        """Helper to validate IP address format."""
        # Simple validation example
        import re
        pattern = r'^(\d{1,3}\.){3}\d{1,3}$'
        return bool(re.match(pattern, str(ip)))


# Example usage function
def example_usage():
    """Demonstrate how agents use the logger."""
    # Initialize logger (typically done once at startup)
    logger = get_logger(
        output_dir="./output",
        log_level=10,  # DEBUG level
        console_output=True
    )
    
    # Create agents with logger
    data_fetcher = DataFetcherAgent(logger)
    differ = DifferAgent(logger)
    applier = ApplierAgent(logger)
    tui = TUIOperatorAgent(logger)
    validator = ValidatorAgent(logger)
    
    # Example workflow with logging
    try:
        # Start process
        logger.info("SYSTEM", "Merger tool started", version="1.0.0")
        
        # Fetch data
        zabbix_assets = data_fetcher.fetch_zabbix_assets()
        
        # Validate
        validation_results = validator.validate_data(zabbix_assets)
        
        # Compare
        differences = differ.compare_assets(zabbix_assets, [])
        
        # TUI interaction
        tui.start_session(user="admin")
        tui.log_field_selection("ip_address", "zabbix", "192.168.1.10")
        tui.log_user_action("save_changes")
        tui.end_session(changes_made=5)
        
        # Apply changes
        changes = [{"asset_id": "asset1", "type": "update", "fields": ["ip", "name"]}]
        results = applier.apply_changes(changes)
        
        # Complete
        logger.info("SYSTEM", "Merger tool completed successfully")
        
    except Exception as e:
        logger.critical("SYSTEM", "Fatal error in merger tool", exception=e)
        raise
    
    finally:
        # Print statistics
        logger.print_statistics()


if __name__ == "__main__":
    example_usage()
