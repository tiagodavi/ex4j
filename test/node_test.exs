defmodule Ex4j.NodeTest do
  use ExUnit.Case, async: true
  use Test.Support.Nodes

  test "creates a standard ecto structure" do
    assert %User{name: "Tiago"} = User.new(%User{}, %{"name" => "Tiago"})
  end

  test "nodes have cypher functions" do
    assert %{match: %{user: "User"}} = User.cypher()
  end

  test "validates node as ecto" do
    changeset = User.changeset(%User{}, %{"name" => "Tiago"})
    refute changeset.valid?

    changeset = User.changeset(%User{}, %{"name" => "Tiago", "email" => "someone@gmail.com"})
    assert changeset.valid?
  end
end
