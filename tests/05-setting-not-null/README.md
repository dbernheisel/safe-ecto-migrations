# Test: Setting NOT NULL on an Existing Column

This test demonstrates how to safely set NOT NULL on an existing column without blocking table access.

## Scenario

We have a `products` table with 100,000 rows where the `active` column is nullable, but all existing rows have `active = true`. We want to enforce NOT NULL on this column.

## Bad Approach

```sql
ALTER TABLE products ALTER COLUMN active SET NOT NULL;
```

**Problems:**
- Performs a full table scan to verify no NULLs exist
- Blocks reads AND writes during the scan
- On a table with 100 million rows, this could block for 30+ seconds
- Acquires `AccessExclusiveLock`

## Good Approach

This approach uses a CHECK constraint to enforce NOT NULL, which can be added and validated separately.

### Step 1: Add CHECK constraint without validation

```sql
ALTER TABLE products
ADD CONSTRAINT active_not_null
CHECK (active IS NOT NULL)
NOT VALID;
```

**Benefits:**
- Instant, no table scan
- New/updated rows are checked immediately
- Existing rows are not validated yet

### Step 2: Validate the constraint

```sql
ALTER TABLE products VALIDATE CONSTRAINT active_not_null;
```

**Benefits:**
- Scans the table but doesn't block reads or writes
- Acquires `ShareUpdateExclusiveLock`
- Safe for production use

### Step 3 (Postgres 12+ only): Convert to NOT NULL

```sql
ALTER TABLE products ALTER COLUMN active SET NOT NULL;
ALTER TABLE products DROP CONSTRAINT active_not_null;
```

**Benefits:**
- Skips table scan because validated CHECK exists
- Results in a proper NOT NULL constraint
- Optional - CHECK constraint provides same guarantees

## Functional Equivalence

A CHECK constraint `CHECK (column IS NOT NULL)` is functionally equivalent to a NOT NULL constraint:
- Both prevent NULL values
- Both are enforced on INSERT/UPDATE
- Performance is virtually identical

The only difference is semantic - NOT NULL is more explicit in intent.

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
# Migration 1: Add CHECK constraint without validation
def change do
  create constraint("products", :active_not_null,
    check: "active IS NOT NULL",
    validate: false
  )
end
```

```elixir
# Migration 2: Validate the constraint
def change do
  execute "ALTER TABLE products VALIDATE CONSTRAINT active_not_null", ""
end
```

```elixir
# Migration 3 (Postgres 12+ only, optional)
def change do
  execute "ALTER TABLE products ALTER COLUMN active SET NOT NULL",
          "ALTER TABLE products ALTER COLUMN active DROP NOT NULL"

  drop constraint("products", :active_not_null)
end
```

## Important Notes

1. You'll likely need to backfill data first to ensure the constraint is satisfied
2. The CHECK constraint provides the same guarantees as NOT NULL
3. In Postgres 12+, you can convert to NOT NULL without a scan if a validated CHECK exists
4. Do NOT use `modify/3` as it rewrites the table unnecessarily

## Key Takeaways

1. Setting NOT NULL directly blocks reads and writes
2. Use a CHECK constraint instead for safe migration
3. Create with NOT VALID, then validate separately
4. The validation step doesn't block reads or writes
5. In Postgres 12+, can convert to NOT NULL without scan
6. Always backfill data before validating the constraint
