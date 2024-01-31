defmodule Ex4j.CypherTest do
  alias Boltx
  use ExUnit.Case, async: true
  use Test.Support.Nodes
  use Ex4j.Cypher

  test "returns a match query" do
    assert %{match: %{user: "User"}} = match(User, as: :user)
  end

  test "combines match with where clauses" do
    assert %{match: %{user: "User"}, where: %{user: "user.name = 'Tiago'"}} =
             User
             |> match(as: :user)
             |> where(:user, "user.name = 'Tiago'")
  end

  test "returns the cypher version" do
    date = ~U[2023-12-15 00:46:05.140690Z]

    assert "MATCH (user:User WHERE user.name = 'Tiago' OR user.age IN [1,2,3])-[has:Has WHERE has.date > '2023-12-15 00:46:05.140690Z']->(comment:Comment WHERE comment.content CONTAINS 'Article')\nRETURN user,comment,has" ==
             User
             |> match(as: :user)
             |> vertex(Comment, as: :comment)
             |> edge(Has, as: :has, from: :user, to: :comment, type: :out)
             |> where(:user, "user.name = 'Tiago' OR user.age IN [1,2,3]")
             |> where(:comment, "comment.content CONTAINS 'Article'")
             |> where(:has, "has.date > '#{to_string(date)}'")
             |> return(:user)
             |> return(:has)
             |> return(:comment)
             |> cypher()
  end

  describe "execute queries" do
    setup [:truncate]

    test "execute a query directly" do
      {:ok, response} = run("RETURN 300 AS r")
      assert %Boltx.Response{results: [%{"r" => 300}]} = response
    end

    test "execute a query" do
      create_query =
        "CREATE (user:User {name: 'Julee', age: 22, uuid: '70f2b97c-bbed-42ff-92a8-1a5ed950dae7'})"

      run(create_query)

      {:ok, response} = User |> match(as: :user) |> return(:user) |> run()

      assert [
               %{
                 "user" => %Node.User{
                   uuid: "70f2b97c-bbed-42ff-92a8-1a5ed950dae7",
                   name: "Julee",
                   age: 22,
                   email: nil
                 }
               }
             ] = response
    end
  end

  defp truncate(c) do
    {:ok, response} = run("MATCH (n) DETACH DELETE n")
    c
  end
end
