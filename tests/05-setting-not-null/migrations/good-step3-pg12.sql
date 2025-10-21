-- GOOD (Step 3 - Postgres 12+ only): Add NOT NULL and drop CHECK constraint
-- This is optional but gives you a proper NOT NULL constraint

\timing on

\echo '=== Step 3 (Postgres 12+ only): Setting NOT NULL and dropping CHECK ==='
\echo 'Because the CHECK constraint is validated, Postgres skips the table scan'

BEGIN;

-- Set NOT NULL - Postgres 12+ will skip table scan due to validated CHECK
ALTER TABLE products ALTER COLUMN active SET NOT NULL;

-- Drop the CHECK constraint since we now have NOT NULL
ALTER TABLE products DROP CONSTRAINT active_not_null;

COMMIT;

\echo ''
\echo '=== NOT NULL set and CHECK constraint removed ==='

-- Verify
SELECT
    column_name,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'products'
AND column_name = 'active';

-- Show constraints
SELECT
    conname,
    contype
FROM pg_constraint
WHERE conrelid = 'products'::regclass
ORDER BY conname;

\echo ''
\echo 'Note: In Postgres 12+, SET NOT NULL skips the scan when a validated CHECK exists'
