# Test: Adding a JSON Column

This test demonstrates why you should use `jsonb` instead of `json` in PostgreSQL.

## Scenario

We want to add a column to store flexible metadata or extra data in JSON format.

## Bad Approach

```sql
ALTER TABLE posts ADD COLUMN metadata json;
```

**Problems:**
- No equality operator for `json` type
- `SELECT DISTINCT` queries fail
- Cannot use in `GROUP BY`
- No indexing support
- Poor query performance

## Good Approach

```sql
ALTER TABLE posts ADD COLUMN extra_data jsonb;
```

**Benefits:**
- Has equality operators
- Works with `SELECT DISTINCT` and `GROUP BY`
- Supports GIN indexes for fast queries
- Better query performance
- Can use containment operators (`@>`, `<@`)

## Key Differences

### Storage

- **json**: Stores exact text representation
- **jsonb**: Stores in decomposed binary format

### Performance

- **json**: Fast on insert, slow on queries
- **jsonb**: Slightly slower on insert, much faster on queries

### Operations

- **json**: Limited operator support
- **jsonb**: Full operator support (`@>`, `?`, `?|`, `?&`, etc.)

### Indexing

- **json**: No index support
- **jsonb**: GIN and other index types supported

## When to Use Each

**Use jsonb (recommended):**
- Almost all use cases
- When you need to query the JSON data
- When you need indexing
- When you care about query performance

**Use json (rare):**
- Only if you need exact whitespace preservation
- Only if you never query the JSON content

## Running the Test

Simply run:
```bash
./run.sh
```

This script will:
1. Start the PostgreSQL container
2. Run the test inside the container
3. Clean up automatically

No need to manage Docker or PostgreSQL manually!
## Ecto Migration Example

```elixir
def change do
  alter table("posts") do
    add :extra_data, :jsonb  # Use jsonb, not :json
  end
end
```

### Adding an Index

```elixir
# GIN index for containment queries
def change do
  create index("posts", [:extra_data], using: :gin)
end
```

### Querying in Ecto

```elixir
# Find posts with specific JSON values
from p in Post,
  where: fragment("? @> ?", p.extra_data, ^%{author: "Alice"})

# Query specific fields
from p in Post,
  where: fragment("? ->> 'author' = ?", p.extra_data, "Alice")
```

## Common Error

If you use `json`, you'll see this error with `SELECT DISTINCT`:

```
ERROR: could not identify an equality operator for type json
```

This breaks many common query patterns and should be avoided.

## Key Takeaways

1. Use `jsonb` in almost all cases
2. `jsonb` = "json but better"
3. `json` type has no equality operator
4. `jsonb` supports indexing for better performance
5. The slight insert overhead of `jsonb` is worth it
6. Only use `json` if you absolutely need exact text preservation
