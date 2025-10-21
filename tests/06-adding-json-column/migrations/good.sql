-- GOOD: Adding a JSONB column
-- The jsonb type has equality operators and better performance

\echo '=== Adding a column with jsonb type ==='
\echo 'This works correctly with SELECT DISTINCT and other operations'

ALTER TABLE posts ADD COLUMN extra_data jsonb;

\echo ''
\echo '=== Column added ==='

-- Show column info
SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'posts'
AND column_name = 'extra_data';

-- Insert some data
INSERT INTO posts (title, content, extra_data)
VALUES
    ('Post 1', 'Content 1', '{"author": "Alice", "tags": ["tech", "postgres"]}'),
    ('Post 2', 'Content 2', '{"author": "Bob", "tags": ["coding"]}'),
    ('Post 3', 'Content 3', '{"author": "Alice", "tags": ["tech", "postgres"]}');

\echo ''
\echo 'SELECT DISTINCT works correctly:'
SELECT DISTINCT extra_data FROM posts WHERE extra_data IS NOT NULL;

\echo ''
\echo 'JSONB also supports indexing:'
-- Create a GIN index on jsonb column
CREATE INDEX idx_posts_extra_data ON posts USING GIN (extra_data);

\echo ''
\echo 'Can query JSON fields efficiently:'
SELECT title, extra_data->>'author' as author
FROM posts
WHERE extra_data @> '{"author": "Alice"}'
LIMIT 5;
