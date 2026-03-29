defmodule Ex4j.Schema do
  @moduledoc """
  Defines graph schemas for Neo4j nodes and relationships.

  Schemas map Neo4j graph elements to Elixir structs, providing
  type definitions, validation via Ecto changesets, and metadata
  for query building.

  ## Node Schema

      defmodule MyApp.User do
        use Ex4j.Schema

        node "User" do
          field :name, :string
          field :age, :integer
          field :email, :string
        end

        def changeset(user, attrs) do
          user
          |> cast(attrs, [:name, :age, :email])
          |> validate_required([:name, :email])
        end
      end

  ## Multi-Label Node

      defmodule MyApp.Admin do
        use Ex4j.Schema

        node ["Person", "Admin"] do
          field :name, :string
          field :role, :string
        end
      end

  ## Relationship Schema

      defmodule MyApp.HasComment do
        use Ex4j.Schema

        relationship "HAS_COMMENT" do
          from MyApp.User
          to MyApp.Comment
          field :created_at, :utc_datetime
        end
      end
  """

  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema
      import Ecto.Changeset
      import Ex4j.Schema, only: [node: 2, relationship: 2, from: 1, to: 1]

      @primary_key {:id, :string, autogenerate: false}
      @type t :: %__MODULE__{}

      Module.register_attribute(__MODULE__, :ex4j_type, accumulate: false)
      Module.register_attribute(__MODULE__, :ex4j_labels, accumulate: false)
      Module.register_attribute(__MODULE__, :ex4j_rel_type, accumulate: false)
      Module.register_attribute(__MODULE__, :ex4j_from, accumulate: false)
      Module.register_attribute(__MODULE__, :ex4j_to, accumulate: false)

      @before_compile Ex4j.Schema
    end
  end

  defmacro __before_compile__(env) do
    module = env.module
    type = Module.get_attribute(module, :ex4j_type)
    labels = Module.get_attribute(module, :ex4j_labels) || []
    rel_type = Module.get_attribute(module, :ex4j_rel_type)
    from_schema = Module.get_attribute(module, :ex4j_from)
    to_schema = Module.get_attribute(module, :ex4j_to)

    quote do
      def __schema__(:ex4j_metadata) do
        %Ex4j.Schema.Metadata{
          module: __MODULE__,
          type: unquote(type),
          labels: unquote(labels),
          rel_type: unquote(rel_type),
          from_schema: unquote(from_schema),
          to_schema: unquote(to_schema),
          fields: __MODULE__.__schema__(:fields),
          primary_key: :id
        }
      end

      def __schema__(:ex4j_type), do: unquote(type)
      def __schema__(:ex4j_labels), do: unquote(labels)
      def __schema__(:ex4j_rel_type), do: unquote(rel_type)

      def __schema__(:ex4j_label) do
        case unquote(type) do
          :node -> unquote(labels) |> List.first()
          :relationship -> unquote(rel_type)
        end
      end

      @doc """
      Creates a new struct from a map of properties.
      """
      def new(props) when is_map(props) do
        fields = __MODULE__.__schema__(:fields)

        __MODULE__.__struct__()
        |> cast(props, fields)
        |> apply_action(:create)
        |> case do
          {:ok, data} ->
            data

          {:error, changeset} ->
            raise "Error creating #{inspect(__MODULE__)}: #{inspect(changeset.errors)}"
        end
      end

      def new(schema, props) when is_map(props) do
        fields = __MODULE__.__schema__(:fields)

        schema
        |> cast(props, fields)
        |> apply_action(:create)
        |> case do
          {:ok, data} ->
            data

          {:error, changeset} ->
            raise "Error creating #{inspect(__MODULE__)}: #{inspect(changeset.errors)}"
        end
      end
    end
  end

  @doc """
  Defines a node schema with the given label(s).
  """
  defmacro node(label, do: block) when is_binary(label) do
    quote do
      @ex4j_type :node
      @ex4j_labels [unquote(label)]

      embedded_schema do
        unquote(block)
      end
    end
  end

  defmacro node(labels, do: block) when is_list(labels) do
    quote do
      @ex4j_type :node
      @ex4j_labels unquote(labels)

      embedded_schema do
        unquote(block)
      end
    end
  end

  @doc """
  Defines a relationship schema with the given type.
  """
  defmacro relationship(rel_type, do: block) when is_binary(rel_type) do
    quote do
      @ex4j_type :relationship
      @ex4j_rel_type unquote(rel_type)
      @ex4j_labels [unquote(rel_type)]

      embedded_schema do
        unquote(block)
      end
    end
  end

  @doc """
  Declares the source node of a relationship.
  """
  defmacro from(schema) do
    quote do
      @ex4j_from unquote(schema)
    end
  end

  @doc """
  Declares the target node of a relationship.
  """
  defmacro to(schema) do
    quote do
      @ex4j_to unquote(schema)
    end
  end
end
