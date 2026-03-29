defmodule Ex4j.Query do
  @moduledoc """
  Represents a composable Cypher query.

  The `%Ex4j.Query{}` struct accumulates query clauses through pipe-based
  composition. Each function in `Ex4j.Query.API` accepts a Query (or Queryable)
  and returns a Query, enabling natural Elixir pipe chains.

  ## Example

      import Ex4j.Query.API

      User
      |> match(as: :u)
      |> where([u], u.age > 18)
      |> return([:u])
      |> limit(10)
  """

  alias Ex4j.Query.{BooleanExpr, SelectExpr, OrderExpr}

  @type binding :: atom()
  @type direction :: :out | :in | :any
  @type match_entry :: {binding(), String.t(), keyword()}
  @type relationship_entry ::
          {binding(), binding(), String.t(), binding(), direction(), Range.t() | nil}

  @type create_rel_entry ::
          {binding(), binding(), String.t(), binding(), :out | :in | :any, map()}

  @type t :: %__MODULE__{
          source: module() | nil,
          matches: [match_entry()],
          optional_matches: [match_entry()],
          creates: [{binding(), String.t(), map()}],
          create_rels: [create_rel_entry()],
          merges: [{binding(), String.t(), map()}],
          wheres: [BooleanExpr.t()],
          returns: [SelectExpr.t()],
          order_bys: [OrderExpr.t()],
          sets: [{binding(), atom(), term()}],
          deletes: [{binding(), keyword()}],
          removes: [{binding(), atom()}],
          skip: non_neg_integer() | nil,
          limit: non_neg_integer() | nil,
          withs: [SelectExpr.t()],
          unwinds: [{term(), binding()}],
          unions: [{t(), :all | :distinct}],
          calls: [t()],
          relationships: [relationship_entry()],
          params: map(),
          param_counter: non_neg_integer(),
          aliases: %{binding() => module()},
          fragments: [term()]
        }

  defstruct source: nil,
            matches: [],
            optional_matches: [],
            creates: [],
            create_rels: [],
            merges: [],
            wheres: [],
            returns: [],
            order_bys: [],
            sets: [],
            deletes: [],
            removes: [],
            skip: nil,
            limit: nil,
            withs: [],
            unwinds: [],
            unions: [],
            calls: [],
            relationships: [],
            params: %{},
            param_counter: 0,
            aliases: %{},
            fragments: []

  @doc """
  Creates an empty query.
  """
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  Adds a parameter to the query, returning the updated query and parameter key.
  """
  @spec add_param(t(), term()) :: {t(), String.t()}
  def add_param(%__MODULE__{param_counter: counter, params: params} = query, value) do
    key = "p#{counter}"

    updated_query = %{
      query
      | param_counter: counter + 1,
        params: Map.put(params, key, value)
    }

    {updated_query, key}
  end

  @doc """
  Merges params from another source into this query.
  """
  @spec merge_params(t(), map()) :: t()
  def merge_params(%__MODULE__{} = query, new_params) when is_map(new_params) do
    %{query | params: Map.merge(query.params, new_params)}
  end
end
