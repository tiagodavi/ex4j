defmodule Ex4j.Repo.Result do
  @moduledoc """
  Hydrates raw Bolt response data into Ex4j.Schema structs.
  """

  alias Ex4j.Query

  @doc """
  Hydrates a list of result rows using the query's alias mapping.
  """
  @spec hydrate([map()], Query.t()) :: [map()]
  def hydrate(results, %Query{aliases: aliases}) when is_list(results) do
    Enum.map(results, fn row ->
      hydrate_row(row, aliases)
    end)
  end

  def hydrate(results, _query) when is_list(results), do: results

  defp hydrate_row(row, aliases) when is_map(row) do
    Enum.reduce(row, %{}, fn {key, value}, acc ->
      binding = if is_binary(key), do: String.to_atom(key), else: key
      schema_module = Map.get(aliases, binding)

      hydrated_value =
        cond do
          schema_module != nil and is_map(value) and has_properties?(value) ->
            hydrate_node_or_rel(value, schema_module)

          schema_module != nil and is_map(value) ->
            try do
              schema_module.new(stringify_keys(value))
            rescue
              _ -> value
            end

          true ->
            value
        end

      Map.put(acc, key, hydrated_value)
    end)
  end

  defp hydrate_row(row, _aliases), do: row

  defp has_properties?(map) do
    Map.has_key?(map, :properties) or Map.has_key?(map, "properties")
  end

  defp hydrate_node_or_rel(data, schema_module) do
    properties = Map.get(data, :properties) || Map.get(data, "properties") || %{}

    try do
      schema_module.new(stringify_keys(properties))
    rescue
      _ -> data
    end
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {key, value}
    end)
  end
end
