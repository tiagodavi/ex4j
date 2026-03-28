defmodule Ex4j.Query.Compiler do
  @moduledoc """
  Compiles Elixir AST expressions into `%BooleanExpr{}` trees.

  This module walks the quoted Elixir AST from macro calls like `where/2`
  and translates operators, field accesses, function calls, and literals
  into expression structs that the Cypher generator can process.

  ## Supported Patterns

  - Field access: `u.name` -> `{:field, :u, :name}`
  - Pin operator: `^var` -> `{:param, key}` (runtime value)
  - Comparison: `==`, `!=`, `>`, `>=`, `<`, `<=`
  - Boolean: `and`, `or`, `not`
  - Membership: `in`
  - String matching: `=~` (CONTAINS)
  - Functions: `is_nil/1`, `count/1`, `starts_with/2`, `ends_with/2`, etc.
  - Fragments: `fragment("cypher ?", value)`
  - Literals: integers, floats, strings, booleans, lists, nil
  """

  alias Ex4j.Query.BooleanExpr

  @comparison_ops [:==, :!=, :>, :>=, :<, :<=]
  @boolean_ops [:and, :or]

  @doc """
  Compiles a quoted expression into a `{expr_ast, params_ast}` tuple
  that can be unquoted back into the caller's context.

  Returns quoted code that, when evaluated, produces
  `{%BooleanExpr{}, %{params}, param_counter}`.
  """
  def compile(expr, bindings, _env) do
    {compiled, params, counter} = do_compile(expr, bindings, %{}, 0)
    {compiled, params, counter}
  end

  # Field access: u.name -> {:field, :u, :name}
  defp do_compile({{:., _, [{binding, _, _}, field]}, _, _}, bindings, params, counter)
       when is_atom(binding) and is_atom(field) do
    if binding in bindings do
      {{:field, binding, field}, params, counter}
    else
      raise CompileError,
        description:
          "Unknown binding `#{binding}` in expression. Known bindings: #{inspect(bindings)}"
    end
  end

  # Pin operator: ^var -> runtime parameter
  defp do_compile({:^, _, [{var_name, _, _}]}, _bindings, params, counter) do
    key = "p#{counter}"
    params = Map.put(params, key, {var_name, [], nil})
    {{:param, key}, params, counter + 1}
  end

  # Boolean operators: and, or
  defp do_compile({op, _, [left, right]}, bindings, params, counter) when op in @boolean_ops do
    {left_compiled, params, counter} = do_compile(left, bindings, params, counter)
    {right_compiled, params, counter} = do_compile(right, bindings, params, counter)

    cypher_op =
      case op do
        :and -> :and
        :or -> :or
      end

    {%BooleanExpr{op: cypher_op, left: left_compiled, right: right_compiled}, params, counter}
  end

  # Comparison operators: ==, !=, >, >=, <, <=
  defp do_compile({op, _, [left, right]}, bindings, params, counter)
       when op in @comparison_ops do
    {left_compiled, params, counter} = do_compile(left, bindings, params, counter)
    {right_compiled, params, counter} = do_compile(right, bindings, params, counter)

    cypher_op =
      case op do
        :== -> :eq
        :!= -> :neq
        :> -> :gt
        :>= -> :gte
        :< -> :lt
        :<= -> :lte
      end

    {%BooleanExpr{op: cypher_op, left: left_compiled, right: right_compiled}, params, counter}
  end

  # `in` operator
  defp do_compile({:in, _, [left, right]}, bindings, params, counter) do
    {left_compiled, params, counter} = do_compile(left, bindings, params, counter)
    {right_compiled, params, counter} = do_compile(right, bindings, params, counter)
    {%BooleanExpr{op: :in, left: left_compiled, right: right_compiled}, params, counter}
  end

  # `not in` operator
  defp do_compile({:not, _, [{:in, _, [left, right]}]}, bindings, params, counter) do
    {left_compiled, params, counter} = do_compile(left, bindings, params, counter)
    {right_compiled, params, counter} = do_compile(right, bindings, params, counter)
    {%BooleanExpr{op: :not_in, left: left_compiled, right: right_compiled}, params, counter}
  end

  # `not` operator
  defp do_compile({:not, _, [expr]}, bindings, params, counter) do
    {compiled, params, counter} = do_compile(expr, bindings, params, counter)
    {%BooleanExpr{op: :not, left: compiled, right: nil}, params, counter}
  end

  # =~ operator (CONTAINS)
  defp do_compile({:=~, _, [left, right]}, bindings, params, counter) do
    {left_compiled, params, counter} = do_compile(left, bindings, params, counter)
    {right_compiled, params, counter} = do_compile(right, bindings, params, counter)
    {%BooleanExpr{op: :contains, left: left_compiled, right: right_compiled}, params, counter}
  end

  # is_nil/1
  defp do_compile({:is_nil, _, [expr]}, bindings, params, counter) do
    {compiled, params, counter} = do_compile(expr, bindings, params, counter)
    {%BooleanExpr{op: :is_nil, left: compiled, right: nil}, params, counter}
  end

  # starts_with/2
  defp do_compile({:starts_with, _, [left, right]}, bindings, params, counter) do
    {left_compiled, params, counter} = do_compile(left, bindings, params, counter)
    {right_compiled, params, counter} = do_compile(right, bindings, params, counter)
    {%BooleanExpr{op: :starts_with, left: left_compiled, right: right_compiled}, params, counter}
  end

  # ends_with/2
  defp do_compile({:ends_with, _, [left, right]}, bindings, params, counter) do
    {left_compiled, params, counter} = do_compile(left, bindings, params, counter)
    {right_compiled, params, counter} = do_compile(right, bindings, params, counter)
    {%BooleanExpr{op: :ends_with, left: left_compiled, right: right_compiled}, params, counter}
  end

  # fragment/1+ - raw Cypher with parameter binding
  defp do_compile({:fragment, _, [cypher_str | args]}, bindings, params, counter)
       when is_binary(cypher_str) do
    {compiled_args, params, counter} =
      Enum.reduce(args, {[], params, counter}, fn arg, {acc, params, counter} ->
        {compiled, params, counter} = do_compile(arg, bindings, params, counter)
        {acc ++ [compiled], params, counter}
      end)

    {{:fragment, cypher_str, compiled_args}, params, counter}
  end

  # Cypher functions: count/1, sum/1, avg/1, collect/1, etc.
  defp do_compile({func_name, _, args}, bindings, params, counter)
       when is_atom(func_name) and is_list(args) do
    if func_name in Ex4j.Cypher.Functions.supported_functions() do
      {compiled_args, params, counter} =
        Enum.reduce(args, {[], params, counter}, fn arg, {acc, params, counter} ->
          {compiled, params, counter} = do_compile(arg, bindings, params, counter)
          {acc ++ [compiled], params, counter}
        end)

      {{:func, func_name, compiled_args}, params, counter}
    else
      # Treat as a variable reference
      key = "p#{counter}"
      params = Map.put(params, key, {func_name, [], args})
      {{:param, key}, params, counter + 1}
    end
  end

  # Literals
  defp do_compile(value, _bindings, params, counter)
       when is_integer(value) or is_float(value) or is_binary(value) or is_boolean(value) do
    key = "p#{counter}"
    params = Map.put(params, key, value)
    {{:param, key}, params, counter + 1}
  end

  defp do_compile(nil, _bindings, params, counter) do
    {{:literal, nil}, params, counter}
  end

  # List literals
  defp do_compile(list, bindings, params, counter) when is_list(list) do
    key = "p#{counter}"
    # If the list contains only literals, store directly
    if Enum.all?(list, &is_literal?/1) do
      params = Map.put(params, key, list)
      {{:param, key}, params, counter + 1}
    else
      # Compile each element
      {compiled_elements, params, counter} =
        Enum.reduce(list, {[], params, counter}, fn elem, {acc, params, counter} ->
          {compiled, params, counter} = do_compile(elem, bindings, params, counter)
          {acc ++ [compiled], params, counter}
        end)

      {{:list, compiled_elements}, params, counter}
    end
  end

  # Catch-all for unrecognized AST (treat as runtime param)
  defp do_compile(ast, _bindings, params, counter) do
    key = "p#{counter}"
    params = Map.put(params, key, ast)
    {{:param, key}, params, counter + 1}
  end

  defp is_literal?(value) when is_integer(value), do: true
  defp is_literal?(value) when is_float(value), do: true
  defp is_literal?(value) when is_binary(value), do: true
  defp is_literal?(value) when is_boolean(value), do: true
  defp is_literal?(nil), do: true
  defp is_literal?(_), do: false
end
