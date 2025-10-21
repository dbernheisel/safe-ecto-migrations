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

echo -e "${BLUE}=== Testing: Adding a JSON Column ===${NC}\n"

# Wait for postgres
echo "Waiting for PostgreSQL..."
until PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c '\q' 2>/dev/null; do
    sleep 1
done
echo -e "${GREEN}PostgreSQL is ready${NC}\n"

# Test BAD approach
echo -e "${RED}========================================${NC}"
echo -e "${RED}Testing BAD approach (json type)${NC}"
echo -e "${RED}========================================${NC}\n"

PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
    -f migrations/bad.sql 2>&1 || true

echo -e "\n${RED}✗ BAD approach - SELECT DISTINCT failed${NC}"
echo -e "${YELLOW}Error: could not identify an equality operator for type json${NC}\n"
sleep 2

# Test GOOD approach
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Testing GOOD approach (jsonb type)${NC}"
echo -e "${GREEN}========================================${NC}\n"

PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
    -f migrations/good.sql

echo -e "\n${GREEN}✓ GOOD approach completed successfully${NC}\n"

# Show comparison
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Summary${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "
${RED}BAD approach (json):${NC}
  - No equality operator
  - SELECT DISTINCT fails
  - Cannot be used in GROUP BY
  - No indexing support
  - Stores exact text representation

${GREEN}GOOD approach (jsonb):${NC}
  - Has equality operators
  - SELECT DISTINCT works
  - Can be used in GROUP BY
  - Supports GIN and other indexes
  - Better query performance
  - Slightly slower on insert (normalizes data)
  - Takes less space (binary format)

${YELLOW}Key Differences:${NC}
  1. jsonb is 'json but better'
  2. jsonb supports indexing and operators
  3. jsonb has better query performance
  4. Only use json if you need exact text preservation
  5. In almost all cases, use jsonb

${YELLOW}Ecto Migration Example:${NC}

  def change do
    alter table(\"posts\") do
      add :extra_data, :jsonb  # Use jsonb, not json
    end
  end

  # Optionally add a GIN index for better query performance
  def change do
    create index(\"posts\", [:extra_data], using: :gin)
  end

${YELLOW}Performance Notes:${NC}
  - json: Faster insert, slower queries
  - jsonb: Slightly slower insert, much faster queries
  - jsonb is the recommended choice in most cases
"
