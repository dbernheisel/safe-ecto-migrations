-- BAD: Adding a foreign key with validation
-- This will block writes on BOTH tables

\timing on

\echo '=== Adding column and foreign key WITH validation ==='
\echo 'This will block writes to both posts and groups tables'

BEGIN;

-- Add the column with foreign key (validates by default)
ALTER TABLE posts ADD COLUMN group_id INTEGER REFERENCES groups(id);

-- Show the locks while the transaction is open
\echo ''
\echo 'Locks acquired:'
SELECT * FROM show_locks();

COMMIT;

\echo ''
\echo '=== Foreign key added ==='

-- Verify the constraint
SELECT
    conname,
    contype,
    convalidated
FROM pg_constraint
WHERE conname LIKE '%group%'
AND conrelid = 'posts'::regclass;
