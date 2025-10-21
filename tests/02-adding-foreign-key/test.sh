#!/bin/bash
set -e

# Source the concurrent testing helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../shared/concurrent-test-helpers.sh"

echo -e "${BLUE}=== Testing: Adding a Foreign Key ===${NC}\n"

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

# Start the FK creation in background
echo -e "${YELLOW}Starting FK creation with validation (with 3 second delay)...${NC}"
result=$(run_sql_file_background "migrations/bad.sql" "Create FK with validation")
bg_pid=$(echo "$result" | cut -d'|' -f1)
bg_output=$(echo "$result" | cut -d'|' -f2)

# Wait a moment for the transaction to start
sleep 1

# Test 1: Attempt concurrent write to posts - should BLOCK
echo -e "\n${CYAN}=== Test 1: Concurrent write to posts table ===${NC}"
INSERT_SQL="INSERT INTO posts (title, content) VALUES ('Test Post ' || floor(random() * 1000000), 'Test Content');"

if test_concurrent_write "posts" "$INSERT_SQL" 50; then
    echo -e "${RED}✗ Unexpected: Write to posts did not block${NC}"
else
    echo -e "${GREEN}✓ Expected: Write to posts was BLOCKED${NC}"
fi

# Test 2: Attempt concurrent write to groups - should ALSO BLOCK
echo -e "\n${CYAN}=== Test 2: Concurrent write to groups table ===${NC}"
INSERT_SQL="INSERT INTO groups (name) VALUES ('Test Group ' || floor(random() * 1000000));"

if test_concurrent_write "groups" "$INSERT_SQL" 50; then
    echo -e "${RED}✗ Unexpected: Write to groups did not block${NC}"
else
    echo -e "${GREEN}✓ Expected: Write to groups was ALSO BLOCKED${NC}"
fi

# Wait for background process to complete
wait $bg_pid 2>/dev/null || true
cat "$bg_output"
rm -f "$bg_output"

echo -e "\n${RED}Summary: Adding FK with validation blocks BOTH tables${NC}\n"
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
    -f migrations/good-step1.sql
echo -e "${GREEN}✓ Step 1 completed (brief blocking)${NC}\n"
sleep 1

# Step 2: Validate constraint - test concurrent writes
echo -e "${YELLOW}--- Step 2: Validate constraint (with concurrent testing) ---${NC}"

# Start validation in background
result=$(run_sql_file_background "migrations/good-step2.sql" "Validate FK constraint")
bg_pid=$(echo "$result" | cut -d'|' -f1)
bg_output=$(echo "$result" | cut -d'|' -f2)

# Wait a moment for validation to start
sleep 1

# Test: Attempt concurrent write to posts - should NOT block
echo -e "\n${CYAN}=== Test: Concurrent write during validation ===${NC}"
INSERT_SQL="INSERT INTO posts (title, content, group_id_safe) VALUES ('Test Post ' || floor(random() * 1000000), 'Test Content', 1);"

if test_concurrent_write "posts" "$INSERT_SQL" 30; then
    echo -e "${GREEN}✓ Expected: Write completed during validation (not blocked)${NC}"
else
    echo -e "${RED}✗ Unexpected: Write was blocked during validation${NC}"
fi

# Wait for background process to complete
wait $bg_pid 2>/dev/null || true
cat "$bg_output"
rm -f "$bg_output"

echo -e "\n${GREEN}Summary: Validation does NOT block reads or writes${NC}\n"

#############################################
# Final Summary
#############################################
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Test Results Summary${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "
${RED}BAD approach (add FK with validation):${NC}
  ✗ Blocks writes to BOTH tables
  ✗ Blocks for entire duration of constraint creation + validation
  ✗ Can cause significant application downtime

${GREEN}GOOD approach (2-step process):${NC}
  Step 1: Add constraint with NOT VALID
    - Brief blocking (milliseconds)
    - New/updated rows checked immediately
  Step 2: Validate separately
    ✓ Does NOT block reads or writes
    ✓ Safe for production with large tables

${YELLOW}Ecto Migration Example:${NC}

  # Migration 1
  def change do
    alter table(\"posts\") do
      add :group_id, references(\"groups\", validate: false)
    end
  end

  # Migration 2 (can be in same deployment)
  def change do
    execute \"ALTER TABLE posts VALIDATE CONSTRAINT posts_group_id_fkey\", \"\"
  end
"
