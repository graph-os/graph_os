defmodule GraphOS.CoreTest do
  use ExUnit.Case
  doctest GraphOS.Core

  test "greets the world" do
    assert GraphOS.Core.hello() == :world
  end
end
