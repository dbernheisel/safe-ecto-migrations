# Proof: Adding an Index

## What This Test Proves

This test demonstrates that creating an index **without** `CONCURRENTLY` blocks writes, while creating an index **with** `CONCURRENTLY` does not block writes.

## Expected Behavior

### BAD Migration (without CONCURRENTLY)

When running `migrations/bad.sql`:

1. **Lock Acquired**: `ShareLock` on the `posts` table
2. **Effect**: All write operations (INSERT, UPDATE, DELETE) are blocked
3. **Duration**: Blocks for the entire duration of index creation
4. **Observable**: If you try to INSERT into `posts` from another session while the index is being created, the INSERT will wait/block

### GOOD Migration (with CONCURRENTLY)

When running `migrations/good.sql`:

1. **Lock Acquired**: Does not acquire `ShareLock`
2. **Effect**: Write operations (INSERT, UPDATE, DELETE) continue normally
3. **Duration**: Takes longer than non-concurrent, but doesn't block
4. **Observable**: You can INSERT into `posts` from another session while the index is being created without waiting

## How to Verify

### Method 1: Automated Test Script

Run the provided test script:
```bash
docker-compose up -d
./test.sh
docker-compose down -v
```

### Method 2: Manual Verification with Two Sessions

**Terminal 1 (Bad approach):**
```bash
docker-compose up -d
docker exec -it test_adding_index psql -U postgres -d testdb
```

```sql
-- In psql session
\timing on
CREATE INDEX posts_slug_idx ON posts(slug);
```

**Terminal 2 (while index is being created in Terminal 1):**
```bash
docker exec -it test_adding_index psql -U postgres -d testdb
```

```sql
-- Try to insert - this will BLOCK/WAIT
INSERT INTO posts (slug, title) VALUES ('test', 'Test');
```

**Observation**: Terminal 2 will be blocked until the index creation in Terminal 1 completes.

Now test the GOOD approach:

**Terminal 1 (Good approach):**
```sql
DROP INDEX IF EXISTS posts_slug_idx_concurrent;
CREATE INDEX CONCURRENTLY posts_slug_idx_concurrent ON posts(slug);
```

**Terminal 2 (while concurrent index is being created):**
```sql
-- Try to insert - this will NOT block
INSERT INTO posts (slug, title) VALUES ('test2', 'Test 2');
```

**Observation**: Terminal 2 completes immediately without waiting.

### Method 3: Check Lock Information

While creating the index, query the locks from another session:

```sql
SELECT
    c.relname,
    l.mode,
    l.granted,
    a.query
FROM pg_locks l
JOIN pg_class c ON c.oid = l.relation
JOIN pg_stat_activity a ON a.pid = l.pid
WHERE c.relname = 'posts';
```

**Expected for BAD approach:**
- You'll see `ShareLock` on `posts`

**Expected for GOOD approach:**
- You'll see `ShareUpdateExclusiveLock` which doesn't conflict with writes

## Measurements

With 100,000 rows:

**BAD approach:**
- Time: ~1-3 seconds (depending on hardware)
- Lock Type: ShareLock
- Blocks: All writes

**GOOD approach:**
- Time: ~2-5 seconds (takes longer)
- Lock Type: ShareUpdateExclusiveLock
- Blocks: Nothing (writes continue)

## References

- [PostgreSQL CREATE INDEX documentation](https://www.postgresql.org/docs/current/sql-createindex.html)
- [PostgreSQL Explicit Locking](https://www.postgresql.org/docs/current/explicit-locking.html)
