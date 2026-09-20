# GraphNight Elixir Bindings

High-performance semantic layer for Elixir applications, powered by Rust via Rustler NIFs.

## Features

- **Native Performance**: Core engine runs in Rust, called via NIFs (zero-copy where possible)
- **Ecto Integration**: Optional helpers for using GraphNight with Ecto
- **Full GraphNight API**: Models, DataSources, Queries, Dry-run, Multi-stage DAG queries
- **Type Safety**: Elixir structs mirroring Rust types
- **Async**: Built on Tokio runtime
- **Security**: Column masks, row-level filters, query timeouts

## Installation

### From Hex (when published)

```elixir
def deps do
  [
    {:graphnight, "~> 1.0"}
  ]
end
```

### From GitHub

```elixir
def deps do
  [
    {:graphnight, git: "https://github.com/niranjanaryan/graphnight-elixir.git"}
  ]
end
```

Then run:

```bash
mix deps.get
mix compile
```

## Quick Start

```elixir
# Initialize the engine (creates ./graphnight_data for YAML storage)
{:ok, engine} = GraphNight.Client.init("./graphnight_data")

# Create a datasource
ds = GraphNight.DataSource.new(
  "analytics",
  "postgres",
  "postgresql://user:pass@localhost/db",
  description: "Analytics database",
  pool_size: 10
)

{:ok, _ds} = GraphNight.Client.create_datasource(engine, ds)

# Create a model with measures, dimensions, time dimensions
model = %GraphNight.Model{
  name: "orders",
  datasource: "analytics",
  description: "Order transactions",
  measures: [
    %GraphNight.Measure{formula: "revenue:sum", aggregation: "SUM"},
    %GraphNight.Measure{formula: "order_count:count", aggregation: "COUNT"},
    %GraphNight.Measure{formula: "avg_order_value:avg", aggregation: "AVG"}
  ],
  dimensions: [
    %GraphNight.Dimension{name: "status"},
    %GraphNight.Dimension{name: "store_id"},
    %GraphNight.Dimension{name: "customer_segment"}
  ],
  time_dimensions: [
    %GraphNight.TimeDimension{dimension: "created_at", granularity: "DAY"},
    %GraphNight.TimeDimension{dimension: "created_at", granularity: "MONTH"}
  ],
  joins: []
}

{:ok, _model} = GraphNight.Client.create_model(engine, model)

# Execute a query
query = GraphNight.Client.build_query(
  name: "orders",
  measures: [GraphNight.Measure.new("revenue:sum")],
  dimensions: [GraphNight.Dimension.new("status")],
  filters: [GraphNight.Filter.eq("status", "completed")],
  order: [GraphNight.OrderBy.desc("revenue:sum")],
  limit: 100
)

{:ok, result} = GraphNight.Client.execute_query(engine, query)

# Result contains:
# result.data - list of rows as maps
# result.columns - column names
# result.sql - generated SQL
# result.execution_time_ms - execution time
```

## Advanced Formulas

GraphNight supports rich formula expressions beyond simple aggregations:

```elixir
# Shorthand: "column:aggregation"
%GraphNight.Measure{formula: "revenue:sum", aggregation: "SUM"}
%GraphNight.Measure{formula: "orders:count", aggregation: "COUNT"}
%GraphNight.Measure{formula: "avg_order:avg", aggregation: "AVG"}

# Window functions
%GraphNight.Measure{formula: "running_total(revenue:sum)", aggregation: "SUM"}
%GraphNight.Measure{formula: "pct_change(revenue:sum)", aggregation: "SUM"}

# Time shift (compare to previous period)
%GraphNight.Measure{formula: "time_shift(revenue:sum, 1, 'MONTH')", aggregation: "SUM"}

# Ratios
%GraphNight.Measure{formula: "ratio(profit:sum, revenue:sum)", aggregation: "SUM"}

# Custom SQL expressions
%GraphNight.Measure{
  formula: "CASE WHEN status = 'premium' THEN revenue * 1.1 ELSE revenue END",
  aggregation: "SUM"
}
```

## Time Dimensions & Granularities

```elixir
time_dimensions: [
  %GraphNight.TimeDimension{
    dimension: "created_at",
    granularity: "DAY"      # or "HOUR", "WEEK", "MONTH", "QUARTER", "YEAR"
  },
  %GraphNight.TimeDimension{
    dimension: "created_at",
    granularity: "MONTH",
    label: "Month"
  }
]

# Query with time dimension grouping
query = GraphNight.Client.build_query(
  name: "orders",
  measures: [GraphNight.Measure.new("revenue:sum")],
  time_dimensions: [GraphNight.TimeDimension.new("created_at", granularity: "MONTH")],
  filters: [
    GraphNight.Filter.gte("created_at", "2024-01-01"),
    GraphNight.Filter.lte("created_at", "2024-12-31")
  ]
)
```

## Joins

```elixir
# Define joins in the model
model = %GraphNight.Model{
  name: "orders",
  datasource: "analytics",
  joins: [
    %GraphNight.Join{
      name: "orders_to_customers",
      model: "customers",
      join_type: "LEFT",
      on: [{"customer_id", "id"}],
      alias: "customers"
    },
    %GraphNight.Join{
      name: "orders_to_products",
      model: "products",
      join_type: "INNER",
      on: [{"product_id", "id"}],
      alias: "products"
    }
  ]
}

# Query uses joined dimensions/measures automatically
query = GraphNight.Client.build_query(
  name: "orders",
  measures: [
    GraphNight.Measure.new("revenue:sum"),
    GraphNight.Measure.new("customers.lifetime_value:sum")
  ],
  dimensions: [
    GraphNight.Dimension.new("status"),
    GraphNight.Dimension.new("customers.tier")
  ]
)
```

## Multi-Stage DAG Queries

Execute multiple queries as a Directed Acyclic Graph with dependencies:

```elixir
# Stage 1: Get top 10 customers by revenue
stage1 = GraphNight.Client.build_query(
  name: "orders",
  measures: [GraphNight.Measure.new("revenue:sum")],
  dimensions: [GraphNight.Dimension.new("customer_id")],
  order: [GraphNight.OrderBy.desc("revenue:sum")],
  limit: 10
)

# Stage 2: Drill down into top customer's orders (references stage1)
stage2 = GraphNight.Client.build_query(
  name: "orders",
  measures: [GraphNight.Measure.new("revenue:sum")],
  dimensions: [GraphNight.Dimension.new("product_id")],
  filters: [GraphNight.Filter.eq("customer_id", "{{stage1.customer_id}}")],
  stage_ref: "stage1"
)

{:ok, %{results: results}} = GraphNight.Client.execute_dag(engine, [stage1, stage2])

# results[0] - top 10 customers
# results[1] - products for each top customer
```

## Dry Run (SQL Generation)

```elixir
# Generate SQL without executing
{:ok, result} = GraphNight.Client.dry_run_query(engine, query)

IO.puts(result.sql)
# SELECT status, SUM(revenue) AS "revenue:sum"
# FROM orders orders
# WHERE status = 'completed'
# GROUP BY status
# ORDER BY "revenue:sum" DESC
# LIMIT 100
```

## Security: Column Masks & Row Filters

```elixir
# Configure session policy with column masking
policy = %GraphNight.SessionPolicy{}
  |> GraphNight.SessionPolicy.with_column_mask("email", &GraphNight.Masks.email_mask/1)
  |> GraphNight.SessionPolicy.with_column_mask("ssn", fn _ -> "***-**-****" end)
  |> GraphNight.SessionPolicy.with_forced_filter(%GraphNight.Filter{
    field: "tenant_id",
    operator: "EQ",
    value: "tenant_123"
  })
  |> GraphNight.SessionPolicy.with_max_rows(10000)
  |> GraphNight.SessionPolicy.with_query_timeout_secs(30)

# Apply policy to context (automatically done by Client with auth)
```

Built-in masks:
- `GraphNight.Masks.email_mask/1` - masks email local part (j***e@domain.com)

## Error Handling

```elixir
case GraphNight.Client.execute_query(engine, query) do
  {:ok, result} ->
    # Success
    Enum.each(result.data, &process_row/1)
  
  {:error, reason} ->
    # Handle errors
    case reason do
      "Model not found: ..." -> {:error, :model_not_found}
      "Datasource not found: ..." -> {:error, :datasource_not_found}
      "Query timeout exceeded" -> {:error, :timeout}
      "Query must have a name or source_model" -> {:error, :invalid_query}
      _ -> {:error, :unknown, reason}
    end
end
```

## Configuration

```elixir
# Environment variables for server mode
# GRAPHNIGHT_DEV_OPEN=1          # Disable auth (dev only)
# GRAPHNIGHT_API_KEYS="alice:secret,bob:secret2"
# GRAPHNIGHT_ADMIN_KEYS="admin:adminsecret"
# GRAPHNIGHT_AUTH_REQUIRED=1     # Force auth even without keys
# GRAPHNIGHT_OIDC_ISSUER="https://..."  # Enable OIDC JWT validation
```

## Testing

```elixir
# In test_helper.exs
{:ok, engine} = GraphNight.Client.init("./test_data")

# Create test datasource with in-memory SQLite
ds = GraphNight.DataSource.new("test", "sqlite", "file::memory:?cache=shared")
GraphNight.Client.create_datasource(engine, ds)

# Test query
{:ok, result} = GraphNight.Client.execute_query(engine, test_query)
assert result.columns == ["status", "revenue:sum"]
```

## Performance Tips

1. **Connection Pooling**: Configure `pool_size` on datasource
2. **Query Caching**: Results cached automatically; invalidate with `engine.sql_engine.invalidate_result_cache()`
3. **Limit Results**: Always use `limit` for large datasets
4. **Indexes**: Ensure database has indexes on filtered/joined columns
5. **Dry Run First**: Use `dry_run_query` to verify SQL before execution

## Ecto Integration

```elixir
# Convert GraphNight model to Ecto schema definition
schema_code = GraphNight.Ecto.model_to_ecto_schema(model)
# Generates:
# defmodule Orders do
#   use Ecto.Schema
#   @primary_key {:id, :id, autogenerate: true}
#   schema "orders" do
#     field :status, :string
#     field :store_id, :string
#     field :created_at, :utc_datetime
#     # measure: revenue:sum (SUM)
#     timestamps()
#   end
# end
```

## Architecture

```
┌─────────────────┐     NIF      ┌──────────────────┐
│   Elixir App    │ ──────────▶ │  Rust Engine     │
│                 │             │                  │
│  GraphNight.*   │             │  graphnight-core │
│  modules        │             │  graphnight-sql  │
│                 │             │  graphnight-     │
└─────────────────┘             │  storage         │
                                 └──────────────────┘
```

The Rust engine handles:
- SQL generation (PostgreSQL, MySQL, SQLite, DuckDB)
- Formula parsing (revenue:sum, ratio(), time_shift(), etc.)
- Join walking and query optimization
- Connection pooling
- Query caching
- Tantivy full-text search

## Requirements

- Elixir 1.14+
- Rust 1.70+ (for compilation)
- Rustler 0.29+

## License

Apache-2.0