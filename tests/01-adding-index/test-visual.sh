#!/bin/bash
set -e

# Source the helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../shared/concurrent-test-helpers.sh"
source "$SCRIPT_DIR/../shared/visual-blocking-test.sh"

echo -e "${BLUE}${BOLD}=== Testing: Adding an Index (VISUAL MODE) ===${NC}\n"

# Wait for postgres with timeout
wait_for_postgres 60 || exit 1
echo ""

#############################################
# Test BAD approach - visually show blocking
#############################################
echo -e "${RED}${BOLD}═══════════════════════════════════════════════════════${NC}"
echo -e "${RED}${BOLD}  TEST 1: CREATE INDEX (without CONCURRENTLY)${NC}"
echo -e "${RED}${BOLD}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}This will start continuous write activity on the posts table.${NC}"
echo -e "${YELLOW}Watch the activity counter - it will FREEZE when we create the index!${NC}"
echo ""

visual_blocking_test "posts" "write" "CREATE INDEX (without CONCURRENTLY)" "migrations/bad.sql" "blocks"

echo ""
sleep 2

#############################################
# Test GOOD approach - visually show NO blocking
#############################################
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  TEST 2: CREATE INDEX CONCURRENTLY${NC}"
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}This will start continuous write activity again.${NC}"
echo -e "${YELLOW}Watch the activity counter - it should CONTINUE running!${NC}"
echo ""

visual_blocking_test "posts" "write" "CREATE INDEX CONCURRENTLY" "migrations/good.sql" "no-block"

echo ""

#############################################
# Final Summary
#############################################
echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}${BOLD}  VISUAL TEST SUMMARY${NC}"
echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${RED}${BOLD}Test 1 - CREATE INDEX (without CONCURRENTLY):${NC}"
echo -e "  Expected: Activity counter FROZE with timestamp stuck"
echo -e "  Effect: All writes blocked during index creation"
echo ""
echo -e "${GREEN}${BOLD}Test 2 - CREATE INDEX CONCURRENTLY:${NC}"
echo -e "  Expected: Activity counter CONTINUED updating"
echo -e "  Effect: Writes continued during concurrent index creation"
echo ""
echo -e "${YELLOW}${BOLD}Conclusion:${NC}"
echo -e "  ${RED}BAD${NC}: Regular CREATE INDEX blocks writes (counter freezes)"
echo -e "  ${GREEN}GOOD${NC}: CONCURRENT CREATE INDEX allows writes (counter keeps running)"
echo ""
echo -e "${CYAN}This visual demonstration clearly shows the blocking behavior!${NC}"
echo ""
