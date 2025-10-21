-- GOOD (Step 2): Validate the constraint
-- This scans the table but doesn't block reads or writes

\timing on

\echo '=== Step 2: Validating the CHECK constraint ==='
\echo 'This performs a full table scan with ShareUpdateExclusiveLock'
\echo 'Reads and writes can continue during validation'

-- Validate the constraint
ALTER TABLE products VALIDATE CONSTRAINT active_not_null;

\echo ''
\echo '=== Constraint validated ==='

-- Verify the constraint is validated
SELECT
    conname,
    contype,
    convalidated
FROM pg_constraint
WHERE conrelid = 'products'::regclass
AND conname = 'active_not_null';

\echo ''
\echo 'Notice: convalidated = true'
