-- GOOD (Step 2): Validate the check constraint
-- This validates existing rows with a lock that allows updates

\timing on

\echo '=== Step 2: Validating the check constraint ==='
\echo 'This performs a full table scan but acquires ShareUpdateExclusiveLock'
\echo 'This lock allows updates to continue during validation'

-- Validate the constraint
-- Acquires ShareUpdateExclusiveLock which doesn't block reads or writes
ALTER TABLE products VALIDATE CONSTRAINT price_must_be_positive_safe;

-- Add a sleep to give concurrent operations time to test
SELECT pg_sleep(2);

\echo ''
\echo '=== Constraint validated ==='
