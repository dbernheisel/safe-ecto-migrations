-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Create a table with sample data
CREATE TABLE comments (
    id SERIAL PRIMARY KEY,
    post_id INTEGER NOT NULL,
    content TEXT NOT NULL,
    author VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Insert a large dataset for testing
INSERT INTO comments (post_id, content, author)
SELECT
    (i % 1000) + 1,
    'Comment content ' || i,
    'User ' || (i % 5000)
FROM generate_series(1, 100000) AS i;

-- Analyze the table
ANALYZE comments;

-- Reset pg_stat_statements
SELECT pg_stat_statements_reset();

-- Show table size
SELECT
    pg_size_pretty(pg_total_relation_size('comments')) as total_size,
    pg_size_pretty(pg_relation_size('comments')) as table_size;
