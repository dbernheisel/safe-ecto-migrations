#!/bin/bash

# Concurrent testing helpers for demonstrating blocking behavior

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Database connection defaults
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-postgres}"
DB_NAME="${DB_NAME:-testdb}"

# Run SQL in background and return PID
run_sql_background() {
    local sql_cmd="$1"
    local description="$2"
    local output_file=$(mktemp)

    echo -e "${CYAN}[Background] Starting: $description${NC}"

    # Run in background and capture PID
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
        -c "$sql_cmd" > "$output_file" 2>&1 &

    local pid=$!
    echo "$pid|$output_file"
}

# Run SQL from file in background
run_sql_file_background() {
    local sql_file="$1"
    local description="$2"
    local output_file=$(mktemp)

    echo -e "${CYAN}[Background] Starting: $description${NC}"

    # Run in background and capture PID
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
        -f "$sql_file" > "$output_file" 2>&1 &

    local pid=$!
    echo "$pid|$output_file"
}

# Check if background process is still running
is_running() {
    local pid=$1
    kill -0 "$pid" 2>/dev/null
}

# Wait for background process with timeout
wait_with_timeout() {
    local pid=$1
    local timeout=$2
    local elapsed=0

    while is_running "$pid"; do
        if [ $elapsed -ge $timeout ]; then
            return 1  # Timeout
        fi
        sleep 0.1
        elapsed=$((elapsed + 1))
    done
    return 0  # Completed
}

# Test concurrent write while operation is running
test_concurrent_write() {
    local table="$1"
    local insert_sql="$2"
    local timeout="${3:-30}"  # 3 second timeout (30 * 0.1s)

    echo -e "${YELLOW}[Concurrent] Attempting write to $table...${NC}"

    local start=$(date +%s.%N)
    local result=$(run_sql_background "$insert_sql" "Concurrent write")
    local pid=$(echo "$result" | cut -d'|' -f1)
    local output_file=$(echo "$result" | cut -d'|' -f2)

    if wait_with_timeout "$pid" "$timeout"; then
        local end=$(date +%s.%N)
        local duration=$(echo "$end - $start" | bc)
        echo -e "${GREEN}✓ Write completed in ${duration}s${NC}"
        rm -f "$output_file"
        return 0
    else
        echo -e "${RED}✗ Write BLOCKED (timed out after ${timeout}00ms)${NC}"
        kill -9 "$pid" 2>/dev/null
        wait "$pid" 2>/dev/null
        rm -f "$output_file"
        return 1
    fi
}

# Show current locks on a table
show_table_locks() {
    local table="$1"

    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
        -c "SELECT
                l.pid,
                c.relname as table,
                l.mode,
                l.granted,
                a.query_start,
                substring(a.query, 1, 60) as query
            FROM pg_locks l
            LEFT JOIN pg_class c ON c.oid = l.relation
            LEFT JOIN pg_stat_activity a ON a.pid = l.pid
            WHERE c.relname = '$table'
            ORDER BY l.granted DESC, l.mode;" 2>/dev/null || true
}

# Show blocking queries
show_blocking_queries() {
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
        -c "SELECT
                blocked_locks.pid AS blocked_pid,
                blocked_activity.usename AS blocked_user,
                blocking_locks.pid AS blocking_pid,
                blocking_activity.usename AS blocking_user,
                blocked_activity.query AS blocked_statement,
                blocking_activity.query AS blocking_statement
            FROM pg_catalog.pg_locks blocked_locks
            JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
            JOIN pg_catalog.pg_locks blocking_locks
                ON blocking_locks.locktype = blocked_locks.locktype
                AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
                AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
                AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
                AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
                AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
                AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
                AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
                AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
                AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
                AND blocking_locks.pid != blocked_locks.pid
            JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
            WHERE NOT blocked_locks.granted;" 2>/dev/null || true
}

# Wait for PostgreSQL to be ready with timeout
wait_for_postgres() {
    local max_attempts="${1:-60}"  # Default 60 seconds
    local attempt=0

    echo "Waiting for PostgreSQL (timeout: ${max_attempts}s)..."

    while [ $attempt -lt $max_attempts ]; do
        if PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c '\q' 2>/dev/null; then
            echo -e "${GREEN}PostgreSQL is ready${NC}"
            return 0
        fi

        attempt=$((attempt + 1))
        if [ $((attempt % 10)) -eq 0 ]; then
            echo "Still waiting for PostgreSQL... (${attempt}s)"
        fi
        sleep 1
    done

    echo -e "${RED}ERROR: PostgreSQL did not become ready within ${max_attempts} seconds${NC}"
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo "  1. Check if Docker is running: docker ps"
    echo "  2. Check container logs: docker compose logs postgres"
    echo "  3. Verify container is running: docker compose ps"
    return 1
}

# Clean up background processes
cleanup_background() {
    local pid=$1
    if is_running "$pid"; then
        echo -e "${YELLOW}Cleaning up background process $pid${NC}"
        kill -9 "$pid" 2>/dev/null
        wait "$pid" 2>/dev/null || true
    fi
}

export -f run_sql_background
export -f run_sql_file_background
export -f is_running
export -f wait_with_timeout
export -f test_concurrent_write
export -f show_table_locks
export -f show_blocking_queries
export -f wait_for_postgres
export -f cleanup_background
