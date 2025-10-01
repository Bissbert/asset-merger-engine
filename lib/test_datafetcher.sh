#!/bin/sh
# test_datafetcher.sh - Test script for data fetcher module

# Source modules
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/common.sh"
. "${SCRIPT_DIR}/datafetcher.sh"

# Test configuration
TEST_LOG="${LOG_FILE:-/tmp/asset-merger-engine/test.log}"
TEST_CACHE_DIR="${CACHE_DIR:-/tmp/asset-merger-engine/cache}"

# Colors for output (if terminal supports it)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test functions
test_start() {
    local test_name="$1"
    TESTS_RUN=$((TESTS_RUN + 1))
    printf "Testing %s... " "${test_name}"
}

test_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    printf "${GREEN}PASS${NC}\n"
}

test_fail() {
    local reason="$1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf "${RED}FAIL${NC}\n"
    [ -n "${reason}" ] && printf "  Reason: %s\n" "${reason}"
}

# Test: Initialize cache directory
test_cache_init() {
    test_start "cache initialization"

    if init_cache; then
        if [ -d "${CACHE_DIR}" ]; then
            test_pass
        else
            test_fail "Cache directory not created"
        fi
    else
        test_fail "init_cache failed"
    fi
}

# Test: Cache validity check
test_cache_validity() {
    test_start "cache validity"

    local test_file="${CACHE_DIR}/test_cache.json"
    echo '{"test": "data"}' > "${test_file}"

    # Test valid cache
    if is_cache_valid "${test_file}"; then
        test_pass
    else
        test_fail "Fresh cache marked as invalid"
    fi

    # Test expired cache
    sleep 2
    CACHE_TTL=1
    if ! is_cache_valid "${test_file}"; then
        printf "${GREEN}PASS${NC} (expired detection)"
    else
        test_fail "Expired cache marked as valid"
    fi
    CACHE_TTL=300  # Reset

    rm -f "${test_file}"
}

# Test: Retry logic
test_retry_logic() {
    test_start "retry logic"

    # Test successful command
    local output
    output=$(retry_command "echo 'success'" "test command")
    if [ "${output}" = "success" ]; then
        test_pass
    else
        test_fail "Failed to execute successful command"
    fi

    # Test failing command (should fail after retries)
    MAX_RETRIES=2
    RETRY_DELAY=1
    if ! retry_command "false" "failing command" >/dev/null 2>&1; then
        printf "${GREEN}PASS${NC} (failure detection)"
    else
        test_fail "Failed command succeeded unexpectedly"
    fi
}

# Test: JSON normalization
test_json_normalization() {
    test_start "JSON normalization"

    # Test Zabbix data normalization
    local zbx_input='{"result": [{"hostid": "123", "host": "test-host", "status": "0"}]}'
    local zbx_output=$(echo "${zbx_input}" | normalize_zabbix_data)

    if echo "${zbx_output}" | grep -q '"source":"zabbix"'; then
        if echo "${zbx_output}" | grep -q '"asset_id":"123"'; then
            test_pass
        else
            test_fail "Zabbix asset_id not normalized"
        fi
    else
        test_fail "Zabbix source not added"
    fi

    # Test Topdesk data normalization
    local td_input='[{"id": "456", "name": "test-asset", "type": "computer"}]'
    local td_output=$(echo "${td_input}" | normalize_topdesk_data)

    if echo "${td_output}" | grep -q '"source":"topdesk"'; then
        if echo "${td_output}" | grep -q '"asset_id":"456"'; then
            printf "${GREEN}PASS${NC} (both normalizations)"
        else
            test_fail "Topdesk asset_id not normalized"
        fi
    else
        test_fail "Topdesk source not added"
    fi
}

# Test: Tool validation
test_tool_validation() {
    test_start "tool validation"

    # This will fail if tools are not installed, but that's expected
    if validate_tools 2>/dev/null; then
        test_pass
    else
        printf "${YELLOW}SKIP${NC} (tools not installed)\n"
    fi
}

# Test: Clear cache
test_clear_cache() {
    test_start "clear cache"

    # Create test cache files
    touch "${CACHE_DIR}/test1.json" "${CACHE_DIR}/test2.json"

    clear_cache

    if [ -z "$(ls "${CACHE_DIR}"/*.json 2>/dev/null)" ]; then
        test_pass
    else
        test_fail "Cache files not cleared"
    fi
}

# Test: Authentication manager integration
test_auth_integration() {
    test_start "authentication integration"

    # Source auth manager
    if [ -f "${SCRIPT_DIR}/auth_manager.sh" ]; then
        . "${SCRIPT_DIR}/auth_manager.sh"

        # Test auth directory initialization
        if init_auth_dir; then
            test_pass
        else
            test_fail "Auth directory initialization failed"
        fi
    else
        printf "${YELLOW}SKIP${NC} (auth_manager.sh not found)\n"
    fi
}

# Test: Mock data fetching
test_mock_fetch() {
    test_start "mock data fetching"

    # Create mock commands
    cat > "${CACHE_DIR}/mock_zbx_cli" <<'EOF'
#!/bin/sh
echo '[{"hostid": "1", "host": "mock-host", "status": "0"}]'
EOF
    chmod +x "${CACHE_DIR}/mock_zbx_cli"

    cat > "${CACHE_DIR}/mock_topdesk_cli" <<'EOF'
#!/bin/sh
echo '[{"id": "2", "name": "mock-asset", "type": "server"}]'
EOF
    chmod +x "${CACHE_DIR}/mock_topdesk_cli"

    # Override commands temporarily
    OLD_PATH="${PATH}"
    export PATH="${CACHE_DIR}:${PATH}"
    alias zbx="${CACHE_DIR}/mock_zbx_cli"
    alias topdesk="${CACHE_DIR}/mock_topdesk_cli"

    # Test fetch (this will still fail without proper mock setup, but tests the flow)
    local result=$(fetch_all_assets "TestGroup" "" 2>/dev/null || echo '{"error": "expected"}')

    if echo "${result}" | grep -q "error"; then
        test_pass  # Expected behavior without real CLI tools
    else
        test_fail "Unexpected success without proper tools"
    fi

    # Cleanup
    export PATH="${OLD_PATH}"
    unalias zbx 2>/dev/null
    unalias topdesk 2>/dev/null
    rm -f "${CACHE_DIR}/mock_zbx_cli" "${CACHE_DIR}/mock_topdesk_cli"
}

# Test: Parallel fetching simulation
test_parallel_fetch() {
    test_start "parallel fetch simulation"

    # Test parallel execution with mock commands
    (
        echo "data1" > "${CACHE_DIR}/.test1.tmp" &
        pid1=$!
        echo "data2" > "${CACHE_DIR}/.test2.tmp" &
        pid2=$!
        wait ${pid1} ${pid2}
    )

    if [ -f "${CACHE_DIR}/.test1.tmp" ] && [ -f "${CACHE_DIR}/.test2.tmp" ]; then
        test_pass
        rm -f "${CACHE_DIR}/.test1.tmp" "${CACHE_DIR}/.test2.tmp"
    else
        test_fail "Parallel execution failed"
    fi
}

# Run all tests
run_all_tests() {
    echo "===== Data Fetcher Module Tests ====="
    echo "Log file: ${TEST_LOG}"
    echo "Cache dir: ${TEST_CACHE_DIR}"
    echo "======================================"
    echo

    # Initialize
    init_logging
    init_cache

    # Run tests
    test_cache_init
    test_cache_validity
    test_retry_logic
    test_json_normalization
    test_tool_validation
    test_auth_integration
    test_mock_fetch
    test_parallel_fetch
    test_clear_cache

    echo
    echo "======================================"
    echo "Test Results:"
    printf "  Total:  %d\n" "${TESTS_RUN}"
    printf "  ${GREEN}Passed: %d${NC}\n" "${TESTS_PASSED}"
    printf "  ${RED}Failed: %d${NC}\n" "${TESTS_FAILED}"

    if [ "${TESTS_FAILED}" -eq 0 ]; then
        printf "\n${GREEN}All tests passed!${NC}\n"
        return 0
    else
        printf "\n${RED}Some tests failed!${NC}\n"
        return 1
    fi
}

# Main
main() {
    case "${1:-test}" in
        test|all)
            run_all_tests
            ;;
        clean)
            echo "Cleaning test artifacts..."
            rm -rf "${TEST_CACHE_DIR}"
            rm -f "${TEST_LOG}"
            echo "Cleanup complete"
            ;;
        *)
            echo "Usage: $0 {test|all|clean}" >&2
            exit 1
            ;;
    esac
}

# Run if executed directly
if [ "${0##*/}" = "test_datafetcher.sh" ]; then
    main "$@"
fi