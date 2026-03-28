defmodule Ex4j.Bolt do
  @moduledoc """
  Thin adapter over Boltx for Neo4j communication.

  Provides a consistent interface for query execution, connection management,
  and transactions. This abstraction allows swapping the underlying Bolt
  implementation without changing user-facing code.

  The connection is managed via the Boltx pool started in `Ex4j.Application`.
  The pool name defaults to `Ex4j.Bolt` and is registered when the application starts.
  """

  @pool_name __MODULE__

  @doc """
  Returns the pool name used for Boltx connections.
  """
  def pool_name, do: @pool_name

  @doc """
  Executes a Cypher query with parameters.
  """
  @spec query(String.t(), map()) :: {:ok, term()} | {:error, term()}
  def query(cypher, params \\ %{}) do
    case Process.get(:ex4j_tx_conn) do
      nil -> Boltx.query(@pool_name, cypher, params)
      conn -> Boltx.query(conn, cypher, params)
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  @doc """
  Executes a function within a Neo4j transaction.
  """
  @spec transaction(function()) :: {:ok, term()} | {:error, term()}
  def transaction(fun) when is_function(fun) do
    Boltx.transaction(@pool_name, fn conn ->
      Process.put(:ex4j_tx_conn, conn)

      try do
        fun.()
      after
        Process.delete(:ex4j_tx_conn)
      end
    end)
  rescue
    e -> {:error, Exception.message(e)}
  end
end
