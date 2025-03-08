defmodule GraphOS.DistributedTest do
  use ExUnit.Case
  doctest GraphOS.Distributed

  test "greets the world" do
    assert GraphOS.Distributed.hello() == :world
  end
end
