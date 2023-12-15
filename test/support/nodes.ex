defmodule Test.Support.Nodes do
  defmacro __using__(_opts) do
    quote do
      alias Node.{User, Has, Comment}
    end
  end
end
