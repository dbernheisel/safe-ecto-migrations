#!/bin/bash
set -e

# Source the concurrent testing helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../shared/concurrent-test-helpers.sh"

echo -e "${BLUE}=== Testing: Adding an Index ===${NC}\n"

# Wait for postgres with timeout
wait_for_postgres 60 || exit 1
echo ""

#############################################
# Test BAD approach with concurrent writes
#############################################
echo -e "${RED}========================================${NC}"
echo -e "${RED}Testing BAD approach (without CONCURRENTLY)${NC}"
echo -e "${RED}========================================${NC}\n"

# Start the index creation in background
echo -e "${YELLOW}Starting index creation (with 3 second delay)...${NC}"
result=$(run_sql_file_background "migrations/bad.sql" "Create index without CONCURRENTLY")
bg_pid=$(echo "$result" | cut -d'|' -f1)
bg_output=$(echo "$result" | cut -d'|' -f2)

# Wait a moment for the transaction to start
sleep 1

# Attempt concurrent write - this should BLOCK
echo -e "\n${CYAN}=== Testing concurrent write during index creation ===${NC}"
INSERT_SQL="INSERT INTO posts (slug, title, content) VALUES ('test-bad-' || floor(random() * 1000000), 'Test Post', 'Test Content');"

if test_concurrent_write "posts" "$INSERT_SQL" 50; then
    echo -e "${RED}✗ Unexpected: Write did not block (should have blocked)${NC}"
else
    echo -e "${GREEN}✓ Expected: Write was BLOCKED by index creation${NC}"
fi

# Wait for background process to complete
wait $bg_pid 2>/dev/null || true
cat "$bg_output"
rm -f "$bg_output"

echo -e "\n${RED}Summary: CREATE INDEX blocks writes${NC}\n"
sleep 2

#############################################
# Test GOOD approach with concurrent writes
#############################################
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Testing GOOD approach (with CONCURRENTLY)${NC}"
echo -e "${GREEN}========================================${NC}\n"

# Start the concurrent index creation in background
echo -e "${YELLOW}Starting CONCURRENT index creation...${NC}"
result=$(run_sql_file_background "migrations/good.sql" "Create index with CONCURRENTLY")
bg_pid=$(echo "$result" | cut -d'|' -f1)
bg_output=$(echo "$result" | cut -d'|' -f2)

# Wait a moment for the index creation to start
sleep 1

# Attempt concurrent write - this should NOT block
echo -e "\n${CYAN}=== Testing concurrent write during CONCURRENT index creation ===${NC}"
INSERT_SQL="INSERT INTO posts (slug, title, content) VALUES ('test-good-' || floor(random() * 1000000), 'Test Post', 'Test Content');"

if test_concurrent_write "posts" "$INSERT_SQL" 50; then
    echo -e "${GREEN}✓ Expected: Write completed successfully (not blocked)${NC}"
else
    echo -e "${RED}✗ Unexpected: Write was blocked (should not block)${NC}"
fi

# Wait for background process to complete
wait $bg_pid 2>/dev/null || true
cat "$bg_output"
rm -f "$bg_output"

echo -e "\n${GREEN}Summary: CREATE INDEX CONCURRENTLY does NOT block writes${NC}\n"

#############################################
# Final Summary
#############################################
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Test Results Summary${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "
${RED}BAD approach (CREATE INDEX):${NC}
  ✗ Blocks concurrent writes
  ✗ Acquires ShareLock on the table
  ✗ Can cause application timeouts

${GREEN}GOOD approach (CREATE INDEX CONCURRENTLY):${NC}
  ✓ Does NOT block concurrent writes
  ✓ Safe for production use
  ✓ Takes longer but allows operations to continue

${YELLOW}Ecto Migration Example:${NC}

  # in config/config.exs
  config MyApp.Repo, migration_lock: :pg_advisory_lock

  # in the migration
  @disable_ddl_transaction true

  def change do
    create index(\"posts\", [:slug], concurrently: true)
  end
"
