-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Create the referenced table (groups)
CREATE TABLE groups (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create the referencing table (posts) without the foreign key
CREATE TABLE posts (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Insert sample data into groups
INSERT INTO groups (name)
SELECT 'Group ' || i
FROM generate_series(1, 1000) AS i;

-- Insert sample data into posts
INSERT INTO posts (title, content)
SELECT
    'Post Title ' || i,
    'Content for post ' || i
FROM generate_series(1, 100000) AS i;

-- Analyze the tables
ANALYZE groups;
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
    WHERE l.relation IS NOT NULL
    AND c.relname IN ('posts', 'groups')
    ORDER BY c.relname, l.mode;
$$ LANGUAGE SQL;

-- Reset pg_stat_statements
SELECT pg_stat_statements_reset();
