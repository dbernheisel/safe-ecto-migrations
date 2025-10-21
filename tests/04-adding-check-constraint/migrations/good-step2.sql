-- GOOD (Step 2): Validate the check constraint
-- This validates existing rows with a lock that allows updates

\timing on

\echo '=== Step 2: Validating the check constraint ==='
\echo 'This performs a full table scan but acquires ShareUpdateExclusiveLock'
\echo 'This lock allows updates to continue during validation'

-- Validate the constraint
-- Acquires ShareUpdateExclusiveLock which doesn't block reads or writes
ALTER TABLE products VALIDATE CONSTRAINT price_must_be_positive_safe;

\echo ''
\echo '=== Constraint validated ==='

-- Verify the constraint is now validated
SELECT
    conname,
    contype,
    convalidated
FROM pg_constraint
WHERE conname = 'price_must_be_positive_safe'
AND conrelid = 'products'::regclass;

\echo ''
\echo 'Notice: convalidated = true'
\echo 'The constraint is now fully enforced on all rows'

-- Verify constraint still works
\echo ''
\echo 'Testing the constraint:'
\echo 'Attempting to insert negative price (should fail):'
INSERT INTO products (name, price) VALUES ('Bad Product', -10.00);
