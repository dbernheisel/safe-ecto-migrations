-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Create a table with a nullable column
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    active BOOLEAN,  -- Nullable column we want to make NOT NULL
    price DECIMAL(10, 2),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Insert sample data with all rows having active = true
-- This ensures the NOT NULL constraint will be satisfiable
INSERT INTO products (name, active, price)
SELECT
    'Product ' || i,
    true,  -- All products are active
    (random() * 100 + 1)::DECIMAL(10, 2)
FROM generate_series(1, 100000) AS i;

-- Analyze the table
ANALYZE products;

-- Reset pg_stat_statements
SELECT pg_stat_statements_reset();

\echo 'Table created with 100,000 rows where active is always true'
