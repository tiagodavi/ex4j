defmodule Test.Comment do
  use Ex4j.Schema

  node "Comment" do
    field(:content, :string)
  end
end
