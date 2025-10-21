-- GOOD (Step 2): Validate the foreign key constraint
-- This can be done in a separate deployment

\timing on

\echo '=== Step 2: Validating the foreign key constraint ==='
\echo 'This acquires ShareUpdateExclusiveLock which does not block reads or writes'

-- Validate the constraint
-- This scans the table but doesn't block reads or writes
ALTER TABLE posts VALIDATE CONSTRAINT posts_group_id_safe_fkey;

-- Add a sleep to give concurrent operations time to test
SELECT pg_sleep(2);

\echo ''
\echo '=== Constraint validated ==='
