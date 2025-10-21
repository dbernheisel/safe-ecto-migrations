-- Create a simple posts table for testing
CREATE TABLE posts (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Insert some sample data
INSERT INTO posts (title, content)
SELECT
    'Post ' || i,
    'Content for post ' || i
FROM generate_series(1, 100) AS i;

\echo 'Table created with 100 rows'
