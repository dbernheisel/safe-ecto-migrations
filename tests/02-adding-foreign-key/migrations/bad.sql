-- BAD: Adding a foreign key with validation
-- This will block writes on BOTH tables

\timing on

\echo '=== Adding column and foreign key WITH validation ==='
\echo 'This will block writes to both posts and groups tables'

-- Clean up if exists
ALTER TABLE posts DROP COLUMN IF EXISTS group_id CASCADE;

BEGIN;

-- Add the column with foreign key (validates by default)
ALTER TABLE posts ADD COLUMN group_id INTEGER REFERENCES groups(id);

-- Add a sleep to give concurrent operations time to attempt writes
SELECT pg_sleep(6);

COMMIT;

\echo ''
\echo '=== Foreign key added ==='
