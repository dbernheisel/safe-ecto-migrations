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

echo -e "${BLUE}=== Testing: Adding an Index ===${NC}\n"

# Wait for postgres
echo "Waiting for PostgreSQL..."
until PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c '\q' 2>/dev/null; do
    sleep 1
done
echo -e "${GREEN}PostgreSQL is ready${NC}\n"

# Test BAD approach
echo -e "${RED}========================================${NC}"
echo -e "${RED}Testing BAD approach (without CONCURRENTLY)${NC}"
echo -e "${RED}========================================${NC}\n"

# Drop index if exists
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
    -c "DROP INDEX IF EXISTS posts_slug_idx;" >/dev/null 2>&1

# Run bad migration
time PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
    -f migrations/bad.sql

echo -e "\n${GREEN}✓ BAD approach completed${NC}\n"
sleep 2

# Test GOOD approach
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Testing GOOD approach (with CONCURRENTLY)${NC}"
echo -e "${GREEN}========================================${NC}\n"

# Drop index if exists
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
    -c "DROP INDEX IF EXISTS posts_slug_idx_concurrent;" >/dev/null 2>&1

# Run good migration
time PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
    -f migrations/good.sql

echo -e "\n${GREEN}✓ GOOD approach completed${NC}\n"

# Show comparison
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Summary${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "
${RED}BAD approach:${NC}
  - Uses CREATE INDEX (without CONCURRENTLY)
  - Acquires ShareLock on the table
  - Blocks all writes (INSERT, UPDATE, DELETE)
  - Can cause timeouts in production

${GREEN}GOOD approach:${NC}
  - Uses CREATE INDEX CONCURRENTLY
  - Does not block writes
  - Takes longer to complete but allows concurrent operations
  - Safe for production use

${YELLOW}Key Differences:${NC}
  1. CONCURRENTLY prevents lock blocking
  2. Cannot be run in a transaction
  3. Requires @disable_ddl_transaction true in Ecto
  4. Requires @disable_migration_lock true OR use advisory locks
"
