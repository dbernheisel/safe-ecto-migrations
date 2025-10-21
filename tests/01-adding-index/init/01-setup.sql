-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Create a table with sample data
CREATE TABLE posts (
    id SERIAL PRIMARY KEY,
    slug VARCHAR(255) NOT NULL,
    title TEXT NOT NULL,
    content TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Insert a large dataset for testing
-- This simulates a production table with significant data
INSERT INTO posts (slug, title, content)
SELECT
    'post-' || i,
    'Post Title ' || i,
    'Content for post ' || i || '. ' || repeat('Lorem ipsum dolor sit amet. ', 50)
FROM generate_series(1, 100000) AS i;

-- Analyze the table
ANALYZE posts;

-- Helper function to show locks
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

-- Reset pg_stat_statements
SELECT pg_stat_statements_reset();
