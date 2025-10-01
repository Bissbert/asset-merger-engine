#!/usr/bin/env python3
"""
Command-line interface for the apply module.

This script provides a simple CLI wrapper for applying APL files
to the Topdesk system using the APLProcessor.
"""

import sys
import os
import argparse
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent))

from apply import APLProcessor, BatchProcessor

def check_dependencies():
    """Check if required dependencies are installed."""
    missing = []

    # Check for topdesk-cli
    try:
        result = subprocess.run(['which', 'topdesk-cli'], capture_output=True, text=True)
        if result.returncode != 0:
            result = subprocess.run(['which', 'topdesk'], capture_output=True, text=True)
            if result.returncode != 0:
                missing.append('topdesk-cli')
    except Exception:
        missing.append('topdesk-cli')

    # Check for requests library (for API fallback)
    try:
        import requests
    except ImportError:
        missing.append('requests')

    if missing:
        print("\nMissing dependencies detected:")
        print("="*50)
        for dep in missing:
            if dep == 'topdesk-cli':
                print("\n❌ topdesk-cli not found")
                print("   Install with: pip install topdesk-cli")
                print("   Or download from: https://github.com/topdesk/cli")
                print("   Note: The tool will fall back to direct API calls if CLI is unavailable.")
            elif dep == 'requests':
                print("\n❌ requests library not found")
                print("   Install with: pip install requests")
                print("   Required for direct API calls when topdesk-cli is not available.")
        print("\n" + "="*50)
        response = input("\nContinue anyway? (y/N): ")
        if response.lower() != 'y':
            sys.exit(1)


def check_authentication():
    """Check if authentication environment variables are set."""
    missing = []

    if not os.environ.get('TOPDESK_URL'):
        missing.append('TOPDESK_URL')
    if not os.environ.get('TOPDESK_USERNAME'):
        missing.append('TOPDESK_USERNAME')
    if not os.environ.get('TOPDESK_API_KEY'):
        missing.append('TOPDESK_API_KEY')

    if missing:
        print("\n⚠️  Missing authentication environment variables:")
        print("="*50)
        for var in missing:
            if var == 'TOPDESK_URL':
                print(f"\n❌ {var} not set")
                print("   Set with: export TOPDESK_URL=https://your-instance.topdesk.net")
                print("   Example: export TOPDESK_URL=https://acme.topdesk.net")
            elif var == 'TOPDESK_USERNAME':
                print(f"\n❌ {var} not set")
                print("   Set with: export TOPDESK_USERNAME=your-username")
                print("   This should be your Topdesk login username")
            elif var == 'TOPDESK_API_KEY':
                print(f"\n❌ {var} not set")
                print("   Set with: export TOPDESK_API_KEY=your-api-key")
                print("   Generate in Topdesk: Settings → API Management → Application passwords")

        print("\n" + "="*50)
        print("\nAlternatively, you can pass these as command-line arguments:")
        print("  --topdesk-url URL")
        print("  --topdesk-username USERNAME")
        print("  --topdesk-api-key API_KEY")
        print("\nNote: Environment variables are recommended for security.")
        return False

    return True


def main():
    """Main CLI entry point."""
    parser = argparse.ArgumentParser(
        description='Apply APL files to update Topdesk assets',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Set authentication (do this first):
  export TOPDESK_URL=https://your-instance.topdesk.net
  export TOPDESK_USERNAME=your-username
  export TOPDESK_API_KEY=your-api-key

  # Process a single APL file
  %(prog)s changes.apl

  # Process with dry-run to preview changes
  %(prog)s changes.apl --dry-run

  # Process all APL files in a directory
  %(prog)s /path/to/apl/directory/

  # Process with custom batch size and retries
  %(prog)s changes.apl --batch-size 20 --max-retries 5

  # Process with verbose output
  %(prog)s changes.apl --verbose

  # Process specific pattern in directory
  %(prog)s /path/to/directory/ --pattern "*_approved.apl"

  # Use command-line authentication (not recommended)
  %(prog)s changes.apl --topdesk-url https://acme.topdesk.net \\
    --topdesk-username user --topdesk-api-key secret
        """
    )

    parser.add_argument(
        'input',
        help='APL file or directory containing APL files to process'
    )

    parser.add_argument(
        '-o', '--output-dir',
        default='./output',
        help='Output directory for reports and logs (default: ./output)'
    )

    parser.add_argument(
        '-b', '--batch-size',
        type=int,
        default=10,
        metavar='N',
        help='Number of assets to process in a batch (default: 10)'
    )

    parser.add_argument(
        '-r', '--max-retries',
        type=int,
        default=3,
        metavar='N',
        help='Maximum retry attempts for failed operations (default: 3)'
    )

    parser.add_argument(
        '-d', '--retry-delay',
        type=float,
        default=2.0,
        metavar='SECONDS',
        help='Initial delay between retries in seconds (default: 2.0)'
    )

    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Simulate changes without applying them to Topdesk'
    )

    parser.add_argument(
        '-v', '--verbose',
        action='store_true',
        help='Enable verbose logging output'
    )

    parser.add_argument(
        '--parallel',
        action='store_true',
        help='Enable parallel processing (experimental)'
    )

    parser.add_argument(
        '--parallel-workers',
        type=int,
        default=4,
        metavar='N',
        help='Number of parallel workers when --parallel is enabled (default: 4)'
    )

    parser.add_argument(
        '--pattern',
        default='*.apl',
        metavar='GLOB',
        help='File pattern when processing directory (default: *.apl)'
    )

    parser.add_argument(
        '--no-archive',
        action='store_true',
        help='Do not archive processed APL files'
    )

    parser.add_argument(
        '--force',
        action='store_true',
        help='Force processing even if validation warnings are present'
    )

    # Authentication arguments (optional if env vars are set)
    auth_group = parser.add_argument_group('authentication')
    auth_group.add_argument(
        '--topdesk-url',
        metavar='URL',
        help='Topdesk instance URL (or set TOPDESK_URL env var)'
    )
    auth_group.add_argument(
        '--topdesk-username',
        metavar='USERNAME',
        help='Topdesk username (or set TOPDESK_USERNAME env var)'
    )
    auth_group.add_argument(
        '--topdesk-api-key',
        metavar='API_KEY',
        help='Topdesk API key (or set TOPDESK_API_KEY env var)'
    )

    parser.add_argument(
        '--skip-dependency-check',
        action='store_true',
        help='Skip checking for required dependencies'
    )

    args = parser.parse_args()

    # Check dependencies unless skipped
    if not args.skip_dependency_check:
        check_dependencies()

    # Set authentication from command line if provided
    if args.topdesk_url:
        os.environ['TOPDESK_URL'] = args.topdesk_url
    if args.topdesk_username:
        os.environ['TOPDESK_USERNAME'] = args.topdesk_username
    if args.topdesk_api_key:
        os.environ['TOPDESK_API_KEY'] = args.topdesk_api_key

    # Check authentication
    if not args.dry_run:
        auth_ok = check_authentication()
        if not auth_ok and not args.force:
            response = input("\nContinue without authentication? (y/N): ")
            if response.lower() != 'y':
                print("Aborted.")
                sys.exit(1)

    # Validate input path
    input_path = Path(args.input)
    if not input_path.exists():
        print(f"Error: Input path does not exist: {input_path}", file=sys.stderr)
        sys.exit(1)

    # Create processor with specified options
    try:
        processor = APLProcessor(
            output_dir=args.output_dir,
            batch_size=args.batch_size,
            max_retries=args.max_retries,
            retry_delay=args.retry_delay,
            dry_run=args.dry_run,
            verbose=args.verbose,
            parallel=args.parallel,
            parallel_workers=args.parallel_workers,
            topdesk_url=args.topdesk_url,
            topdesk_username=args.topdesk_username,
            topdesk_api_key=args.topdesk_api_key
        )
    except ValueError as e:
        print(f"\n❌ Configuration error: {e}", file=sys.stderr)
        print("\nPlease check your authentication settings and try again.")
        sys.exit(1)
    except ConnectionError as e:
        print(f"\n❌ Connection error: {e}", file=sys.stderr)
        print("\nPlease verify:")
        print("  1. Your Topdesk URL is correct")
        print("  2. Your credentials are valid")
        print("  3. You have network connectivity")
        print("  4. The Topdesk API is accessible")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Failed to initialize processor: {e}", file=sys.stderr)
        if args.verbose:
            import traceback
            traceback.print_exc()
        sys.exit(1)

    # Display configuration if verbose
    if args.verbose:
        print("Configuration:")
        print(f"  Output Directory: {args.output_dir}")
        print(f"  Batch Size: {args.batch_size}")
        print(f"  Max Retries: {args.max_retries}")
        print(f"  Retry Delay: {args.retry_delay}s")
        print(f"  Dry Run: {args.dry_run}")
        print(f"  Parallel: {args.parallel}")
        if args.parallel:
            print(f"  Parallel Workers: {args.parallel_workers}")
        print()

    if args.dry_run:
        print("=" * 60)
        print("DRY RUN MODE - No actual changes will be applied")
        print("=" * 60)
        print()

    try:
        if input_path.is_file():
            # Process single file
            if not str(input_path).endswith('.apl'):
                print(f"Warning: File does not have .apl extension: {input_path}")
                if not args.force:
                    response = input("Continue anyway? (y/N): ")
                    if response.lower() != 'y':
                        print("Aborted.")
                        sys.exit(0)

            print(f"Processing APL file: {input_path}")
            result = processor.process_apl_file(str(input_path))

            if result['success']:
                print(f"\n✅ Processing completed successfully")
                if 'report_path' in result:
                    print(f"  Report saved to: {result['report_path']}")
                sys.exit(0)
            else:
                print(f"\n❌ Processing failed: {result.get('error', 'Unknown error')}", file=sys.stderr)
                if 'authentication' in result.get('error', '').lower():
                    print("\nAuthentication issue detected. Please verify your credentials.")
                sys.exit(1)

        elif input_path.is_dir():
            # Process directory
            print(f"Processing APL files in directory: {input_path}")
            print(f"File pattern: {args.pattern}")
            print()

            batch_processor = BatchProcessor(processor)
            result = batch_processor.process_directory(str(input_path), args.pattern)

            # Print detailed summary
            print("\n" + "=" * 60)
            print("Batch Processing Summary")
            print("=" * 60)
            print(f"Files Processed: {result['files_processed']}")
            print(f"Files Successful: {result['files_successful']}")
            print(f"Files Failed: {result['files_failed']}")

            if 'total_statistics' in result:
                print("\nTotal Statistics:")
                stats = result['total_statistics']
                print(f"  Total Assets: {stats.get('total_assets', 0)}")
                print(f"  Successfully Updated: {stats.get('successful_updates', 0)}")
                print(f"  Failed Updates: {stats.get('failed_updates', 0)}")
                print(f"  Partially Updated: {stats.get('partial_updates', 0)}")
                print(f"  Skipped: {stats.get('skipped', 0)}")
                if stats.get('rollbacks', 0) > 0:
                    print(f"  Rollbacks Performed: {stats['rollbacks']}")

            # Show failed files if any
            if result['files_failed'] > 0:
                print("\nFailed Files:")
                for item in result.get('details', []):
                    if not item['result']['success']:
                        print(f"  - {Path(item['file']).name}: {item['result'].get('error', 'Unknown error')}")

            print("\nReports saved to: {}/apply/reports/".format(args.output_dir))

            if result['success']:
                print("\n✅ All files processed successfully")
                sys.exit(0)
            else:
                print(f"\n⚠️  Some files failed processing", file=sys.stderr)
                sys.exit(1)

        else:
            print(f"Error: Input is neither a file nor a directory: {input_path}", file=sys.stderr)
            sys.exit(1)

    except KeyboardInterrupt:
        print("\n\n⚠️  Operation cancelled by user")
        sys.exit(130)
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}", file=sys.stderr)

        # Provide helpful error messages for common issues
        error_str = str(e).lower()
        if 'connection' in error_str or 'timeout' in error_str:
            print("\nConnection issue detected. Please check:")
            print("  - Network connectivity")
            print("  - Topdesk URL is correct")
            print("  - Firewall/proxy settings")
        elif 'authentication' in error_str or '401' in error_str:
            print("\nAuthentication failed. Please check:")
            print("  - Username is correct")
            print("  - API key is valid and not expired")
            print("  - User has sufficient permissions")
        elif 'permission' in error_str or '403' in error_str:
            print("\nPermission denied. Please check:")
            print("  - User has asset management permissions")
            print("  - API key has required scopes")
        elif 'not found' in error_str or '404' in error_str:
            print("\nResource not found. Please check:")
            print("  - Asset IDs in APL file are correct")
            print("  - Assets exist in Topdesk")

        if args.verbose:
            import traceback
            print("\nDetailed error trace:")
            traceback.print_exc()
        else:
            print("\nUse --verbose for detailed error information")

        sys.exit(1)


if __name__ == '__main__':
    main()