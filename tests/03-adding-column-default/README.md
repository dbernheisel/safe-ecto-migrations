# Test: Adding a Column with a Default Value

This test demonstrates the difference between adding a column with a default value in one step versus two steps.

## Scenario

We have a `comments` table with 100,000 rows, and we want to add an `approved` boolean column with a default value of `false`.

## Postgres Version Considerations

**Postgres 11+:**
- Non-volatile defaults (like `false`, `0`, `'text'`) are safe
- Volatile defaults (like `NOW()`, `gen_random_uuid()`) still cause table rewrites

**Postgres < 11:**
- ALL defaults cause table rewrites
- Rewrites block reads and writes

## Bad Approach

```sql
ALTER TABLE comments ADD COLUMN approved BOOLEAN DEFAULT false;
```

**Problems:**
- Postgres < 11: Rewrites entire table, blocks reads and writes
- ANY version with volatile defaults: Rewrites table
- Can take minutes for large tables
- Acquires `AccessExclusiveLock`

## Good Approach

### Step 1: Add column without default

```sql
ALTER TABLE comments ADD COLUMN approved BOOLEAN;
```

### Step 2: Set default value

```sql
ALTER TABLE comments ALTER COLUMN approved SET DEFAULT false;
```

**Benefits:**
- Fast in all Postgres versions
- No table rewrite
- Minimal locking
- Works with both volatile and non-volatile defaults

## Important Notes

The two-step approach does **NOT** materialize the default value for existing rows:

- Existing rows will have `NULL` for the column
- New `INSERT` operations will get the default value
- Ecto will apply the default when reading records
- If you need to materialize values, you must backfill separately

## Running the Test

Simply run:
```bash
./run.sh
```

This script will:
1. Start the PostgreSQL container
2. Run the test inside the container
3. Clean up automatically

No need to manage Docker or PostgreSQL manually!
## Ecto Migration Example

```elixir
# Migration 1: Add column without default
def change do
  alter table("comments") do
    add :approved, :boolean
  end
end
```

```elixir
# Migration 2: Set default value
def change do
  execute "ALTER TABLE comments ALTER COLUMN approved SET DEFAULT false",
          "ALTER TABLE comments ALTER COLUMN approved DROP DEFAULT"
end
```

```elixir
# Schema: Include default in schema definition
schema "comments" do
  field :approved, :boolean, default: false
end
```

## Why Not Use modify/3?

Do NOT use `modify/3` as it includes updating the column type, causing Postgres to rewrite the table unnecessarily:

```elixir
# DON'T DO THIS
def change do
  alter table("comments") do
    modify :approved, :boolean, default: false  # This rewrites the table!
  end
end
```

## Key Takeaways

1. Use two-step process for maximum safety
2. Step 1: Add column without default
3. Step 2: Set default using raw SQL
4. The default is NOT materialized for existing rows
5. Ecto applies the default on read
6. For materialization, use a separate backfill migration
7. Avoid `modify/3` for setting defaults
