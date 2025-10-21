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

echo -e "${BLUE}=== Testing: Adding a Foreign Key ===${NC}\n"

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
    -c "ALTER TABLE posts DROP COLUMN IF EXISTS group_id CASCADE;" >/dev/null 2>&1

# Run bad migration
time PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
    -f migrations/bad.sql

echo -e "\n${GREEN}✓ BAD approach completed${NC}\n"
sleep 2

# Test GOOD approach
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Testing GOOD approach (2-step process)${NC}"
echo -e "${GREEN}========================================${NC}\n"

# Clean up if exists
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
    -c "ALTER TABLE posts DROP COLUMN IF EXISTS group_id_safe CASCADE;" >/dev/null 2>&1

# Run good migration - step 1
echo -e "${YELLOW}--- Step 1: Add constraint without validation ---${NC}"
time PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
    -f migrations/good-step1.sql

echo -e "\n${GREEN}✓ Step 1 completed${NC}\n"
sleep 1

# Run good migration - step 2
echo -e "${YELLOW}--- Step 2: Validate constraint ---${NC}"
time PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
    -f migrations/good-step2.sql

echo -e "\n${GREEN}✓ Step 2 completed${NC}\n"

# Show comparison
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Summary${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "
${RED}BAD approach:${NC}
  - Adds foreign key with immediate validation
  - Acquires ShareRowExclusiveLock on BOTH tables
  - Blocks writes to both posts AND groups tables
  - Validation happens during constraint creation
  - Can cause significant downtime

${GREEN}GOOD approach:${NC}
  - Step 1: Add constraint with NOT VALID
    - Briefly blocks writes but doesn't validate existing rows
    - New/updated rows will be checked immediately
  - Step 2: Validate constraint separately
    - Acquires ShareUpdateExclusiveLock
    - Does NOT block reads or writes
    - Can be done in separate deployment

${YELLOW}Key Differences:${NC}
  1. Two-step process minimizes lock time
  2. Step 1 obtains brief lock, Step 2 no blocking
  3. Can deploy in same release, just separate migrations
  4. Much safer for production with large tables

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
