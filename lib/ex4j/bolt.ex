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
    conn = Process.get(:ex4j_tx_conn) || @pool_name
    query = %Boltx.Query{statement: cypher, extra: query_extra()}
    formatted_params = format_params(params)

    case DBConnection.prepare_execute(conn, query, formatted_params) do
      {:ok, _query, result} -> {:ok, result}
      {:error, _} = error -> error
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

  defp query_extra do
    case Application.get_env(:ex4j, :database) do
      nil -> %{}
      db -> %{db: db}
    end
  end

  defp format_params(params) do
    params
    |> Enum.map(&format_param/1)
    |> Map.new()
  end

  defp format_param({k, %Boltx.Types.Duration{} = v}),
    do: {k, Boltx.Types.Duration.format_param(v)}

  defp format_param({k, %Boltx.Types.Point{} = v}),
    do: {k, Boltx.Types.Point.format_param(v)}

  defp format_param({k, v}), do: {k, v}
end
