# Test: Adding a Check Constraint

This test demonstrates the difference between adding a check constraint with and without immediate validation.

## Scenario

We have a `products` table with 100,000 rows, and we want to add a constraint that ensures `price > 0`.

## Bad Approach

```sql
ALTER TABLE products
ADD CONSTRAINT price_must_be_positive
CHECK (price > 0);
```

**Problems:**
- Performs full table scan immediately
- Acquires lock that blocks UPDATE operations
- For large tables, this can block updates for seconds/minutes
- All 100,000 rows must be checked before committing

## Good Approach

### Step 1: Create constraint without validation

```sql
ALTER TABLE products
ADD CONSTRAINT price_must_be_positive
CHECK (price > 0)
NOT VALID;
```

### Step 2: Validate the constraint

```sql
ALTER TABLE products VALIDATE CONSTRAINT price_must_be_positive;
```

**Benefits:**
- Step 1: Commits immediately, no table scan
- Step 2: Scans table but doesn't block updates
- New/updated rows are checked immediately after Step 1
- ShareUpdateExclusiveLock allows concurrent updates

## How It Works

The two-step process separates two operations:

1. **Creating the constraint**: Tells PostgreSQL to check new/updated rows
2. **Validating the constraint**: Verifies existing rows satisfy the constraint

By separating these, we minimize the time that blocking locks are held.

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
# Migration 1: Create constraint without validation
def change do
  create constraint("products", :price_must_be_positive,
    check: "price > 0",
    validate: false
  )
end
```

```elixir
# Migration 2: Validate the constraint
# Can be in the same deployment, just a separate migration
def change do
  execute "ALTER TABLE products VALIDATE CONSTRAINT price_must_be_positive", ""
end
```

## Key Takeaways

1. Check constraints block updates by default during creation
2. Use `NOT VALID` to skip initial validation
3. Validate in a separate migration
4. The validation step doesn't block updates
5. New rows are checked immediately even with NOT VALID
6. Both migrations can be in the same deployment
7. For large tables, this prevents update timeouts
