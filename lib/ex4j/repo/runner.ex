defmodule Ex4j.Repo.Runner do
  @moduledoc """
  Executes queries against Neo4j via the Bolt adapter.

  Pipeline: Query -> Queryable.to_query -> Cypher.to_cypher -> Boltx.query -> Result.hydrate
  """

  alias Ex4j.Query.Builder
  alias Ex4j.Cypher
  alias Ex4j.Repo.Result

  @doc """
  Executes a query and returns all results as hydrated structs.
  """
  @spec all(Ex4j.Query.t() | module(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def all(queryable, _config) do
    query = Builder.ensure_query(queryable)
    {cypher_str, params} = Cypher.to_cypher(query)

    case Ex4j.Bolt.query(cypher_str, params) do
      {:ok, results} ->
        hydrated = Result.hydrate(results, query)
        {:ok, hydrated}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Executes a query and returns the first result.
  """
  @spec one(Ex4j.Query.t() | module(), keyword()) :: {:ok, map() | nil} | {:error, term()}
  def one(queryable, config) do
    case all(queryable, config) do
      {:ok, [first | _]} -> {:ok, first}
      {:ok, []} -> {:ok, nil}
      {:error, _} = error -> error
    end
  end

  @doc """
  Executes a query and returns raw results.
  """
  @spec run(Ex4j.Query.t() | module(), keyword()) :: {:ok, term()} | {:error, term()}
  def run(queryable, _config) do
    query = Builder.ensure_query(queryable)
    {cypher_str, params} = Cypher.to_cypher(query)
    Ex4j.Bolt.query(cypher_str, params)
  end

  @doc """
  Executes a raw Cypher query string.
  """
  @spec query(String.t(), map(), keyword()) :: {:ok, term()} | {:error, term()}
  def query(cypher_string, params, _config) when is_binary(cypher_string) do
    Ex4j.Bolt.query(cypher_string, params)
  end

  @doc """
  Executes operations within a transaction.
  """
  @spec transaction(function(), keyword()) :: {:ok, term()} | {:error, term()}
  def transaction(fun, _config) when is_function(fun) do
    Ex4j.Bolt.transaction(fun)
  end
end
