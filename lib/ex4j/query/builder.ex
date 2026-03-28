defmodule Ex4j.Query.Builder do
  @moduledoc """
  Internal module that applies compiled expressions to the Query struct.

  Each `apply_*` function takes a query and an expression, and returns
  an updated query with the expression added to the appropriate clause list.
  """

  alias Ex4j.Query
  alias Ex4j.Query.{BooleanExpr, SelectExpr, OrderExpr, DynamicExpr}

  @doc """
  Resolves a queryable into a Query struct.
  """
  @spec ensure_query(Query.t() | module()) :: Query.t()
  def ensure_query(%Query{} = query), do: query

  def ensure_query(module) when is_atom(module) do
    Ex4j.Queryable.to_query(module)
  end

  @doc """
  Applies a MATCH clause.
  """
  @spec apply_match(Query.t(), atom(), String.t() | [String.t()], module() | nil) :: Query.t()
  def apply_match(%Query{} = query, binding, labels, schema_module) do
    labels = List.wrap(labels)

    %{
      query
      | matches: query.matches ++ [{binding, labels, []}],
        aliases: Map.put(query.aliases, binding, schema_module)
    }
  end

  @doc """
  Applies an OPTIONAL MATCH clause.
  """
  @spec apply_optional_match(Query.t(), atom(), String.t() | [String.t()], module() | nil) ::
          Query.t()
  def apply_optional_match(%Query{} = query, binding, labels, schema_module) do
    labels = List.wrap(labels)

    %{
      query
      | optional_matches: query.optional_matches ++ [{binding, labels, []}],
        aliases: Map.put(query.aliases, binding, schema_module)
    }
  end

  @doc """
  Applies a WHERE expression.
  """
  @spec apply_where(Query.t(), BooleanExpr.t(), map(), non_neg_integer()) :: Query.t()
  def apply_where(%Query{} = query, expr, params, param_counter) do
    # Rebase parameter keys to avoid collisions
    {rebased_expr, rebased_params} = rebase_params(expr, params, query.param_counter)

    %{
      query
      | wheres: query.wheres ++ [rebased_expr],
        params: Map.merge(query.params, rebased_params),
        param_counter: query.param_counter + param_counter
    }
  end

  @doc """
  Applies a WHERE from a dynamic expression.
  """
  @spec apply_where_dynamic(Query.t(), DynamicExpr.t()) :: Query.t()
  def apply_where_dynamic(%Query{} = query, %DynamicExpr{} = dynamic) do
    {rebased_expr, rebased_params} =
      rebase_params(dynamic.expr, dynamic.params, query.param_counter)

    %{
      query
      | wheres: query.wheres ++ [rebased_expr],
        params: Map.merge(query.params, rebased_params),
        param_counter: query.param_counter + dynamic.param_counter
    }
  end

  @doc """
  Applies a RETURN clause.
  """
  @spec apply_return(Query.t(), atom(), [atom()]) :: Query.t()
  def apply_return(%Query{} = query, binding, fields) do
    select = %SelectExpr{binding: binding, fields: fields}
    %{query | returns: query.returns ++ [select]}
  end

  @doc """
  Applies a RETURN clause with an expression (for aggregations).
  """
  @spec apply_return_expr(Query.t(), term(), atom()) :: Query.t()
  def apply_return_expr(%Query{} = query, expr, alias_as) do
    select = %SelectExpr{binding: nil, fields: [], expr: expr, alias_as: alias_as}
    %{query | returns: query.returns ++ [select]}
  end

  @doc """
  Applies an ORDER BY clause.
  """
  @spec apply_order_by(Query.t(), atom(), atom(), :asc | :desc) :: Query.t()
  def apply_order_by(%Query{} = query, binding, field, direction) do
    order = %OrderExpr{binding: binding, field: field, direction: direction}
    %{query | order_bys: query.order_bys ++ [order]}
  end

  @doc """
  Applies a SKIP clause.
  """
  @spec apply_skip(Query.t(), non_neg_integer()) :: Query.t()
  def apply_skip(%Query{} = query, skip) when is_integer(skip) and skip >= 0 do
    %{query | skip: skip}
  end

  @doc """
  Applies a LIMIT clause.
  """
  @spec apply_limit(Query.t(), non_neg_integer()) :: Query.t()
  def apply_limit(%Query{} = query, limit) when is_integer(limit) and limit >= 0 do
    %{query | limit: limit}
  end

  @doc """
  Applies a CREATE clause.
  """
  @spec apply_create(Query.t(), atom(), String.t() | [String.t()], map(), module() | nil) ::
          Query.t()
  def apply_create(%Query{} = query, binding, labels, props, schema_module) do
    labels = List.wrap(labels)

    # Parameterize properties
    {param_props, query} =
      Enum.reduce(props, {%{}, query}, fn {key, value}, {acc, q} ->
        {q, param_key} = Query.add_param(q, value)
        {Map.put(acc, key, param_key), q}
      end)

    %{
      query
      | creates: query.creates ++ [{binding, labels, param_props}],
        aliases: Map.put(query.aliases, binding, schema_module)
    }
  end

  @doc """
  Applies a MERGE clause.
  """
  @spec apply_merge(Query.t(), atom(), String.t() | [String.t()], map(), module() | nil) ::
          Query.t()
  def apply_merge(%Query{} = query, binding, labels, props, schema_module) do
    labels = List.wrap(labels)

    {param_props, query} =
      Enum.reduce(props, {%{}, query}, fn {key, value}, {acc, q} ->
        {q, param_key} = Query.add_param(q, value)
        {Map.put(acc, key, param_key), q}
      end)

    %{
      query
      | merges: query.merges ++ [{binding, labels, param_props}],
        aliases: Map.put(query.aliases, binding, schema_module)
    }
  end

  @doc """
  Applies a SET clause.
  """
  @spec apply_set(Query.t(), atom(), atom(), term()) :: Query.t()
  def apply_set(%Query{} = query, binding, field, value) do
    {query, param_key} = Query.add_param(query, value)
    %{query | sets: query.sets ++ [{binding, field, param_key}]}
  end

  @doc """
  Applies a DELETE clause.
  """
  @spec apply_delete(Query.t(), atom(), keyword()) :: Query.t()
  def apply_delete(%Query{} = query, binding, opts) do
    %{query | deletes: query.deletes ++ [{binding, opts}]}
  end

  @doc """
  Applies a REMOVE clause.
  """
  @spec apply_remove(Query.t(), atom(), atom()) :: Query.t()
  def apply_remove(%Query{} = query, binding, field) do
    %{query | removes: query.removes ++ [{binding, field}]}
  end

  @doc """
  Applies a relationship (edge) pattern.
  """
  @spec apply_edge(
          Query.t(),
          atom(),
          atom(),
          String.t(),
          atom(),
          atom(),
          :out | :in | :any,
          Range.t() | nil
        ) :: Query.t()
  def apply_edge(
        %Query{} = query,
        from,
        rel_binding,
        rel_label,
        to,
        to_label_or_nil,
        direction,
        length \\ nil
      ) do
    %{
      query
      | relationships:
          query.relationships ++ [{from, rel_binding, rel_label, to, direction, length}],
        aliases:
          if to_label_or_nil do
            Map.put(query.aliases, rel_binding, nil)
          else
            Map.put(query.aliases, rel_binding, nil)
          end
    }
  end

  @doc """
  Applies a WITH clause.
  """
  @spec apply_with(Query.t(), [SelectExpr.t()]) :: Query.t()
  def apply_with(%Query{} = query, selects) do
    %{query | withs: query.withs ++ selects}
  end

  @doc """
  Applies an UNWIND clause.
  """
  @spec apply_unwind(Query.t(), term(), atom()) :: Query.t()
  def apply_unwind(%Query{} = query, expr, binding) do
    {query, param_key} = Query.add_param(query, expr)
    %{query | unwinds: query.unwinds ++ [{param_key, binding}]}
  end

  @doc """
  Applies a UNION clause.
  """
  @spec apply_union(Query.t(), Query.t(), :all | :distinct) :: Query.t()
  def apply_union(%Query{} = query, %Query{} = other, type) do
    %{query | unions: query.unions ++ [{other, type}]}
  end

  @doc """
  Applies a CALL subquery.
  """
  @spec apply_call(Query.t(), Query.t()) :: Query.t()
  def apply_call(%Query{} = query, %Query{} = subquery) do
    %{query | calls: query.calls ++ [subquery]}
  end

  # Rebases parameter keys to avoid collision with existing params
  defp rebase_params(expr, params, base_counter) do
    key_map =
      params
      |> Map.keys()
      |> Enum.with_index()
      |> Enum.map(fn {old_key, idx} -> {old_key, "p#{base_counter + idx}"} end)
      |> Map.new()

    rebased_expr = rebase_expr(expr, key_map)
    rebased_params = Enum.map(params, fn {k, v} -> {Map.get(key_map, k, k), v} end) |> Map.new()

    {rebased_expr, rebased_params}
  end

  defp rebase_expr(%BooleanExpr{} = expr, key_map) do
    %{
      expr
      | left: rebase_expr(expr.left, key_map),
        right: rebase_expr(expr.right, key_map)
    }
  end

  defp rebase_expr({:param, key}, key_map), do: {:param, Map.get(key_map, key, key)}
  defp rebase_expr({:field, _, _} = field, _key_map), do: field
  defp rebase_expr({:literal, _} = lit, _key_map), do: lit
  defp rebase_expr({:binding, _} = b, _key_map), do: b

  defp rebase_expr({:func, name, args}, key_map) do
    {:func, name, Enum.map(args, &rebase_expr(&1, key_map))}
  end

  defp rebase_expr({:fragment, cypher, args}, key_map) do
    {:fragment, cypher, Enum.map(args, &rebase_expr(&1, key_map))}
  end

  defp rebase_expr({:list, elements}, key_map) do
    {:list, Enum.map(elements, &rebase_expr(&1, key_map))}
  end

  defp rebase_expr(nil, _key_map), do: nil
end
