# Safe Ecto Migrations - Docker Compose Tests

This directory contains docker-compose-based tests that demonstrate the concepts covered in the main README. Each test shows both the **unsafe** and **safe** approaches to common migration scenarios.

**Crucially, these tests include concurrent operation testing** to prove blocking behavior - they actually run write operations while migrations are in progress to demonstrate which approaches block and which don't.

## Available Tests

Each test directory contains:
- `docker-compose.yml` - PostgreSQL container configuration
- `init/` - Database initialization scripts
- `migrations/` - SQL files showing BAD and GOOD approaches
- `test.sh` - Automated test runner
- `README.md` - Detailed explanation of the scenario

### Test Scenarios

1. **[01-adding-index](./01-adding-index/)** - Creating indexes without blocking writes
2. **[02-adding-foreign-key](./02-adding-foreign-key/)** - Adding foreign keys safely
3. **[03-adding-column-default](./03-adding-column-default/)** - Adding columns with default values
4. **[04-adding-check-constraint](./04-adding-check-constraint/)** - Adding check constraints without table scans
5. **[05-setting-not-null](./05-setting-not-null/)** - Setting NOT NULL on existing columns
6. **[06-adding-json-column](./06-adding-json-column/)** - Choosing json vs jsonb

## Running Tests

### Prerequisites

- Docker and Docker Compose installed
- `psql` client installed (for test scripts)

### Running Individual Tests

```bash
cd tests/01-adding-index
docker-compose up -d
./test.sh
docker-compose down -v
```

### Running All Tests

From the `tests/` directory:

```bash
./run-all-tests.sh
```

This will:
1. Run each test scenario sequentially
2. Show timing and lock information
3. Clean up containers after each test

## What These Tests Demonstrate

### Concurrent Operation Testing

**The most important feature:** Each test actually runs concurrent write operations while migrations are in progress to prove blocking behavior:

- Tests launch migrations in background processes
- While the migration runs, concurrent writes are attempted
- If the write completes quickly → **not blocked** ✓
- If the write times out → **blocked** ✗

This provides real proof of which approaches block operations and which don't.

### Lock Behavior

Each test shows which PostgreSQL locks are acquired and how they affect concurrent operations:

- **ShareLock** - Blocks writes (INSERT, UPDATE, DELETE)
- **ShareRowExclusiveLock** - Blocks writes on multiple tables
- **ShareUpdateExclusiveLock** - Doesn't block reads or writes
- **AccessExclusiveLock** - Blocks everything

### Performance Impact

The tests use realistic data volumes:
- 100,000 rows for most tables
- Demonstrates actual timing differences
- Shows real-world blocking scenarios

### Safe Migration Patterns

Common patterns demonstrated:
1. **Two-step validation** - Create without validating, then validate separately
2. **CONCURRENTLY keyword** - For index creation
3. **NOT VALID constraints** - Defer validation to avoid locks
4. **Raw SQL execution** - When Ecto helpers are insufficient

## Test Environment

All tests use:
- PostgreSQL 16 (latest stable)
- pg_stat_statements extension for performance metrics
- Lock monitoring enabled
- Realistic data volumes

## Understanding Test Output

### Concurrent Operation Results

Tests show whether concurrent writes were blocked:

```
[Concurrent] Attempting write to posts...
✓ Write completed in 0.15s
```

**vs**

```
[Concurrent] Attempting write to posts...
✗ Write BLOCKED (timed out after 3000ms)
```

### Timing Information

Each test shows execution time for both approaches:
```
Timing is on.
Time: 2543.891 ms (00:02.544)
```

### Test Result Summary

At the end, tests show clear comparisons:

```
BAD approach (CREATE INDEX):
  ✗ Blocks concurrent writes
  ✗ Acquires ShareLock on the table

GOOD approach (CREATE INDEX CONCURRENTLY):
  ✓ Does NOT block concurrent writes
  ✓ Safe for production use
```

## Troubleshooting

### Docker Issues

If containers fail to start:
```bash
# Check Docker is running
docker ps

# Clean up old containers
docker-compose down -v

# Remove all test containers
docker ps -a | grep test_ | awk '{print $1}' | xargs docker rm -f
```

### PostgreSQL Connection Issues

If tests can't connect:
```bash
# Check container logs
docker-compose logs postgres

# Verify container is running
docker-compose ps

# Test connection manually
docker exec -it <container_name> psql -U postgres -d testdb
```

### Port Conflicts

If port 5432 is already in use:
```bash
# Find what's using the port
lsof -i :5432

# Or modify docker-compose.yml to use a different port
ports:
  - "5433:5432"  # Change host port
```

## Contributing

To add a new test scenario:

1. Create a new directory `XX-test-name/`
2. Include all required files (see structure above)
3. Follow the existing test patterns
4. Update this README with the new test
5. Add to `run-all-tests.sh`

## References

- [PostgreSQL Lock Conflicts](https://www.postgresql.org/docs/current/explicit-locking.html)
- [Ecto SQL Migrations](https://hexdocs.pm/ecto_sql/Ecto.Migration.html)
- [Main README](../README.md)

## Credits

Inspired by the fantastic docker-compose testing approach used in:
- [OnGres Blog: Generated Columns vs Triggers](https://gitlab.com/ongresinc/blog-posts-src/-/tree/master/202005-generate_column_vs_trigger)
