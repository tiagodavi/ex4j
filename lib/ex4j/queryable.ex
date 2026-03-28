defprotocol Ex4j.Queryable do
  @moduledoc """
  Protocol for converting data structures into `%Ex4j.Query{}`.

  Any type implementing this protocol can be used as the starting
  point of a query pipeline.

  ## Built-in Implementations

  - `Ex4j.Query` - identity (returns itself)
  - `Atom` - schema modules that define `__schema__(:ex4j_metadata)`
  """

  @doc """
  Converts the given data structure into an `%Ex4j.Query{}`.
  """
  @spec to_query(t) :: Ex4j.Query.t()
  def to_query(data)
end

defimpl Ex4j.Queryable, for: Ex4j.Query do
  def to_query(query), do: query
end

defimpl Ex4j.Queryable, for: Atom do
  def to_query(module) when is_atom(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :__schema__, 1) do
      # Validate the module has Ex4j metadata
      _metadata = module.__schema__(:ex4j_metadata)

      %Ex4j.Query{
        source: module,
        aliases: %{}
      }
    else
      raise ArgumentError,
            "#{inspect(module)} is not a valid Ex4j schema. " <>
              "Ensure the module uses `use Ex4j.Schema` and defines a node or relationship."
    end
  end
end
