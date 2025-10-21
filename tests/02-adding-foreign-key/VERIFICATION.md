# Proof: Adding a Foreign Key

## What This Test Proves

This test demonstrates that adding a foreign key **with immediate validation** blocks writes on BOTH tables, while adding it **without validation** and validating separately minimizes blocking.

## Expected Behavior

### BAD Migration (with immediate validation)

When running `migrations/bad.sql`:

1. **Lock Acquired**: `ShareRowExclusiveLock` on BOTH `posts` and `groups` tables
2. **Effect**: All writes to both tables are blocked during validation
3. **Duration**: Blocks while creating AND validating the constraint
4. **Observable**: INSERT/UPDATE/DELETE on either table will block

### GOOD Migration (two-step process)

**Step 1** (`migrations/good-step1.sql`):
1. **Lock Acquired**: Brief `ShareRowExclusiveLock`
2. **Effect**: Very brief blocking, no validation of existing rows
3. **Constraint State**: Created but `NOT VALID`
4. **Observable**: New/updated rows are checked, existing rows are not yet validated

**Step 2** (`migrations/good-step2.sql`):
1. **Lock Acquired**: `ShareUpdateExclusiveLock`
2. **Effect**: Does NOT block reads or writes
3. **Constraint State**: Now fully validated
4. **Observable**: You can INSERT/UPDATE while validation runs

## How to Verify

### Method 1: Check Constraint Validation Status

```sql
SELECT
    conname,
    contype,
    convalidated
FROM pg_constraint
WHERE conrelid = 'posts'::regclass
AND conname LIKE '%group%';
```

**After Step 1:**
- `convalidated = false` (not yet validated)

**After Step 2:**
- `convalidated = true` (fully validated)

### Method 2: Observe Locks During Operations

```sql
-- While constraint is being created/validated
SELECT
    c.relname,
    l.mode,
    l.granted
FROM pg_locks l
LEFT JOIN pg_class c ON c.oid = l.relation
WHERE c.relname IN ('posts', 'groups')
ORDER BY c.relname, l.mode;
```

**BAD approach shows:**
- `ShareRowExclusiveLock` on both tables
- Blocks INSERT/UPDATE/DELETE

**GOOD approach (Step 2) shows:**
- `ShareUpdateExclusiveLock`
- Does NOT conflict with writes

### Method 3: Concurrent Write Test

**Terminal 1:**
```sql
-- Start the BAD approach
ALTER TABLE posts ADD COLUMN group_id INTEGER REFERENCES groups(id);
```

**Terminal 2 (during the operation above):**
```sql
-- This will BLOCK
INSERT INTO posts (title, content) VALUES ('Test', 'Content');
-- This will also BLOCK
INSERT INTO groups (name) VALUES ('New Group');
```

Now test GOOD approach:

**Terminal 1:**
```sql
-- Step 2: Validate constraint
ALTER TABLE posts VALIDATE CONSTRAINT posts_group_id_safe_fkey;
```

**Terminal 2 (during validation):**
```sql
-- These will NOT block
INSERT INTO posts (title, content, group_id_safe) VALUES ('Test', 'Content', 1);
INSERT INTO groups (name) VALUES ('New Group');
```

## Measurements

With 100,000 rows in `posts` and 1,000 in `groups`:

**BAD approach:**
- Time: ~500ms-2s
- Locks: Both tables blocked for entire duration
- Impact: Both tables unavailable for writes

**GOOD approach:**
- Step 1 Time: ~10-50ms
- Step 2 Time: ~500ms-2s (but no blocking!)
- Locks: Step 1 briefly blocks, Step 2 doesn't block
- Impact: Minimal disruption

## Why This Matters

For a table with 100 million rows:
- BAD approach: Both tables blocked for 30-60 seconds
- GOOD approach: Step 1 blocks for <100ms, Step 2 doesn't block writes

The GOOD approach allows your application to continue serving requests during validation.

## References

- [PostgreSQL ADD FOREIGN KEY documentation](https://www.postgresql.org/docs/current/sql-altertable.html)
- [PostgreSQL NOT VALID constraints](https://www.postgresql.org/docs/current/sql-altertable.html#SQL-ALTERTABLE-DESC-ADD-TABLE-CONSTRAINT)
