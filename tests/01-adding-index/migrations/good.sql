-- GOOD: Creating an index with CONCURRENTLY
-- This will NOT block writes to the table

\timing on

\echo '=== Creating index WITH concurrently ==='
\echo 'This will NOT block writes to the table'
\echo 'Note: Cannot be run inside a transaction block'

-- This is the safe way - does not block writes
-- Note: This cannot be run inside a transaction
CREATE INDEX CONCURRENTLY posts_slug_idx_concurrent ON posts(slug);

\echo ''
\echo '=== Index created ==='

-- Verify the index was created
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'posts'
ORDER BY indexname;

-- Show timing statistics
SELECT
    query,
    calls,
    mean_exec_time,
    total_exec_time
FROM pg_stat_statements
WHERE query LIKE '%CREATE INDEX%posts%'
ORDER BY mean_exec_time DESC;
