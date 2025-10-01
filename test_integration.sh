#!/bin/sh
# Integration test without requiring zbx/topdesk commands

echo "================================"
echo "Integration Test Suite"
echo "================================"
echo

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

passed=0
failed=0

test_result() {
    if [ $1 -eq 0 ]; then
        echo "${GREEN}✓${NC} $2"
        passed=$((passed + 1))
    else
        echo "${RED}✗${NC} $2"
        failed=$((failed + 1))
    fi
}

# Test 1: Check directory structure
echo "1. Directory Structure Tests"
test -d ./bin && test_result $? "bin directory exists"
test -d ./lib && test_result $? "lib directory exists"
test -d ./output && test_result $? "output directory exists"
test -d ./cache && test_result $? "cache directory exists"
echo

# Test 2: Check executable scripts
echo "2. Executable Script Tests"
test -x ./bin/merger.sh && test_result $? "merger.sh is executable"
test -x ./lib/datafetcher.sh && test_result $? "datafetcher.sh is executable"
test -x ./lib/check_cli_tools.sh && test_result $? "check_cli_tools.sh is executable"
echo

# Test 3: Test Python modules
echo "3. Python Module Tests"
python3 -c "import sys; sys.path.insert(0, './lib'); import differ" 2>/dev/null
test_result $? "differ.py imports successfully"
python3 -c "import sys; sys.path.insert(0, './lib'); import validator" 2>/dev/null
test_result $? "validator.py imports successfully"
python3 -c "import sys; sys.path.insert(0, './lib'); import logger" 2>/dev/null
test_result $? "logger.py imports successfully"
python3 -c "import sys; sys.path.insert(0, './lib'); import apply" 2>/dev/null
test_result $? "apply.py imports successfully"
echo

# Test 4: Test merger.sh commands
echo "4. Merger Command Tests"
./bin/merger.sh --help >/dev/null 2>&1
test_result $? "merger.sh --help works"
./bin/merger.sh validate >/dev/null 2>&1
test_result $? "merger.sh validate works"
./bin/merger.sh health >/dev/null 2>&1
test_result $? "merger.sh health works"
echo

# Test 5: Test wrapper scripts
echo "5. Wrapper Script Tests"
./lib/zbx_cli_wrapper.sh --help >/dev/null 2>&1
test_result $? "zbx_cli_wrapper.sh --help works"
./lib/topdesk_cli_wrapper.sh --help >/dev/null 2>&1
test_result $? "topdesk_cli_wrapper.sh --help works"
echo

# Test 6: Test validator
echo "6. Validator Tests"
python3 ./lib/test_validator.py >/dev/null 2>&1
test_result $? "validator test suite passes"
echo

# Summary
echo "================================"
echo "Test Summary"
echo "================================"
echo "Passed: ${GREEN}$passed${NC}"
echo "Failed: ${RED}$failed${NC}"
echo "Total: $((passed + failed))"
echo

if [ $failed -eq 0 ]; then
    echo "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo "${YELLOW}Some tests failed.${NC}"
    exit 1
fi
