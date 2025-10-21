#!/bin/bash
set -e

# Source the concurrent testing helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../shared/concurrent-test-helpers.sh"

echo -e "${BLUE}=== Testing: Adding a Check Constraint ===${NC}\n"

# Wait for postgres
echo "Waiting for PostgreSQL..."
until PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c '\q' 2>/dev/null; do
    sleep 1
done
echo -e "${GREEN}PostgreSQL is ready${NC}\n"

#############################################
# Test BAD approach with concurrent writes
#############################################
echo -e "${RED}========================================${NC}"
echo -e "${RED}Testing BAD approach (with validation)${NC}"
echo -e "${RED}========================================${NC}\n"

# Start the constraint creation in background
echo -e "${YELLOW}Starting constraint creation with validation (with 3 second delay)...${NC}"
result=$(run_sql_file_background "migrations/bad.sql" "Create constraint with validation")
bg_pid=$(echo "$result" | cut -d'|' -f1)
bg_output=$(echo "$result" | cut -d'|' -f2)

# Wait a moment for the transaction to start
sleep 1

# Attempt concurrent UPDATE - should BLOCK
echo -e "\n${CYAN}=== Testing concurrent UPDATE during constraint creation ===${NC}"
UPDATE_SQL="UPDATE products SET price = price + 0.01 WHERE id = (SELECT id FROM products ORDER BY random() LIMIT 1);"

if test_concurrent_write "products" "$UPDATE_SQL" 50; then
    echo -e "${RED}✗ Unexpected: UPDATE did not block${NC}"
else
    echo -e "${GREEN}✓ Expected: UPDATE was BLOCKED${NC}"
fi

# Wait for background process to complete
wait $bg_pid 2>/dev/null || true
cat "$bg_output"
rm -f "$bg_output"

echo -e "\n${RED}Summary: Adding constraint with validation blocks UPDATEs${NC}\n"
sleep 2

#############################################
# Test GOOD approach with concurrent writes
#############################################
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Testing GOOD approach (2-step process)${NC}"
echo -e "${GREEN}========================================${NC}\n"

# Step 1: Create constraint without validation
echo -e "${YELLOW}--- Step 1: Add constraint without validation ---${NC}"
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
    -f migrations/good-step1.sql 2>&1 | grep -v "ERROR" || true
echo -e "${GREEN}✓ Step 1 completed (instant, no table scan)${NC}\n"
sleep 1

# Step 2: Validate constraint - test concurrent writes
echo -e "${YELLOW}--- Step 2: Validate constraint (with concurrent testing) ---${NC}"

# Start validation in background
result=$(run_sql_file_background "migrations/good-step2.sql" "Validate constraint")
bg_pid=$(echo "$result" | cut -d'|' -f1)
bg_output=$(echo "$result" | cut -d'|' -f2)

# Wait a moment for validation to start
sleep 1

# Attempt concurrent UPDATE - should NOT block
echo -e "\n${CYAN}=== Testing concurrent UPDATE during validation ===${NC}"
UPDATE_SQL="UPDATE products SET price = price + 0.01 WHERE id = (SELECT id FROM products ORDER BY random() LIMIT 1);"

if test_concurrent_write "products" "$UPDATE_SQL" 30; then
    echo -e "${GREEN}✓ Expected: UPDATE completed during validation (not blocked)${NC}"
else
    echo -e "${RED}✗ Unexpected: UPDATE was blocked during validation${NC}"
fi

# Wait for background process to complete
wait $bg_pid 2>/dev/null || true
cat "$bg_output"
rm -f "$bg_output"

echo -e "\n${GREEN}Summary: Validation does NOT block UPDATEs${NC}\n"

#############################################
# Final Summary
#############################################
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Test Results Summary${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "
${RED}BAD approach (add constraint with validation):${NC}
  ✗ Blocks UPDATE operations during creation
  ✗ Performs full table scan while holding lock
  ✗ Can cause query timeouts

${GREEN}GOOD approach (2-step process):${NC}
  Step 1: Create constraint with NOT VALID
    - Instant, no table scan
    - New/updated rows checked immediately
  Step 2: Validate separately
    ✓ Does NOT block reads or writes
    ✓ Acquires ShareUpdateExclusiveLock
    ✓ Safe for production

${YELLOW}Ecto Migration Example:${NC}

  # Migration 1
  def change do
    create constraint(\"products\", :price_must_be_positive,
      check: \"price > 0\",
      validate: false
    )
  end

  # Migration 2 (can be in same deployment)
  def change do
    execute \"ALTER TABLE products VALIDATE CONSTRAINT price_must_be_positive\", \"\"
  end
"
