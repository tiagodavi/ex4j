defmodule Ex4j.Query.BooleanExpr do
  @moduledoc """
  Represents a boolean expression in a WHERE clause.

  Expression nodes form a tree that represents conditions like
  `u.age > 18 AND u.name = $p0`.
  """

  @type operand ::
          {:field, atom(), atom()}
          | {:param, String.t()}
          | {:literal, term()}
          | {:func, atom(), [operand()]}
          | {:fragment, String.t(), [operand()]}
          | {:binding, atom()}
          | t()

  @type op ::
          :and
          | :or
          | :not
          | :eq
          | :neq
          | :gt
          | :gte
          | :lt
          | :lte
          | :in
          | :not_in
          | :contains
          | :starts_with
          | :ends_with
          | :is_nil
          | :is_not_nil
          | :regex_match

  @type t :: %__MODULE__{
          op: op(),
          left: operand() | nil,
          right: operand() | nil
        }

  defstruct [:op, :left, :right]
end

defmodule Ex4j.Query.SelectExpr do
  @moduledoc """
  Represents a RETURN or WITH expression.
  """

  @type t :: %__MODULE__{
          binding: atom(),
          fields: [atom()],
          alias_as: atom() | nil,
          expr: term() | nil
        }

  defstruct [:binding, :alias_as, :expr, fields: []]
end

defmodule Ex4j.Query.OrderExpr do
  @moduledoc """
  Represents an ORDER BY expression.
  """

  @type t :: %__MODULE__{
          binding: atom(),
          field: atom(),
          direction: :asc | :desc
        }

  defstruct [:binding, :field, direction: :asc]
end

defmodule Ex4j.Query.DynamicExpr do
  @moduledoc """
  Wraps a runtime-built boolean expression for dynamic query composition.

  ## Example

      dynamic = Ex4j.Query.API.dynamic([u], u.age > ^min_age)
      query |> where(^dynamic)
  """

  @type t :: %__MODULE__{
          expr: Ex4j.Query.BooleanExpr.t(),
          params: map(),
          param_counter: non_neg_integer()
        }

  defstruct [:expr, params: %{}, param_counter: 0]
end
