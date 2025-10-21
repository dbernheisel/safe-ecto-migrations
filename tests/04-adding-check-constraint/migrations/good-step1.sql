-- GOOD (Step 1): Adding a check constraint WITHOUT validation
-- This creates the constraint but doesn't validate existing rows

\timing on

\echo '=== Step 1: Adding check constraint WITHOUT validation ==='
\echo 'This creates the constraint but skips full table scan'
\echo 'New and updated rows will be checked, but existing rows are not validated yet'

BEGIN;

-- Create the constraint without validating existing rows
ALTER TABLE products
ADD CONSTRAINT price_must_be_positive_safe
CHECK (price > 0)
NOT VALID;

COMMIT;

\echo ''
\echo '=== Constraint added (not yet validated) ==='

-- Verify the constraint
SELECT
    conname,
    contype,
    convalidated
FROM pg_constraint
WHERE conname = 'price_must_be_positive_safe'
AND conrelid = 'products'::regclass;

\echo ''
\echo 'Notice: convalidated = false'
\echo 'The constraint exists but has not been validated for existing rows'

\echo ''
\echo 'Testing the constraint on new data:'

-- This should fail even though constraint is not validated
-- Because new rows are still checked
\echo 'Attempting to insert negative price (should fail):'
INSERT INTO products (name, price) VALUES ('Bad Product', -10.00);
