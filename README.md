# Ex4j

An Ecto-inspired Cypher DSL and Neo4j driver for Elixir.

Ex4j lets you build **parameterized Cypher queries** using Elixir macros, protocols, and pipe-based composition — no raw strings required. All values become query parameters (`$p0`, `$p1`, ...) to prevent injection and enable Neo4j query plan caching.

Powered by [Boltx](https://github.com/sagastume/boltx) (Bolt 5.0–5.4, Neo4j 5.x) and [Ecto](https://github.com/elixir-ecto/ecto) for schema validation.

## Installation

Add `ex4j` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex4j, "~> 0.2.0"}
  ]
end
```

Configure the Neo4j connection:

```elixir
# config/config.exs
config :ex4j, Boltx,
  url: "bolt://localhost:7687",
  basic_auth: [username: "neo4j", password: "your_password"],
  pool_size: 10

# For Neo4j Aura (cloud), use neo4j+s:// and specify the database name:
config :ex4j, Boltx,
  url: "neo4j+s://your-instance-id.databases.neo4j.io",
  basic_auth: [username: "your_username", password: "your_password"],
  database: "your-database-name",
  pool_size: 5
```

Define a Repo module for executing queries:

```elixir
defmodule MyApp.Repo do
  use Ex4j.Repo, otp_app: :my_app
end
```

Add the Repo config:

```elixir
# config/config.exs
config :my_app, MyApp.Repo, []
```

The docs can be found at <https://hexdocs.pm/ex4j>.

## Defining Schemas

### Nodes

```elixir
defmodule MyApp.User do
  use Ex4j.Schema

  node "User" do
    field(:name, :string)
    field(:age, :integer)
    field(:email, :string)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :age, :email])
    |> validate_required([:name, :email])
    |> validate_format(:email, ~r/@/)
    |> validate_inclusion(:age, 18..100)
  end
end
```

### Comments

```elixir
defmodule MyApp.Comment do
  use Ex4j.Schema

  node "Comment" do
    field(:content, :string)
  end
end
```

### Relationships

```elixir
defmodule MyApp.HasComment do
  use Ex4j.Schema

  relationship "HAS_COMMENT" do
    from(MyApp.User)
    to(MyApp.Comment)
    field(:created_at, :utc_datetime)
  end
end
```

### Multi-Label Nodes

```elixir
defmodule MyApp.Admin do
  use Ex4j.Schema

  node ["Person", "Admin"] do
    field(:name, :string)
    field(:role, :string)
  end
end
```





All schemas automatically get:
- Ecto `embedded_schema` with a `:uuid` primary key
- `Ecto.Changeset` functions imported
- `new/1` and `new/2` constructors for creating structs from maps
- `__schema__/1` introspection callbacks for query building

## Building Queries

Import the query API to access all macros:

```elixir
import Ex4j.Query.API
```

### Simple Match + Return

```elixir
User
|> match(as: :u)
|> return([:u])
|> MyApp.Repo.all()
# => {:ok, [%{"u" => %MyApp.User{name: "Tiago", age: 38, ...}}]}
```

**Generated Cypher:**

```cypher
MATCH (u:User)
RETURN u
```

### Where with Macro Expressions

No more raw strings! Write Elixir expressions and they compile to parameterized Cypher:

```elixir
User
|> match(as: :u)
|> where([u], u.age > 18 and u.name == "Tiago")
|> return([:u])
|> limit(10)
|> MyApp.Repo.all()
```

**Generated Cypher:**

```cypher
MATCH (u:User)
WHERE (u.age > $p0 AND u.name = $p1)
RETURN u
LIMIT 10
-- params: %{"p0" => 18, "p1" => "Tiago"}
```

### Pin Operator for Runtime Values

Use `^` to inject runtime variables as parameters (just like Ecto):

```elixir
name = "Tiago"
min_age = 18

User
|> match(as: :u)
|> where([u], u.name == ^name and u.age >= ^min_age)
|> return([u], [:name, :age])
|> MyApp.Repo.all()
```

**Generated Cypher:**

```cypher
MATCH (u:User)
WHERE (u.name = $p0 AND u.age >= $p1)
RETURN u.name, u.age
-- params: %{"p0" => "Tiago", "p1" => 18}
```

### Relationship Traversal

```elixir
query()
|> match(User, as: :u)
|> match(Comment, as: :c)
|> edge(HasComment, as: :r, from: :u, to: :c, direction: :out)
|> where([u], u.name == ^user_name)
|> where([c], c.content =~ "Article")
|> return([:u, :c])
|> MyApp.Repo.all()
```

**Generated Cypher:**

```cypher
MATCH (u:User)-[r:HAS_COMMENT]->(c:Comment)
WHERE (u.name = $p0 AND c.content CONTAINS $p1)
RETURN u, c
```

### Relationship Directions

```elixir
# Outgoing: ->
edge(HasComment, as: :r, from: :u, to: :c, direction: :out)
# (u)-[r:HAS_COMMENT]->(c)

# Incoming: <-
edge(HasComment, as: :r, from: :u, to: :c, direction: :in)
# (u)<-[r:HAS_COMMENT]-(c)

# Any direction: -
edge(HasComment, as: :r, from: :u, to: :c, direction: :any)
# (u)-[r:HAS_COMMENT]-(c)
```

### Variable-Length Relationships

```elixir
query()
|> match(User, as: :u)
|> match(User, as: :friend)
|> edge(:KNOWS, as: :r, from: :u, to: :friend, direction: :out, length: 1..3)
|> return([:u, :friend])
|> MyApp.Repo.all()
```

**Generated Cypher:**

```cypher
MATCH (u:User)-[r:KNOWS*1..3]->(friend:User)
RETURN u, friend
```

## Where Operators

The `where` macro supports all common comparison and logical operators:

| Elixir Expression | Cypher Output |
|---|---|
| `u.age > 18` | `u.age > $p0` |
| `u.age >= 18` | `u.age >= $p0` |
| `u.age < 65` | `u.age < $p0` |
| `u.age <= 65` | `u.age <= $p0` |
| `u.name == "Tiago"` | `u.name = $p0` |
| `u.name != "Admin"` | `u.name <> $p0` |
| `u.age in [18, 25, 30]` | `u.age IN $p0` |
| `u.name =~ "pattern"` | `u.name CONTAINS $p0` |
| `starts_with(u.name, "T")` | `u.name STARTS WITH $p0` |
| `ends_with(u.name, "go")` | `u.name ENDS WITH $p0` |
| `is_nil(u.email)` | `u.email IS NULL` |
| `not is_nil(u.email)` | `NOT u.email IS NULL` |
| `expr1 and expr2` | `expr1 AND expr2` |
| `expr1 or expr2` | `expr1 OR expr2` |
| `^variable` | `$pN` (runtime parameter) |

### Multiple Where Clauses

Multiple `where` calls are combined with `AND`:

```elixir
User
|> match(as: :u)
|> where([u], u.age > 18)
|> where([u], u.name == "Tiago")
|> return([:u])
```

**Generated Cypher:**

```cypher
MATCH (u:User)
WHERE u.age > $p0 AND u.name = $p1
RETURN u
```

## Write Operations

### CREATE

```elixir
query()
|> create(User, as: :u, set: %{name: "Alice", age: 30, email: "alice@example.com"})
|> return([:u])
|> MyApp.Repo.run()
```

**Generated Cypher:**

```cypher
CREATE (u:User {name: $p0, age: $p1, email: $p2})
RETURN u
```

### CREATE Relationship

```elixir
query()
|> match(User, as: :u, where: %{email: "alice@example.com"})
|> match(Comment, as: :c, where: %{content: "Great article!"})
|> create(HasComment, as: :r, from: :u, to: :c, set: %{created_at: "2025-06-01T10:00:00Z"})
|> return([:r])
|> MyApp.Repo.run()
```

**Generated Cypher:**

```cypher
MATCH (u:User {email: $p0}), (c:Comment {content: $p1})
CREATE (u)-[r:HAS_COMMENT {created_at: $p2}]->(c)
RETURN r
```

You can also create relationships without properties:

```elixir
query()
|> match(User, as: :u, where: %{email: "bob@example.com"})
|> match(Comment, as: :c, where: %{content: "Great article!"})
|> create(HasComment, as: :r, from: :u, to: :c)
|> return([:r])
|> MyApp.Repo.run()
```

Or with a specific direction:

```elixir
# Incoming relationship
query()
|> match(User, as: :u, where: %{email: "alice@example.com"})
|> match(Comment, as: :c, where: %{content: "Great article!"})
|> create(HasComment, as: :r, from: :u, to: :c, direction: :in)
|> return([:r])
|> MyApp.Repo.run()
```

### MERGE

```elixir
query()
|> merge(User, as: :u, match: %{email: "alice@example.com"})
|> return([:u])
|> MyApp.Repo.run()
```

**Generated Cypher:**

```cypher
MERGE (u:User {email: $p0})
RETURN u
```

### SET

```elixir
query()
|> match(User, as: :u)
|> where([u], u.email == "alice@example.com")
|> set(:u, :name, "Alice Updated")
|> set(:u, :age, 31)
|> return([:u])
|> MyApp.Repo.run()
```

**Generated Cypher:**

```cypher
MATCH (u:User)
WHERE u.email = $p0
SET u.name = $p1, u.age = $p2
RETURN u
```

### DELETE

```elixir
# Simple delete
query()
|> match(User, as: :u)
|> where([u], u.name == "Alice")
|> delete(:u)
|> MyApp.Repo.run()

# Detach delete (removes all relationships first)
query()
|> match(User, as: :u)
|> where([u], u.name == "Alice")
|> delete(:u, detach: true)
|> MyApp.Repo.run()
```

**Generated Cypher:**

```cypher
MATCH (u:User)
WHERE u.name = $p0
DETACH DELETE u
```

### REMOVE

```elixir
query()
|> match(User, as: :u)
|> where([u], u.name == "Alice")
|> remove(:u, :email)
|> return([:u])
|> MyApp.Repo.run()
```

**Generated Cypher:**

```cypher
MATCH (u:User)
WHERE u.name = $p0
REMOVE u.email
RETURN u
```

## Advanced Features

### OPTIONAL MATCH

```elixir
query()
|> match(User, as: :u)
|> optional_match(Comment, as: :c)
|> return([:u, :c])
|> MyApp.Repo.all()
```

**Generated Cypher:**

```cypher
MATCH (u:User)
OPTIONAL MATCH (c:Comment)
RETURN u, c
```

### ORDER BY, SKIP, LIMIT

```elixir
User
|> match(as: :u)
|> return([:u])
|> order_by([u], asc: :name, desc: :age)
|> skip(10)
|> limit(25)
|> MyApp.Repo.all()
```

**Generated Cypher:**

```cypher
MATCH (u:User)
RETURN u
ORDER BY u.name, u.age DESC
SKIP 10
LIMIT 25
```

### WITH (Query Chaining)

```elixir
query()
|> match(User, as: :u)
|> with_query([:u])
|> return([:u])
|> MyApp.Repo.all()
```

**Generated Cypher:**

```cypher
MATCH (u:User)
WITH u
RETURN u
```

### UNWIND

```elixir
query()
|> unwind([1, 2, 3], as: :x)
|> return([:x])
|> MyApp.Repo.all()
```

**Generated Cypher:**

```cypher
UNWIND $p0 AS x
RETURN x
-- params: %{"p0" => [1, 2, 3]}
```

### UNION

```elixir
q1 =
  query()
  |> match(User, as: :u)
  |> where([u], u.age > 30)
  |> return(:u, [:name])

q2 =
  query()
  |> match(User, as: :u)
  |> where([u], u.age < 20)
  |> return(:u, [:name])

union(q1, q2)      # UNION (distinct)
union(q1, q2, :all) # UNION ALL
|> MyApp.Repo.all()
```

### CALL Subqueries

```elixir
subquery =
  query()
  |> match(Comment, as: :c)
  |> return([:c])

query()
|> match(User, as: :u)
|> call(subquery)
|> return([:u, :c])
|> MyApp.Repo.all()
```

**Generated Cypher:**

```cypher
MATCH (u:User)
CALL {
  MATCH (c:Comment)
  RETURN c
}
RETURN u, c
```

## Dynamic Queries

Build queries at runtime based on user input or conditions:

```elixir
import Ex4j.Query.API

min_age = 18
name = "Tiago"

dyn = dynamic([u], u.age > ^min_age and u.name == ^name)

User
|> match(as: :u)
|> where(^dyn)
|> return([:u])
|> MyApp.Repo.all()
```

## Fragments

For Cypher syntax not covered by the DSL, use `fragment/1+` to embed raw Cypher with safe parameter binding:

```elixir
User
|> match(as: :u)
|> where([u], fragment("u.score > duration(?)", "P1Y"))
|> return([:u])
|> MyApp.Repo.all()
```

**Generated Cypher:**

```cypher
MATCH (u:User)
WHERE u.score > duration($p0)
RETURN u
-- params: %{"p0" => "P1Y"}
```

Each `?` placeholder becomes a parameterized value. Never interpolate user input directly — always use `?` placeholders.

## Raw Cypher Queries

For full control, pass a raw Cypher string directly:

```elixir
MyApp.Repo.query("MATCH (n:User) RETURN n LIMIT 25")

# With parameters
MyApp.Repo.query("MATCH (n:User) WHERE n.age > $age RETURN n", %{"age" => 18})
```

## Transactions

```elixir
MyApp.Repo.transaction(fn ->
  MyApp.Repo.run(create_user_query)
  MyApp.Repo.run(create_relationship_query)
end)
```

## Debugging Queries

Inspect the generated Cypher and parameters without executing:

```elixir
import Ex4j.Query.API

{cypher, params} =
  User
  |> match(as: :u)
  |> where([u], u.age > 18)
  |> return([:u])
  |> to_cypher()

IO.puts(cypher)
# MATCH (u:User)
# WHERE u.age > $p0
# RETURN u

IO.inspect(params)
# %{"p0" => 18}
```

Or get just the Cypher string:

```elixir
cypher_string =
  User
  |> match(as: :u)
  |> return([:u])
  |> cypher()
# "MATCH (u:User)\nRETURN u"
```

## Changeset Validation

Schemas integrate with Ecto changesets for validation:

```elixir
changeset = User.changeset(%User{}, %{"name" => "Tiago", "email" => "tiago@test.com"})

if changeset.valid? do
  user = Ecto.Changeset.apply_action!(changeset, :create)
  # proceed with creating the node...
end
```

Graph-specific validations are available via `Ex4j.Changeset`:

```elixir
changeset
|> Ex4j.Changeset.validate_node_label()
|> Ex4j.Changeset.validate_neo4j_type(:age)
```

## Cypher 25 Support

Ex4j includes a comprehensive Cypher functions registry supporting Cypher 25 additions:

- **Aggregation**: `count`, `sum`, `avg`, `min`, `max`, `collect`, `percentile_cont`, `percentile_disc`
- **Scalar**: `coalesce`, `head`, `last`, `size`, `length`, `keys`, `labels`, `type`, `id`, `element_id`
- **String**: `trim`, `to_lower`, `to_upper`, `replace`, `substring`, `split`
- **Math**: `abs`, `ceil`, `floor`, `round`, `sqrt`, `log`, `rand`
- **Temporal**: `date`, `datetime`, `duration`, `time`, `timestamp`
- **Spatial**: `point`, `distance`
- **Cypher 25 Vectors**: `vector`, `vector_dimension_count`, `vector_distance`, `vector_norm`

## Sample Data for Testing

A complete seed script using the `User`, `Comment`, and `HasComment` schemas.
Paste this into `priv/repo/seeds.exs` or run it in `iex -S mix`.

```elixir
import Ex4j.Query.API

alias MyApp.{User, Comment, HasComment}

# --- Indexes & Constraints ---------------------------------------------------

MyApp.Repo.query("CREATE CONSTRAINT user_email_unique IF NOT EXISTS FOR (u:User) REQUIRE u.email IS UNIQUE")
MyApp.Repo.query("CREATE INDEX user_name_index IF NOT EXISTS FOR (u:User) ON (u.name)")
MyApp.Repo.query("CREATE INDEX comment_content_index IF NOT EXISTS FOR (c:Comment) ON (c.content)")

# --- Nodes: Users ------------------------------------------------------------

users = [
  %{name: "Tiago", age: 38, email: "tiago@example.com"},
  %{name: "Alice", age: 30, email: "alice@example.com"},
  %{name: "Bob",   age: 25, email: "bob@example.com"}
]

for attrs <- users do
  query()
  |> create(User, as: :u, set: attrs)
  |> return([:u])
  |> MyApp.Repo.run()
end

# --- Nodes: Comments ----------------------------------------------------------

comments = [
  %{content: "Great article on Elixir!"},
  %{content: "Neo4j is awesome for graph data"},
  %{content: "Loving the Ex4j DSL"}
]

for attrs <- comments do
  query()
  |> create(Comment, as: :c, set: attrs)
  |> return([:c])
  |> MyApp.Repo.run()
end

# --- Edges: HAS_COMMENT (with optional properties) ---------------------------

edges = [
  {"tiago@example.com", "Great article on Elixir!",          %{created_at: "2025-06-01T10:00:00Z"}},
  {"tiago@example.com", "Neo4j is awesome for graph data",   %{created_at: "2025-06-02T14:30:00Z"}},
  {"alice@example.com", "Loving the Ex4j DSL",               %{created_at: "2025-06-03T09:15:00Z"}},
  {"bob@example.com",   "Great article on Elixir!",          %{}}  # no properties
]

for {email, content, props} <- edges do
  query()
  |> match(User, as: :u, where: %{email: email})
  |> match(Comment, as: :c, where: %{content: content})
  |> create(HasComment, as: :r, from: :u, to: :c, set: props)
  |> return([:r])
  |> MyApp.Repo.run()
end

# --- Verify ------------------------------------------------------------------

# All users with their comments
query()
|> match(User, as: :u)
|> match(Comment, as: :c)
|> edge(HasComment, as: :r, from: :u, to: :c, direction: :out)
|> return([:u, :r, :c])
|> MyApp.Repo.all()

# Users older than 25
User
|> match(as: :u)
|> where([u], u.age > 25)
|> return([u], [:name, :email])
|> order_by([u], asc: :name)
|> MyApp.Repo.all()

# Bob's comments (should be 1, no properties on the edge)
query()
|> match(User, as: :u)
|> match(Comment, as: :c)
|> edge(HasComment, as: :r, from: :u, to: :c, direction: :out)
|> where([u], u.name == "Bob")
|> return([:c, :r])
|> MyApp.Repo.all()
```

### Cleanup

```elixir
MyApp.Repo.query("MATCH (n) DETACH DELETE n")
MyApp.Repo.query("DROP CONSTRAINT user_email_unique IF EXISTS")
MyApp.Repo.query("DROP INDEX user_name_index IF EXISTS")
MyApp.Repo.query("DROP INDEX comment_content_index IF EXISTS")
```

## Architecture

| Module | Responsibility |
|---|---|
| `Ex4j.Schema` | Define node and relationship schemas with labels, fields, and Ecto validation |
| `Ex4j.Query` | Immutable query struct that accumulates clauses via pipe composition |
| `Ex4j.Query.API` | Public macro DSL (`match`, `where`, `return`, `create`, `edge`, etc.) |
| `Ex4j.Query.Compiler` | Compiles Elixir AST into parameterized expression structs |
| `Ex4j.Cypher` | Generates `{cypher_string, params_map}` from query structs |
| `Ex4j.Cypher.Fragment` | Handles raw Cypher fragments with `?` parameter binding |
| `Ex4j.Queryable` | Protocol allowing schemas and queries to be used interchangeably |
| `Ex4j.Repo` | Execution interface (like Ecto.Repo) with `all`, `one`, `run`, `query`, `transaction` |
| `Ex4j.Bolt` | Boltx adapter for Neo4j communication |
| `Ex4j.Changeset` | Graph-aware validation extensions |

## License

Ex4j source code is released under Apache License 2.0.

Check [NOTICE](NOTICE) and [LICENSE](LICENSE) files for more information.
