-- BAD: Creating an index without CONCURRENTLY
-- This will block writes to the table

\timing on

\echo '=== Creating index WITHOUT concurrently ==='
\echo 'This will acquire a ShareLock on the table, blocking writes'

-- Drop index if exists
DROP INDEX IF EXISTS posts_slug_idx;

BEGIN;

-- This is the unsafe way - blocks writes
CREATE INDEX posts_slug_idx ON posts(slug);

-- Add a sleep to give concurrent operations time to attempt writes
-- This simulates a long-running index creation
SELECT pg_sleep(3);

COMMIT;

\echo ''
\echo '=== Index created ==='
