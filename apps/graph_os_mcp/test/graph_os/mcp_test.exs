defmodule GraphOS.MCPTest do
  use ExUnit.Case
  doctest GraphOS.MCP

  test "greets the world" do
    assert GraphOS.MCP.hello() == :world
  end
end
