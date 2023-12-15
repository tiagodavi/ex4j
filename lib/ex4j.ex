defmodule Ex4j do
  @moduledoc """
  Combine the power of Ecto with the Bolt protocol + an elegant DSL for Neo4J databases.

  ## Settings

    Add the dependency:

      def deps do
        [
          {:ex4j, "~> 0.1.0"}
        ]
      end

     Add the configuration:

      config :ex4j, Bolt,
        url: "bolt://localhost:7687",
        basic_auth: [username: "neo4j", password: "zEb0zryxK62NNRXKWxJKd7qeEFkO3mLIgcGwuUA4lvg"],
        pool_size: 10,
        ssl: false

  ## Examples

      defmodule Node.User do
        use Ex4j.Node

        graph do
          field(:name, :string)
          field(:age, :integer)
          field(:email, :string)
        end
      end

      defmodule Node.Has do
        use Ex4j.Node

        graph do
          field(:date, :utc_datetime)
        end
      end

      defmodule Node.Comment do
        use Ex4j.Node

        graph do
          field(:content, :string)
        end
      end

      defmodule App do
        use Ex4j.Cypher

        alias Node.{User, Has, Comment}

        def execute do
          User
          |> match(as: :user)
          |> vertex(Comment, as: :comment)
          |> edge(Has, as: :has, from: :user, to: :comment, type: :out)
          |> where(:user, "user.name = 'Tiago' OR user.age IN [1,2,3]")
          |> where(:comment, "comment.content CONTAINS 'Article'")
          |> where(:has, "has.date > date('2019-09-30')")
          |> return(:user)
          |> return(:has)
          |> return(:comment)
          |> run()
        end
      end

  ## Cypher

      MATCH (user:User WHERE user.name = 'Tiago' OR user.age IN [1,2,3])-[has:Has WHERE has.date > date('2019-09-30')]->(comment:Comment WHERE comment.content CONTAINS 'Article')
      RETURN user, has, comment
  """
end
