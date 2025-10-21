#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Database connection details
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-postgres}"
DB_NAME="${DB_NAME:-testdb}"

# Execute SQL and measure time
execute_sql() {
    local sql_file=$1
    local description=$2

    echo -e "${YELLOW}Executing: ${description}${NC}"

    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
        -f "$sql_file" \
        -v ON_ERROR_STOP=1 \
        --echo-all

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Success${NC}\n"
    else
        echo -e "${RED}✗ Failed${NC}\n"
        return 1
    fi
}

# Execute SQL command directly
execute_sql_cmd() {
    local sql_cmd=$1
    local description=$2

    echo -e "${YELLOW}Executing: ${description}${NC}"

    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
        -c "$sql_cmd" \
        -v ON_ERROR_STOP=1

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Success${NC}\n"
    else
        echo -e "${RED}✗ Failed${NC}\n"
        return 1
    fi
}

# Show current locks
show_locks() {
    echo -e "${YELLOW}Current locks:${NC}"
    execute_sql_cmd "SELECT * FROM show_locks();" "Show locks"
}

# Wait for postgres to be ready
wait_for_postgres() {
    echo "Waiting for PostgreSQL to be ready..."
    until PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d postgres -c '\q' 2>/dev/null; do
        echo "PostgreSQL is unavailable - sleeping"
        sleep 1
    done
    echo -e "${GREEN}PostgreSQL is ready${NC}\n"
}

# Measure execution time
measure_time() {
    local start=$(date +%s.%N)
    "$@"
    local end=$(date +%s.%N)
    local duration=$(echo "$end - $start" | bc)
    echo -e "${GREEN}Execution time: ${duration}s${NC}"
}

# Run test scenario
run_scenario() {
    local scenario_name=$1
    local sql_file=$2

    echo -e "\n${YELLOW}=== Running: ${scenario_name} ===${NC}\n"
    measure_time execute_sql "$sql_file" "$scenario_name"
}

export -f execute_sql
export -f execute_sql_cmd
export -f show_locks
export -f wait_for_postgres
export -f measure_time
export -f run_scenario
