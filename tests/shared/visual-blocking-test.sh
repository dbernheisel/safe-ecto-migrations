#!/bin/bash

# Visual blocking test - shows continuous activity that freezes during blocking operations

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Database connection
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-postgres}"
DB_NAME="${DB_NAME:-testdb}"

# Counter for activity display
ACTIVITY_COUNTER=0
ACTIVITY_PID=""

# Start continuous read/write activity on a table
start_activity_monitor() {
    local table=$1
    local activity_type=$2  # "read", "write", or "both"

    echo -e "${CYAN}${BOLD}Starting continuous ${activity_type} activity on ${table}...${NC}"
    echo ""

    # Create a background process that continuously reads/writes
    (
        counter=0
        last_second=$SECONDS
        ops_this_second=0

        while true; do
            counter=$((counter + 1))

            current_second=$SECONDS
            if [ $current_second -ne $last_second ]; then
                ops_this_second=$((counter - ops_this_second))
                last_second=$current_second
            fi

            # Overwrite the same line with timestamp to show when it freezes
            local timestamp=$(date +%H:%M:%S)
            printf "\r${GREEN}[Activity %s] ${activity_type}: %d ops/sec | Total: %d | Status: RUNNING ✓${NC}    " \
                   "$timestamp" $ops_this_second $counter

            case $activity_type in
                read)
                    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
                        -c "SELECT COUNT(*) FROM $table;" >/dev/null 2>&1
                    ;;
                write)
                    # Use INSERT instead of UPDATE to avoid needing updated_at column
                    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
                        -c "INSERT INTO $table (slug, title, content) VALUES ('monitor-write', 'Activity Monitor', 'Test') ON CONFLICT DO NOTHING;" >/dev/null 2>&1
                    ;;
                both)
                    if [ $((counter % 2)) -eq 0 ]; then
                        PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
                            -c "SELECT COUNT(*) FROM $table;" >/dev/null 2>&1
                    else
                        PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
                            -c "INSERT INTO $table (slug, title, content) VALUES ('monitor-write-' || floor(random() * 1000000), 'Activity Monitor', 'Test');" >/dev/null 2>&1
                    fi
                    ;;
            esac

            # Small delay to make it readable
            sleep 0.1
        done
    ) &

    ACTIVITY_PID=$!

    # Give it a moment to start
    sleep 1
}

# Stop the activity monitor
stop_activity_monitor() {
    if [ -n "$ACTIVITY_PID" ]; then
        kill $ACTIVITY_PID 2>/dev/null
        wait $ACTIVITY_PID 2>/dev/null || true
        echo ""
        echo -e "${YELLOW}Activity monitor stopped${NC}"
    fi
}

# Run a blocking operation and observe the effect
run_blocking_operation() {
    local description=$1
    local sql_file=$2
    local expect_blocking=$3  # "blocks" or "no-block"

    echo ""
    echo -e "${BOLD}${YELLOW}========================================${NC}"
    echo -e "${BOLD}${YELLOW}Testing: ${description}${NC}"
    echo -e "${BOLD}${YELLOW}========================================${NC}"
    echo ""

    # Give activity time to show it's running
    sleep 2

    echo -e "${CYAN}Executing: ${description}${NC}"
    echo -e "${CYAN}Watch the activity counter above...${NC}"
    echo ""

    if [ "$expect_blocking" = "blocks" ]; then
        echo -e "${RED}${BOLD}⚠ Expected: Activity should FREEZE during this operation${NC}"
    else
        echo -e "${GREEN}${BOLD}✓ Expected: Activity should CONTINUE during this operation${NC}"
    fi

    echo ""
    sleep 1

    # Run the operation (which may block the activity)
    local start=$SECONDS
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
        -f "$sql_file" 2>&1 | grep -E "(Time:|CREATE|ALTER)" || true
    local duration=$((SECONDS - start))

    echo ""
    echo -e "${GREEN}Operation completed in ${duration}s${NC}"

    # Give activity time to resume/continue
    sleep 2
    echo ""
}

# Visual test with blocking detection
visual_blocking_test() {
    local table=$1
    local activity_type=$2
    local operation_description=$3
    local sql_file=$4
    local expect_blocking=$5

    echo -e "\n${BLUE}${BOLD}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}${BOLD}  VISUAL BLOCKING TEST${NC}"
    echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════${NC}\n"

    start_activity_monitor "$table" "$activity_type"

    sleep 3

    run_blocking_operation "$operation_description" "$sql_file" "$expect_blocking"

    sleep 2

    stop_activity_monitor

    echo ""
    if [ "$expect_blocking" = "blocks" ]; then
        echo -e "${YELLOW}${BOLD}Review:${NC}"
        echo -e "  - Did the activity counter FREEZE during the operation? ${RED}(It should!)${NC}"
        echo -e "  - Did it RESUME after the operation completed? ${GREEN}(It should!)${NC}"
    else
        echo -e "${YELLOW}${BOLD}Review:${NC}"
        echo -e "  - Did the activity counter CONTINUE during the operation? ${GREEN}(It should!)${NC}"
        echo -e "  - Activity should never freeze ${GREEN}(even briefly)${NC}"
    fi
    echo ""
}

# Export functions
export -f start_activity_monitor
export -f stop_activity_monitor
export -f run_blocking_operation
export -f visual_blocking_test
