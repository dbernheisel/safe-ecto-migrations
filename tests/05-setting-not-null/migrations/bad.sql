-- BAD: Setting NOT NULL directly
-- This performs a full table scan and blocks reads/writes

\timing on

\echo '=== Setting NOT NULL directly ==='
\echo 'This performs a full table scan and blocks reads and writes'

BEGIN;

-- This scans the entire table to verify no NULLs exist
ALTER TABLE products ALTER COLUMN active SET NOT NULL;

COMMIT;

\echo ''
\echo '=== NOT NULL constraint set ==='

-- Verify the constraint
SELECT
    column_name,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'products'
AND column_name = 'active';

-- Test the constraint
\echo ''
\echo 'Testing constraint (should fail):'
INSERT INTO products (name, price) VALUES ('Test Product', 10.00);
