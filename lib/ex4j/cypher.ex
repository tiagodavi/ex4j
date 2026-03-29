defmodule Ex4j.Cypher do
  @moduledoc """
  Converts a `%Ex4j.Query{}` struct into a Cypher string with parameterized values.

  All user values are emitted as parameters (`$p0`, `$p1`, ...)
  to prevent injection and enable Neo4j query plan caching.

  ## Example

      {cypher, params} = Ex4j.Cypher.to_cypher(query)
      # cypher: "MATCH (u:User) WHERE u.age > $p0 RETURN u"
      # params: %{"p0" => 18}
  """

  alias Ex4j.Query
  alias Ex4j.Query.{BooleanExpr, SelectExpr, OrderExpr}

  @doc """
  Converts a Query struct into `{cypher_string, params_map}`.
  """
  @spec to_cypher(Query.t()) :: {String.t(), map()}
  def to_cypher(%Query{} = query) do
    clauses =
      []
      |> build_matches(query)
      |> build_optional_matches(query)
      |> build_wheres(query)
      |> build_withs(query)
      |> build_unwinds(query)
      |> build_calls(query)
      |> build_creates(query)
      |> build_create_rels(query)
      |> build_merges(query)
      |> build_sets(query)
      |> build_removes(query)
      |> build_deletes(query)
      |> build_returns(query)
      |> build_order_bys(query)
      |> build_skip(query)
      |> build_limit(query)

    cypher = Enum.join(clauses, "\n")

    # Handle UNION
    cypher =
      if query.unions != [] do
        union_parts =
          Enum.map(query.unions, fn {union_query, type} ->
            {union_cypher, _} = to_cypher(union_query)
            union_keyword = if type == :all, do: "UNION ALL", else: "UNION"
            "#{union_keyword}\n#{union_cypher}"
          end)

        Enum.join([cypher | union_parts], "\n")
      else
        cypher
      end

    # Collect all params (including from unions)
    all_params = collect_all_params(query)

    {cypher, all_params}
  end

  # MATCH clauses
  defp build_matches(clauses, %Query{matches: [], relationships: []}), do: clauses

  defp build_matches(clauses, %Query{matches: matches, relationships: relationships}) do
    # Group relationships by their `from` binding
    rel_map = Enum.group_by(relationships, fn {from, _, _, _, _, _} -> from end)

    match_strs =
      Enum.map(matches, fn {binding, labels, props} ->
        label_str = Enum.join(labels, ":")
        props_str = build_inline_props(props)
        node_str = "(#{binding}:#{label_str}#{props_str})"

        # Append any outgoing relationships from this node
        case Map.get(rel_map, binding) do
          nil ->
            node_str

          rels ->
            Enum.reduce(rels, node_str, fn {_from, rel_binding, rel_label, to, direction, length},
                                           acc ->
              rel_part = build_relationship_pattern(rel_binding, rel_label, direction, length)

              # Find the target node
              to_str = build_target_node(to, matches)
              acc <> rel_part <> to_str
            end)
        end
      end)

    # Filter out match nodes that are only targets of relationships
    target_bindings =
      Enum.flat_map(relationships, fn {_, _, _, to, _, _} -> [to] end)
      |> MapSet.new()

    # Only emit MATCH for nodes that aren't solely targets
    # (targets are inlined into relationship patterns)
    primary_matches =
      match_strs
      |> Enum.zip(matches)
      |> Enum.reject(fn {_str, {binding, _, _}} ->
        binding in target_bindings and not has_own_relationships?(binding, rel_map)
      end)
      |> Enum.map(fn {str, _} -> "MATCH #{str}" end)

    clauses ++ primary_matches
  end

  defp has_own_relationships?(binding, rel_map), do: Map.has_key?(rel_map, binding)

  defp build_target_node(to_binding, matches) do
    case Enum.find(matches, fn {binding, _, _} -> binding == to_binding end) do
      {binding, labels, props} ->
        label_str = Enum.join(labels, ":")
        props_str = build_inline_props(props)
        "(#{binding}:#{label_str}#{props_str})"

      nil ->
        "(#{to_binding})"
    end
  end

  defp build_inline_props(props) when props == %{}, do: ""

  defp build_inline_props(props) do
    inner =
      Enum.map(props, fn {key, param_key} -> "#{key}: $#{param_key}" end)
      |> Enum.join(", ")

    " {#{inner}}"
  end

  defp build_relationship_pattern(rel_binding, rel_label, direction, length) do
    length_str =
      case length do
        nil -> ""
        %Range{first: first, last: last} -> "*#{first}..#{last}"
        n when is_integer(n) -> "*#{n}"
      end

    rel_inner = "[#{rel_binding}:#{rel_label}#{length_str}]"

    case direction do
      :out -> "-#{rel_inner}->"
      :in -> "<-#{rel_inner}-"
      :any -> "-#{rel_inner}-"
    end
  end

  # OPTIONAL MATCH clauses
  defp build_optional_matches(clauses, %Query{optional_matches: []}), do: clauses

  defp build_optional_matches(clauses, %Query{optional_matches: opt_matches}) do
    opt_strs =
      Enum.map(opt_matches, fn {binding, labels, _opts} ->
        label_str = Enum.join(labels, ":")
        "OPTIONAL MATCH (#{binding}:#{label_str})"
      end)

    clauses ++ opt_strs
  end

  # WHERE clauses (ANDed together)
  defp build_wheres(clauses, %Query{wheres: []}), do: clauses

  defp build_wheres(clauses, %Query{wheres: wheres}) do
    where_strs = Enum.map(wheres, &expr_to_cypher/1)
    combined = Enum.join(where_strs, " AND ")
    clauses ++ ["WHERE #{combined}"]
  end

  # WITH clauses
  defp build_withs(clauses, %Query{withs: []}), do: clauses

  defp build_withs(clauses, %Query{withs: withs}) do
    with_parts =
      Enum.map(withs, fn %SelectExpr{
                           binding: binding,
                           fields: fields,
                           expr: expr,
                           alias_as: alias_as
                         } ->
        cond do
          expr != nil and alias_as != nil ->
            "#{expr_to_cypher(expr)} AS #{alias_as}"

          fields != [] ->
            Enum.map(fields, fn f -> "#{binding}.#{f}" end) |> Enum.join(", ")

          true ->
            "#{binding}"
        end
      end)

    clauses ++ ["WITH #{Enum.join(with_parts, ", ")}"]
  end

  # UNWIND clauses
  defp build_unwinds(clauses, %Query{unwinds: []}), do: clauses

  defp build_unwinds(clauses, %Query{unwinds: unwinds}) do
    unwind_strs =
      Enum.map(unwinds, fn {param_key, binding} ->
        "UNWIND $#{param_key} AS #{binding}"
      end)

    clauses ++ unwind_strs
  end

  # CALL subqueries
  defp build_calls(clauses, %Query{calls: []}), do: clauses

  defp build_calls(clauses, %Query{calls: calls}) do
    call_strs =
      Enum.map(calls, fn subquery ->
        {sub_cypher, _} = to_cypher(subquery)
        "CALL {\n  #{String.replace(sub_cypher, "\n", "\n  ")}\n}"
      end)

    clauses ++ call_strs
  end

  # CREATE clauses
  defp build_creates(clauses, %Query{creates: []}), do: clauses

  defp build_creates(clauses, %Query{creates: creates}) do
    create_strs =
      Enum.map(creates, fn {binding, labels, param_props} ->
        label_str = Enum.join(labels, ":")

        props_str =
          if map_size(param_props) > 0 do
            props =
              Enum.map(param_props, fn {key, param_key} -> "#{key}: $#{param_key}" end)
              |> Enum.join(", ")

            " {#{props}}"
          else
            ""
          end

        "CREATE (#{binding}:#{label_str}#{props_str})"
      end)

    clauses ++ create_strs
  end

  # CREATE relationship clauses
  defp build_create_rels(clauses, %Query{create_rels: []}), do: clauses

  defp build_create_rels(clauses, %Query{create_rels: create_rels}) do
    create_rel_strs =
      Enum.map(create_rels, fn {from, rel_binding, rel_type, to, direction, param_props} ->
        props_str =
          if map_size(param_props) > 0 do
            props =
              Enum.map(param_props, fn {key, param_key} -> "#{key}: $#{param_key}" end)
              |> Enum.join(", ")

            " {#{props}}"
          else
            ""
          end

        rel_inner = "[#{rel_binding}:#{rel_type}#{props_str}]"

        rel_pattern =
          case direction do
            :out -> "-#{rel_inner}->"
            :in -> "<-#{rel_inner}-"
            :any -> "-#{rel_inner}-"
          end

        "CREATE (#{from})#{rel_pattern}(#{to})"
      end)

    clauses ++ create_rel_strs
  end

  # MERGE clauses
  defp build_merges(clauses, %Query{merges: []}), do: clauses

  defp build_merges(clauses, %Query{merges: merges}) do
    merge_strs =
      Enum.map(merges, fn {binding, labels, param_props} ->
        label_str = Enum.join(labels, ":")

        props_str =
          if map_size(param_props) > 0 do
            props =
              Enum.map(param_props, fn {key, param_key} -> "#{key}: $#{param_key}" end)
              |> Enum.join(", ")

            " {#{props}}"
          else
            ""
          end

        "MERGE (#{binding}:#{label_str}#{props_str})"
      end)

    clauses ++ merge_strs
  end

  # SET clauses
  defp build_sets(clauses, %Query{sets: []}), do: clauses

  defp build_sets(clauses, %Query{sets: sets}) do
    set_parts =
      Enum.map(sets, fn {binding, field, param_key} ->
        "#{binding}.#{field} = $#{param_key}"
      end)

    clauses ++ ["SET #{Enum.join(set_parts, ", ")}"]
  end

  # REMOVE clauses
  defp build_removes(clauses, %Query{removes: []}), do: clauses

  defp build_removes(clauses, %Query{removes: removes}) do
    remove_parts =
      Enum.map(removes, fn {binding, field} ->
        "#{binding}.#{field}"
      end)

    clauses ++ ["REMOVE #{Enum.join(remove_parts, ", ")}"]
  end

  # DELETE clauses
  defp build_deletes(clauses, %Query{deletes: []}), do: clauses

  defp build_deletes(clauses, %Query{deletes: deletes}) do
    delete_strs =
      Enum.map(deletes, fn {binding, opts} ->
        if Keyword.get(opts, :detach, false) do
          "DETACH DELETE #{binding}"
        else
          "DELETE #{binding}"
        end
      end)

    clauses ++ delete_strs
  end

  # RETURN clauses
  defp build_returns(clauses, %Query{returns: []}), do: clauses

  defp build_returns(clauses, %Query{returns: returns}) do
    return_parts =
      Enum.map(returns, fn %SelectExpr{
                             binding: binding,
                             fields: fields,
                             expr: expr,
                             alias_as: alias_as
                           } ->
        cond do
          expr != nil and alias_as != nil ->
            "#{expr_to_cypher(expr)} AS #{alias_as}"

          expr != nil ->
            expr_to_cypher(expr)

          fields != [] ->
            Enum.map(fields, fn f -> "#{binding}.#{f}" end) |> Enum.join(", ")

          true ->
            "#{binding}"
        end
      end)

    clauses ++ ["RETURN #{Enum.join(return_parts, ", ")}"]
  end

  # ORDER BY clauses
  defp build_order_bys(clauses, %Query{order_bys: []}), do: clauses

  defp build_order_bys(clauses, %Query{order_bys: order_bys}) do
    order_parts =
      Enum.map(order_bys, fn %OrderExpr{binding: binding, field: field, direction: direction} ->
        dir = if direction == :desc, do: " DESC", else: ""
        "#{binding}.#{field}#{dir}"
      end)

    clauses ++ ["ORDER BY #{Enum.join(order_parts, ", ")}"]
  end

  # SKIP clause
  defp build_skip(clauses, %Query{skip: nil}), do: clauses
  defp build_skip(clauses, %Query{skip: skip}), do: clauses ++ ["SKIP #{skip}"]

  # LIMIT clause
  defp build_limit(clauses, %Query{limit: nil}), do: clauses
  defp build_limit(clauses, %Query{limit: limit}), do: clauses ++ ["LIMIT #{limit}"]

  # Expression to Cypher string conversion

  defp expr_to_cypher(%BooleanExpr{op: :and, left: left, right: right}) do
    "(#{expr_to_cypher(left)} AND #{expr_to_cypher(right)})"
  end

  defp expr_to_cypher(%BooleanExpr{op: :or, left: left, right: right}) do
    "(#{expr_to_cypher(left)} OR #{expr_to_cypher(right)})"
  end

  defp expr_to_cypher(%BooleanExpr{op: :not, left: expr}) do
    "NOT #{expr_to_cypher(expr)}"
  end

  defp expr_to_cypher(%BooleanExpr{op: :eq, left: left, right: right}) do
    "#{expr_to_cypher(left)} = #{expr_to_cypher(right)}"
  end

  defp expr_to_cypher(%BooleanExpr{op: :neq, left: left, right: right}) do
    "#{expr_to_cypher(left)} <> #{expr_to_cypher(right)}"
  end

  defp expr_to_cypher(%BooleanExpr{op: :gt, left: left, right: right}) do
    "#{expr_to_cypher(left)} > #{expr_to_cypher(right)}"
  end

  defp expr_to_cypher(%BooleanExpr{op: :gte, left: left, right: right}) do
    "#{expr_to_cypher(left)} >= #{expr_to_cypher(right)}"
  end

  defp expr_to_cypher(%BooleanExpr{op: :lt, left: left, right: right}) do
    "#{expr_to_cypher(left)} < #{expr_to_cypher(right)}"
  end

  defp expr_to_cypher(%BooleanExpr{op: :lte, left: left, right: right}) do
    "#{expr_to_cypher(left)} <= #{expr_to_cypher(right)}"
  end

  defp expr_to_cypher(%BooleanExpr{op: :in, left: left, right: right}) do
    "#{expr_to_cypher(left)} IN #{expr_to_cypher(right)}"
  end

  defp expr_to_cypher(%BooleanExpr{op: :not_in, left: left, right: right}) do
    "NOT #{expr_to_cypher(left)} IN #{expr_to_cypher(right)}"
  end

  defp expr_to_cypher(%BooleanExpr{op: :contains, left: left, right: right}) do
    "#{expr_to_cypher(left)} CONTAINS #{expr_to_cypher(right)}"
  end

  defp expr_to_cypher(%BooleanExpr{op: :starts_with, left: left, right: right}) do
    "#{expr_to_cypher(left)} STARTS WITH #{expr_to_cypher(right)}"
  end

  defp expr_to_cypher(%BooleanExpr{op: :ends_with, left: left, right: right}) do
    "#{expr_to_cypher(left)} ENDS WITH #{expr_to_cypher(right)}"
  end

  defp expr_to_cypher(%BooleanExpr{op: :is_nil, left: expr}) do
    "#{expr_to_cypher(expr)} IS NULL"
  end

  defp expr_to_cypher(%BooleanExpr{op: :is_not_nil, left: expr}) do
    "#{expr_to_cypher(expr)} IS NOT NULL"
  end

  defp expr_to_cypher(%BooleanExpr{op: :regex_match, left: left, right: right}) do
    "#{expr_to_cypher(left)} =~ #{expr_to_cypher(right)}"
  end

  # Operands
  defp expr_to_cypher({:field, binding, field}) do
    "#{binding}.#{field}"
  end

  defp expr_to_cypher({:param, key}) do
    "$#{key}"
  end

  defp expr_to_cypher({:literal, nil}), do: "null"
  defp expr_to_cypher({:literal, value}), do: "#{inspect(value)}"

  defp expr_to_cypher({:binding, binding}), do: "#{binding}"

  defp expr_to_cypher({:func, name, args}) do
    cypher_name = Ex4j.Cypher.Functions.to_cypher_name(name)
    arg_strs = Enum.map(args, &expr_to_cypher/1) |> Enum.join(", ")
    "#{cypher_name}(#{arg_strs})"
  end

  defp expr_to_cypher({:fragment, cypher_template, args}) do
    Ex4j.Cypher.Fragment.render(cypher_template, args)
  end

  defp expr_to_cypher({:list, elements}) do
    inner = Enum.map(elements, &expr_to_cypher/1) |> Enum.join(", ")
    "[#{inner}]"
  end

  # Collect params from query and all union subqueries
  defp collect_all_params(%Query{params: params, unions: unions}) do
    union_params =
      Enum.reduce(unions, %{}, fn {union_query, _}, acc ->
        Map.merge(acc, collect_all_params(union_query))
      end)

    Map.merge(params, union_params)
  end
end
