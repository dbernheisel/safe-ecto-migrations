-- GOOD (Step 2): Validate the constraint
-- This scans the table but doesn't block reads or writes

\timing on

\echo '=== Step 2: Validating the CHECK constraint ==='
\echo 'This performs a full table scan with ShareUpdateExclusiveLock'
\echo 'Reads and writes can continue during validation'

-- Validate the constraint
ALTER TABLE products VALIDATE CONSTRAINT active_not_null;

-- Add a sleep to give concurrent operations time to test
SELECT pg_sleep(2);

\echo ''
\echo '=== Constraint validated ==='
