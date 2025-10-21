-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Helper function to measure query execution time and locks
CREATE OR REPLACE FUNCTION show_locks()
RETURNS TABLE (
    relation text,
    mode text,
    granted boolean
) AS $$
    SELECT
        c.relname::text,
        l.mode::text,
        l.granted
    FROM pg_locks l
    LEFT JOIN pg_class c ON c.oid = l.relation
    WHERE l.pid = pg_backend_pid()
    ORDER BY c.relname, l.mode;
$$ LANGUAGE SQL;

-- Helper function to show blocking queries
CREATE OR REPLACE FUNCTION show_blocking()
RETURNS TABLE (
    blocked_pid int,
    blocking_pid int,
    blocked_query text,
    blocking_query text
) AS $$
    SELECT
        blocked_locks.pid AS blocked_pid,
        blocking_locks.pid AS blocking_pid,
        blocked_activity.query AS blocked_query,
        blocking_activity.query AS blocking_query
    FROM pg_catalog.pg_locks blocked_locks
    JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
    JOIN pg_catalog.pg_locks blocking_locks
        ON blocking_locks.locktype = blocked_locks.locktype
        AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
        AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
        AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
        AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
        AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
        AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
        AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
        AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
        AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
        AND blocking_locks.pid != blocked_locks.pid
    JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
    WHERE NOT blocked_locks.granted;
$$ LANGUAGE SQL;
