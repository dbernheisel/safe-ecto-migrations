# Test: Adding an Index

This test demonstrates the difference between creating an index with and without the `CONCURRENTLY` option in PostgreSQL.

## Scenario

We have a `posts` table with 100,000 rows, and we want to add an index on the `slug` column.

## Bad Approach

```sql
CREATE INDEX posts_slug_idx ON posts(slug);
```

**Problems:**
- Acquires a `ShareLock` on the table
- Blocks all writes (INSERT, UPDATE, DELETE) while the index is being built
- Can cause timeouts and application errors in production
- For 100,000 rows, this might take several seconds during which writes are blocked

## Good Approach

```sql
CREATE INDEX CONCURRENTLY posts_slug_idx ON posts(slug);
```

**Benefits:**
- Does not block writes
- Allows concurrent INSERT, UPDATE, DELETE operations
- Safe for production use
- Takes longer to complete but doesn't impact application availability

## Running the Test

1. Start the PostgreSQL container:
```bash
docker-compose up -d
```

2. Run the test script:
```bash
chmod +x test.sh
./test.sh
```

3. Clean up:
```bash
docker-compose down -v
```

## Ecto Migration Example

```elixir
# Option 1: Using advisory locks (recommended)
# in config/config.exs
config MyApp.Repo, migration_lock: :pg_advisory_lock

# in the migration
@disable_ddl_transaction true

def change do
  create index("posts", [:slug], concurrently: true)
end
```

```elixir
# Option 2: Disable migration lock
@disable_ddl_transaction true
@disable_migration_lock true

def change do
  create index("posts", [:slug], concurrently: true)
end
```

## Key Takeaways

1. Always use `CONCURRENTLY` when creating indexes on existing tables in production
2. The migration must disable DDL transactions (`@disable_ddl_transaction true`)
3. Consider using advisory locks for safer concurrent migration execution
4. The operation takes longer but prevents blocking writes
5. Do not include other changes in the same migration
