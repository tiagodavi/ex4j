defmodule Ex4j.SchemaTest do
  use ExUnit.Case, async: true
  use Test.Support.Nodes

  describe "node schema" do
    test "creates a struct from properties" do
      user = User.new(%{"name" => "Tiago", "age" => "38", "email" => "tiago@test.com"})
      assert %User{name: "Tiago", age: 38, email: "tiago@test.com"} = user
    end

    test "creates a struct with new/2" do
      user = User.new(%User{}, %{"name" => "Tiago"})
      assert %User{name: "Tiago"} = user
    end

    test "exposes schema metadata" do
      metadata = User.__schema__(:ex4j_metadata)
      assert metadata.type == :node
      assert metadata.labels == ["User"]
      assert metadata.module == Test.User
      assert :name in metadata.fields
      assert :age in metadata.fields
      assert :email in metadata.fields
    end

    test "exposes ex4j_type" do
      assert User.__schema__(:ex4j_type) == :node
    end

    test "exposes ex4j_labels" do
      assert User.__schema__(:ex4j_labels) == ["User"]
    end

    test "exposes ex4j_label" do
      assert User.__schema__(:ex4j_label) == "User"
    end
  end

  describe "relationship schema" do
    test "exposes relationship metadata" do
      metadata = HasComment.__schema__(:ex4j_metadata)
      assert metadata.type == :relationship
      assert metadata.rel_type == "HAS_COMMENT"
      assert metadata.from_schema == Test.User
      assert metadata.to_schema == Test.Comment
    end

    test "exposes ex4j_label for relationship" do
      assert HasComment.__schema__(:ex4j_label) == "HAS_COMMENT"
    end
  end

  describe "changeset validation" do
    test "invalid changeset" do
      changeset = User.changeset(%User{}, %{"name" => "Tiago"})
      refute changeset.valid?
    end

    test "valid changeset" do
      changeset = User.changeset(%User{}, %{"name" => "Tiago", "email" => "someone@gmail.com"})
      assert changeset.valid?
    end

    test "validates email format" do
      changeset = User.changeset(%User{}, %{"name" => "Tiago", "email" => "invalid"})
      refute changeset.valid?
    end
  end
end
