-- GOOD (Step 1): Add column without default
-- This is fast and doesn't block

\timing on

\echo '=== Step 1: Adding column WITHOUT default ==='
\echo 'This is very fast - does not rewrite the table'

BEGIN;

-- Add the column without a default value
ALTER TABLE comments ADD COLUMN approved_safe BOOLEAN;

COMMIT;

\echo ''
\echo '=== Column added (no default yet) ==='

-- Show table info
SELECT
    column_name,
    data_type,
    column_default
FROM information_schema.columns
WHERE table_name = 'comments'
AND column_name = 'approved_safe';

-- Show a few rows (will be NULL)
SELECT id, approved_safe FROM comments LIMIT 5;
