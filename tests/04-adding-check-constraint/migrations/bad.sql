-- BAD: Adding a check constraint with validation
-- This performs a full table scan and blocks updates

\timing on

\echo '=== Adding check constraint WITH validation ==='
\echo 'This performs a full table scan and acquires a lock that blocks updates'

BEGIN;

-- This validates all existing rows immediately
-- Default behavior is validate: true
ALTER TABLE products
ADD CONSTRAINT price_must_be_positive
CHECK (price > 0);

-- Show the locks while the transaction is open
\echo ''
\echo 'Locks acquired during constraint creation:'
SELECT * FROM show_locks();

COMMIT;

\echo ''
\echo '=== Constraint added and validated ==='

-- Verify the constraint
SELECT
    conname,
    contype,
    convalidated
FROM pg_constraint
WHERE conname = 'price_must_be_positive'
AND conrelid = 'products'::regclass;

\echo ''
\echo 'Testing the constraint:'

-- This should fail
\echo 'Attempting to insert negative price (should fail):'
INSERT INTO products (name, price) VALUES ('Bad Product', -10.00);
