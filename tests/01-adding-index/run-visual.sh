#!/bin/bash
set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${BLUE}Starting PostgreSQL container...${NC}"
docker compose up -d

echo -e "${YELLOW}Waiting for PostgreSQL to be ready inside container...${NC}"

# Wait for postgres to be ready
attempt=0
max_attempts=60
until docker compose exec -T postgres pg_isready -U postgres >/dev/null 2>&1; do
    if [ $attempt -ge $max_attempts ]; then
        echo -e "${RED}ERROR: PostgreSQL did not become ready within ${max_attempts} seconds${NC}"
        echo "Container logs:"
        docker compose logs
        exit 1
    fi
    attempt=$((attempt + 1))
    if [ $((attempt % 10)) -eq 0 ]; then
        echo "Still waiting... (${attempt}s)"
    fi
    sleep 1
done

echo -e "${GREEN}PostgreSQL is ready!${NC}\n"

# Run the VISUAL test inside the container
echo -e "${BLUE}Running VISUAL blocking demonstration inside container...${NC}\n"
docker compose exec -T postgres bash /test/test-visual.sh

exit_code=$?

# Cleanup
echo -e "\n${YELLOW}Cleaning up...${NC}"
docker compose down -v

if [ $exit_code -eq 0 ]; then
    echo -e "${GREEN}Visual test completed successfully!${NC}"
else
    echo -e "${RED}Visual test failed with exit code $exit_code${NC}"
fi

exit $exit_code
