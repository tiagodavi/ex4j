defmodule Ex4j.Node do
  @moduledoc ~S"""
  Represents a NODE in your Neo4j Database.

  ## Examples

      defmodule Node.User do
        use Ex4j.Node

        graph do
          field(:name, :string)
          field(:age, :integer)
          field(:email, :string)
        end
      end
  """
  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema
      use Ex4j.Cypher

      import Ecto.Changeset

      @primary_key {:uuid, :binary_id, autogenerate: false}

      @type t :: %__MODULE__{}

      import unquote(__MODULE__)

      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      @doc """
      Creates a new Node.

      ## Parameters

        - schema: A schema module
        - props: A map with properties

      ## Examples

          iex> User.new(%User{}, %{"name" => "Tiago"})
          %User{name: "Tiago"}
      """
      def new(schema, props), do: instance(schema, props)
    end
  end

  @doc """
  A graph macro similar to Ecto Schemas.

  https://hexdocs.pm/ecto/Ecto.Schema.html

  ## Examples

      graph do
        field(:name, :string)
        field(:age, :integer)
        field(:email, :string)
        field(:date, :utc_datetime)
      end
  """
  @spec graph(block :: term()) :: term()
  defmacro graph(do: block) do
    quote do
      embedded_schema do
        unquote(block)
      end
    end
  end

  defmacrop instance(schema, props) do
    quote do
      unquote(schema)
      |> cast(unquote(props), __MODULE__.__schema__(:fields))
      |> apply_action(:create)
      |> case do
        {:ok, data} -> data
        _ -> raise "Error creating a new #{inspect(__MODULE__)}"
      end
    end
  end
end
