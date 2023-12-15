defmodule Node.User do
  use Ex4j.Node

  graph do
    field(:name, :string)
    field(:age, :integer)
    field(:email, :string)
  end

  def cypher do
    match(__MODULE__, as: :user)
  end

  def changeset(user, params \\ %{}) do
    user
    |> cast(params, [:name, :email, :age])
    |> validate_required([:name, :email])
    |> validate_format(:email, ~r/@/)
    |> validate_inclusion(:age, 18..100)
  end
end
