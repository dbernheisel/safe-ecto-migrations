-- BAD: Adding a column with a VOLATILE default value
-- This ALWAYS rewrites the table, even in Postgres 11+

\timing on

\echo '=== Adding column WITH volatile default value ==='
\echo 'This rewrites the table in ALL Postgres versions'
\echo 'Acquires AccessExclusiveLock - blocks ALL operations'

BEGIN;

-- This is ALWAYS unsafe - volatile default
ALTER TABLE comments ADD COLUMN created_timestamp TIMESTAMP DEFAULT NOW();

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
AND column_name = 'created_timestamp';
