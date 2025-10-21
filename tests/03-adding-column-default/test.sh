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

echo -e "${BLUE}=== Testing: Adding a Column with Default Value ===${NC}\n"

# Wait for postgres
echo "Waiting for PostgreSQL..."
until PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c '\q' 2>/dev/null; do
    sleep 1
done
echo -e "${GREEN}PostgreSQL is ready${NC}\n"

# Show Postgres version
echo -e "${YELLOW}PostgreSQL Version:${NC}"
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
    -c "SELECT version();"
echo ""

# Test BAD approach (non-volatile)
echo -e "${RED}========================================${NC}"
echo -e "${RED}Testing BAD approach (with default)${NC}"
echo -e "${RED}========================================${NC}\n"

# Run bad migration
time PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
    -f migrations/bad.sql

echo -e "\n${GREEN}✓ BAD approach completed${NC}"
echo -e "${YELLOW}Note: In Postgres 11+, this is actually safe for non-volatile defaults${NC}"
echo -e "${YELLOW}But in Postgres < 11, this would rewrite the entire table${NC}\n"
sleep 2

# Test BAD approach (volatile)
echo -e "${RED}========================================${NC}"
echo -e "${RED}Testing BAD approach (volatile default)${NC}"
echo -e "${RED}========================================${NC}\n"

# Run bad volatile migration
time PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
    -f migrations/bad-volatile.sql

echo -e "\n${GREEN}✓ BAD (volatile) approach completed${NC}"
echo -e "${RED}This ALWAYS rewrites the table, even in Postgres 11+${NC}\n"
sleep 2

# Test GOOD approach
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Testing GOOD approach (2-step process)${NC}"
echo -e "${GREEN}========================================${NC}\n"

# Run good migration - step 1
echo -e "${YELLOW}--- Step 1: Add column without default ---${NC}"
time PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
    -f migrations/good-step1.sql

echo -e "\n${GREEN}✓ Step 1 completed${NC}\n"
sleep 1

# Run good migration - step 2
echo -e "${YELLOW}--- Step 2: Set default value ---${NC}"
time PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
    -f migrations/good-step2.sql

echo -e "\n${GREEN}✓ Step 2 completed${NC}\n"

# Show comparison
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Summary${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "
${RED}BAD approach:${NC}
  - Add column with default in one step
  - Postgres < 11: Rewrites table, blocks reads/writes
  - Postgres 11+: Safe for non-volatile defaults (like false, 0, 'text')
  - ANY version: Volatile defaults (NOW(), gen_random_uuid()) always rewrite

${GREEN}GOOD approach:${NC}
  - Step 1: Add column without default (very fast)
  - Step 2: Set default value (very fast)
  - Works safely in all Postgres versions
  - No table rewrite, minimal blocking

${YELLOW}Important Notes:${NC}
  1. The safe method does NOT materialize defaults for existing rows
  2. Existing rows will have NULL (unless you backfill)
  3. Ecto will apply the default when reading records
  4. New inserts will get the default value
  5. If you need to materialize values, see Backfilling guide

${YELLOW}Postgres Version Compatibility:${NC}
  - Postgres 11+: Non-volatile defaults are safe
  - Postgres < 11: All defaults cause table rewrite
  - All versions: Volatile defaults always rewrite
  - Use 2-step approach for maximum compatibility

${YELLOW}Ecto Migration Example:${NC}

  # Migration 1
  def change do
    alter table(\"comments\") do
      add :approved, :boolean
    end
  end

  # Migration 2
  def change do
    execute \"ALTER TABLE comments ALTER COLUMN approved SET DEFAULT false\",
            \"ALTER TABLE comments ALTER COLUMN approved DROP DEFAULT\"
  end

  # In schema
  schema \"comments\" do
    field :approved, :boolean, default: false
  end
"
