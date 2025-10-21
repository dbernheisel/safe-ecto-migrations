-- GOOD (Step 1): Adding a foreign key WITHOUT validation
-- This minimizes the lock time

\timing on

\echo '=== Step 1: Adding column and foreign key WITHOUT validation ==='
\echo 'This will briefly block writes but not validate existing rows'

BEGIN;

-- Add the column with foreign key but don't validate it
ALTER TABLE posts ADD COLUMN group_id_safe INTEGER;

-- Create the foreign key constraint without validation
ALTER TABLE posts
ADD CONSTRAINT posts_group_id_safe_fkey
FOREIGN KEY (group_id_safe)
REFERENCES groups(id)
NOT VALID;

COMMIT;

\echo ''
\echo '=== Constraint added (not yet validated) ==='

-- Verify the constraint exists but is not validated
SELECT
    conname,
    contype,
    convalidated
FROM pg_constraint
WHERE conname = 'posts_group_id_safe_fkey'
AND conrelid = 'posts'::regclass;

\echo ''
\echo 'Notice: convalidated = false'
\echo 'This means new/updated rows will be checked, but existing rows are not yet validated'
