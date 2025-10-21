-- BAD: Setting NOT NULL directly
-- This performs a full table scan and blocks reads/writes

\timing on

\echo '=== Setting NOT NULL directly ==='
\echo 'This performs a full table scan and blocks reads and writes'

BEGIN;

-- This scans the entire table to verify no NULLs exist
ALTER TABLE products ALTER COLUMN active SET NOT NULL;

-- Add a sleep to give concurrent operations time to test
SELECT pg_sleep(3);

COMMIT;

\echo ''
\echo '=== NOT NULL constraint set ==='
