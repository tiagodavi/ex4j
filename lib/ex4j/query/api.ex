defmodule Ex4j.Query.API do
  @moduledoc """
  Public macro API for building Cypher queries.

  Import this module to use the query DSL:

      import Ex4j.Query.API

  All macros accept a Query (or Queryable) and return a Query,
  enabling pipe-based composition.

  ## Examples

      import Ex4j.Query.API

      # Simple read query
      User
      |> match(as: :u)
      |> where([u], u.age > 18 and u.name == "Tiago")
      |> return([:u])
      |> limit(10)

      # Relationship traversal
      User
      |> match(as: :u)
      |> edge(HasComment, as: :r, from: :u, to: :c, direction: :out)
      |> match(Comment, as: :c)
      |> where([u], u.name == ^user_name)
      |> return([:u, :c])

      # Create
      User
      |> create(as: :u, set: %{name: "Alice", age: 30})
      |> return([:u])

      # Fragment (raw Cypher)
      User
      |> match(as: :u)
      |> where([u], fragment("u.score > duration(?)", "P1Y"))
      |> return([:u])
  """

  alias Ex4j.Query
  alias Ex4j.Query.{Builder, Compiler, DynamicExpr, SelectExpr}

  @doc """
  Creates an empty query. Useful as a starting point for queries
  that don't begin with a schema.
  """
  @spec query() :: Query.t()
  def query, do: Query.new()

  @doc """
  Creates a MATCH clause.

  ## Options

    - `:as` - binding name (required)
    - `:mode` - match mode: `:repeatable_elements` for Cypher 25 walk semantics

  ## Examples

      User |> match(as: :u)
      query |> match(User, as: :u)
  """
  defmacro match(queryable, opts) do
    {schema, binding, _mode, where} = extract_match_opts(opts)
    where = where || {:%{}, [], []}

    if schema do
      quote do
        query = Builder.ensure_query(unquote(queryable))
        module = unquote(schema)
        labels = module.__schema__(:ex4j_labels)
        Builder.apply_match(query, unquote(binding), labels, module, unquote(where))
      end
    else
      quote do
        query = Builder.ensure_query(unquote(queryable))
        source = query.source
        labels = if source, do: source.__schema__(:ex4j_labels), else: []
        Builder.apply_match(query, unquote(binding), labels, source, unquote(where))
      end
    end
  end

  defmacro match(queryable, schema, opts) do
    {_schema, binding, _mode, where} = extract_match_opts(opts)
    where = where || {:%{}, [], []}

    quote do
      query = Builder.ensure_query(unquote(queryable))
      module = unquote(schema)
      labels = module.__schema__(:ex4j_labels)
      Builder.apply_match(query, unquote(binding), labels, module, unquote(where))
    end
  end

  @doc """
  Creates an OPTIONAL MATCH clause.

  ## Examples

      User
      |> match(as: :u)
      |> optional_match(Comment, as: :c)
  """
  defmacro optional_match(queryable, schema, opts) do
    {_schema, binding, _mode, _where} = extract_match_opts(opts)

    quote do
      query = Builder.ensure_query(unquote(queryable))
      module = unquote(schema)
      labels = module.__schema__(:ex4j_labels)
      Builder.apply_optional_match(query, unquote(binding), labels, module)
    end
  end

  @doc """
  Creates a WHERE clause using macro-based expressions.

  Expressions are compiled at macro expansion time into parameterized
  Cypher. All values become parameters to prevent injection.

  ## Binding Syntax

  Use `[binding_name]` to declare which binding the expression refers to:

      where(query, [u], u.age > 18)
      where(query, [u, c], u.age > 18 and c.active == true)

  ## Supported Operators

    - Comparison: `==`, `!=`, `>`, `>=`, `<`, `<=`
    - Boolean: `and`, `or`, `not`
    - Membership: `in`, `not in`
    - String: `=~` (CONTAINS), `starts_with/2`, `ends_with/2`
    - Null check: `is_nil/1`
    - Pin: `^variable` for runtime values
    - Fragment: `fragment("cypher ?", value)` for raw Cypher

  ## Examples

      # Static values (parameterized)
      where(query, [u], u.age > 18)

      # Runtime values with pin
      where(query, [u], u.name == ^user_name)

      # Complex expressions
      where(query, [u], u.age > 18 and (u.city == "NYC" or u.city == "LA"))

      # Dynamic expression
      where(query, ^dynamic_expr)
  """
  defmacro where(queryable, bindings_or_dynamic, expr \\ nil) do
    case extract_where_args(bindings_or_dynamic, expr) do
      {:dynamic, var_ast} ->
        # var_ast is the inner variable reference (without ^)
        quote do
          query = Builder.ensure_query(unquote(queryable))
          Builder.apply_where_dynamic(query, unquote(var_ast))
        end

      {:expr, bindings, expression} ->
        {compiled, params, counter} = Compiler.compile(expression, bindings, __CALLER__)

        # Build the params map at runtime (resolve pinned variables)
        params_ast = build_params_ast(params)

        quote do
          query = Builder.ensure_query(unquote(queryable))

          Builder.apply_where(
            query,
            unquote(Macro.escape(compiled)),
            unquote(params_ast),
            unquote(counter)
          )
        end
    end
  end

  @doc """
  Creates a RETURN clause.

  ## Examples

      # Return whole nodes
      return(query, [:u, :c])

      # Return specific fields
      return(query, [u], [:name, :age])

      # Return a single binding
      return(query, :u)
  """
  defmacro return(queryable, bindings_or_binding, fields \\ nil) do
    cond do
      # return(query, [:u, :c]) - list of bindings
      is_list(bindings_or_binding) and is_nil(fields) ->
        returns =
          Enum.map(bindings_or_binding, fn binding ->
            quote do: Builder.apply_return(acc, unquote(binding), [])
          end)

        quote do
          acc = Builder.ensure_query(unquote(queryable))

          unquote(
            Enum.reduce(returns, quote(do: acc), fn ret, acc_ast ->
              quote do
                acc = unquote(acc_ast)
                unquote(ret)
              end
            end)
          )
        end

      # return(query, :u) - single binding
      is_atom(bindings_or_binding) and is_nil(fields) ->
        quote do
          query = Builder.ensure_query(unquote(queryable))
          Builder.apply_return(query, unquote(bindings_or_binding), [])
        end

      # return(query, [u], [:name, :age]) - binding with fields
      true ->
        binding =
          case bindings_or_binding do
            [{binding, _, _}] when is_atom(binding) -> binding
            [binding] when is_atom(binding) -> binding
            binding when is_atom(binding) -> binding
          end

        quote do
          query = Builder.ensure_query(unquote(queryable))
          Builder.apply_return(query, unquote(binding), unquote(fields))
        end
    end
  end

  @doc """
  Creates an ORDER BY clause.

  ## Examples

      order_by(query, [u], asc: :name)
      order_by(query, [u], desc: :age)
      order_by(query, [u], asc: :name, desc: :age)
  """
  defmacro order_by(queryable, bindings, orders) do
    binding = extract_single_binding(bindings)

    order_calls =
      Enum.map(orders, fn {direction, field} ->
        quote do
          Builder.apply_order_by(acc, unquote(binding), unquote(field), unquote(direction))
        end
      end)

    quote do
      acc = Builder.ensure_query(unquote(queryable))

      unquote(
        Enum.reduce(order_calls, quote(do: acc), fn call, acc_ast ->
          quote do
            acc = unquote(acc_ast)
            unquote(call)
          end
        end)
      )
    end
  end

  @doc """
  Creates a SKIP clause.

  ## Examples

      skip(query, 10)
  """
  def skip(queryable, value) when is_integer(value) do
    queryable
    |> Builder.ensure_query()
    |> Builder.apply_skip(value)
  end

  @doc """
  Creates a LIMIT clause.

  ## Examples

      limit(query, 25)
  """
  def limit(queryable, value) when is_integer(value) do
    queryable
    |> Builder.ensure_query()
    |> Builder.apply_limit(value)
  end

  @doc """
  Creates a CREATE clause.

  ## Options

    - `:as` - binding name (required)
    - `:set` - map of properties to set

  ## Examples

      User |> create(as: :u, set: %{name: "Alice", age: 30})
  """
  defmacro create(queryable, schema, opts) do
    binding = Keyword.fetch!(opts, :as)
    props = Keyword.get(opts, :set, {:%{}, [], []})
    from = Keyword.get(opts, :from)
    to = Keyword.get(opts, :to)
    direction = Keyword.get(opts, :direction, :out)

    # Dispatch at compile time based on whether :from/:to options are provided.
    # This avoids a runtime `case` on __schema__(:ex4j_type) which triggers
    # unreachable clause warnings from the type checker.
    if from || to do
      quote do
        query = Builder.ensure_query(unquote(queryable))
        module = unquote(schema)

        from_binding =
          unquote(from) ||
            raise ArgumentError,
                  "create/3 with a relationship schema requires :from option"

        to_binding =
          unquote(to) ||
            raise ArgumentError,
                  "create/3 with a relationship schema requires :to option"

        rel_type = module.__schema__(:ex4j_rel_type)

        Builder.apply_create_rel(
          query,
          from_binding,
          unquote(binding),
          rel_type,
          to_binding,
          unquote(direction),
          unquote(props),
          module
        )
      end
    else
      quote do
        query = Builder.ensure_query(unquote(queryable))
        module = unquote(schema)
        labels = module.__schema__(:ex4j_labels)
        Builder.apply_create(query, unquote(binding), labels, unquote(props), module)
      end
    end
  end

  defmacro create(queryable, opts) do
    binding = Keyword.fetch!(opts, :as)
    props = Keyword.get(opts, :set, %{})

    quote do
      query = Builder.ensure_query(unquote(queryable))
      source = query.source

      if source do
        labels = source.__schema__(:ex4j_labels)
        Builder.apply_create(query, unquote(binding), labels, unquote(props), source)
      else
        raise ArgumentError,
              "create/2 requires a source schema. Use create/3 with an explicit schema."
      end
    end
  end

  @doc """
  Creates a MERGE clause.

  ## Options

    - `:as` - binding name (required)
    - `:match` - map of properties to match on

  ## Examples

      User |> merge(as: :u, match: %{email: "alice@example.com"})
  """
  defmacro merge(queryable, schema, opts) do
    binding = Keyword.fetch!(opts, :as)
    props = Keyword.get(opts, :match, %{})

    quote do
      query = Builder.ensure_query(unquote(queryable))
      module = unquote(schema)
      labels = module.__schema__(:ex4j_labels)
      Builder.apply_merge(query, unquote(binding), labels, unquote(props), module)
    end
  end

  defmacro merge(queryable, opts) do
    binding = Keyword.fetch!(opts, :as)
    props = Keyword.get(opts, :match, %{})

    quote do
      query = Builder.ensure_query(unquote(queryable))
      source = query.source

      if source do
        labels = source.__schema__(:ex4j_labels)
        Builder.apply_merge(query, unquote(binding), labels, unquote(props), source)
      else
        raise ArgumentError,
              "merge/2 requires a source schema. Use merge/3 with an explicit schema."
      end
    end
  end

  @doc """
  Creates a SET clause.

  ## Examples

      set(query, [u], :name, "Alice")
      set(query, :u, :name, "Alice")
  """
  def set(queryable, binding, field, value) when is_atom(binding) and is_atom(field) do
    queryable
    |> Builder.ensure_query()
    |> Builder.apply_set(binding, field, value)
  end

  @doc """
  Creates a DELETE clause.

  ## Options

    - `:detach` - if true, generates DETACH DELETE (default: false)

  ## Examples

      delete(query, :u)
      delete(query, :u, detach: true)
  """
  def delete(queryable, binding, opts \\ []) when is_atom(binding) do
    queryable
    |> Builder.ensure_query()
    |> Builder.apply_delete(binding, opts)
  end

  @doc """
  Creates a REMOVE clause.

  ## Examples

      remove(query, :u, :email)
  """
  def remove(queryable, binding, field) when is_atom(binding) and is_atom(field) do
    queryable
    |> Builder.ensure_query()
    |> Builder.apply_remove(binding, field)
  end

  @doc """
  Creates a relationship (edge) pattern between nodes.

  ## Options

    - `:as` - binding for the relationship (required)
    - `:from` - source node binding (required)
    - `:to` - target node binding (required)
    - `:direction` - `:out` (->), `:in` (<-), or `:any` (-) (default: `:out`)
    - `:length` - variable-length range, e.g., `1..3` for `*1..3`

  ## Examples

      edge(query, HasComment, as: :r, from: :u, to: :c, direction: :out)
      edge(query, :KNOWS, as: :r, from: :u, to: :friend, direction: :out, length: 1..3)
  """
  defmacro edge(queryable, rel_schema_or_type, opts) do
    binding = Keyword.fetch!(opts, :as)
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    direction = Keyword.get(opts, :direction, :out)
    length = Keyword.get(opts, :length)

    quote do
      query = Builder.ensure_query(unquote(queryable))

      rel_label = Ex4j.Query.API.__resolve_rel_label__(unquote(rel_schema_or_type))

      Builder.apply_edge(
        query,
        unquote(from),
        unquote(binding),
        rel_label,
        unquote(to),
        nil,
        unquote(direction),
        unquote(length)
      )
    end
  end

  @doc """
  Creates a WITH clause for query chaining/projection.

  ## Examples

      with_query(query, [:u])
      with_query(query, [u], [:u, count: count(u)])
  """
  def with_query(queryable, bindings) when is_list(bindings) do
    query = Builder.ensure_query(queryable)

    selects =
      Enum.map(bindings, fn binding ->
        %SelectExpr{binding: binding, fields: []}
      end)

    Builder.apply_with(query, selects)
  end

  @doc """
  Creates an UNWIND clause.

  ## Examples

      unwind(query, [1, 2, 3], as: :x)
  """
  def unwind(queryable, expr, as: binding) do
    queryable
    |> Builder.ensure_query()
    |> Builder.apply_unwind(expr, binding)
  end

  @doc """
  Creates a UNION between two queries.

  ## Examples

      union(query1, query2)
      union(query1, query2, :all)
  """
  def union(queryable1, queryable2, type \\ :distinct) do
    query1 = Builder.ensure_query(queryable1)
    query2 = Builder.ensure_query(queryable2)
    Builder.apply_union(query1, query2, type)
  end

  @doc """
  Creates a CALL subquery.

  ## Examples

      call(query, subquery)
  """
  def call(queryable, %Query{} = subquery) do
    queryable
    |> Builder.ensure_query()
    |> Builder.apply_call(subquery)
  end

  @doc """
  Creates a dynamic expression for runtime query building.

  ## Examples

      dynamic = dynamic([u], u.age > ^min_age)
      query |> where(^dynamic)

      # Composing dynamics
      d1 = dynamic([u], u.age > ^min_age)
      d2 = dynamic([u], ^d1 and u.city == ^city)
  """
  defmacro dynamic(bindings, expr) do
    binding_names = extract_binding_names(bindings)
    {compiled, params, counter} = Compiler.compile(expr, binding_names, __CALLER__)
    params_ast = build_params_ast(params)

    quote do
      %DynamicExpr{
        expr: unquote(Macro.escape(compiled)),
        params: unquote(params_ast),
        param_counter: unquote(counter)
      }
    end
  end

  @doc """
  Converts a query to its Cypher string representation and params.

  ## Examples

      {cypher, params} = to_cypher(query)
  """
  def to_cypher(queryable) do
    queryable
    |> Builder.ensure_query()
    |> Ex4j.Cypher.to_cypher()
  end

  @doc """
  Returns just the Cypher string for debugging.

  ## Examples

      cypher_string = cypher(query)
  """
  def cypher(queryable) do
    {cypher_str, _params} = to_cypher(queryable)
    cypher_str
  end

  @doc false
  def __resolve_rel_label__(rel_schema_or_type) do
    case rel_schema_or_type do
      module when is_atom(module) ->
        if Code.ensure_loaded?(module) and function_exported?(module, :__schema__, 1) do
          module.__schema__(:ex4j_label)
        else
          module |> Atom.to_string() |> String.trim_leading("Elixir.")
        end

      label when is_binary(label) ->
        label
    end
  end

  # Private helpers

  @valid_match_opts [:as, :schema, :mode, :where]

  defp extract_match_opts(opts) do
    unknown = Keyword.keys(opts) -- @valid_match_opts

    if unknown != [] do
      raise ArgumentError,
            "unknown option(s) #{inspect(unknown)} passed to match/2 or match/3. " <>
              "Valid options are: #{inspect(@valid_match_opts)}"
    end

    binding = Keyword.fetch!(opts, :as)
    schema = Keyword.get(opts, :schema)
    mode = Keyword.get(opts, :mode)
    where = Keyword.get(opts, :where)
    {schema, binding, mode, where}
  end

  defp extract_where_args({:^, _, [inner_var]}, nil) do
    # Extract the variable from inside ^ so we don't re-emit the pin operator
    {:dynamic, inner_var}
  end

  defp extract_where_args(bindings, expr) when is_list(bindings) do
    binding_names = extract_binding_names(bindings)
    {:expr, binding_names, expr}
  end

  defp extract_where_args(bindings, expr) do
    binding_names = extract_binding_names(bindings)
    {:expr, binding_names, expr}
  end

  defp extract_binding_names(bindings) when is_list(bindings) do
    Enum.map(bindings, fn
      {name, _, _} when is_atom(name) -> name
      name when is_atom(name) -> name
    end)
  end

  defp extract_binding_names({name, _, _}) when is_atom(name), do: [name]
  defp extract_binding_names(name) when is_atom(name), do: [name]

  defp extract_single_binding(bindings) when is_list(bindings) do
    case bindings do
      [{name, _, _}] when is_atom(name) -> name
      [name] when is_atom(name) -> name
    end
  end

  defp extract_single_binding({name, _, _}) when is_atom(name), do: name
  defp extract_single_binding(name) when is_atom(name), do: name

  # Builds a quoted map expression that resolves runtime values for params
  defp build_params_ast(params) do
    pairs =
      Enum.map(params, fn
        {key, {var_name, meta, ctx}} when is_atom(var_name) ->
          # This is a pinned variable reference - resolve at runtime
          {key, {var_name, meta, ctx}}

        {key, value} ->
          # Static literal value
          {key, value}
      end)

    {:%{}, [], pairs}
  end
end
