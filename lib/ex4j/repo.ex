defmodule Ex4j.Repo do
  @moduledoc """
  Defines a repository for executing Cypher queries against Neo4j.

  A repository maps to a Neo4j database connection. You can define
  a repository in your application:

      defmodule MyApp.Repo do
        use Ex4j.Repo, otp_app: :my_app
      end

  Configuration in `config/config.exs`:

      config :my_app, MyApp.Repo,
        url: "bolt://localhost:7687",
        basic_auth: [username: "neo4j", password: "neo4j"],
        pool_size: 10

  ## Usage

      import Ex4j.Query.API

      # Read queries
      query = User |> match(as: :u) |> where([u], u.age > 18) |> return([:u])
      {:ok, results} = MyApp.Repo.all(query)

      # Single result
      {:ok, user} = MyApp.Repo.one(query |> limit(1))

      # Write operations
      {:ok, results} = MyApp.Repo.run(create_query)

      # Raw Cypher
      {:ok, results} = MyApp.Repo.query("MATCH (n:User) RETURN n LIMIT 25")

      # Transactions
      {:ok, results} = MyApp.Repo.transaction(fn ->
        MyApp.Repo.run(query1)
        MyApp.Repo.run(query2)
      end)
  """

  defmacro __using__(opts) do
    otp_app = Keyword.fetch!(opts, :otp_app)

    quote do
      @otp_app unquote(otp_app)

      def config do
        Application.get_env(@otp_app, __MODULE__, [])
      end

      @doc """
      Executes a query and returns all results.
      """
      @spec all(Ex4j.Query.t() | module()) :: {:ok, [map()]} | {:error, term()}
      def all(queryable) do
        Ex4j.Repo.Runner.all(queryable, config())
      end

      @doc """
      Executes a query and returns the first result.
      """
      @spec one(Ex4j.Query.t() | module()) :: {:ok, map() | nil} | {:error, term()}
      def one(queryable) do
        Ex4j.Repo.Runner.one(queryable, config())
      end

      @doc """
      Executes a query and returns raw results.
      """
      @spec run(Ex4j.Query.t() | module()) :: {:ok, term()} | {:error, term()}
      def run(queryable) do
        Ex4j.Repo.Runner.run(queryable, config())
      end

      @doc """
      Executes a raw Cypher query string with optional parameters.
      """
      @spec query(String.t(), map()) :: {:ok, term()} | {:error, term()}
      def query(cypher_string, params \\ %{}) do
        Ex4j.Repo.Runner.query(cypher_string, params, config())
      end

      @doc """
      Executes operations within a transaction.
      """
      @spec transaction(function()) :: {:ok, term()} | {:error, term()}
      def transaction(fun) when is_function(fun) do
        Ex4j.Repo.Runner.transaction(fun, config())
      end

      @doc """
      Returns the Cypher string and params for a query without executing it.
      Useful for debugging.
      """
      @spec to_cypher(Ex4j.Query.t() | module()) :: {String.t(), map()}
      def to_cypher(queryable) do
        query = Ex4j.Query.Builder.ensure_query(queryable)
        Ex4j.Cypher.to_cypher(query)
      end
    end
  end
end
