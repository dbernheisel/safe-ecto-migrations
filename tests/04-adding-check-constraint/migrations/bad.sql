-- BAD: Adding a check constraint with validation
-- This performs a full table scan and blocks updates

\timing on

\echo '=== Adding check constraint WITH validation ==='
\echo 'This performs a full table scan and acquires a lock that blocks updates'

-- Clean up if exists
ALTER TABLE products DROP CONSTRAINT IF EXISTS price_must_be_positive;

BEGIN;

-- This validates all existing rows immediately
-- Default behavior is validate: true
ALTER TABLE products
ADD CONSTRAINT price_must_be_positive
CHECK (price > 0);

-- Add a sleep to give concurrent operations time to test
SELECT pg_sleep(3);

COMMIT;

\echo ''
\echo '=== Constraint added and validated ==='
