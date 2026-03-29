defmodule Ex4j.Schema.Metadata do
  @moduledoc """
  Stores compile-time metadata about a schema (node or relationship).
  """

  @type schema_type :: :node | :relationship

  @type t :: %__MODULE__{
          module: module(),
          type: schema_type(),
          labels: [String.t()],
          rel_type: String.t() | nil,
          from_schema: module() | nil,
          to_schema: module() | nil,
          fields: [atom()],
          primary_key: atom()
        }

  defstruct [
    :module,
    :type,
    :rel_type,
    :from_schema,
    :to_schema,
    labels: [],
    fields: [],
    primary_key: :id
  ]
end
