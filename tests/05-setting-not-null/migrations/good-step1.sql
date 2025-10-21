-- GOOD (Step 1): Add a CHECK constraint without validation
-- This creates the constraint without scanning existing rows

\timing on

\echo '=== Step 1: Adding CHECK constraint (NOT NULL equivalent) without validation ==='
\echo 'This creates the constraint but does not validate existing rows'

BEGIN;

-- Create a CHECK constraint that enforces NOT NULL
-- Use NOT VALID to skip validation of existing rows
ALTER TABLE products
ADD CONSTRAINT active_not_null
CHECK (active IS NOT NULL)
NOT VALID;

COMMIT;

\echo ''
\echo '=== CHECK constraint added (not validated) ==='

-- Verify the constraint exists but is not validated
SELECT
    conname,
    contype,
    convalidated
FROM pg_constraint
WHERE conrelid = 'products'::regclass
AND conname = 'active_not_null';

\echo ''
\echo 'Notice: convalidated = false'
\echo 'New/updated rows will be checked, but existing rows are not validated yet'

-- Test that new rows are checked
\echo ''
\echo 'Testing constraint on new data (should fail):'
INSERT INTO products (name, price) VALUES ('Test Product', 10.00);
