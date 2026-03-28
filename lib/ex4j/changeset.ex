defmodule Ex4j.Changeset do
  @moduledoc """
  Graph-aware changeset extensions for Ex4j schemas.

  Provides additional validation functions specific to graph database
  operations, complementing Ecto.Changeset.

  ## Example

      def changeset(user, attrs) do
        user
        |> Ecto.Changeset.cast(attrs, [:name, :age, :email])
        |> Ecto.Changeset.validate_required([:name, :email])
        |> Ex4j.Changeset.validate_node_label()
      end
  """

  import Ecto.Changeset

  @doc """
  Validates that the changeset's data module has a valid node label defined.
  """
  @spec validate_node_label(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def validate_node_label(%Ecto.Changeset{data: %{__struct__: module}} = changeset) do
    if function_exported?(module, :__schema__, 1) do
      case module.__schema__(:ex4j_type) do
        :node -> changeset
        :relationship -> changeset
        _ -> add_error(changeset, :base, "schema must define a node or relationship")
      end
    else
      add_error(changeset, :base, "module must use Ex4j.Schema")
    end
  end

  @doc """
  Validates that a property value conforms to Neo4j's supported types.
  Neo4j supports: boolean, integer, float, string, list, point, date,
  time, local time, datetime, local datetime, duration.
  """
  @spec validate_neo4j_type(Ecto.Changeset.t(), atom()) :: Ecto.Changeset.t()
  def validate_neo4j_type(changeset, field) do
    validate_change(changeset, field, fn _, value ->
      if neo4j_compatible?(value) do
        []
      else
        [{field, "value type is not compatible with Neo4j"}]
      end
    end)
  end

  defp neo4j_compatible?(value) when is_binary(value), do: true
  defp neo4j_compatible?(value) when is_integer(value), do: true
  defp neo4j_compatible?(value) when is_float(value), do: true
  defp neo4j_compatible?(value) when is_boolean(value), do: true
  defp neo4j_compatible?(nil), do: true
  defp neo4j_compatible?(value) when is_list(value), do: Enum.all?(value, &neo4j_compatible?/1)
  defp neo4j_compatible?(%Date{}), do: true
  defp neo4j_compatible?(%Time{}), do: true
  defp neo4j_compatible?(%DateTime{}), do: true
  defp neo4j_compatible?(%NaiveDateTime{}), do: true
  defp neo4j_compatible?(_), do: false
end
