defmodule GraphOS.GraphTest do
  use ExUnit.Case
  doctest GraphOS.Graph

  test "greets the world" do
    assert GraphOS.Graph.hello() == :world
  end
end
