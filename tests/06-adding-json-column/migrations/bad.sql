-- BAD: Adding a JSON column
-- The json type has no equality operator, which breaks SELECT DISTINCT

\echo '=== Adding a column with json type ==='
\echo 'This will cause errors with SELECT DISTINCT queries'

ALTER TABLE posts ADD COLUMN metadata json;

\echo ''
\echo '=== Column added ==='

-- Show column info
SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'posts'
AND column_name = 'metadata';

-- Insert some data
INSERT INTO posts (title, content, metadata)
VALUES ('Test Post', 'Test Content', '{"key": "value"}');

\echo ''
\echo 'Attempting SELECT DISTINCT (will fail):'
\echo ''

-- This will fail because json has no equality operator
SELECT DISTINCT metadata FROM posts;
