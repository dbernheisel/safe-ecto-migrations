#!/bin/bash
set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${BLUE}"
echo "=========================================="
echo "  Safe Ecto Migrations - Test Suite"
echo "=========================================="
echo -e "${NC}\n"

# Array of test directories
TESTS=(
    "01-adding-index"
    "02-adding-foreign-key"
    "03-adding-column-default"
    "04-adding-check-constraint"
    "05-setting-not-null"
    "06-adding-json-column"
)

PASSED=0
FAILED=0
SKIPPED=0

# Function to run a single test
run_test() {
    local test_dir=$1
    local test_name=$(echo $test_dir | sed 's/^[0-9]*-//' | tr '-' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2));}1')

    echo -e "${BOLD}${YELLOW}========================================${NC}"
    echo -e "${BOLD}${YELLOW}Running: $test_name${NC}"
    echo -e "${BOLD}${YELLOW}========================================${NC}\n"

    cd "$test_dir"

    # Check if test.sh exists
    if [ ! -f "test.sh" ]; then
        echo -e "${YELLOW}⊘ Skipping - no test.sh found${NC}\n"
        ((SKIPPED++))
        cd ..
        return
    fi

    # Start docker-compose
    echo "Starting PostgreSQL container..."
    if docker compose up -d >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Container started${NC}\n"
    else
        echo -e "${RED}✗ Failed to start container${NC}\n"
        ((FAILED++))
        cd ..
        return
    fi

    # Wait a moment for postgres to initialize
    sleep 3

    # Run the test
    if ./test.sh; then
        echo -e "\n${GREEN}${BOLD}✓ Test passed: $test_name${NC}\n"
        ((PASSED++))
    else
        echo -e "\n${RED}${BOLD}✗ Test failed: $test_name${NC}\n"
        ((FAILED++))
    fi

    # Cleanup
    echo "Cleaning up..."
    docker compose down -v >/dev/null 2>&1
    echo -e "${GREEN}✓ Cleaned up${NC}\n"

    cd ..
    sleep 2
}

# Main test execution
START_TIME=$(date +%s)

for test in "${TESTS[@]}"; do
    if [ -d "$test" ]; then
        run_test "$test"
    else
        echo -e "${YELLOW}⊘ Skipping $test - directory not found${NC}\n"
        ((SKIPPED++))
    fi
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Summary
echo -e "${BOLD}${BLUE}"
echo "=========================================="
echo "  Test Suite Summary"
echo "=========================================="
echo -e "${NC}"
echo -e "${GREEN}Passed:  $PASSED${NC}"
echo -e "${RED}Failed:  $FAILED${NC}"
echo -e "${YELLOW}Skipped: $SKIPPED${NC}"
echo ""
echo -e "Total time: ${DURATION}s"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}${BOLD}All tests passed! ✓${NC}\n"
    exit 0
else
    echo -e "${RED}${BOLD}Some tests failed ✗${NC}\n"
    exit 1
fi
