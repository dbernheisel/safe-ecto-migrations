-- GOOD (Step 2): Set the default value
-- This is also very fast

\timing on

\echo '=== Step 2: Setting default value on column ==='
\echo 'This only affects future INSERTs, does not rewrite existing rows'

-- Set the default value (does not affect existing rows)
ALTER TABLE comments ALTER COLUMN approved_safe SET DEFAULT false;

\echo ''
\echo '=== Default value set ==='

-- Show table info
SELECT
    column_name,
    data_type,
    column_default
FROM information_schema.columns
WHERE table_name = 'comments'
AND column_name = 'approved_safe';

-- Show existing rows (still NULL)
\echo ''
\echo 'Existing rows (still NULL):'
SELECT id, approved_safe FROM comments LIMIT 5;

-- Insert a new row to show default applies
INSERT INTO comments (post_id, content, author) VALUES (1, 'New comment', 'Test User');

\echo ''
\echo 'New row (has default):'
SELECT id, approved_safe FROM comments ORDER BY id DESC LIMIT 1;

\echo ''
\echo 'Note: The default is NOT materialized for existing rows.'
\echo 'Ecto will apply the default when reading records.'
\echo 'If you need to backfill, see the Backfilling guide.'
