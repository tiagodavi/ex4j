defmodule Test.Support.Nodes do
  defmacro __using__(_opts) do
    quote do
      alias Test.User
      alias Test.Comment
      alias Test.HasComment
    end
  end
end
