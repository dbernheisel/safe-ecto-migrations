-- BAD: Adding a column with a default value
-- In older Postgres versions (< 11), this rewrites the entire table
-- Even in Postgres 11+, volatile defaults still cause rewrites

\timing on

\echo '=== Adding column WITH default value ==='
\echo 'In Postgres < 11, this rewrites the table and blocks reads/writes'
\echo 'In Postgres 11+, non-volatile defaults are safe, but volatile ones still rewrite'

BEGIN;

-- This is unsafe in older Postgres or with volatile defaults
ALTER TABLE comments ADD COLUMN approved BOOLEAN DEFAULT false;

COMMIT;

\echo ''
\echo '=== Column added ==='

-- Show table info
SELECT
    column_name,
    data_type,
    column_default
FROM information_schema.columns
WHERE table_name = 'comments'
AND column_name = 'approved';

-- Show a few rows
SELECT id, approved FROM comments LIMIT 5;
