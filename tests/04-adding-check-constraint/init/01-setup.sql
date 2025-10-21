-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Create a table with sample data
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    stock INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Insert sample data with valid prices
INSERT INTO products (name, price, stock)
SELECT
    'Product ' || i,
    (random() * 100 + 1)::DECIMAL(10, 2),  -- Prices between 1 and 101
    (random() * 1000)::INTEGER
FROM generate_series(1, 100000) AS i;

-- Analyze the table
ANALYZE products;

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
    WHERE c.relname = 'products'
    ORDER BY c.relname, l.mode;
$$ LANGUAGE SQL;

-- Reset pg_stat_statements
SELECT pg_stat_statements_reset();
