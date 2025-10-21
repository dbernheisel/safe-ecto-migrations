#!/bin/bash
set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DB_HOST="localhost"
DB_PORT="5432"
DB_USER="postgres"
DB_PASSWORD="postgres"
DB_NAME="testdb"

echo -e "${BLUE}=== Testing: Adding a Check Constraint ===${NC}\n"

# Wait for postgres
echo "Waiting for PostgreSQL..."
until PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c '\q' 2>/dev/null; do
    sleep 1
done
echo -e "${GREEN}PostgreSQL is ready${NC}\n"

# Test BAD approach
echo -e "${RED}========================================${NC}"
echo -e "${RED}Testing BAD approach (with validation)${NC}"
echo -e "${RED}========================================${NC}\n"

# Clean up if exists
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
    -c "ALTER TABLE products DROP CONSTRAINT IF EXISTS price_must_be_positive;" >/dev/null 2>&1

# Run bad migration
time PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
    -f migrations/bad.sql 2>&1 | grep -v "ERROR" || true

echo -e "\n${GREEN}✓ BAD approach completed${NC}\n"
sleep 2

# Test GOOD approach
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Testing GOOD approach (2-step process)${NC}"
echo -e "${GREEN}========================================${NC}\n"

# Clean up if exists
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
    -c "ALTER TABLE products DROP CONSTRAINT IF EXISTS price_must_be_positive_safe;" >/dev/null 2>&1

# Run good migration - step 1
echo -e "${YELLOW}--- Step 1: Add constraint without validation ---${NC}"
time PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
    -f migrations/good-step1.sql 2>&1 | grep -v "ERROR" || true

echo -e "\n${GREEN}✓ Step 1 completed${NC}\n"
sleep 1

# Run good migration - step 2
echo -e "${YELLOW}--- Step 2: Validate constraint ---${NC}"
time PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
    -f migrations/good-step2.sql 2>&1 | grep -v "ERROR" || true

echo -e "\n${GREEN}✓ Step 2 completed${NC}\n"

# Show comparison
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Summary${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "
${RED}BAD approach:${NC}
  - Creates and validates constraint in one step
  - Performs full table scan while holding lock
  - Acquires lock that blocks UPDATE operations
  - All existing rows checked during constraint creation

${GREEN}GOOD approach:${NC}
  - Step 1: Create constraint with NOT VALID
    - Commits immediately without table scan
    - New/updated rows are checked immediately
  - Step 2: Validate constraint separately
    - Performs full table scan
    - Acquires ShareUpdateExclusiveLock
    - Does NOT block reads or writes

${YELLOW}Key Differences:${NC}
  1. Two operations separated: creation + validation
  2. Step 1 is instant, Step 2 doesn't block updates
  3. New data is checked immediately after Step 1
  4. Safe to run both in same deployment

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
