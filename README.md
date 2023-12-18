# Ex4j

This library combines the power of Ecto with the Bolt protocol provided by [Bolt Sips](https://github.com/florinpatrascu/bolt_sips) :hearts:

You can use the whole ecto suite you love for validations and structures plus an elegant DSL to retrieve data from Neo4j.

All `Ex4j.Node` have `Ecto.Schema`, `Ecto.Changeset` and `Ex4j.Cypher` automatically imported for convenience.
   
## Installation

The package can be installed by adding `ex4j` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex4j, "~> 0.1.0"}
  ]
end
```

Add the connection settings

```elixir
config :ex4j, Bolt,
  url: "bolt://localhost:7687",
  basic_auth: [username: "neo4j", password: "zEb0zryxK62NNRXKWxJKd7qeEFkO3mLIgcGwuUA4lvg"],
  pool_size: 10,
  ssl: false
```

The docs can be found at <https://hexdocs.pm/ex4j>.

## Usage 

All the entities you query must have a schema `Node.` like below associated in your code:

```elixir
defmodule Node.User do
  use Ex4j.Node

  graph do
    field(:name, :string)
    field(:age, :integer)
    field(:email, :string)
  end
end
```

```elixir
defmodule Node.Has do
  use Ex4j.Node

  graph do
    field(:date, :utc_datetime_usec)
  end
end
```

```elixir
defmodule Node.Comment do
  use Ex4j.Node

  graph do
    field(:content, :string)
  end
end
```

The module you intend to use for queries must `use Ex4j.Cypher`: 

```elixir
defmodule App do
  use Ex4j.Cypher

  def execute do 
    match(Node.User, as: :u)
    |> return(:u)
    |> run()
  end
end
```

```bash
  iex> App.execute()
  {:ok, [
    %{"u" => %Node.User{uuid: nil, name: "Tiago", age: 38, email: nil}},
    %{"u" => %Node.User{uuid: nil, name: "Davi", age: 35, email: nil}}
  ]}
```

```elixir
defmodule App do
  use Ex4j.Cypher

  def execute do 
   match(Node.User, as: :u)
    |> vertex(Node.Comment, as: :c)
    |> edge(Node.Has, as: :h, from: :u, to: :c, type: :out)
    |> where(:u, "u.age IN [35,38] AND u.name CONTAINS 'Ti'")
    |> where(:c, "c.content CONTAINS 'Article'")
    |> where(:h, "h.date > date('2023-12-15')")
    |> return(:u)
    |> return(:c)
    |> run()
  end
end
```

```bash
 iex> User.execute()
 {:ok, [
    %{
      "c" => %Node.Comment{uuid: nil, content: "Tiago's Comment"},
      "u" => %Node.User{uuid: nil, name: "Tiago", age: 38, email: nil}
    },
    %{
      "c" => %Node.Comment{uuid: nil, content: "Davi's Comment"},
      "u" => %Node.User{uuid: nil, name: "Davi", age: 35, email: nil}
    }
 ]}
```

```elixir
defmodule App do
  use Ex4j.Cypher

  def execute do 
    match(Node.User, as: :u)
    |> edge(Node.Has, as: :h, from: :u, to: :c, type: :out)
    |> vertex(Node.Comment, as: :c)
    |> return(:h)
    |> run()
  end
end
```

```bash
 iex> User.execute()
 {:ok, [
    %{"h" => %Node.Has{uuid: nil, role: "Tiago's Role"}},
    %{"h" => %Node.Has{uuid: nil, role: "Davi's Role"}}
 ]}
```


```elixir
defmodule App do
  use Ex4j.Cypher

  def execute do 
    match(Node.User, as: :u)
    |> edge(Node.Has, as: :h, from: :u, to: :c, type: :out)
    |> vertex(Node.Comment, as: :c)
    |> return(:u, [:name])
    |> return(:c, [:content])
    |> run()
  end
end
```

```bash
iex> User.execute()
{:ok,[
    {"c" => %{"content" => "Tiago's Comment"}, "u" => %{"name" => "Tiago"}},
    %{"c" => %{"content" => "Davi's Comment"}, "u" => %{"name" => "Davi"}}
]}
```


```elixir
defmodule App do
  use Ex4j.Cypher

  def execute do 
    match(Node.User, as: :u)
    |> edge(Node.Has, as: :h, from: :u, to: :c, type: :out)
    |> vertex(Node.Comment, as: :c)
    |> return(:u, [:name])
    |> return(:c, [:content])
    |> cypher()
  end
end
```

```bash
  iex> User.execute()
  "MATCH (u:User)-[h:Has]->(c:Comment)\nRETURN c.content,u.name"
```

You can always execute a query directly like so: 

```elixir
defmodule App do
  use Ex4j.Cypher

  def execute do
    query = 
    """
      MATCH (n:Comment) 
      RETURN n 
      LIMIT 25
    """

    run(query)
  end
end
```

```bash
  iex> App.execute()
  {:ok,
  %Bolt.Sips.Response{
   results: [
     %{
       "n" => %Bolt.Sips.Types.Node{
         id: 2,
         properties: %{"text" => "Tiago's Comment"},
         labels: ["Comment"]
       }
     },
     %{
       "n" => %Bolt.Sips.Types.Node{
         id: 3,
         properties: %{"content" => "Davi's Comment"},
         labels: ["Comment"]
       }
     },
   ],
   fields: ["n"],
   records: [
     [
       %Bolt.Sips.Types.Node{
         id: 2,
         properties: %{"text" => "Tiago's Comment"},
         labels: ["Comment"]
       }
     ],
     [
       %Bolt.Sips.Types.Node{
         id: 3,
         properties: %{"content" => "Davi's Comment"},
         labels: ["Comment"]
       }
     ]
   ],
   plan: nil,
   notifications: [],
   stats: [],
   profile: nil,
   type: "r",
   bookmark: "FB:kcwQOoduCuitRfejxXkLly0aBBiQ"
 }}
```

## Plans 

- Add support for migrations 
- Add suport for more Cypher clauses like: CREATE, SKIP

## License

Ex4j source code is released under Apache License 2.0.

Check [NOTICE](NOTICE) and [LICENSE](LICENSE) files for more information.
