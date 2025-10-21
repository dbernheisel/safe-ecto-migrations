# Test: Adding a Foreign Key

This test demonstrates the difference between adding a foreign key with and without immediate validation.

## Scenario

We have two tables:
- `groups` with 1,000 rows
- `posts` with 100,000 rows

We want to add a `group_id` column to `posts` that references `groups(id)`.

## Bad Approach

```sql
ALTER TABLE posts ADD COLUMN group_id INTEGER REFERENCES groups(id);
```

**Problems:**
- Acquires `ShareRowExclusiveLock` on BOTH tables
- Blocks writes to both `posts` and `groups`
- Validates all existing rows during constraint creation
- For large tables, this can block writes for seconds or minutes

## Good Approach

### Step 1: Add constraint without validation

```sql
ALTER TABLE posts ADD COLUMN group_id INTEGER;
ALTER TABLE posts
ADD CONSTRAINT posts_group_id_fkey
FOREIGN KEY (group_id)
REFERENCES groups(id)
NOT VALID;
```

### Step 2: Validate the constraint (separate migration)

```sql
ALTER TABLE posts VALIDATE CONSTRAINT posts_group_id_fkey;
```

**Benefits:**
- Step 1: Brief lock, no validation of existing rows
- Step 2: No blocking locks, reads and writes continue
- New/updated rows are validated immediately after Step 1
- Much safer for production deployments

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
# Migration 1: Add column with unvalidated constraint
def change do
  alter table("posts") do
    add :group_id, references("groups", validate: false)
  end
end
```

```elixir
# Migration 2: Validate the constraint
# This can be in the same deployment but must be a separate migration
def change do
  execute "ALTER TABLE posts VALIDATE CONSTRAINT posts_group_id_fkey", ""
end
```

## Key Takeaways

1. Adding a foreign key blocks writes on BOTH tables by default
2. Use `validate: false` to create the constraint without validation
3. Validate in a separate migration using `ALTER TABLE ... VALIDATE CONSTRAINT`
4. The validation step doesn't block reads or writes
5. Both migrations can be in the same deployment
6. For empty tables, the difference may be negligible
7. For tables with 100M+ rows, the difference becomes critical
