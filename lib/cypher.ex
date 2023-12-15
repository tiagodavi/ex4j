defmodule Ex4j.Cypher do
  @moduledoc """
  DSL to turn elixir code into Cypher Language.
  """
  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)
    end
  end

  @doc """
  Creates a MATCH clause.

  ## Parameters

    - module: The name of the Node
    - as: The alias of the Node

  ## Examples

      iex> match(Node.User, as: :user)
      %{match: %{user: "User"}}

      iex> query = match(Node.User, as: :user)
      iex> match(query, Node.Comment, as: :comment)
      %{match: %{user: "User", comment: "Comment"}}

  ## Cypher

      MATCH(user:User)
      MATCH(comment:Comment)
  """
  @spec match(module :: module(), keyword()) :: map()
  def match(module, as: label) when is_atom(module) and is_atom(label) do
    %{match: %{label => resolve_module(module)}}
  end

  @spec match(query :: map(), module :: module(), keyword()) :: map()
  def match(query, module, as: label) when is_map(query) and is_atom(label) do
    put_in(query, [:match, label], module)
  end

  @doc """
  Creates a WHERE clause.

  ## Parameters

    - query: The previous query
    - label: The alias of the Node
    - rules: The String rules

  ## Examples

      iex> query = match(Node.User, as: :user)
      iex> where(query, :user, "user.name = 'Tiago' AND user.age = 38")
      %{
        match: %{user: "User"},
        where: %{user: "user.name = 'Tiago' AND user.age = 38"}
      }

      iex> query = match(Node.User, as: :user)
      iex> where(query, :user, "user.name = 'Tiago' OR user.age IN [38]")
      %{
        match: %{user: "User"},
        where: %{user: "user.name = 'Tiago' OR user.age IN [38]"}
      }

  ## Cypher

      MATCH(user:User WHERE user.age = 38 AND user.name = 'Tiago')
      MATCH(user:User WHERE user.name = 'Tiago' OR user.age IN [38])
  """
  @spec where(query :: map(), label :: atom(), rules :: String.t()) :: map()
  def where(query, label, rules) do
    where =
      query
      |> Map.get(:where, %{})
      |> Map.put(label, rules)

    Map.put(query, :where, where)
  end

  @doc """
  Creates a RETURN clause.

  ## Parameters

    - query: The previous query
    - label: The alias of the Node
    - props: An optional list of properties to return

  ## Examples

      iex> query = match(Node.User, as: :user)
      iex> return(query, :user)
      %{return: %{user: []}, match: %{user: "User"}}

      iex> query = match(Node.User, as: :user)
      iex> return(query, :user, [:age, name])
      %{return: %{user: [:age, :name]}, match: %{user: "User"}}

      iex> query = match(Node.User, as: :user)
      iex> query = match(query, Node.Comment, as: :comment)
      iex> query = return(query, :user, [:age, :name])
      iex> return(query, :comment, [:text])
      %{
          return: %{user: [:age, :name], comment: [:text]},
          match: %{user: "User", comment: "Comment"}
      }

  ## Cypher

      MATCH(user:User)
      MATCH(comment:Comment)
      RETURN user, comment

      MATCH(user:User)
      MATCH(comment:Comment)
      RETURN user.name, user.age, comment.text
  """
  @spec return(query :: map(), label :: atom(), props :: list()) :: map()
  def return(query, label, props \\ []) when is_map(query) and is_atom(label) do
    return =
      query
      |> Map.get(:return, %{})
      |> Map.put(label, props)

    Map.put(query, :return, return)
  end

  @doc """
  Creates a LIMIT clause.

  ## Parameters

    - query: The previous query
    - limit: The limit value

  ## Examples

      iex> query = match(User, as: :user)
      iex> query = return(query, :user)
      iex> limit(query, 10)
      %{return: %{user: []}, match: %{user: "User"}, limit: 10}

  ## Cypher

      MATCH(user:User)
      RETURN user
      LIMIT 10
  """
  @spec limit(query :: map(), limit :: integer()) :: map()
  def limit(query, limit) do
    Map.put(query, :limit, limit)
  end

  @doc """
  Creates an EDGE.

  ## Parameters

    - query: The previous query
    - module: The name of the Node
    - as: The alias of the Node
    - from: Start point
    - to: End point
    - type:
      - :out (->)
      - :in  (<-)
      - :any (-)

  ## Examples

      iex> query = match(Node.User, as: :user)
      iex> query = vertex(query, Node.Comment, as: :comment)
      iex> query = edge(query, HAS, as: :h, from: :user, to: :comment, type: :any)
      iex> query = where(query, :user, "user.name = 'Tiago'"])
      iex> query = where(query, :h, "h.value = 42")
      iex> return(query, :comment, [:text])
      %{
        match: %{user: "User"},
        vertex: %{comment: "Comment"},
        where: %{
          user: "user.name = 'Tiago'",
          h: "h.value = 42"
        },
        edge: %{
          user: %{module: HAS, type: :any, to: :comment, label: :h}
        },
        return: %{comment: [:text]}
      }

  ## Cypher

      MATCH (user:User WHERE user.name = 'Tiago')-[h:HAS WHERE h.value = 42]-(comment:Comment)
      RETURN comment.text
  """
  @spec edge(query :: map(), module :: atom(), keyword()) :: map()
  def edge(query, module, as: label, from: from, to: to, type: type)
      when is_map(query) and
             is_atom(module) and
             is_atom(label) and
             is_atom(from) and
             is_atom(to) and
             is_atom(type) do
    edge =
      query
      |> Map.get(:edge, %{})
      |> Map.put(from, %{module: resolve_module(module), label: label, to: to, type: type})

    Map.put(query, :edge, edge)
  end

  @doc """
  Creates a VERTEX.

  ## Parameters

    - query: The previous query
    - module: The name of the Node
    - as: The alias of the Node

  ## Examples

      iex> query = match(Node.User, as: :user)
      iex> query = vertex(query, Node.Comment, as: :comment)
      iex> query = edge(query, HAS, as: :h, from: :user, to: :comment, type: :any)
      iex> query = where(query, :user, "user.name = 'Tiago'")
      iex> query = where(query, :comment, "comment.value IN [1,2,3]")
      iex> query = where(query, :h, "h.total = 10")
      iex> return(query, :user)
      %{
          match: %{user: "User"},
          where: %{
            user:  "user.name = 'Tiago'",
            h: "h.total = 10",
            comment: "comment.value IN [1, 2, 3]"
          },
          edge: %{user: %{module: HAS, type: :any, to: :comment, label: :h}},
          vertex: %{comment: "Comment"},
          return: %{user: []}
      }

  ## Cypher

      MATCH (user:User WHERE user.name = 'Tiago')-[h:HAS WHERE h.total = 10]-(comment:Comment WHERE comment.value in [1,2,3])
      RETURN user
  """
  @spec vertex(query :: map(), module :: atom(), keyword()) :: map()
  def vertex(query, module, as: label)
      when is_map(query) and
             is_atom(module) and
             is_atom(label) do
    vertex =
      query
      |> Map.get(:vertex, %{})
      |> Map.put(label, resolve_module(module))

    Map.put(query, :vertex, vertex)
  end

  @doc """
  Build and execute the query.

  ## Parameters

    - query: Either the dynamic query or a string cypher query

  ## Examples

      iex> query = match(Node.User, as: :user)
      iex> query = return(query, :user)
      iex> run(query)
      [%{"user" => %Node.User{uuid: nil, name: "Tiago", age: 38, email: nil}}]

      iex> query = \"""
                    MATCH (user:User WHERE user.name = 'Tiago')
                    RETURN user
                   \"""
      iex> run(query)
      [%{"user" => %Node.User{uuid: nil, name: "Tiago", age: 38, email: nil}}]
  """
  @spec run(query :: map() | String.t()) :: any()
  def run(query) when is_map(query) do
    conn = Bolt.Sips.conn()

    if is_pid(conn) do
      conn
      |> Bolt.Sips.query(build(query))
      |> build_response()
    else
      raise "Neo4j: connection failure"
    end
  end

  def run(query) when is_binary(query) do
    conn = Bolt.Sips.conn()

    if is_pid(conn) do
      Bolt.Sips.query(conn, query)
    else
      raise "Neo4j: connection failure"
    end
  end

  @doc """
  Returns the Cypher query.

  ## Parameters

    - query: Either the dynamic query or a string cypher query

  ## Examples

      iex> query = match(User, as: :user)
      iex> query = return(query, :user)
      iex> cypher(query)
      "MATCH (user:User) RETURN user"

      iex> cypher("MATCH (user:User) RETURN user")
      "MATCH (user:User) RETURN user"
  """
  @spec cypher(query :: map() | String.t()) :: String.t()
  def cypher(query) do
    if is_map(query) do
      build(query)
    else
      query
    end
  end

  defp build(%{match: match} = query) do
    match
    |> Enum.reduce([], fn {key, val}, acc ->
      acc ++
        [
          "MATCH (#{_to_string(key)}:#{_to_string(val)}#{build_rules(query, key)})#{build_edge(query, key)}"
          |> String.replace(" WHERE )", ")")
          |> String.replace(" WHERE ]", "]")
        ]
    end)
    |> build_return(query)
    |> build_limit(query)
  end

  defp build(_), do: ""

  defp build_edge(%{edge: edge} = query, key) do
    edge = Map.get(edge, key, %{})

    if map_size(edge) > 0 do
      "-[#{_to_string(edge.label)}:#{_to_string(edge.module)}#{build_rules(query, edge.label)}]#{build_vertex(query, edge)}"
    else
      ""
    end
  end

  defp build_edge(_query, _key), do: ""

  defp build_vertex(%{vertex: vertex} = query, edge) do
    vertex = Map.get(vertex, edge.to)

    if vertex do
      "#{edge_type(edge.type)}(#{_to_string(edge.to)}:#{_to_string(vertex)}#{build_rules(query, edge.to)})#{build_edge(query, edge.to)}"
    else
      ""
    end
  end

  defp build_vertex(_query, _key), do: ""

  defp build_rules(%{where: where}, key) do
    rules = Map.get(where, key, "")

    Enum.join([" WHERE ", rules])
  end

  defp build_rules(_query, _key), do: ""

  defp build_return(elements, %{return: return}) do
    element =
      Enum.reduce(return, "", fn
        {key, props}, acc ->
          if length(props) > 0 do
            acc <>
              Enum.reduce(props, "", fn val, acc ->
                acc <> ",#{_to_string(key)}.#{val}"
              end)
          else
            acc <> ",#{_to_string(key)}"
          end

        _, acc ->
          acc
      end)

    Enum.concat([elements, ["RETURN #{element}"]])
    |> Enum.join("\n")
    |> String.replace("RETURN ,", "RETURN ")
  end

  defp build_return(elements, _query) do
    """
    #{Enum.join(elements)}
    """
  end

  defp build_limit(str, %{limit: limit}) do
    [str]
    |> Enum.concat(["LIMIT #{limit}"])
    |> Enum.join("\n")
  end

  defp build_limit(str, _query), do: str

  defp build_response({:ok, %{results: results}}) do
    Enum.map(results, fn result ->
      Enum.reduce(result, %{}, &prepare_response/2)
    end)
  end

  defp build_response({:error, _reason} = response), do: response

  defp prepare_response(
         {key, %Bolt.Sips.Types.Node{properties: properties, labels: [label]}},
         acc
       ) do
    module = _to_module(label)

    Map.put(acc, key, apply(module, :new, [module.__struct__(), properties]))
  end

  defp prepare_response(
         {key, %Bolt.Sips.Types.Relationship{properties: properties, type: type}},
         acc
       ) do
    module = _to_module(type)

    Map.put(acc, key, apply(module, :new, [module.__struct__(), properties]))
  end

  defp prepare_response({key, val}, acc) when is_binary(key) and is_binary(val) do
    [key, prop] = String.split(key, ".")

    schema =
      acc
      |> Map.get(key, %{})
      |> Map.put(prop, val)

    Map.put(acc, key, schema)
  end

  defp prepare_response(_, acc), do: acc

  defp edge_type(:any), do: "-"
  defp edge_type(:out), do: "->"
  defp edge_type(:in), do: "<-"
  defp edge_type(_), do: ""

  defp _to_string(item) do
    item
    |> to_string()
    |> String.replace("Elixir.", "")
  end

  defp _to_module(item) do
    ["Elixir.Node.", String.capitalize(item)]
    |> Enum.join()
    |> String.to_existing_atom()
  end

  defp resolve_module(module) do
    module
    |> Module.split()
    |> List.last()
  end
end
