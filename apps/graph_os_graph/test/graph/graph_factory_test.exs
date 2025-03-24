defmodule GraphOS.Test.Support.GraphFactoryTest do
  use ExUnit.Case

  alias GraphOS.Test.Support.GraphFactory
  alias GraphOS.Store

  test "creates a graph with nodes and edges" do
    # Clean up any existing store
    Store.stop()

    # Use the factory to create a graph
    GraphFactory.create_graph(3, 2, :acyclic)

    # Verify that nodes were created
    {:ok, node1} = Store.get(:node, "1")
    {:ok, node2} = Store.get(:node, "2")
    {:ok, node3} = Store.get(:node, "3")

    assert node1.id == "1"
    assert node2.id == "2"
    assert node3.id == "3"

    # Clean up
    Store.stop()
  end
end
