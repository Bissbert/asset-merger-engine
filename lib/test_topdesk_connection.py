#!/usr/bin/env python3
"""
Test script to verify Topdesk connection and authentication.

This script helps diagnose connection issues and verify that
the authentication is properly configured.
"""

import os
import sys
import subprocess
import json
import base64
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent))

try:
    import requests
    REQUESTS_AVAILABLE = True
except ImportError:
    REQUESTS_AVAILABLE = False


def test_environment_variables():
    """Check if required environment variables are set."""
    print("\n" + "="*60)
    print("CHECKING ENVIRONMENT VARIABLES")
    print("="*60)

    required_vars = {
        'TOPDESK_URL': 'Topdesk instance URL',
        'TOPDESK_USERNAME': 'Topdesk username',
        'TOPDESK_API_KEY': 'Topdesk API key'
    }

    missing = []
    found = []

    for var, description in required_vars.items():
        value = os.environ.get(var)
        if value:
            # Mask sensitive data
            if var == 'TOPDESK_API_KEY':
                masked_value = value[:4] + '...' + value[-4:] if len(value) > 8 else '***'
                print(f"✅ {var}: {masked_value}")
            elif var == 'TOPDESK_USERNAME':
                masked_value = value[:2] + '***' if len(value) > 2 else '***'
                print(f"✅ {var}: {masked_value}")
            else:
                print(f"✅ {var}: {value}")
            found.append(var)
        else:
            print(f"❌ {var}: Not set ({description})")
            missing.append(var)

    return len(missing) == 0, missing


def test_cli_availability():
    """Check if topdesk-cli is available."""
    print("\n" + "="*60)
    print("CHECKING CLI AVAILABILITY")
    print("="*60)

    cli_commands = ['topdesk']
    found_cli = None

    for cmd in cli_commands:
        try:
            result = subprocess.run(
                ['which', cmd],
                capture_output=True,
                text=True
            )
            if result.returncode == 0:
                print(f"✅ Found {cmd} at: {result.stdout.strip()}")
                found_cli = cmd
                break
        except Exception:
            continue

    if not found_cli:
        print("❌ topdesk command not found")
        print("   Please ensure 'topdesk' command is installed and in PATH")
        print("   Or use direct API calls (requests library required)")

    return found_cli


def test_cli_connection(cli_command):
    """Test connection using topdesk-cli."""
    print("\n" + "="*60)
    print("TESTING CLI CONNECTION")
    print("="*60)

    env = os.environ.copy()

    # Try to list one asset to test connection
    cmd = [cli_command, 'asset', 'list', '--limit', '1']

    print(f"Running: {' '.join(cmd)}")

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=30,
            env=env
        )

        if result.returncode == 0:
            print("✅ CLI connection successful")

            # Try to parse output
            try:
                data = json.loads(result.stdout)
                print(f"   Retrieved {len(data)} asset(s)")
                return True
            except json.JSONDecodeError:
                print("   Note: Output is not JSON, but connection works")
                return True
        else:
            print(f"❌ CLI connection failed")
            if result.stderr:
                print(f"   Error: {result.stderr[:200]}")
            return False

    except subprocess.TimeoutExpired:
        print("❌ CLI connection timed out")
        return False
    except Exception as e:
        print(f"❌ CLI test failed: {e}")
        return False


def test_api_connection():
    """Test direct API connection."""
    print("\n" + "="*60)
    print("TESTING DIRECT API CONNECTION")
    print("="*60)

    if not REQUESTS_AVAILABLE:
        print("❌ requests library not available")
        print("   Install with: pip install requests")
        return False

    url = os.environ.get('TOPDESK_URL')
    username = os.environ.get('TOPDESK_USERNAME')
    api_key = os.environ.get('TOPDESK_API_KEY')

    if not all([url, username, api_key]):
        print("❌ Missing required environment variables for API test")
        return False

    # Create basic auth header
    auth_string = f"{username}:{api_key}"
    auth_bytes = auth_string.encode('ascii')
    auth_b64 = base64.b64encode(auth_bytes).decode('ascii')

    headers = {
        'Authorization': f'Basic {auth_b64}',
        'Content-Type': 'application/json'
    }

    # Test API endpoint
    test_url = f"{url}/tas/api/assetmgmt/assets"

    print(f"Testing: {test_url}")

    try:
        response = requests.get(
            test_url,
            headers=headers,
            params={'pageSize': 1},
            timeout=30,
            verify=True  # Enable SSL verification
        )

        if response.status_code == 200:
            print("✅ API connection successful")
            data = response.json()
            if isinstance(data, list):
                print(f"   Retrieved {len(data)} asset(s)")
            return True
        elif response.status_code == 401:
            print("❌ Authentication failed (401)")
            print("   Check your username and API key")
            return False
        elif response.status_code == 403:
            print("❌ Permission denied (403)")
            print("   Check user permissions for asset management")
            return False
        elif response.status_code == 404:
            print("❌ API endpoint not found (404)")
            print("   Check your Topdesk URL")
            return False
        else:
            print(f"❌ API request failed with status: {response.status_code}")
            if response.text:
                print(f"   Response: {response.text[:200]}")
            return False

    except requests.exceptions.SSLError as e:
        print("❌ SSL certificate verification failed")
        print(f"   Error: {e}")
        print("   If using self-signed certificates, you may need to configure SSL settings")
        return False
    except requests.exceptions.ConnectionError as e:
        print("❌ Connection failed")
        print(f"   Error: {e}")
        print("   Check network connectivity and Topdesk URL")
        return False
    except requests.exceptions.Timeout:
        print("❌ Connection timed out")
        print("   Check network connectivity and firewall settings")
        return False
    except Exception as e:
        print(f"❌ API test failed: {e}")
        return False


def test_sample_apl_processing():
    """Test processing a sample APL file."""
    print("\n" + "="*60)
    print("TESTING APL PROCESSING (DRY RUN)")
    print("="*60)

    # Create a temporary sample APL file
    sample_apl = {
        "asset_id": "TEST-ASSET-001",
        "fields": {
            "name": "Test Asset",
            "ip_address": "192.168.1.100",
            "location": "Test Location"
        }
    }

    import tempfile
    with tempfile.NamedTemporaryFile(mode='w', suffix='.apl', delete=False) as f:
        json.dump([sample_apl], f, indent=2)
        temp_file = f.name

    try:
        from apply import APLProcessor

        processor = APLProcessor(
            dry_run=True,
            verbose=True
        )

        print(f"Processing sample APL file: {temp_file}")
        result = processor.process_apl_file(temp_file)

        if result['success']:
            print("✅ APL processing test successful (dry run)")
            return True
        else:
            print(f"❌ APL processing test failed: {result.get('error', 'Unknown error')}")
            return False

    except Exception as e:
        print(f"❌ APL processing test failed: {e}")
        return False
    finally:
        # Clean up temp file
        try:
            os.unlink(temp_file)
        except:
            pass


def main():
    """Main test function."""
    print("\n" + "="*60)
    print("TOPDESK CONNECTION TEST")
    print("="*60)

    results = []

    # Test 1: Environment variables
    env_ok, missing_vars = test_environment_variables()
    results.append(("Environment Variables", env_ok))

    # Test 2: CLI availability
    cli_command = test_cli_availability()
    results.append(("CLI Availability", cli_command is not None))

    # Test 3: CLI connection (if available and env vars set)
    if cli_command and env_ok:
        cli_ok = test_cli_connection(cli_command)
        results.append(("CLI Connection", cli_ok))
    else:
        print("\n⚠️  Skipping CLI connection test (CLI not found or env vars missing)")

    # Test 4: API connection (if env vars set)
    if env_ok:
        api_ok = test_api_connection()
        results.append(("API Connection", api_ok))
    else:
        print("\n⚠️  Skipping API connection test (env vars missing)")

    # Test 5: APL processing (dry run)
    apl_ok = test_sample_apl_processing()
    results.append(("APL Processing (Dry Run)", apl_ok))

    # Summary
    print("\n" + "="*60)
    print("TEST SUMMARY")
    print("="*60)

    all_ok = True
    for test_name, passed in results:
        status = "✅ PASSED" if passed else "❌ FAILED"
        print(f"{test_name:.<30} {status}")
        if not passed:
            all_ok = False

    print("="*60)

    if all_ok:
        print("\n✅ All tests passed! You're ready to use the apply module.")
        sys.exit(0)
    else:
        print("\n⚠️  Some tests failed. Please review the output above.")
        print("\nTroubleshooting tips:")
        print("1. Set environment variables:")
        print("   export TOPDESK_URL=https://your-instance.topdesk.net")
        print("   export TOPDESK_USERNAME=your-username")
        print("   export TOPDESK_API_KEY=your-api-key")
        print("\n2. Install topdesk-cli (optional):")
        print("   pip install topdesk-cli")
        print("\n3. Install requests library (for API fallback):")
        print("   pip install requests")
        sys.exit(1)


if __name__ == '__main__':
    main()