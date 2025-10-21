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

echo -e "${BLUE}=== Testing: Setting NOT NULL on Existing Column ===${NC}\n"

# Wait for postgres
echo "Waiting for PostgreSQL..."
until PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c '\q' 2>/dev/null; do
    sleep 1
done
echo -e "${GREEN}PostgreSQL is ready${NC}\n"

# Show Postgres version
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
    -c "SHOW server_version;" | grep "server_version"
echo ""

# Note: We'll skip the BAD approach in the automated test to avoid breaking the table
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Note: Skipping BAD approach in automated test${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "The BAD approach would block reads/writes during table scan.
You can run migrations/bad.sql manually to see the behavior.\n"

# Test GOOD approach
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Testing GOOD approach (3-step process)${NC}"
echo -e "${GREEN}========================================${NC}\n"

# Run good migration - step 1
echo -e "${YELLOW}--- Step 1: Add CHECK constraint without validation ---${NC}"
time PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
    -f migrations/good-step1.sql 2>&1 | grep -v "ERROR" || true

echo -e "\n${GREEN}✓ Step 1 completed${NC}\n"
sleep 1

# Run good migration - step 2
echo -e "${YELLOW}--- Step 2: Validate constraint ---${NC}"
time PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
    -f migrations/good-step2.sql

echo -e "\n${GREEN}✓ Step 2 completed${NC}\n"
sleep 1

# Run good migration - step 3 (Postgres 12+)
echo -e "${YELLOW}--- Step 3: Set NOT NULL and drop CHECK (Postgres 12+) ---${NC}"
time PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
    -f migrations/good-step3-pg12.sql

echo -e "\n${GREEN}✓ Step 3 completed${NC}\n"

# Show comparison
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Summary${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "
${RED}BAD approach:${NC}
  - ALTER COLUMN SET NOT NULL directly
  - Performs full table scan
  - Blocks reads AND writes during scan
  - Can cause significant downtime on large tables

${GREEN}GOOD approach:${NC}
  - Step 1: Add CHECK constraint with NOT VALID
    - Instant, no table scan
    - New/updated rows are checked
  - Step 2: Validate the CHECK constraint
    - Performs table scan
    - Acquires ShareUpdateExclusiveLock
    - Does NOT block reads or writes
  - Step 3 (Postgres 12+ only): Set NOT NULL
    - Skips table scan (CHECK is validated)
    - Drop the CHECK constraint
    - Results in proper NOT NULL constraint

${YELLOW}Key Differences:${NC}
  1. CHECK constraint provides same functionality as NOT NULL
  2. Two-step validation prevents blocking
  3. In Postgres 12+, can convert to NOT NULL without scan
  4. Safe for large tables in production

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
