-- GOOD (Step 2): Validate the foreign key constraint
-- This can be done in a separate deployment

\timing on

\echo '=== Step 2: Validating the foreign key constraint ==='
\echo 'This acquires ShareUpdateExclusiveLock which does not block reads or writes'

-- Validate the constraint
-- This scans the table but doesn't block reads or writes
ALTER TABLE posts VALIDATE CONSTRAINT posts_group_id_safe_fkey;

\echo ''
\echo '=== Constraint validated ==='

-- Verify the constraint is now validated
SELECT
    conname,
    contype,
    convalidated
FROM pg_constraint
WHERE conname = 'posts_group_id_safe_fkey'
AND conrelid = 'posts'::regclass;

\echo ''
\echo 'Notice: convalidated = true'
\echo 'The constraint is now fully enforced on all rows'
