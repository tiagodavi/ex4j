defmodule Ex4jTest do
  use ExUnit.Case
  doctest Ex4j

  test "greets the world" do
    assert Ex4j.hello() == :world
  end
end
