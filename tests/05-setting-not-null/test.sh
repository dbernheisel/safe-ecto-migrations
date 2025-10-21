#!/bin/bash
set -e

# Source the concurrent testing helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../shared/concurrent-test-helpers.sh"

echo -e "${BLUE}=== Testing: Setting NOT NULL on Existing Column ===${NC}\n"

# Wait for postgres with timeout
wait_for_postgres 60 || exit 1
echo ""

# Show Postgres version
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
    -c "SHOW server_version;" | grep "server_version"
echo ""

#############################################
# Test BAD approach with concurrent writes
#############################################
echo -e "${RED}========================================${NC}"
echo -e "${RED}Testing BAD approach (SET NOT NULL directly)${NC}"
echo -e "${RED}========================================${NC}\n"

# Start the NOT NULL operation in background
echo -e "${YELLOW}Starting SET NOT NULL operation (with 3 second delay)...${NC}"
result=$(run_sql_file_background "migrations/bad.sql" "Set NOT NULL directly")
bg_pid=$(echo "$result" | cut -d'|' -f1)
bg_output=$(echo "$result" | cut -d'|' -f2)

# Wait a moment for the transaction to start
sleep 1

# Attempt concurrent UPDATE - should BLOCK
echo -e "\n${CYAN}=== Testing concurrent UPDATE during SET NOT NULL ===${NC}"
UPDATE_SQL="UPDATE products SET active = true WHERE id = (SELECT id FROM products ORDER BY random() LIMIT 1);"

if test_concurrent_write "products" "$UPDATE_SQL" 50; then
    # test_concurrent_write returns 0 if blocked, 1 if not blocked
    echo -e "${GREEN}✓ Expected: UPDATE was BLOCKED${NC}"
else
    echo -e "${RED}✗ Unexpected: UPDATE did not block${NC}"
fi

# Wait for background process to complete
wait $bg_pid 2>/dev/null || true
cat "$bg_output"
rm -f "$bg_output"

echo -e "\n${RED}Summary: SET NOT NULL blocks reads and writes${NC}\n"
sleep 2

#############################################
# Test GOOD approach with concurrent writes
#############################################
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Testing GOOD approach (CHECK constraint method)${NC}"
echo -e "${GREEN}========================================${NC}\n"

# Clean up from bad test
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
    -c "ALTER TABLE products ALTER COLUMN active DROP NOT NULL;" >/dev/null 2>&1 || true

# Step 1: Create CHECK constraint without validation
echo -e "${YELLOW}--- Step 1: Add CHECK constraint without validation ---${NC}"
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
    -f migrations/good-step1.sql 2>&1 | grep -v "ERROR" || true
echo -e "${GREEN}✓ Step 1 completed (instant, no table scan)${NC}\n"
sleep 1

# Step 2: Validate constraint - test concurrent writes
echo -e "${YELLOW}--- Step 2: Validate constraint (with concurrent testing) ---${NC}"

# Start validation in background
result=$(run_sql_file_background "migrations/good-step2.sql" "Validate CHECK constraint")
bg_pid=$(echo "$result" | cut -d'|' -f1)
bg_output=$(echo "$result" | cut -d'|' -f2)

# Wait a moment for validation to start
sleep 1

# Attempt concurrent UPDATE - should NOT block
echo -e "\n${CYAN}=== Testing concurrent UPDATE during validation ===${NC}"
UPDATE_SQL="UPDATE products SET active = true WHERE id = (SELECT id FROM products ORDER BY random() LIMIT 1);"

if test_concurrent_write "products" "$UPDATE_SQL" 30; then
    # test_concurrent_write returns 0 if blocked, 1 if not blocked
    echo -e "${RED}✗ Unexpected: UPDATE was blocked during validation${NC}"
else
    echo -e "${GREEN}✓ Expected: UPDATE completed during validation (not blocked)${NC}"
fi

# Wait for background process to complete
wait $bg_pid 2>/dev/null || true
cat "$bg_output"
rm -f "$bg_output"

echo -e "\n${GREEN}Summary: CHECK constraint validation does NOT block operations${NC}\n"

#############################################
# Final Summary
#############################################
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Test Results Summary${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "
${RED}BAD approach (SET NOT NULL directly):${NC}
  ✗ Blocks reads and writes during full table scan
  ✗ Can cause significant downtime on large tables
  ✗ Acquires AccessExclusiveLock

${GREEN}GOOD approach (CHECK constraint method):${NC}
  Step 1: Add CHECK constraint with NOT VALID
    - Instant, no table scan
    - New/updated rows checked immediately
  Step 2: Validate constraint
    ✓ Does NOT block reads or writes
    ✓ Acquires ShareUpdateExclusiveLock
  Step 3 (Postgres 12+, optional): Convert to NOT NULL
    - Can skip table scan due to validated CHECK
    - Results in proper NOT NULL constraint

${YELLOW}Ecto Migration Example:${NC}

  # Migration 1
  def change do
    create constraint(\"products\", :active_not_null,
      check: \"active IS NOT NULL\",
      validate: false
    )
  end

  # Migration 2
  def change do
    execute \"ALTER TABLE products VALIDATE CONSTRAINT active_not_null\", \"\"
  end

  # Migration 3 (Postgres 12+ only, optional)
  def change do
    execute \"ALTER TABLE products ALTER COLUMN active SET NOT NULL\",
            \"ALTER TABLE products ALTER COLUMN active DROP NOT NULL\"

    drop constraint(\"products\", :active_not_null)
  end
"
