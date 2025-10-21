-- BAD: Creating an index without CONCURRENTLY
-- This will block writes to the table

\timing on

-- Show what locks will be acquired
\echo '=== Creating index WITHOUT concurrently ==='
\echo 'This will acquire a ShareLock on the table, blocking writes'

BEGIN;

-- This is the unsafe way - blocks writes
CREATE INDEX posts_slug_idx ON posts(slug);

-- Show the locks while the transaction is open
SELECT * FROM show_locks() WHERE relation = 'posts';

COMMIT;

\echo ''
\echo '=== Index created ==='

-- Show timing statistics
SELECT
    query,
    calls,
    mean_exec_time,
    total_exec_time
FROM pg_stat_statements
WHERE query LIKE '%CREATE INDEX posts_slug_idx%'
ORDER BY mean_exec_time DESC;
