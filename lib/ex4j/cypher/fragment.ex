defmodule Ex4j.Cypher.Fragment do
  @moduledoc """
  Handles raw Cypher fragments with parameter binding.

  Fragments allow embedding raw Cypher when the DSL doesn't cover
  a specific use case. Parameters are bound via `?` placeholders.

  ## Example

      fragment("u.score > duration(?)", "P1Y")
      # Produces: u.score > duration($p0)

      fragment("point.distance(u.location, point({latitude: ?, longitude: ?}))", lat, lon)
      # Produces: point.distance(u.location, point({latitude: $p0, longitude: $p1}))
  """

  @doc """
  Renders a fragment template by replacing `?` placeholders with
  parameter references from the compiled args.
  """
  @spec render(String.t(), [term()]) :: String.t()
  def render(template, args) do
    {result, _} =
      template
      |> String.graphemes()
      |> Enum.reduce({"", args}, fn
        "?", {acc, [arg | rest]} ->
          {acc <> render_arg(arg), rest}

        char, {acc, args} ->
          {acc <> char, args}
      end)

    result
  end

  defp render_arg({:param, key}), do: "$#{key}"
  defp render_arg({:field, binding, field}), do: "#{binding}.#{field}"
  defp render_arg({:literal, nil}), do: "null"
  defp render_arg({:literal, value}), do: inspect(value)

  defp render_arg({:func, name, args}) do
    cypher_name = Ex4j.Cypher.Functions.to_cypher_name(name)
    arg_strs = Enum.map(args, &render_arg/1) |> Enum.join(", ")
    "#{cypher_name}(#{arg_strs})"
  end

  defp render_arg({:binding, binding}), do: "#{binding}"
  defp render_arg(other), do: "#{inspect(other)}"
end
