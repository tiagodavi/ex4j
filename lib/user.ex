defmodule Node.User do
  use Ex4j.Node

  graph do
    field(:name, :string)
    field(:age, :integer)
    field(:email, :string)
  end
end
