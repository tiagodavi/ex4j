defmodule Test.User do
  use Ex4j.Schema

  node "User" do
    field(:name, :string)
    field(:age, :integer)
    field(:email, :string)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :age, :email])
    |> validate_required([:name, :email])
    |> validate_format(:email, ~r/@/)
    |> validate_inclusion(:age, 18..100)
  end
end
