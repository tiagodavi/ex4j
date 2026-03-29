defmodule Ex4j do
  @moduledoc """
  An Ecto-inspired Cypher DSL and Neo4j driver for Elixir.

  Ex4j provides a macro-based query builder that compiles Elixir expressions
  into parameterized Cypher queries, preventing injection and enabling
  Neo4j query plan caching.

  ## Setup

  Add the dependency:

      def deps do
        [{:ex4j, "~> 2.0"}]
      end

  Configure the connection:

      config :ex4j, Boltx,
        url: "bolt://localhost:7687",
        basic_auth: [username: "neo4j", password: "password"],
        pool_size: 10

      # For Neo4j Aura:
      config :ex4j, Boltx,
        url: "neo4j+s://your-instance.databases.neo4j.io",
        basic_auth: [username: "your_username", password: "your_password"],
        database: "your-database-name",
        pool_size: 5

  Define a Repo:

      defmodule MyApp.Repo do
        use Ex4j.Repo, otp_app: :my_app
      end

  ## Defining Schemas

      defmodule MyApp.User do
        use Ex4j.Schema

        node "User" do
          field :name, :string
          field :age, :integer
          field :email, :string
        end

        def changeset(user, attrs) do
          user
          |> cast(attrs, [:name, :age, :email])
          |> validate_required([:name, :email])
        end
      end

      defmodule MyApp.Comment do
        use Ex4j.Schema

        node "Comment" do
          field :content, :string
        end
      end

      defmodule MyApp.HasComment do
        use Ex4j.Schema

        relationship "HAS_COMMENT" do
          from MyApp.User
          to MyApp.Comment
          field :created_at, :utc_datetime
        end
      end

  ## Building Queries

      import Ex4j.Query.API

      # Read with macro-based WHERE (parameterized, safe)
      User
      |> match(as: :u)
      |> where([u], u.age > 18 and u.name == "Tiago")
      |> return([:u])
      |> limit(10)
      |> MyApp.Repo.all()

      # Runtime values with pin operator
      name = "Tiago"
      User
      |> match(as: :u)
      |> where([u], u.name == ^name)
      |> return([u], [:name, :age])
      |> MyApp.Repo.all()

      # Relationship traversal
      User
      |> match(as: :u)
      |> edge(HasComment, as: :r, from: :u, to: :c, direction: :out)
      |> match(Comment, as: :c)
      |> where([c], c.content =~ "Article")
      |> return([:u, :c])
      |> MyApp.Repo.all()

      # CREATE
      query()
      |> create(User, as: :u, set: %{name: "Alice", age: 30, email: "alice@example.com"})
      |> return([:u])
      |> MyApp.Repo.run()

      # MERGE + SET
      query()
      |> merge(User, as: :u, match: %{email: "alice@example.com"})
      |> set(:u, :name, "Alice Updated")
      |> return([:u])
      |> MyApp.Repo.run()

      # DELETE
      User
      |> match(as: :u)
      |> where([u], u.name == "Alice")
      |> delete(:u, detach: true)
      |> MyApp.Repo.run()

      # Dynamic queries for runtime conditions
      dynamic = Enum.reduce(filters, dynamic([u], true), fn
        {:name, name}, dyn -> dynamic([u], ^dyn and u.name == ^name)
        {:min_age, age}, dyn -> dynamic([u], ^dyn and u.age >= ^age)
      end)

      User |> match(as: :u) |> where(^dynamic) |> return([:u]) |> MyApp.Repo.all()

      # Fragment for raw Cypher
      User
      |> match(as: :u)
      |> where([u], fragment("u.score > duration(?)", "P1Y"))
      |> return([:u])
      |> MyApp.Repo.all()

      # Raw Cypher query (full escape hatch)
      MyApp.Repo.query("MATCH (n:User) RETURN n LIMIT 25")

      # Transactions
      MyApp.Repo.transaction(fn ->
        MyApp.Repo.run(create_query)
        MyApp.Repo.run(relationship_query)
      end)

  ## Cypher 25 Support

  Ex4j supports the latest Cypher 25 features including:
  - Walk semantics (REPEATABLE ELEMENTS)
  - Vector operations (vector(), vector_distance(), etc.)
  - Full aggregation function set
  - Subqueries with CALL {}
  - UNION / UNION ALL
  - Variable-length relationship patterns
  """
end
