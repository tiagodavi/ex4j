defmodule Ex4j.Cypher.Functions do
  @moduledoc """
  Registry of supported Cypher functions.

  These functions can be used inside query expressions and will be
  translated to their Cypher equivalents.
  """

  @aggregation_functions [
    :count,
    :sum,
    :avg,
    :min,
    :max,
    :collect,
    :percentile_cont,
    :percentile_disc,
    :st_dev,
    :st_dev_p
  ]

  @scalar_functions [
    :coalesce,
    :head,
    :last,
    :size,
    :length,
    :type,
    :id,
    :element_id,
    :keys,
    :labels,
    :nodes,
    :relationships,
    :properties,
    :tail,
    :range,
    :reverse,
    :to_string_cypher,
    :to_integer,
    :to_float,
    :to_boolean
  ]

  @string_functions [
    :trim,
    :l_trim,
    :r_trim,
    :to_lower,
    :to_upper,
    :replace,
    :substring,
    :split,
    :left,
    :right
  ]

  @math_functions [
    :abs,
    :ceil,
    :floor,
    :round,
    :rand,
    :sign,
    :sqrt,
    :log,
    :log10,
    :exp,
    :e,
    :pi
  ]

  @temporal_functions [
    :date,
    :datetime,
    :local_datetime,
    :local_time,
    :time,
    :duration,
    :timestamp
  ]

  @spatial_functions [
    :point,
    :distance
  ]

  @list_functions [
    :reduce,
    :extract
  ]

  # Cypher 25 additions
  @cypher25_functions [
    :vector,
    :vector_dimension_count,
    :vector_distance,
    :vector_norm
  ]

  @all_functions @aggregation_functions ++
                   @scalar_functions ++
                   @string_functions ++
                   @math_functions ++
                   @temporal_functions ++
                   @spatial_functions ++
                   @list_functions ++
                   @cypher25_functions

  @doc """
  Returns the list of all supported function names.
  """
  @spec supported_functions() :: [atom()]
  def supported_functions, do: @all_functions

  @doc """
  Returns true if the given function name is a supported Cypher function.
  """
  @spec supported?(atom()) :: boolean()
  def supported?(name), do: name in @all_functions

  @doc """
  Returns true if the function is an aggregation function.
  """
  @spec aggregation?(atom()) :: boolean()
  def aggregation?(name), do: name in @aggregation_functions

  @doc """
  Converts an Elixir function name atom to its Cypher string representation.
  """
  @spec to_cypher_name(atom()) :: String.t()
  def to_cypher_name(:to_string_cypher), do: "toString"
  def to_cypher_name(:to_integer), do: "toInteger"
  def to_cypher_name(:to_float), do: "toFloat"
  def to_cypher_name(:to_boolean), do: "toBoolean"
  def to_cypher_name(:to_lower), do: "toLower"
  def to_cypher_name(:to_upper), do: "toUpper"
  def to_cypher_name(:l_trim), do: "lTrim"
  def to_cypher_name(:r_trim), do: "rTrim"
  def to_cypher_name(:element_id), do: "elementId"
  def to_cypher_name(:local_datetime), do: "localDatetime"
  def to_cypher_name(:local_time), do: "localTime"
  def to_cypher_name(:st_dev), do: "stDev"
  def to_cypher_name(:st_dev_p), do: "stDevP"
  def to_cypher_name(:percentile_cont), do: "percentileCont"
  def to_cypher_name(:percentile_disc), do: "percentileDisc"
  def to_cypher_name(:vector_dimension_count), do: "vector.dimensionCount"
  def to_cypher_name(:vector_distance), do: "vector.distance"
  def to_cypher_name(:vector_norm), do: "vector.norm"
  def to_cypher_name(name), do: Atom.to_string(name)
end
