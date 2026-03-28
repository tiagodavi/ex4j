defmodule Ex4j.CypherTest do
  use ExUnit.Case, async: true
  use Test.Support.Nodes
  import Ex4j.Query.API

  describe "match" do
    test "creates a simple match" do
      {cypher, _params} =
        User
        |> match(as: :u)
        |> return([:u])
        |> to_cypher()

      assert cypher == "MATCH (u:User)\nRETURN u"
    end

    test "creates match with specific schema" do
      {cypher, _} =
        query()
        |> match(User, as: :u)
        |> return([:u])
        |> to_cypher()

      assert cypher == "MATCH (u:User)\nRETURN u"
    end

    test "creates multiple matches" do
      {cypher, _} =
        query()
        |> match(User, as: :u)
        |> match(Comment, as: :c)
        |> return([:u, :c])
        |> to_cypher()

      assert cypher == "MATCH (u:User)\nMATCH (c:Comment)\nRETURN u, c"
    end
  end

  describe "where" do
    test "simple comparison" do
      {cypher, params} =
        query()
        |> match(User, as: :u)
        |> where([u], u.age > 18)
        |> return([:u])
        |> to_cypher()

      assert cypher == "MATCH (u:User)\nWHERE u.age > $p0\nRETURN u"
      assert params["p0"] == 18
    end

    test "equality check" do
      {cypher, params} =
        query()
        |> match(User, as: :u)
        |> where([u], u.name == "Tiago")
        |> return([:u])
        |> to_cypher()

      assert cypher == "MATCH (u:User)\nWHERE u.name = $p0\nRETURN u"
      assert params["p0"] == "Tiago"
    end

    test "pin operator for runtime values" do
      name = "Tiago"

      {cypher, params} =
        query()
        |> match(User, as: :u)
        |> where([u], u.name == ^name)
        |> return([:u])
        |> to_cypher()

      assert cypher == "MATCH (u:User)\nWHERE u.name = $p0\nRETURN u"
      assert params["p0"] == "Tiago"
    end

    test "AND expression" do
      {cypher, params} =
        query()
        |> match(User, as: :u)
        |> where([u], u.age > 18 and u.name == "Tiago")
        |> return([:u])
        |> to_cypher()

      assert cypher == "MATCH (u:User)\nWHERE (u.age > $p0 AND u.name = $p1)\nRETURN u"
      assert params["p0"] == 18
      assert params["p1"] == "Tiago"
    end

    test "OR expression" do
      {cypher, params} =
        query()
        |> match(User, as: :u)
        |> where([u], u.age > 18 or u.name == "Tiago")
        |> return([:u])
        |> to_cypher()

      assert cypher == "MATCH (u:User)\nWHERE (u.age > $p0 OR u.name = $p1)\nRETURN u"
      assert params["p0"] == 18
      assert params["p1"] == "Tiago"
    end

    test "NOT expression" do
      {cypher, _} =
        query()
        |> match(User, as: :u)
        |> where([u], not is_nil(u.email))
        |> return([:u])
        |> to_cypher()

      assert cypher == "MATCH (u:User)\nWHERE NOT u.email IS NULL\nRETURN u"
    end

    test "IS NULL" do
      {cypher, _} =
        query()
        |> match(User, as: :u)
        |> where([u], is_nil(u.email))
        |> return([:u])
        |> to_cypher()

      assert cypher == "MATCH (u:User)\nWHERE u.email IS NULL\nRETURN u"
    end

    test "IN operator" do
      {cypher, params} =
        query()
        |> match(User, as: :u)
        |> where([u], u.age in [18, 25, 30])
        |> return([:u])
        |> to_cypher()

      assert cypher == "MATCH (u:User)\nWHERE u.age IN $p0\nRETURN u"
      assert params["p0"] == [18, 25, 30]
    end

    test "CONTAINS via =~" do
      {cypher, params} =
        query()
        |> match(User, as: :u)
        |> where([u], u.name =~ "Tia")
        |> return([:u])
        |> to_cypher()

      assert cypher == "MATCH (u:User)\nWHERE u.name CONTAINS $p0\nRETURN u"
      assert params["p0"] == "Tia"
    end

    test "STARTS WITH" do
      {cypher, params} =
        query()
        |> match(User, as: :u)
        |> where([u], starts_with(u.name, "T"))
        |> return([:u])
        |> to_cypher()

      assert cypher == "MATCH (u:User)\nWHERE u.name STARTS WITH $p0\nRETURN u"
      assert params["p0"] == "T"
    end

    test "ENDS WITH" do
      {cypher, params} =
        query()
        |> match(User, as: :u)
        |> where([u], ends_with(u.name, "go"))
        |> return([:u])
        |> to_cypher()

      assert cypher == "MATCH (u:User)\nWHERE u.name ENDS WITH $p0\nRETURN u"
      assert params["p0"] == "go"
    end

    test "multiple where clauses are ANDed" do
      {cypher, params} =
        query()
        |> match(User, as: :u)
        |> where([u], u.age > 18)
        |> where([u], u.name == "Tiago")
        |> return([:u])
        |> to_cypher()

      assert cypher == "MATCH (u:User)\nWHERE u.age > $p0 AND u.name = $p1\nRETURN u"
      assert params["p0"] == 18
      assert params["p1"] == "Tiago"
    end

    test "not equal" do
      {cypher, params} =
        query()
        |> match(User, as: :u)
        |> where([u], u.name != "Admin")
        |> return([:u])
        |> to_cypher()

      assert cypher == "MATCH (u:User)\nWHERE u.name <> $p0\nRETURN u"
      assert params["p0"] == "Admin"
    end

    test "less than or equal" do
      {cypher, params} =
        query()
        |> match(User, as: :u)
        |> where([u], u.age <= 65)
        |> return([:u])
        |> to_cypher()

      assert cypher == "MATCH (u:User)\nWHERE u.age <= $p0\nRETURN u"
      assert params["p0"] == 65
    end

    test "greater than or equal" do
      {cypher, params} =
        query()
        |> match(User, as: :u)
        |> where([u], u.age >= 18)
        |> return([:u])
        |> to_cypher()

      assert cypher == "MATCH (u:User)\nWHERE u.age >= $p0\nRETURN u"
      assert params["p0"] == 18
    end
  end

  describe "return" do
    test "returns whole node" do
      {cypher, _} =
        query()
        |> match(User, as: :u)
        |> return([:u])
        |> to_cypher()

      assert cypher == "MATCH (u:User)\nRETURN u"
    end

    test "returns specific fields" do
      {cypher, _} =
        query()
        |> match(User, as: :u)
        |> return(:u, [:name, :age])
        |> to_cypher()

      assert cypher == "MATCH (u:User)\nRETURN u.name, u.age"
    end

    test "returns multiple bindings" do
      {cypher, _} =
        query()
        |> match(User, as: :u)
        |> match(Comment, as: :c)
        |> return([:u, :c])
        |> to_cypher()

      assert cypher == "MATCH (u:User)\nMATCH (c:Comment)\nRETURN u, c"
    end

    test "returns single binding" do
      {cypher, _} =
        query()
        |> match(User, as: :u)
        |> return(:u)
        |> to_cypher()

      assert cypher == "MATCH (u:User)\nRETURN u"
    end
  end

  describe "order_by" do
    test "ascending order" do
      {cypher, _} =
        query()
        |> match(User, as: :u)
        |> return([:u])
        |> order_by([u], asc: :name)
        |> to_cypher()

      assert cypher == "MATCH (u:User)\nRETURN u\nORDER BY u.name"
    end

    test "descending order" do
      {cypher, _} =
        query()
        |> match(User, as: :u)
        |> return([:u])
        |> order_by([u], desc: :age)
        |> to_cypher()

      assert cypher == "MATCH (u:User)\nRETURN u\nORDER BY u.age DESC"
    end

    test "multiple order by" do
      {cypher, _} =
        query()
        |> match(User, as: :u)
        |> return([:u])
        |> order_by([u], asc: :name, desc: :age)
        |> to_cypher()

      assert cypher == "MATCH (u:User)\nRETURN u\nORDER BY u.name, u.age DESC"
    end
  end

  describe "skip and limit" do
    test "limit" do
      {cypher, _} =
        query()
        |> match(User, as: :u)
        |> return([:u])
        |> limit(10)
        |> to_cypher()

      assert cypher == "MATCH (u:User)\nRETURN u\nLIMIT 10"
    end

    test "skip" do
      {cypher, _} =
        query()
        |> match(User, as: :u)
        |> return([:u])
        |> skip(5)
        |> to_cypher()

      assert cypher == "MATCH (u:User)\nRETURN u\nSKIP 5"
    end

    test "skip and limit together" do
      {cypher, _} =
        query()
        |> match(User, as: :u)
        |> return([:u])
        |> skip(10)
        |> limit(25)
        |> to_cypher()

      assert cypher == "MATCH (u:User)\nRETURN u\nSKIP 10\nLIMIT 25"
    end
  end

  describe "create" do
    test "creates a node with properties" do
      {cypher, params} =
        query()
        |> create(User, as: :u, set: %{name: "Alice", age: 30})
        |> return([:u])
        |> to_cypher()

      assert cypher =~ "CREATE (u:User {"
      assert cypher =~ "RETURN u"

      # Params should contain the values
      values = Map.values(params)
      assert "Alice" in values
      assert 30 in values
    end
  end

  describe "merge" do
    test "merges a node with match properties" do
      {cypher, params} =
        query()
        |> merge(User, as: :u, match: %{email: "alice@test.com"})
        |> return([:u])
        |> to_cypher()

      assert cypher =~ "MERGE (u:User {"
      assert cypher =~ "email: $"
      assert cypher =~ "RETURN u"
      assert "alice@test.com" in Map.values(params)
    end
  end

  describe "set" do
    test "sets a property" do
      {cypher, params} =
        query()
        |> match(User, as: :u)
        |> where([u], u.name == "Alice")
        |> set(:u, :age, 31)
        |> return([:u])
        |> to_cypher()

      assert cypher =~ "SET u.age = $"
      assert 31 in Map.values(params)
    end
  end

  describe "delete" do
    test "simple delete" do
      {cypher, _} =
        query()
        |> match(User, as: :u)
        |> where([u], u.name == "Alice")
        |> delete(:u)
        |> to_cypher()

      assert cypher =~ "DELETE u"
      refute cypher =~ "DETACH"
    end

    test "detach delete" do
      {cypher, _} =
        query()
        |> match(User, as: :u)
        |> where([u], u.name == "Alice")
        |> delete(:u, detach: true)
        |> to_cypher()

      assert cypher =~ "DETACH DELETE u"
    end
  end

  describe "remove" do
    test "removes a property" do
      {cypher, _} =
        query()
        |> match(User, as: :u)
        |> remove(:u, :email)
        |> return([:u])
        |> to_cypher()

      assert cypher =~ "REMOVE u.email"
    end
  end

  describe "relationships (edge)" do
    test "outgoing relationship" do
      {cypher, _} =
        query()
        |> match(User, as: :u)
        |> match(Comment, as: :c)
        |> edge(HasComment, as: :r, from: :u, to: :c, direction: :out)
        |> return([:u, :c])
        |> to_cypher()

      assert cypher =~ "-[r:HAS_COMMENT]->"
    end

    test "incoming relationship" do
      {cypher, _} =
        query()
        |> match(User, as: :u)
        |> match(Comment, as: :c)
        |> edge(HasComment, as: :r, from: :u, to: :c, direction: :in)
        |> return([:u, :c])
        |> to_cypher()

      assert cypher =~ "<-[r:HAS_COMMENT]-"
    end

    test "any direction relationship" do
      {cypher, _} =
        query()
        |> match(User, as: :u)
        |> match(Comment, as: :c)
        |> edge(HasComment, as: :r, from: :u, to: :c, direction: :any)
        |> return([:u, :c])
        |> to_cypher()

      assert cypher =~ "-[r:HAS_COMMENT]-"
      refute cypher =~ "->"
      refute cypher =~ "<-"
    end

    test "variable-length relationship" do
      {cypher, _} =
        query()
        |> match(User, as: :u)
        |> match(User, as: :friend)
        |> edge(:KNOWS, as: :r, from: :u, to: :friend, direction: :out, length: 1..3)
        |> return([:u, :friend])
        |> to_cypher()

      assert cypher =~ "[r:KNOWS*1..3]"
    end
  end

  describe "optional match" do
    test "generates OPTIONAL MATCH" do
      {cypher, _} =
        query()
        |> match(User, as: :u)
        |> optional_match(Comment, as: :c)
        |> return([:u, :c])
        |> to_cypher()

      assert cypher =~ "MATCH (u:User)"
      assert cypher =~ "OPTIONAL MATCH (c:Comment)"
    end
  end

  describe "with_query" do
    test "generates WITH clause" do
      {cypher, _} =
        query()
        |> match(User, as: :u)
        |> with_query([:u])
        |> return([:u])
        |> to_cypher()

      assert cypher =~ "WITH u"
    end
  end

  describe "unwind" do
    test "generates UNWIND clause" do
      {cypher, params} =
        query()
        |> unwind([1, 2, 3], as: :x)
        |> return([:x])
        |> to_cypher()

      assert cypher =~ "UNWIND $p0 AS x"
      assert cypher =~ "RETURN x"
      assert params["p0"] == [1, 2, 3]
    end
  end

  describe "union" do
    test "generates UNION" do
      q1 =
        query()
        |> match(User, as: :u)
        |> where([u], u.age > 30)
        |> return(:u, [:name])

      q2 =
        query()
        |> match(User, as: :u)
        |> where([u], u.age < 20)
        |> return(:u, [:name])

      {cypher, _} = union(q1, q2) |> to_cypher()

      assert cypher =~ "UNION"
      refute cypher =~ "UNION ALL"
    end

    test "generates UNION ALL" do
      q1 =
        query()
        |> match(User, as: :u)
        |> return(:u, [:name])

      q2 =
        query()
        |> match(User, as: :u)
        |> return(:u, [:name])

      {cypher, _} = union(q1, q2, :all) |> to_cypher()

      assert cypher =~ "UNION ALL"
    end
  end

  describe "fragment" do
    test "embeds raw Cypher in where" do
      {cypher, params} =
        query()
        |> match(User, as: :u)
        |> where([u], fragment("u.score > duration(?)", "P1Y"))
        |> return([:u])
        |> to_cypher()

      assert cypher =~ "u.score > duration($p0)"
      assert params["p0"] == "P1Y"
    end
  end

  describe "dynamic queries" do
    test "builds dynamic where expression" do
      min_age = 18

      dyn = dynamic([u], u.age > ^min_age)

      {cypher, params} =
        query()
        |> match(User, as: :u)
        |> where(^dyn)
        |> return([:u])
        |> to_cypher()

      assert cypher =~ "WHERE"
      assert cypher =~ "u.age >"
      assert 18 in Map.values(params)
    end

    test "builds dynamic with multiple conditions" do
      name = "Tiago"
      min_age = 18

      dyn = dynamic([u], u.age > ^min_age and u.name == ^name)

      {cypher, params} =
        query()
        |> match(User, as: :u)
        |> where(^dyn)
        |> return([:u])
        |> to_cypher()

      assert cypher =~ "WHERE"
      assert cypher =~ "u.age >"
      assert cypher =~ "u.name ="
      assert 18 in Map.values(params)
      assert "Tiago" in Map.values(params)
    end
  end

  describe "complex queries" do
    test "full read query with relationship" do
      {cypher, params} =
        query()
        |> match(User, as: :u)
        |> match(Comment, as: :c)
        |> edge(HasComment, as: :r, from: :u, to: :c, direction: :out)
        |> where([u], u.name == "Tiago")
        |> where([u], u.age > 18)
        |> return([:u, :c])
        |> order_by([u], desc: :name)
        |> skip(0)
        |> limit(25)
        |> to_cypher()

      assert cypher =~ "MATCH"
      assert cypher =~ "-[r:HAS_COMMENT]->"
      assert cypher =~ "WHERE"
      assert cypher =~ "RETURN u, c"
      assert cypher =~ "ORDER BY u.name DESC"
      assert cypher =~ "SKIP 0"
      assert cypher =~ "LIMIT 25"
      assert "Tiago" in Map.values(params)
      assert 18 in Map.values(params)
    end

    test "create with set and return" do
      {cypher, params} =
        query()
        |> create(User, as: :u, set: %{name: "Alice", age: 30, email: "alice@test.com"})
        |> return([:u])
        |> to_cypher()

      assert cypher =~ "CREATE (u:User {"
      assert cypher =~ "RETURN u"
      values = Map.values(params)
      assert "Alice" in values
      assert 30 in values
      assert "alice@test.com" in values
    end

    test "match, set, return" do
      {cypher, params} =
        query()
        |> match(User, as: :u)
        |> where([u], u.email == "alice@test.com")
        |> set(:u, :name, "Alice Updated")
        |> set(:u, :age, 31)
        |> return([:u])
        |> to_cypher()

      assert cypher =~ "MATCH (u:User)"
      assert cypher =~ "WHERE u.email = $"
      assert cypher =~ "SET u.name = $"
      assert cypher =~ "u.age = $"
      assert cypher =~ "RETURN u"
      values = Map.values(params)
      assert "alice@test.com" in values
      assert "Alice Updated" in values
      assert 31 in values
    end
  end

  describe "cypher helper" do
    test "returns just the cypher string" do
      cypher_str =
        query()
        |> match(User, as: :u)
        |> return([:u])
        |> cypher()

      assert cypher_str == "MATCH (u:User)\nRETURN u"
    end
  end
end
